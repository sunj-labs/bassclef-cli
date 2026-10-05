---
goal: Session F — cli#329 ADR hook dead-letter driver
date: 2026-10-05
lenses:
  - michael-feathers
  - saltzer-schroeder
mode: light
---

# Pre-mortem light — cli#329 driver

Scope: one new file greps `dist/lite/.claude/settings.json` for `adr-discipline-check.sh`. Driver passes when zero hits found. DEAD-LETTER class per `mechanism-fidelity.md`.

## Lens 1 — Michael Feathers (characterization)

**F1 — settings.json path varies.** The shipped settings may land at either `dist/lite/.claude/settings.json` or elsewhere depending on bundle shape. Fold: driver pins exact path; cli bundles settings.json at the canonical path (verified via `test -f` 2026-10-05).

**F2 — hook could get removed instead of wired.** If upstream cures by removing the hook file (and reworking the rule to say "methodology only"), driver's precondition fails. Fold: driver checks both — hook present AND wiring absent. Either precondition failing flips the test.

## Lens 2 — Saltzer-Schroeder (complete mediation)

**S1 — the rule promises mediation that does not fire.** This is the DEAD-LETTER failure the ticket names. Rule body line 10 says the hook is "load-bearing"; settings.json has no wiring. Fold: driver captures the gap as evidence — the rule's claim and the actual wiring disagree.

**S2 — adopter trust erodes silently.** Agent reads the rule, trusts the mediation fires, writes `package.json` edits with no ADR, nothing blocks. Operator discovers the gap after real damage. Fold: driver gives CI a signal so the gap gets caught before adopter hands.

## Folded into plan

- F1 → pin exact settings.json path
- F2 → check both preconditions (hook present + wiring absent)
- S1 → driver output names "DEAD-LETTER" explicitly
- S2 → PR body cites the rule's L10 claim as the warrant
