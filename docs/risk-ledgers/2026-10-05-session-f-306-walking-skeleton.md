---
goal: Session F walking skeleton — cli#306 bash 3.2 driver
date: 2026-10-05
lenses:
  - michael-feathers
  - linus-torvalds
mode: light
---

# Pre-mortem light — cli#306 driver

Scope: ship ONE new file (`scripts/tests/smoke-drive-adopter-306-bash32.test.sh`) + brief UC. Static grep over shipped bundle. No fixture dir, no new container, no helper lib.

## Lens 1 — Michael Feathers (characterization-before-cure)

**F1 — grep too broad; catches false positives in code examples.** `assert_bash_3_2_syntax` from Session A hits BOTH `declare -A` AND `[[ `. SKILL.md is markdown; carries bash examples in code fences. `[[ ` matches on sentences inside examples that aren't the actual label-step bashism. Fold: driver uses a NARROWER grep (`declare -A` only; or `declare -A LABELS` even narrower) scoped to the Phase 1.1 label section.

**F2 — bundle out of sync with source.** `dist/lite/` can lag `scripts/upstream-source/.claude/skills/onboard-repo/SKILL.md`. Driver greps the shipped bundle (what adopters see), not the source (what upstream fixes). If a cure lands upstream but bundle isn't regenerated, driver stays RED. Fold: that's actually the right behavior — the characterization asserts what adopters observe. Document the two-step cure cycle in the UC extension 4a.

**F3 — exit code semantics drift.** Driver's exit 0 means "RED confirmed" today; after cure flip, exit 0 means "GREEN confirmed." CI reading only exit codes can't tell which semantics are active. Fold: structured stdout line (`RED-CONFIRMED|...` vs `GREEN-CONFIRMED|...`) names the semantics. CI logs carry the signal.

## Lens 2 — Linus Torvalds (adopter stability)

**L1 — driver file path collides with future Session G drivers.** Session F ships `scripts/tests/smoke-drive-adopter-306-bash32.test.sh`. Session G may ship `smoke-drive-adopter-321-*.test.sh` etc. Naming pattern already established across 12 Session A-D drivers. Fold: no collision — ticket number in filename is unique key.

**L2 — new container needed on CI.** Lite runtime invariants lib runs under any bash; driver is pure static grep. No container change needed. Fold: zero new infrastructure.

**L3 — Session A invariants lib breaks on future substrate restructure.** If upstream renames `onboard-repo` skill or moves it under a nested path, driver's hardcoded path to `dist/lite/.claude/skills/onboard-repo/SKILL.md` 404s. Driver exits 77 (SKIP). Fold: SKIP is correct — the ticket's observable surface moved; filing a new characterization ticket is the right response.

## Folded into plan

- F1 → narrower grep for `declare -A` only, no `[[ ` check in this driver
- F2 → UC extension 4a documents the two-step cure cycle (upstream fix → bundle regen → driver flip)
- F3 → structured stdout prefix carries semantics
- L1, L2, L3 → no code change needed; patterns already stable
