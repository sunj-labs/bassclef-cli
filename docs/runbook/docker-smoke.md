---
tier: standard
runbook_id: docker-smoke
authored: 2026-09-20
session_id: 2026-09-20b
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
invocation_stability: frozen per ADR-031 at V1 (RFC-0001 R1 cure)
---

# Docker cold-adopter smoke — runbook

## Invocation contract

The commands below are stable across cli minor versions per ADR-031. Copy-paste flows depend on this shape. Any change ships with a compat shim.

## Preflight (do this once per session)

Run these three checks before you invoke the harness. Each has a specific remediation if it fails.

```bash
# 1. Docker installed?
command -v docker || {
  echo "MISSING: docker not on PATH. Install OrbStack (macOS) or Docker Engine (Linux)."
  exit 1
}

# 2. Docker daemon running?
docker info >/dev/null 2>&1 || {
  echo "MISSING: docker daemon not responding. Start OrbStack app or Docker Desktop."
  exit 1
}

# 3. Claude auth set? (V2 skill drive only; V1 tolerates missing)
# Per #184: V2 accepts EITHER ANTHROPIC_API_KEY (metered) OR
# CLAUDE_CODE_OAUTH_TOKEN (Claude subscription). Prefer OAuth when both set.
[[ -n "${ANTHROPIC_API_KEY:-}" || -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] || {
  echo "WARN: neither ANTHROPIC_API_KEY nor CLAUDE_CODE_OAUTH_TOKEN is set."
  echo "      V1 harness runs; V2 skill drive will exit 25."
  echo "      Subscription path: run 'claude setup-token' on host + export CLAUDE_CODE_OAUTH_TOKEN."
  echo "      Metered path: export ANTHROPIC_API_KEY=<key>."
}
```

## Single-command invocation

Build the image, then run the container. Two commands. That is the contract.

```bash
# Build once per session (or after harness/ changes)
docker build \
  --platform=linux/amd64 \
  -t bassclef-cli-cold-adopter \
  -f harness/docker/Dockerfile.cold-adopter \
  .

# Run against a specific cli version (default: latest on npm)
# Pass BOTH auth env vars. Harness preflight prefers OAuth (subscription)
# when both are set; runs bill against the Claude subscription, not metered API.
docker run \
  --rm \
  --platform=linux/amd64 \
  -e CLI_VERSION="${CLI_VERSION:-latest}" \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  -e CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}" \
  bassclef-cli-cold-adopter
```

## Auth paths (V2 skill drive)

Two paths, prefer OAuth. Per #184.

**Path A — Claude subscription (recommended when you hold one).**

1. On the host, one-time: `claude setup-token` — opens a browser flow, prints a long-lived token.
2. `export CLAUDE_CODE_OAUTH_TOKEN=<token>` in your shell (or add to `~/.zshrc` / `~/.bashrc`).
3. Run the container as above. Harness prints `INFO: V2 auth via CLAUDE_CODE_OAUTH_TOKEN (Claude subscription).`
4. Runs bill against your subscription quota, not metered API.

**Path B — Metered API key (fallback).**

1. `export ANTHROPIC_API_KEY=<sk-ant-...>`.
2. Run the container. Harness prints `INFO: V2 auth via ANTHROPIC_API_KEY (metered).`
3. Runs bill against your metered API usage.

**Both set?** Harness prefers OAuth. It unsets `ANTHROPIC_API_KEY` inside the container so `claude` routes to subscription per `claude config list` precedence. You see `INFO: both ... set. Preferring OAuth ...`.

**Adding to CI:** create a repo secret named `CLAUDE_CODE_OAUTH_TOKEN` with the token from `claude setup-token`. The `docker-smoke.yml` workflow already passes it when set.

## Auth-path bifurcation (cli#245 + cli#227)

If you use Claude Code's Remote Control on the same Mac that runs docker smoke, do NOT put `CLAUDE_CODE_OAUTH_TOKEN` in your shell profile. Long-lived tokens make interactive Claude sessions refuse `/remote-control` with "long-lived token limited to inference-only." Pick one of two isolation paths.

### Path 1 — File-scoped token (recommended)

Store the token in a file. The docker harness reads it as a fallback when the env var is absent.

