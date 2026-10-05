---
id: UC-script-cli-329-adr-dead-letter-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - saltzer-schroeder
    - alistair-cockburn
---

# UC — Characterize ADR hook DEAD-LETTER state (cli#329)

## Scope

Session F driver. Captures the gap between what `adr-discipline.md:10` claims (hook wired) and what `dist/lite/.claude/settings.json` actually has (no wiring). DEAD-LETTER class per `mechanism-fidelity.md`.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/hooks/adr-discipline-check.sh` exists (hook file shipped).
- `dist/lite/.claude/settings.json` exists.

## Main scenario

1. Runner invokes `bash scripts/tests/smoke-drive-adopter-329-adr-dead-letter.test.sh`.
2. Driver confirms `adr-discipline-check.sh` is shipped under `dist/lite/.claude/hooks/`.
3. Driver greps `dist/lite/.claude/settings.json` for `adr-discipline-check.sh` references.
4. Driver finds zero matches (RED signal — hook not wired).
5. Driver emits `RED-CONFIRMED|driver-329|DEAD-LETTER — adr-discipline-check.sh shipped but not wired in settings.json`.
6. Driver exits 0.

## Extensions

**4a — wiring present.** `settings.json` has at least one reference to `adr-discipline-check.sh`.

1. Driver emits `GREEN-UNEXPECTED|driver-329|wiring present — ADR hook now mediates`.
2. Driver exits 1.
3. Operator flips semantics; ticket closes via cross-ref.

**2a — hook file absent.** Upstream removed the hook (alternative cure path per ticket body).

1. Driver emits `PATH-CHANGED|driver-329|hook file removed — alternative cure path landed`.
2. Driver exits 1 (still signals cure landed, different shape).

**1a — settings.json absent.** Bundle incomplete.

1. Driver emits `SKIP|driver-329|dist/lite/.claude/settings.json absent`.
2. Driver exits 77.

## Postconditions

- Exit 0: DEAD-LETTER confirmed; adopter risk documented.
- Exit 1: cure landed in some shape; operator reviews whether anchor shape still matches.
- Exit 77: bundle prereq fail.

## Non-goals

- Does not run /build + fake package.json edit to prove the hook never fires. Smoke-drive layer.
- Does not cure #329. Cure is upstream (wire the hook OR rework the rule).

## References

- cli#329 — the ticket this driver characterizes
- `dist/lite/.claude/rules/adr-discipline.md:10` — the rule's claim
- `dist/lite/.claude/settings.json` — missing wiring
- `.claude/rules/mechanism-fidelity.md` — DEAD-LETTER classification
- @luminary michael-feathers — characterization
- @luminary saltzer-schroeder — complete mediation
