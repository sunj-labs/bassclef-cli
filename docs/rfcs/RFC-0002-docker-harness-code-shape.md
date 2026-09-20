---
tier: operator-private
rfc_id: RFC-0002
authored: 2026-09-20
session_id: 2026-09-20b
subject: Docker harness code shape (Step 4 pre-code review)
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
disposition: Revised A (accept scope; cure 2 HIGH findings inline before Step 4 code writes)
council:
  - alan-cooper
  - martin-fowler
  - vaughn-vernon
  - david-parnas
  - bertrand-meyer
outside_set_from:
  - alistair-cockburn
  - kent-beck
  - andreas-zeller
  - michael-feathers
  - michael-nygard
  - linus-torvalds
  - jane-cleland-huang
excluded_prior_council:
  - hyrum-wright
  - frederick-brooks
  - john-ousterhout
  - jerome-saltzer-and-michael-schroeder
  - donald-norman
---

# RFC-0002 — Docker harness code shape (Handoff 2 outside council)

Second-pass adversarial review. Focus on Step 4 code writing shape. Outside prior RFC council. Outside authoring set.

## Sources read

- `docs/decompositions/2026-09-20b-docker-cold-adopter-harness.md` — module shape
- `docs/use-cases/UC-docker-cold-adopter-harness.md` — extensions
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-2.md` — 15 pre-mortem-2 risks
- `docs/rfcs/RFC-0001-docker-cold-adopter-harness.md` — prior council findings

## Council

| Lens | Role |
|---|---|
| Alan Cooper | Persona review — who is the "adopter" user inside the container? |
| Martin Fowler | Refactoring debt — are we adding smell to bash scripts? |
| Vaughn Vernon | Anticorruption layer — container as ACL between operator env and cli install env |
| David Parnas | Information hiding — exit-code contract as hidden interface |
| Bertrand Meyer | Design by contract — pre/post conditions per entry.sh stage |

## Findings

### HIGH-R9 (Vernon — anticorruption layer)

- **Claim:** the container boundary IS an anticorruption layer per Vernon DDD. The cli-install-inside-container is the "bounded context"; the operator env is the outside model. Every env var that crosses is a translation.
- **Evidence:** decomposition doc § "Env passthrough" allows 2 vars. But `HOME`, `USER`, `PATH`, `TERM`, and the whole shell environment implicitly cross.
- **Why it fails:** if the container inherits e.g. `NODE_OPTIONS` or `NPM_CONFIG_*` from operator env, the smoke behaves differently than a truly cold adopter's environment.
- **Cure:** `docker run` uses `--env-file` OR explicit `-e VAR` for the 2 documented vars only. `docker run` does NOT use `--env` bare (which would pass all). Verify in the workflow + runbook + Tier 0 test.

### HIGH-R10 (Meyer — design by contract)

- **Claim:** each stage of entry.sh has an implicit precondition (previous stage succeeded) and postcondition (next stage's precondition holds). No explicit contract.
- **Evidence:** decomposition doc § "Control objects" names the 4 actions but does not spell out the contract per stage.
- **Why it fails:** silent contract violations cascade — e.g., install fails but reports success; smoke-assert runs against no install; exit code is misleading.
- **Cure:** each stage function in entry.sh follows Meyer contract shape: opening comment `## Precondition:` + `## Postcondition:`; explicit `[[ ... ]] || { emit + exit }` check between stages. Tier 0 test asserts contract enforcement.

### MEDIUM-R11 (Cooper — persona)

- **Claim:** the "adopter" user inside the container is under-specified. Do they have `sudo`? Do they get their own home dir? Do they have shell history?
- **Cure:** Dockerfile creates `adopter` user with `uid=1000 gid=1000` + `HOME=/adopter` + no sudo + `/bin/bash` shell. Document in comment header. Rejects any assumption that adopter runs as root.

### MEDIUM-R12 (Fowler — refactoring smell in bash)

- **Claim:** entry.sh will accumulate helper functions during authoring. Bash lacks module boundaries; functions leak into global scope.
- **Cure:** prefix all internal functions with `_docker_harness_` (private-by-convention). Public API is `main` only. Rejects any bare-named helper that could clash with sourced smoke scripts.

### MEDIUM-R13 (Parnas — information hiding)

- **Claim:** exit-code contract lives across UC + decomposition + Tier 0 test + smoke-assert. Three sources of truth risk drift.
- **Cure:** one source — a `harness/docker/exit-codes.sh` file that declares the exit-code constants (`readonly EXIT_HOOKS_MISSING=3`, `readonly EXIT_INSTALL_FAIL=21`, etc.). Sourced by entry.sh + Tier 0 test. UC references this file as authoritative.

## Findings summary

- HIGH: 2 (R9 anticorruption layer, R10 design by contract)
- MEDIUM: 3 (R11 persona, R12 refactoring smell, R13 information hiding)
- LOW: 0

## Disposition — Revised A

Accept scope. Cure 2 HIGH inline before Step 4 code writes. Cure 3 MEDIUM inside Step 4 authoring.

### Inline cures folded

- **R9 (Vernon ACL)** — workflow + runbook use only `-e CLI_VERSION -e ANTHROPIC_API_KEY`; docker run never passes bare `--env`; Tier 0 test asserts no other env vars leak
- **R10 (Meyer contract)** — each entry.sh stage function ships with `## Precondition:` + `## Postcondition:` comment header; explicit contract-enforcement check between stages
- **R11 (Cooper persona)** — Dockerfile creates `adopter` user with specific uid/gid/home; header comment documents the persona
- **R12 (Fowler smell)** — internal functions prefixed `_docker_harness_`; only `main` is public
- **R13 (Parnas hiding)** — `harness/docker/exit-codes.sh` becomes the single source of truth for exit codes

## Follow-on plan

None. Zero deferrals.

## Refs

- `.claude/skills/rfc/SKILL.md` — dispatch source
- Handoff 2 pre-mortem — `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-2.md`
- Prior RFC — `docs/rfcs/RFC-0001-docker-cold-adopter-harness.md`
