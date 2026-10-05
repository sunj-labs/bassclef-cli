---
id: UC-script-cli-326-build-preview-state-slug-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - kent-beck
    - linus-torvalds
---

# UC — Characterize /build Phase 2b slug mismatch (cli#326)

## Scope

Session H driver 3. Characterizes shipped `/build` + `/launch` SKILL bodies. The /build Phase 2b path-based lookup (`docs/preview-state/<slug>.yml`) does not match the file /launch writes (`<sprint-slug>.yml` without `-construction` suffix). The /launch SKILL also uses two different construction-goal naming patterns.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/skills/build/SKILL.md` AND `.../launch/SKILL.md` both exist.

## Main scenario

1. Runner invokes the driver.
2. Driver greps /build SKILL for the literal `preview-state/<slug>.yml` path pattern.
3. Driver greps /build SKILL for a field-read pattern.
4. Driver finds path pattern present and field read absent.
5. Driver emits `RED-CONFIRMED|driver-326|...`.

## Extensions

**4a — cure landed.** /build Phase 2b reads the goal's `preview_state:` field.

1. Driver emits GREEN-UNEXPECTED.
2. Driver exits 1.

**4b — bundle absent.** Driver emits SKIP with code 77.

## Postconditions

- RED-CONFIRMED — defect reproduces; ticket stays open.
- GREEN-UNEXPECTED — cure reached adopters; ticket closes after bundle sync.
- SKIP — bundle not available.

## Related

- cli#326
- Session F precedent — grep-based characterization (#322)
