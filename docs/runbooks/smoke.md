---
tier: project
title: Runbook — cold-adopter smoke against @thebassclef/lite
id: runbook-smoke
status: living
last_updated: 2026-09-18 (v4 — terminal-banner note added)
audience: operator (kingofrock) or agent on the cold-adopter Mac profile
---

# Runbook — cold-adopter smoke

Living doc. Update whenever the smoke shape changes. Every release runs this once before ship.

## What this runbook does

Runs Layer 1 of the smoke test system against whatever is currently `latest` on npm for `@thebassclef/lite`. Captures per-hook output. Fires 5 skills. Runs 4 checks per surface. Posts one issue with the `smoke-run-v1` label so the agent can pick up RED rows on demand.

## What it does NOT do yet

- Layer 2 (drive `/launch` + `/build` to produce a mock app)
- Layer 3 (drive `/verify`, `/architect-review`, `/decompose`, `/pattern-review` against the mock)
- CI wiring (value is on a real profile)

## Prereqs (one-time on the cold profile)

- Node 20+ and npm 10+
- `jq` on PATH (`brew install jq`)
- `perl` on PATH (ships with macOS)
- `curl` on PATH (ships with macOS)
- `gh` on PATH plus `gh auth login` completed as `kingofrock`
- `claude` CLI on PATH

No git clone needed. The bootstrap curls everything.

## Setup — one-curl bootstrap

Fetches the ten smoke scripts into `~/tmp/bassclef-smoke/scripts/` from `main`:

```bash
curl -sfL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/smoke-bootstrap.sh | bash
export BCLI=~/tmp/bassclef-smoke
```

Idempotent — re-run any time to pull the latest scripts.

**Options:**

```bash
# Fetch from a branch other than main
curl -sfL .../smoke-bootstrap.sh | bash -s -- --ref feat/109-smoke-evidence-capture-layer-1

# Land in a different dir
curl -sfL .../smoke-bootstrap.sh | bash -s -- --target ~/tools/smoke

# Preview without fetching
curl -sfL .../smoke-bootstrap.sh | bash -s -- --dry-run
```

**Fetched files** (10 total):

- `scripts/smoke-capture.sh`, `scripts/smoke-assert-hooks.sh`, `scripts/smoke-assert-skills.sh`
- `scripts/smoke-drive-skills.sh`, `scripts/smoke-report.sh`
- `scripts/smoke-reset.sh`, `scripts/smoke-reset-whole.sh`, `scripts/smoke-preflight.sh`
- `scripts/lib/smoke-assert.sh`, `scripts/lib/smoke-schema.sh`

The scripts source each other via `${SCRIPT_DIR}/lib/...`, so the layout under `$BCLI/scripts/` is what makes them work.

**Bootstrap prints the next commands** — reset (dry-run + apply), version fetch, one-liner. You paste with intent. Reset is destructive, so bootstrap will not run it for you.

## Step 1 — Reset with snapshot (safe)

Dry run first. Then apply.

```bash
bash $BCLI/scripts/smoke-reset-whole.sh --dry-run
bash $BCLI/scripts/smoke-reset-whole.sh
```

Snapshot lands at `~/tmp/bassclef-smoke-reset-backups/<timestamp>/`. Auto-prunes anything over 7 days.

**Undo if you meant `--cold`, not `--whole`:**

```bash
ls ~/tmp/bassclef-smoke-reset-backups/
bash $BCLI/scripts/smoke-reset-whole.sh --restore <timestamp>
```

## Step 2 — Fetch the latest version tag

Curl the npm registry. Use whatever it returns as the version to install and to tag the report.

```bash
LITE_VER=$(curl -sf https://registry.npmjs.org/@thebassclef/lite/latest | jq -r .version)
echo "will install and smoke @thebassclef/lite@${LITE_VER}"
```

If `LITE_VER` comes back empty or `null`, the registry is slow or unreachable. Retry after 30 seconds.

## Step 3 — Install and init

```bash
npm install -g "@thebassclef/lite@${LITE_VER}"
mkdir -p ~/tmp/bassclef-smoke-test
cd ~/tmp/bassclef-smoke-test
git init -q
bassclef init
```

Expect the banner to say **24 hooks armed** and around 379 files.

## Step 4 — Capture SessionStart hooks

```bash
bash $BCLI/scripts/smoke-capture.sh
```

Writes one file per hook under `docs/smoke-captures/<date>/hooks/`.

## Step 5 — Drive 5 skills through `claude -p`

```bash
bash $BCLI/scripts/smoke-drive-skills.sh
```

Writes one file per skill under `docs/smoke-captures/<date>/skills/`. Default timeout is 30 seconds per call. Bump with `--timeout 60` if a skill is slow.

## Step 6 — Assert both surfaces

```bash
bash $BCLI/scripts/smoke-assert-hooks.sh
bash $BCLI/scripts/smoke-assert-skills.sh
```

Exit 0 means all pass. Exit 3 means one or more checks failed.

**Re-run one check on the hook surface (Operator-Diagnose):**

```bash
bash $BCLI/scripts/smoke-assert-hooks.sh --only paths-exist
```

Same flag works on `smoke-assert-skills.sh`.

## Step 7 — Build the report and publish

