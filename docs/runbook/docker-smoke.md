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

# 3. Anthropic key set? (V2 skill drive only; V1 tolerates missing)
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || {
  echo "WARN: ANTHROPIC_API_KEY not set. V1 harness runs; V2 skill drive will exit 25."
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
docker run \
  --rm \
  --platform=linux/amd64 \
  -e CLI_VERSION="${CLI_VERSION:-latest}" \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  bassclef-cli-cold-adopter
```

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
| 25 | PREFLIGHT — ANTHROPIC_API_KEY missing (V2 only) | Export the key |
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

## Refs

- Goal doc — `docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md`
- Fully-dressed UC — `docs/use-cases/UC-docker-cold-adopter-harness.md`
- Decomposition — `docs/decompositions/2026-09-20b-docker-cold-adopter-harness.md`
- Exit codes source — `harness/docker/exit-codes.sh`
- Entry.sh — `harness/docker/entry.sh`
- Dockerfile — `harness/docker/Dockerfile.cold-adopter`
- CI workflow — `.github/workflows/docker-smoke.yml`
- Tier 0 tests — `.claude/hooks/tests/docker-harness-entry.test.sh`