1. Run `claude setup-token` once to produce the token.
2. Write it to `~/.config/claude/oauth-token`:
   ```bash
   mkdir -p ~/.config/claude
   echo '<token>' > ~/.config/claude/oauth-token
   chmod 600 ~/.config/claude/oauth-token
   ```
3. Do NOT export `CLAUDE_CODE_OAUTH_TOKEN` in `~/.zshrc` or `~/.bashrc`.
4. Interactive `claude` sees no long-lived token; `/remote-control` arms cleanly.
5. Docker harness reads from the file. Two ways:
   - **Host inline** (any container invocation): `docker run -e CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.config/claude/oauth-token) ...` — token stays in the container process only.
   - **Container-native fallback** (mount the config dir): `docker run -v ~/.config/claude:/root/.config/claude:ro ...`. Entry.sh's preflight_v2 reads it and logs `INFO: loaded CLAUDE_CODE_OAUTH_TOKEN from <path> (V2 file-fallback per cli#227)`.
6. Custom location: set `CLAUDE_OAUTH_TOKEN_FILE=<path>` in the container env to override the default.

### Path 2 — direnv-scoped token

Store the token in an `.envrc` local to the repo where you run docker smoke.

1. `echo 'export CLAUDE_CODE_OAUTH_TOKEN=<token>' >> ~/src/sunj-labs/bassclef-cli/.envrc`
2. `direnv allow ~/src/sunj-labs/bassclef-cli`
3. Add `.envrc` to your global gitignore or `~/src/sunj-labs/bassclef-cli/.git/info/exclude`.
4. Every shell OUTSIDE that directory has no token. Interactive Claude in other paths works with Remote Control.
5. Every shell INSIDE that directory has the token. Docker harness invocations there work.

### Which path to pick

- **Path 1** — most flexible. Works with any shell state. Container reads inline or via mount. Recommended for adopters who use Remote Control frequently.
- **Path 2** — repo-scoped. Simpler for adopters who mostly work inside one repo. `.envrc` becomes the source of truth.

Env var still takes precedence when set. File-fallback fires only when `CLAUDE_CODE_OAUTH_TOKEN` is absent from the environment. Empty or unreadable file falls through to the standard env-missing error path.

## Exit-code vocabulary

Read the exit code to know what the container detected.

