---
tier: standard
authored: 2026-09-20
session_id: 2026-09-20b
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
use_case: docs/use-cases/UC-docker-cold-adopter-harness.md
method: Jacobson BCE + Ousterhout deep modules + GRASP
patterns_used:
  - patterns/code/gof/observer.md
  - patterns/code/gof/facade.md
  - patterns/code/gof/strategy.md
  - patterns/code/nygard/circuit-breaker.md
---

# Decomposition — Docker cold-adopter harness

## Sources read

- `docs/use-cases/UC-docker-cold-adopter-harness.md` — 11-step main success scenario + 8 extensions + 4 postcondition classes
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-1.md` — 23 risks; strongest folded here
- `docs/rfcs/RFC-0001-docker-cold-adopter-harness.md` — R1 + R2 + R3 HIGH findings absorbed into module shape
- `bassclef-cli#162` body L37-52 — original entry.sh flow spec (11 steps)

## Method

Jacobson BCE (Boundary + Control + Entity) applied at the container edge. Ousterhout deep-module discipline applied per module — narrow interface, deep behavior. GRASP responsibility assignment for module-to-module handoffs.

## Boundary objects

External-facing modules. Interact with Docker daemon, operator, CI, npm registry, Anthropic API.

| Module | Interfaces with | Path |
|---|---|---|
| `Dockerfile.cold-adopter` | Docker daemon (build API) | `harness/docker/Dockerfile.cold-adopter` |
| `entry.sh` | Operator/CI runner (container entrypoint) | `harness/docker/entry.sh` |
| `docker-smoke.yml` | GitHub Actions runner | `.github/workflows/docker-smoke.yml` |
| `docker-smoke.md` | Operator (local invocation) | `docs/runbook/docker-smoke.md` |

## Control objects

Orchestration logic. Not entities. Not boundaries.

| Module | Responsibility (GRASP) | Interface (Ousterhout) |
|---|---|---|
| `OrchestratorController` (inside entry.sh) | Coordinates the 4-action sequence: env-check → install → smoke-invoke → exit-propagate. Never contains assertion logic (RFC R3 cure). Facade over the smoke-* script family. | `entry.sh --version=$CLI_VERSION` |
| `ExitCodeMapper` (inside entry.sh) | Maps assertion outputs to specific exit codes (3-6, 20-26). Deep module — the exit-code contract IS the assertion vocabulary. | `map_exit_code $assertion_output` |
| `BackoffRetrier` (inside entry.sh) | 3-attempt exponential backoff for npm install + registry pulls. Circuit-breaker pattern. | `retry_with_backoff <cmd> <max-attempts> <base-delay>` |
| `EvidenceRowEmitter` (inside entry.sh) | Appends a schema-valid JSON line to `state/events/evidence-status-changed.jsonl`. Observer pattern — bandleader subscribes to the event stream. | `emit_evidence_row <status> <detail>` |
| `ReportWriter` (inside entry.sh) | Writes text report to `state/harness-runs/<ISO-ts>/report.txt`. | `write_report <path> <content>` |
| `PreflightChecker` (inside entry.sh) | 3 checks: `docker info`, `command -v docker`, `printenv ANTHROPIC_API_KEY` (V2 only). Norman feedback-loop cure R6. | `preflight_all` |

## Entity objects

Data at rest. Read by observers. Never mutated after write.

| Module | Shape | Persisted at |
|---|---|---|
| `EvidenceRow` | JSON per `bassclef-upstream/standards/state-spine/schemas/evidence.schema.json` (extension `trace` field per session paper) | `state/events/evidence-status-changed.jsonl` (append-only) |
| `HarnessRunReport` | Plain text (assertion outputs + exit codes + timing) | `state/harness-runs/<ISO-ts>/report.txt` |
| `InstallManifest` | JSON emitted by `bassclef init` | `.bassclef/init.manifest.json` inside container |
| `SettingsHookList` | Set of hook paths declared in `.claude/settings.json` | Read-only; computed by smoke-assert |
| `OnDiskHookFileSet` | Set of hook file paths under `.claude/hooks/` | Read-only; computed by smoke-assert |

## Interfaces (Ousterhout — narrow at the module boundary)

### Container ↔ Docker daemon

Docker CLI. Standard Docker API. `docker build --platform=linux/amd64 -t bassclef-cli-cold-adopter -f harness/docker/Dockerfile.cold-adopter .` and `docker run --rm --platform=linux/amd64 -e ANTHROPIC_API_KEY -e CLI_VERSION bassclef-cli-cold-adopter`.

### entry.sh ↔ smoke-assert-settings-hooks.sh

Bash function call. Contract: assertion prints diagnostic text to stdout; exits 0 (pass) or 3 (fail — hooks wired but missing). Existing script under `scripts/` reused verbatim.

### entry.sh ↔ EvidenceRowEmitter

Function call. Contract: emitter takes `<status>` + `<detail>` args, constructs a JSON line matching the evidence schema, appends to the log. Schema-version pinned at `1.0`.

### entry.sh ↔ operator/CI

