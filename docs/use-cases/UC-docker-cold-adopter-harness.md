---
tier: standard
uc_id: UC-docker-cold-adopter-harness
authored: 2026-09-20
session_id: 2026-09-20b
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
cockburn_tier: fully-dressed
primary_actor: operator (or CI runner)
supporting_actors:
  - docker-daemon (OrbStack or Docker Desktop or GHA runner)
  - npm-registry (public thebassclef/lite)
  - anthropic-api (V2 skill drive only)
---

# UC-docker-cold-adopter-harness — cold-adopter smoke inside a Docker container

## Sources read

- `docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md` — subject goal doc
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-1.md` — 23 risks
- `docs/rfcs/RFC-0001-docker-cold-adopter-harness.md` — 8 outside-council findings
- `bassclef-cli#162` body L38-52 — original entry.sh flow spec
- `scripts/smoke-bootstrap.sh` + `scripts/smoke-preflight.sh` + `scripts/smoke-reset.sh` — existing smoke helpers reused (paths cited; contents read at Step 4)

## Name

Cold-adopter smoke inside a Docker container

## Scope

`harness/docker/` package in bassclef-cli — Dockerfile + entry.sh + CI workflow + local runbook + Tier 0 tests

## Level

User-goal (Cockburn level)

## Primary actor

Operator (local) OR GitHub Actions ubuntu-latest runner (CI)

## Stakeholders and interests

| Stakeholder | Interest |
|---|---|
| Operator | Verify `@thebassclef/lite` self-contained without operator-machine ceremony |
| CI (GHA) | Block release publish when harness exits non-zero on the target version |
| bassclef-upstream maintainers | Litmus test for whether upstream cures actually work in an adopter environment |
| Future adopters | Trust that cli releases have passed a real cold-adopter check |

## Preconditions

- Operator has Docker installed (OrbStack on macOS, Docker Desktop, Docker Engine, or Podman with compat)
- Docker daemon is running (`docker info` returns success)
- ANTHROPIC_API_KEY exists in operator env (V2 skill drive only; V1 tolerates missing)
- Repository has `harness/docker/Dockerfile.cold-adopter` and `harness/docker/entry.sh` on disk
- Network access to `registry.npmjs.org` and (V2) `api.anthropic.com`

## Postconditions

### Success

- Container exits 0 when the target cli version is self-contained
- Evidence row appended to `state/events/evidence-status-changed.jsonl` with `status: harness_pass`
- Assertion output logged under `state/harness-runs/<ISO-timestamp>/report.txt`

### Failure (falsification-test success)

- Container exits with a specific non-zero code mapping to a defect class:
  - 3 = settings-hooks-present assertion failed (12-hook cascade class)
  - 4 = skill hardcode found in captured output (skill-hardcode class)
  - 5 = timeout on skill drive (timeout class)
  - 6 = init manifest count mismatch (manifest class)
- Evidence row appended with `status: harness_detect_<class>`
- Log preserved under `state/harness-runs/<ISO-timestamp>/report.txt`

## Trigger

- Operator runs `bash docs/runbook/docker-smoke.md` invocation OR
- PR opened touching `src/**` or `harness/**` OR
- Release publish workflow scheduled

## Main success scenario

1. Actor invokes the harness with target cli version (default `latest`, override via env var `CLI_VERSION`)
2. Container builds from `Dockerfile.cold-adopter` (Debian 12 slim, linux/amd64 pinned, node 20 + jq + git)
3. Container starts as unprivileged `adopter` user (R4 cure)
4. Entry.sh prints banner naming version under test and expected outcome
5. Entry.sh runs `npm install -g @thebassclef/lite@$CLI_VERSION` with 3-attempt backoff on network errors
6. Entry.sh creates `/adopter/test`, runs `git init -q`, runs `bassclef init`
7. Entry.sh invokes `bash /adopter/scripts/smoke-assert-settings-hooks.sh` (V1 assertion)
8. Entry.sh captures exit code from smoke-assert
9. Entry.sh emits report to `state/harness-runs/<ISO-timestamp>/report.txt`
10. Entry.sh exits with captured code
11. CI or operator reads exit code; downstream automation acts on it

## Extensions

- **2a. Docker build fails on base image pull.** Retry with backoff. After 3 failed attempts, exit code 20 with clear stderr.
- **2b. Container fails to start (Rosetta emulation issue on Apple Silicon).** Log the arch mismatch. Recommend `--platform=linux/amd64` in Dockerfile FROM.
- **5a. npm registry timeout during install.** Retry with backoff (3 attempts × 15s). After exhaustion, exit code 21.
- **5b. Target version not found on registry (`npm ERR! 404`).** Exit code 22 with clear stderr naming the version.
- **6a. `bassclef init` fails.** Exit code 23 with init output logged.
- **7a. Assertion script not found.** Exit code 24 (path bug caught at build time by Tier 0 tests).
- **8a. V2 skill drive fires but ANTHROPIC_API_KEY is missing.** Exit code 25 with remediation message per R6 cure.
- **9a. Report path is not writable.** Exit code 26 (container filesystem permission bug).

## Priority

HIGH — launch gates on this per operator recap L18-22

## Frequency

Every PR touching `src/**` or `harness/**` in CI. Every release locally before publish workflow. Ad-hoc for adopter smoke debugging.

## Special requirements

- Must run on macOS OrbStack AND GHA ubuntu-latest with identical behavior
- Arch pinned to `linux/amd64` per pre-mortem N2 cure
- Container removes on exit (`docker run --rm`) per pre-mortem N7 cure
- Runbook invocation contract frozen at V1 per RFC R1 cure
- entry.sh stays a 4-action orchestrator per RFC R3 cure

## Frequency of usage per week

Approximately 3-5 CI runs per typical week; 1-2 operator ad-hoc runs. Increases at release cadence.

## Business rules

- Container never persists state between runs — always fresh
- ANTHROPIC_API_KEY never baked into image; passed via `-e` at run time only
- Container runs as unprivileged user per Saltzer-Schroeder cure R4
