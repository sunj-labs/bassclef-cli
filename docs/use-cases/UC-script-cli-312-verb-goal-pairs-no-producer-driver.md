---
id: UC-script-cli-312-verb-goal-pairs-no-producer-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - kent-beck
    - linus-torvalds
---

# UC — Characterize verb_goal_pairs schema asymmetry (cli#312)

## Scope

Session H driver 5. Characterizes read-vs-write asymmetry for `structural_hints.verb_goal_pairs`. /build SKILL reads the key. No producer in scripts, lib, or bundle hooks writes it.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/skills/build/SKILL.md` exists.

## Main scenario

1. Runner invokes the driver.
2. Driver counts reads of `verb_goal_pairs` in /build SKILL.
3. Driver counts writers across cli scripts + lib + bundle hooks.
4. Driver finds reads > 0 and writers = 0.
5. Driver emits RED-CONFIRMED.

## Extensions

**4a — writer added.** Upstream cured — /objectory-decompose writes verb_goal_pairs back to the InputArtifact, OR /build reads from the decomposition instead.
Driver emits GREEN-UNEXPECTED. Exits 1.

**4b — bundle absent.** SKIP with code 77.

## Postconditions

- RED-CONFIRMED — defect reproduces.
- GREEN-UNEXPECTED — cure reached adopters.
- SKIP — bundle absent.

## Related

- cli#312
- Session F precedent — grep pattern (#322)
