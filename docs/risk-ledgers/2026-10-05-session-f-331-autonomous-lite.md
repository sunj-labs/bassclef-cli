---
goal: Session F pivot — cli#331 autonomous lite driver
date: 2026-10-05
lenses:
  - michael-feathers
  - linus-torvalds
mode: light
---

# Pre-mortem light — cli#331 driver

Scope: one new file (`scripts/tests/smoke-drive-adopter-331-autonomous-lite.test.sh`). Static grep over shipped bundle. Same pattern as #306 — ceremony compressed since the pattern already proved out.

## Lens 1 — Michael Feathers (characterization-before-cure)

**F1 — anchor pattern is too permissive.** `grep -qE '^##[[:space:]]+Lite procedure'` matches any H2 heading starting with "Lite procedure". If a different skill later adds the same heading, driver passes against the wrong file. Fold: driver pins the exact file path (`dist/lite/.claude/skills/autonomous/SKILL.md`). Scope is scoped to one shipped file; cross-skill collision impossible.

**F2 — bundle regenerated between cure and driver ship.** If v1.7.1 bundle sync lands BEFORE this driver merges, the driver flips GREEN-UNEXPECTED on first CI run. Fold: that's actually fine — the driver's job is to signal "cure reached adopters." A test that passes on first run because the cure already shipped is still a regression anchor from that point forward.

**F3 — RED today / GREEN after sync is the same shape as #306.** Operator reviewing drivers across Session F will see consistent semantics: all drivers assert pre-cure state exists today. Fold: consistency is the design intent; no change needed.

## Lens 2 — Linus Torvalds (adopter stability)

**L1 — assertion name clash with Session F #306 driver.** Both drivers use RED-CONFIRMED / GREEN-UNEXPECTED prefixes. If a reader greps the output for RED-CONFIRMED, both drivers' output lands. Fold: ticket number is in the prefix (`driver-306` vs `driver-331`); grep remains unambiguous.

**L2 — bundle version pin.** This driver reads from `dist/lite/.claude/skills/autonomous/SKILL.md` which is tied to the cli's current bassclef pin (v1.7.0 pre-cascade). Fold: that IS the surface adopters see today; the driver correctly characterizes shipped state.

**L3 — strategy/ refs stay in cured SKILL.md as "standard+ tier reference".** Driver could flag naked strategy/ refs today AND fail falsely post-cure because strategy/ refs still exist (just qualified). Fold: driver asserts the POSITIVE anchor (`## Lite procedure` header) rather than the NEGATIVE one (naked strategy/ refs). Simpler + more robust.

## Folded into plan

- F1 → driver pins exact shipped file path
- F2 → first-run GREEN pass is acceptable; serves as regression anchor from merge point
- F3 → no change; consistent Session F semantics
- L1 → `driver-NNN` prefix in output disambiguates
- L2 → bundle version pin is correct — reads adopter-observable surface
- L3 → assert positive anchor (`## Lite procedure`) not negative (naked strategy/ refs)
