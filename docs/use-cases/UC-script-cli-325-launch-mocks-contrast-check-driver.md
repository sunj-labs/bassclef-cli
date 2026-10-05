---
id: UC-script-cli-325-launch-mocks-contrast-check-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - kent-beck
    - linus-torvalds
---

# UC — Characterize /launch mocks no-contrast-check (cli#325)

## Scope

Session H driver 6. Characterizes absence of contrast check in /launch SKILL vs presence of 4.5:1 floor in usability rule.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/skills/launch/SKILL.md` AND `.../rules/usability.md` both exist.

## Main scenario

1. Runner invokes the driver.
2. Driver greps /launch SKILL for contrast / wcag / 4.5:1.
3. Driver greps usability rule for 4.5:1 floor.
4. Driver finds launch count = 0 AND rule count > 0.
5. Driver emits RED-CONFIRMED.

## Extensions

**4a — contrast step added.** Upstream added a contrast check in Phase 4 or 10.
Driver emits GREEN-UNEXPECTED. Exits 1.

**4b — bundle absent.** SKIP with code 77.

## Postconditions

- RED-CONFIRMED — defect reproduces.
- GREEN-UNEXPECTED — cure reached adopters.
- SKIP — bundle absent.

## Related

- cli#325
- Session F precedent — grep pattern (#322)
