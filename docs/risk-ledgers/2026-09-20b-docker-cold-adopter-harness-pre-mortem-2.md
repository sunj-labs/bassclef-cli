---
tier: operator-private
authored: 2026-09-20
session_id: 2026-09-20b
mode: pre-mortem-light
handoff: design-to-construction
parent_goal: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
lenses:
  - michael-feathers
  - john-ousterhout
  - jerome-saltzer-and-michael-schroeder
---

# Pre-mortem light — Handoff 2 (Design → Construction)

Klein workshop shape. 3 lenses. 5-8 risks per lens. 30 min budget.
Focused on code-writing hazards for Step 4 (Dockerfile + entry.sh + Tier 0 tests).

## Sources read

- `docs/decompositions/2026-09-20b-docker-cold-adopter-harness.md` — module shape
- `docs/use-cases/UC-docker-cold-adopter-harness.md` — extensions + exit codes
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-1.md` — prior 23 risks
- `.claude/rules/defensive-bash.md` — 7 disciplines for bash hooks
- `.claude/rules/testing-tier-config.md` — Tier 0 strict-TDD requirement

## Feathers — characterization tests for the wrapped bash scripts

The 6 existing smoke scripts under `scripts/` become Docker's first characterization surface. Feathers: legacy code is code without tests.

| ID | Risk | Severity | Mitigation | Step folded |
|---|---|---|---|---|
| F1 | The existing smoke scripts run cleanly on operator's Mac but fail inside a Debian container due to bash 3.2 vs 5.x differences | 🟡 med | Container ships bash 5.x from Debian 12; scripts should already handle 5.x per cli history; add characterization test that runs each smoke script inside container as its baseline | Step 4 tests |
| F2 | Smoke scripts assume `python3` or `jq` are on PATH; container may lack them | 🟢 low | Dockerfile installs `python3` + `jq` explicitly; test asserts both present before smoke fires | Step 4 Dockerfile + tests |
| F3 | Smoke scripts read env vars the operator's shell has but the container does not | 🟡 med | Entry.sh sets only the 2 documented env vars; scripts must fail-loud if any missing | Step 4 entry.sh |
| F4 | Smoke script exit codes differ from what UC extensions define (contract drift) | 🟢 low | Tier 0 test asserts smoke-assert-settings-hooks.sh exits 0 on green + 3 on hooks missing; pins the contract | Step 4 tests |
| F5 | Smoke scripts write to `/tmp` or `.playwright-mcp/`; container `--rm` erases these between runs; operator debug expects them persistent | 🟢 low | Report writer copies key outputs to `state/harness-runs/<ts>/` before container exits | Step 4 entry.sh |

## Ousterhout — deep-module discipline for entry.sh

Entry.sh is the top-level orchestrator. Narrow interface, deep behavior. Any shallow wrapper is a design defect.

| ID | Risk | Severity | Mitigation | Step folded |
|---|---|---|---|---|
| O1 | Entry.sh accretes assertion logic during authoring (breaks RFC R3 cure) | 🔴 high | Reviewer discipline — during code writing, any `if [[ ... ]]` on assertion output inside entry.sh triggers a rewrite; delegate to `map_exit_code` function | Step 4 code review |
| O2 | Exit-code mapper becomes a shallow if-else chain; adding a new class requires editing entry.sh | 🟡 med | ExitCodeMapper reads a lookup table (associative array); adding a class = adding a table entry, not editing logic | Step 4 entry.sh |
| O3 | BackoffRetrier signature grows past 3 args (command + max-attempts + base-delay); becomes shallow | 🟡 med | Freeze signature at 3 args; extend via env vars if needed, not new positional args | Step 4 entry.sh |
| O4 | Preflight checker duplicates env-var checks across V1 + V2 paths | 🟢 low | Single `preflight_all` function called once at start; V2 path calls `preflight_v2` after V1 clears | Step 4 entry.sh |
| O5 | Evidence-row emitter grows to accept per-row schema variants (V1 vs V2 different fields) | 🟢 low | Emitter takes generic `(status, detail)` args; JSON construction hidden inside; V1 + V2 same emitter interface | Step 4 entry.sh |

## Saltzer + Schroeder — complete mediation on exit codes

Every failure path in the harness must terminate with a specific exit code from the UC vocabulary. No silent fallthrough. No default-to-1.

| ID | Risk | Severity | Mitigation | Step folded |
|---|---|---|---|---|
| S1 | `set -e` in entry.sh causes early exit on unexpected commands; loses specific exit-code mapping | 🔴 high | Wrap each stage in a function; capture `$?` explicitly; propagate via `map_exit_code`; `set -e` OFF around exit-code-sensitive blocks | Step 4 entry.sh |
| S2 | Unhandled exit codes fall through to shell default 1 | 🟡 med | Explicit `case` statement at end of entry.sh; any unmapped code becomes 99 (unknown-defect class) with stderr flagging the bug | Step 4 entry.sh |
| S3 | Signal handlers (SIGTERM, SIGINT) not trapped; container force-kill loses evidence row | 🟡 med | `trap 'emit_evidence_row "signal" "SIGTERM"; exit 130' TERM INT` at start of entry.sh | Step 4 entry.sh |
| S4 | `docker run` without `--rm` leaks container filesystem between runs | 🟢 low | Runbook + workflow both use `--rm`; runbook front matter asserts this | Step 5 runbook + workflow |
| S5 | Preflight failures exit before evidence row emits; observers miss the failure entirely | 🟡 med | Preflight failure emits `evidence_row("preflight_fail", <reason>)` BEFORE `exit`; no silent skip | Step 4 entry.sh |

## Total risks named

- Feathers: 5 (2 med, 3 low)
- Ousterhout: 5 (1 high, 3 med, 1 low)
- Saltzer + Schroeder: 5 (1 high, 3 med, 1 low)
- Grand total: 15 risks; 2 HIGH; 8 MEDIUM; 5 LOW

## Strongest folded before Step 4

- **O1 (entry.sh assertion accretion)** — code review at every entry.sh commit checks the 4-action orchestrator contract
- **S1 (`set -e` interaction)** — entry.sh explicit `$?` capture with `set +e` around exit-code-sensitive blocks
- **F1 (bash version drift)** — characterization test runs each smoke script inside container as baseline before Step 4 code lands

## Refs

- `.claude/skills/pre-mortem/SKILL.md` — light mode
- `.claude/luminaries/michael-feathers.md` — anchor
- `.claude/luminaries/john-ousterhout.md` — anchor
- `.claude/luminaries/jerome-saltzer-and-michael-schroeder.md` — anchor
- cli#162 — parent ticket