| Code | Meaning | Action |
|---|---|---|
| 0 | PASS — cli self-contained | Ship it |
| 3 | DETECT — hooks wired but missing (upstream#1827 class) | Wait for upstream cure |
| 4 | DETECT — skill hardcodes operator paths (upstream#1824 class) | Wait for upstream cure |
| 5 | DETECT — skill drive timeout | Investigate skill; may need timeout bump |
| 6 | DETECT — init manifest count mismatch | Cli defect; open ticket |
| 20 | INFRA — docker build failed after retries | Check base-image pull rate limit; retry |
| 21 | INFRA — npm install failed after retries | Check npm registry status |
| 22 | INFRA — target version not on registry | Check the CLI_VERSION value; try `latest` |
| 23 | INFRA — bassclef init failed | Cli defect; open ticket |
| 24 | INFRA — smoke-assert script not found | Repository state defect; check `scripts/` |
| 25 | PREFLIGHT — neither ANTHROPIC_API_KEY nor CLAUDE_CODE_OAUTH_TOKEN set (V2 only) | Export one (OAuth preferred; see Auth paths section) |
| 26 | INFRA — report path not writable | Check container filesystem |
| 99 | UNKNOWN — unmapped exit code fell through | ExitCodeMapper bug; open ticket |

## Falsification-test framing (Zeller)

The harness is a hypothesis-test pairing. Every run runs against a specific hypothesis:

- **Hypothesis A** (V1): cli is self-contained. Exit 0 confirms.
- **Hypothesis B** (V1): cli 1.2.1 has the 12-hook cascade class. Exit 3 confirms.

If the harness runs against cli 1.2.1 and exits 0, the assertion is buggy. If it exits 3, the detection works.

If the harness runs against cli 1.2.2 (with upstream cures) and exits 3, the cures did not work. If it exits 0, the cures work.

## Local vs CI

- **Local** (macOS OrbStack): copy-paste the two commands above; expect ~30-60s from `docker build` completion.
- **CI** (GHA ubuntu-latest): `.github/workflows/docker-smoke.yml` runs the same commands. Detection codes (0, 3, 4, 5) pass the CI job. Infrastructure codes (20-26, 99) fail the CI job.

## What NOT to do

- **Do not pass `--env` alone** in `docker run`. That inherits every env var from the host. INSTEAD: use `-e VAR` for each documented variable (CLI_VERSION, ANTHROPIC_API_KEY only). This is the anticorruption layer per RFC-0002 R9.
- **Do not build without `--platform=linux/amd64`** on Apple Silicon. Rosetta emulation handles it; arm64-native builds cause behavior drift vs CI ubuntu-latest.
- **Do not drop `--rm`**. Container state must not persist between runs.
- **Do not run as root inside the container**. Dockerfile pins `USER adopter`; do not override.

## Troubleshooting

### Container fails on npm install with `403 Forbidden`

Cause: some npm registry mirrors rate-limit unauthenticated pulls. Retry.

### Container exits 25 on V1

Cause: entry.sh V2 preflight fires prematurely. Should not happen in V1 flow. File a bug against harness/docker/entry.sh.

### `docker: Error response from daemon: pull rate limit exceeded`

Cause: Docker Hub anonymous pull rate limit. Retry after 6h OR authenticate `docker login`.

### Tests pass locally but CI shows exit 3

Expected against cli 1.2.1. This is the falsification-test success case per Zeller. Wait for upstream cures + cli 1.2.2 to see exit 0.

## Host smoke — one-shot report + publish (cli#147 shape)

Docker smoke lives in CI. The **host smoke** chain lives on the operator's Mac. It writes captures under `docs/smoke-captures/<date>/`, produces per-check assertion JSONs, then posts a report as a GitHub issue matching #147's shape.

### Single-paste for cold-adopter profile

Paste this whole block into a shell running on a **dedicated cold-adopter profile**. It nukes prior state, installs cli fresh, inits a test project, runs the smoke chain, and posts the report:

```bash
# ─── COLD-ADOPTER SMOKE — one paste ──────────────────────────────────────
# Nukes prior state, installs cli fresh, runs smoke, publishes report.
# WARNING: destructive on dev machines. Cold-adopter profile only.
# Requires: node 20+, npm, git, gh authenticated, and one of
#           CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY exported.

cd ~   # defensive — reset may delete your cwd

VER=1.9.3
SCRIPTS_DIR=~/tmp/bassclef-smoke-scripts

# 1. Fetch smoke scripts from bassclef-cli main
curl -fsSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/smoke-bootstrap.sh -o /tmp/smoke-bootstrap.sh
bash /tmp/smoke-bootstrap.sh --target $SCRIPTS_DIR

# 2. Run the whole cycle
bash $SCRIPTS_DIR/scripts/smoke-one-shot.sh --reset --install --cli-version $VER
```

**What each phase does:**

| Phase | Fires | Effect |
|---|---|---|
| Defensive cd | `cd ~` at paste + inside script | avoids `getcwd` errors that kill Ghostty/Kitty panes when reset deletes cwd |
| Nuke | `smoke-reset.sh --cold` | `npm uninstall -g @thebassclef/lite`, purge `~/tmp/bassclef-smoke-test`, back up `~/.claude/` → `~/.claude.bak.<ts>/` |
| Install | `npm install -g @thebassclef/lite@VER` | fresh install of the version under test |
| Init | `bassclef init` in `~/tmp/bassclef-smoke-test` | writes `.bassclef-source.json` with `tier: lite` |
| Smoke | preflight → capture → drive-skills → assert-hooks → assert-skills | captures under `docs/smoke-captures/<date>/` |
| Publish | `smoke-report.sh --publish` | posts a GitHub issue with the `smoke-run-VER` label (auto-created) |

### Flags worth knowing

| Flag | When to use |
|---|---|
| `--cli-version X.Y.Z` | Version under test. Required unless `$CLI_VERSION` or a local `package.json` sets it. |
| `--reset` | Nuke prior state via `smoke-reset.sh --cold`. Cold-adopter profile only — destructive on dev machines. |
| `--install` | After reset, `npm install -g @thebassclef/lite@VER` + init a fresh test project. Composes with `--reset`. |
| `--date YYYY-MM-DD` | Override the capture-dir date suffix. Default: today UTC. |
| `--skip-skills` | Skip the skill drive when claude auth is not available. Hooks still run. |
| `--no-publish` | Build the report locally without posting. |
| `--repo OWNER/REPO` | Override the publish target. Default: `sunj-labs/bassclef-cli`. |

### Failure classes closed

The script validates `--cli-version` against a semver regex BEFORE any `gh` call. That closes the label-shape drift class from prior runs — a phrase like `1.9.2-nosync-nuked` exits with a fix prompt, not a `smoke-run-1.9.2-nosync-nuked` label that never resolves.

### Run descriptions belong in the body, not the version tag

If a run needs a descriptive tag (nuked user scope, no-sync mode), edit the report body via `--no-publish` first, then re-run with `--publish`. Do NOT pass `--cli-version 1.9.3-nuked` — that produces a label the auto-create never matches.

### What the script does NOT do

- Does not run docker-smoke — that path is CI-only.
- Does not tag or push git.
- Does not create the label — `smoke-report.sh` handles auto-create per cli#236.

## Adjacent-shadow refusal (cli#247)

The smoke harness refuses to run when an adjacent bassclef checkout at `$(dirname WORK_DIR)/bassclef` would shadow the npm install after Claude opens a session.

### What triggers the refusal

`smoke-reset.sh` and `harness/docker/entry.sh` both fire `detect_stale_bassclef_shadows` before doing any work. The function returns non-zero when both hold:

1. A directory exists at `$(dirname WORK_DIR)/bassclef`
2. The sentinel file `$(dirname WORK_DIR)/bassclef/presence/install/bassclef-hook-connect.sh` exists inside that directory

For the host flow, `WORK_DIR = ${HOME}/tmp/bassclef-smoke-test`, so the shadow path is `${HOME}/tmp/bassclef`. For the docker flow, `WORK_DIR = ${ADOPTER_TEST_DIR:-/adopter/test}`, so the shadow path is `/adopter/bassclef`.

### Why the class exists

Peer trace at `bassclef-upstream#1953` and cure at `bassclef-upstream#1954`: the resolver `lib/bassclef-dir-resolver.sh` Check 1 tests `$CWD/../bassclef` before Check 3 tests the npm install path. If a stale bassclef clone sits next to the workdir, SessionStart resolves `BASSCLEF_DIR` to the stale clone and merges from its pre-v1.6.0 hook-connect fragment. Result: 44 phantom entries in `.claude/settings.json` at first Claude open.

This runbook check is defense-in-depth. Peer's `#1954` fixes the resolver directly. This check catches the class at the harness surface before init even runs.

### Three options when the refusal fires

The warning lines the operator sees:

```
shadow-detection: WARN — adjacent bassclef checkout at <path> shadows the npm install.
  This will corrupt settings.json when Claude opens (see bassclef-upstream#1954).
  Options:
    1. mv <path> <path>.aside   — recover the checkout later
    2. rm -rf <path>            — destroy the stale checkout
    3. SMOKE_ALLOW_SHADOW=1 <cmd>    — bypass this run (accept the risk)
```

Pick per situation:

- **Recover later** — `mv ~/tmp/bassclef ~/tmp/bassclef.aside`. Non-destructive. Reversible.
- **Destroy** — `rm -rf ~/tmp/bassclef`. The checkout gets removed. Use when you know the clone is stale and unwanted.
- **Bypass** — `SMOKE_ALLOW_SHADOW=1 bash scripts/smoke-one-shot.sh --reset --install --cli-version X.Y.Z`. Run under override. The check emits a bypass log line to stderr but proceeds. Use only if you accept the risk of settings.json corruption at first Claude open.

### Non-triggers (S1 fold — no false positives)

- Directory at `$(dirname WORK_DIR)/bassclef` exists but sentinel file absent → check passes silently.
- No adjacent directory at all → check passes silently.

The check only fires on directories that carry the specific sentinel file. A random `~/tmp/bassclef/` scratch dir with no bassclef substrate inside does not block smoke.

## Refs

- Goal doc — `docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md`
- Fully-dressed UC — `docs/use-cases/UC-docker-cold-adopter-harness.md`
- Decomposition — `docs/decompositions/2026-09-20b-docker-cold-adopter-harness.md`
- Exit codes source — `harness/docker/exit-codes.sh`
- Entry.sh — `harness/docker/entry.sh`
- Dockerfile — `harness/docker/Dockerfile.cold-adopter`
- CI workflow — `.github/workflows/docker-smoke.yml`
- Tier 0 tests — `.claude/hooks/tests/docker-harness-entry.test.sh`