```bash
bash $BCLI/scripts/smoke-report.sh --version-tag "${LITE_VER}" --publish
```

Publish is idempotent per version and date. Same-day re-run updates the same issue. Force a fresh issue with `--new`.

**Skip build and publish an existing report:**

```bash
bash $BCLI/scripts/smoke-report.sh --publish-only
```

The script returns the issue number to stdout. Follow it to `https://github.com/sunj-labs/bassclef-cli/issues/<N>`.

## Step 8 — Hand off to the agent

Paste the issue link into a Claude session. Agent runs `gh issue view <N>` then `/diagnose` per RED row.

## The one-liner (once you trust it)

Reset stays separate — you decide when to nuke the profile.

```bash
LITE_VER=$(curl -sf https://registry.npmjs.org/@thebassclef/lite/latest | jq -r .version) && \
  npm install -g "@thebassclef/lite@${LITE_VER}" && \
  mkdir -p ~/tmp/bassclef-smoke-test && cd ~/tmp/bassclef-smoke-test && \
  git init -q && bassclef init && \
  bash $BCLI/scripts/smoke-capture.sh && \
  bash $BCLI/scripts/smoke-drive-skills.sh && \
  bash $BCLI/scripts/smoke-assert-hooks.sh; \
  bash $BCLI/scripts/smoke-assert-skills.sh; \
  bash $BCLI/scripts/smoke-report.sh --version-tag "${LITE_VER}" --publish
```

The `;` after each assert is on purpose. Asserts may exit non-zero on RED, and the report still needs to run.

## What you'll see in the terminal

Every smoke script prints two banner lines to stderr:

- `>>> smoke-<name> starting` — the script has begun work
- `<<< smoke-<name> done (exit N)` — the script finished; N is the exit code

The end banner fires from a `trap ... EXIT` hook, so it prints on any exit path — success, failure, or error mid-run. When you run the one-liner, six banner pairs march down your terminal:

```
>>> smoke-capture starting
smoke-capture: found 24 SessionStart hook(s)
smoke-capture: captured 24 hook(s) to docs/smoke-captures/...
<<< smoke-capture done (exit 0)
>>> smoke-drive-skills starting
smoke-drive-skills: driving 5 skill(s) via /opt/homebrew/bin/claude
...
<<< smoke-drive-skills done (exit 0)
>>> smoke-assert-hooks starting
...
```

A slow step (like `smoke-drive-skills` waiting on `claude -p`) shows the start banner right away, so you know it's running and not hung.

## What to expect on the first real run

**`paths-exist` may fire more RED rows than you want.** Real hook output carries many absolute paths that exist on the machine that produced them but not on yours. Treat `paths-exist` FAILs as advisory unless they cluster on one hook. Layer 2 will likely tighten the check or add an allowlist for system paths.

**cli#106 and cli#107 fire no check.** Both fall outside the V1 four-check surface. Follow-on tickets planned for a 5th check (message quality) and a 6th check (repeat warning).

## Troubleshooting

**`gh` auth fails at publish.** Run `gh auth status`. Re-run `gh auth login` if needed.

**`jq` not found.** `brew install jq`.

**`claude -p` returns quickly with no content.** Confirm `claude` CLI is authenticated and can run interactively (`claude` opens the TUI). Then re-run Step 5.

**Registry returns stale version.** Wait 3 minutes and re-fetch. First observed 2026-09-17 — npm registry lag after publish per whereami L37.

**One skill hits the 30-second timeout.** Bump with `--timeout 60`. Deferred pre-mortem F3 fold — measure real latency across three runs, then pin the default from data.

## Updating this doc

- Bump `last_updated` in frontmatter.
- Add a dated note under a `## Change log` section if the shape of a step changes.
- Never remove old steps silently — mark them deprecated with a date.
- File a follow-on ticket for anything the runbook cannot yet do.

## References

- Goal doc: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Spec: `docs/specs/smoke-evidence-capture.md`
- UC: `docs/use-cases/UC-smoke-run.md`
- PR: sunj-labs/bassclef-cli#110
- Coordination ticket for the 2026-09-17 smoke findings: bassclef-upstream#1728
- Fixture pins: cli#101 through cli#108

## Change log

**2026-09-18 v4 — terminal-banner note.** Added "What you'll see in the terminal" section naming the `>>>` and `<<<` bookend banners that ship with every smoke script since PR #113. Should have shipped in PR #113; caught by the operator on runbook re-read.

**2026-09-18 v3 — bootstrap prints next commands.** After fetching the ten files, `smoke-bootstrap.sh` now prints the reset + version-fetch + one-liner commands to stderr. Operator pastes with intent. Reset stays operator-triggered (destructive; `curl | bash` has no interactive stdin, so an auto-prompt would either be skipped or surprising). Norman + Cooper + Nygard lens driven.

**2026-09-18 v2 — curl bootstrap.** Setup no longer needs `git clone`. New `scripts/smoke-bootstrap.sh` curls the ten smoke files into `~/tmp/bassclef-smoke/scripts/`. One command from the cold profile.

**2026-09-18 v1 — initial runbook.** Shipped with PR #110 alongside Layer 1 scripts. Setup used `git clone`.