stdout + exit code. Contract: exit codes 0-26 per UC extensions. Any non-zero exit stops CI publish workflow.

## Cross-cutting concerns

### Retry logic (Nygard stability)

`BackoffRetrier` wraps `npm install`, `bassclef init`, and any network-dependent step. 3 attempts × 15s base delay × 2x backoff. Failure after exhaustion propagates a specific exit code (21 for install, 20 for build).

### Container arch (pre-mortem N2 cure)

Dockerfile `FROM --platform=linux/amd64 debian:12-slim`. `docker build --platform=linux/amd64`. Both required for Apple Silicon + GHA parity.

### Container user (RFC R4 cure)

Dockerfile `USER adopter` after apt-get install. `adopter` is uid 1000, gid 1000, home `/adopter`. Container runs unprivileged.

### Container network (RFC R5)

V1 default network. V3 restricts egress via `--network` flag. Deferred per cli#162 L57.

### Env passthrough

Only two env vars cross the boundary: `CLI_VERSION` (default `latest`) and `ANTHROPIC_API_KEY` (V2 only, checked at preflight). No other operator state enters.

## Patterns instantiated

Per `.claude/rules/pattern-annotation.md` L13-22 — code annotations `@pattern <catalog-path>` land on the modules that instantiate the pattern.

| Module | Pattern | Reason |
|---|---|---|
| `OrchestratorController` | `patterns/code/gof/facade.md` | entry.sh presents a narrow interface over the family of smoke-* scripts |
| `ExitCodeMapper` | `patterns/code/gof/strategy.md` | maps assertion output classes to exit-code strategies |
| `BackoffRetrier` | `patterns/code/nygard/circuit-breaker.md` | retries with backoff; fails loud after exhaustion |
| `EvidenceRowEmitter` | `patterns/code/gof/observer.md` | bandleader + chronicle writer + HUD subscribe to the emitted events |

## Deep modules per Ousterhout

Each module hides substantial complexity behind a narrow interface:

- `entry.sh` orchestrates 4 actions with one CLI shape (`bash entry.sh`). Adopters never see the internal flow.
- `BackoffRetrier` hides retry math, jitter, timeout composition. Callers pass a command; retrier handles the rest.
- `EvidenceRowEmitter` hides JSON schema validation, path resolution, append semantics. Callers pass 2 args.

Shallow modules avoided — no thin wrappers around single commands.

## Cross-cutting decisions folded

| Source | Finding | Fold |
|---|---|---|
| Pre-mortem N2 | Arch mismatch | Dockerfile FROM `--platform=linux/amd64` |
| Pre-mortem N3 | npm registry timeout | `BackoffRetrier` around install |
| Pre-mortem N7 | State leaks between runs | `docker run --rm` always |
| Pre-mortem L1 | Runbook assumes Docker | `PreflightChecker` fires first |
| Pre-mortem L3 | Missing ANTHROPIC_API_KEY | preflight check + specific exit code 25 |
| Pre-mortem L6 | 1.2.1 vs 1.2.2 release cadence | `CLI_VERSION` env var; falsification-test framing |
| Pre-mortem C3 | No Tier 0 tests | Tests land in Step 4 alongside entry.sh |
| Pre-mortem C7 | entry.sh does too much | `OrchestratorController` = 4 actions only; assertion logic stays in `cli/scripts/` |
| RFC R1 | Runbook contract | Runbook front matter names ADR-031 stability |
| RFC R2 | V2 scope creep | Step 7 → Step 8 gate; two commits, not one |
| RFC R3 | entry.sh depth | Enforced in `OrchestratorController` contract |
| RFC R4 | Root user | `USER adopter` in Dockerfile |
| RFC R6 | Runbook error messages | `PreflightChecker` prints remediation per failure |
| RFC R8 | Falsification-test banner | `OrchestratorController` prints banner at start |

## Test surfaces

Tier 0 tests owed at Step 4 per `.claude/rules/testing-tier-config.md` for the `.claude/hooks/tests/` path:

- `docker-harness-entry.test.sh` — 12+ tests covering:
  - Preflight passes when docker + env present
  - Preflight fails specific code when docker missing (extension 8a)
  - Preflight fails specific code when ANTHROPIC_API_KEY missing (extension 5a→25)
  - Backoff retrier retries N times before giving up
  - Backoff retrier propagates the correct final exit code
  - Exit-code mapper produces 3 on settings-hooks-present fail
  - Exit-code mapper produces 4 on skill-hardcode fail (V2)
  - Exit-code mapper produces 0 on all-green
  - Evidence-row-emitter appends valid JSON
  - Report-writer writes to timestamped path
  - Orchestrator invokes preflight before install
  - Orchestrator invokes install before smoke-assert

## What this decomposition explicitly rejects

- Adding assertion logic to entry.sh (RFC R3 anti-pattern)
- Baking ANTHROPIC_API_KEY into the image (Saltzer-Schroeder violation)
- Persistent volume between runs (defeats the fresh-install purpose)
- V2 skill drive as part of Step 4 (V1 skeleton lands green FIRST, per Cockburn + Brooks R2 cure)
