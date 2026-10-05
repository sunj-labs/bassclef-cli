---
id: UC-script-cli-324-launch-ux-migration-must-skip-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - kent-beck
    - linus-torvalds
---

# UC — Characterize /launch vs /ux-migration MUST-vs-skip conflict (cli#324)

## Scope

Session H driver 4. Characterizes shipped /launch Phase 11 + /ux-migration SKILLs. /launch calls /ux-migration a MUST gate. /ux-migration says Skip for greenfield. Both ship together.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/skills/launch/SKILL.md` AND `.../ux-migration/SKILL.md` both exist.

## Main scenario

1. Runner invokes the driver.
2. Driver greps /launch for `/ux-migration ... MUST gate`.
3. Driver greps /ux-migration for `Skip ... greenfield`.
4. Driver finds both.
5. Driver emits RED-CONFIRMED.

## Extensions

**4a — /launch Phase 11 reshaped.** Cure landed — Phase 11 passes greenfield to a Step-only subset of /ux-migration.
Driver emits GREEN-UNEXPECTED. Exits 1.

**4b — bundle absent.** SKIP with code 77.

## Postconditions

- RED-CONFIRMED exit — defect reproduces.
- GREEN-UNEXPECTED exit — cure reached adopters.
- SKIP — bundle absent.

## Related

- cli#324
- Session F precedent — grep pattern (#322)
