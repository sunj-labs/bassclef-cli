---
id: UC-script-cli-322-launch-template-jargon-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - linus-torvalds
---

# UC — Characterize /launch template jargon self-block (cli#322)

## Scope

Session F driver. Captures ironic defect — /launch Phase 14 goal template contains BLOCK terms (`scope-bounded`, `appetite:`) that `substrate-clarity-gate.sh` refuses on write.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/skills/launch/SKILL.md` exists.

## Main scenario

1. Runner invokes `bash scripts/tests/smoke-drive-adopter-322-launch-template-jargon.test.sh`.
2. Driver greps shipped `/launch` SKILL.md for `scope-bounded` and `appetite:`.
3. Driver finds one or more hits (RED signal).
4. Driver emits `RED-CONFIRMED|driver-322|shipped template carries jargon`.
5. Driver exits 0.

## Extensions

**3a — both absent.** Upstream rewrote the template.

1. Driver emits `GREEN-UNEXPECTED|driver-322|both jargon terms absent — template cured`.
2. Driver exits 1.
3. Operator flips semantics.

**1a — bundle absent.** Driver exits 77.

## Non-goals

- Does not run /launch end-to-end against a fixture to trigger the gate.
- Does not cure #322. Cure is upstream — rewrite template to use `mode: fixed-scope` + `time_budget:`.

## References

- cli#322
- `dist/lite/.claude/skills/launch/SKILL.md:615` — jargon line
- `standards/bassclef-internal-jargon.md:38` — BLOCK entry for `scope-bounded`
- ADR-040 — `appetite` → `time budget` rename
- @luminary michael-feathers — characterization
- @luminary linus-torvalds — adopter contract
