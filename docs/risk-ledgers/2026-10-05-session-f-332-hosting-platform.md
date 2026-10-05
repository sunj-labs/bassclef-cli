---
goal: Session F pivot — cli#332 hosting_platform driver
date: 2026-10-05
lenses:
  - michael-feathers
  - linus-torvalds
mode: light
---

# Pre-mortem light — cli#332 driver

Scope: one new file. Grep 3 cure anchors across /launch + /build + /deploy-prod shipped SKILL.md files. All 3 absent today, present in upstream (PR #2070 merged).

## Lens 1 — Michael Feathers (characterization-before-cure)

**F1 — three anchor files means three independent failure modes.** If one of three cure files gets bundle-synced before the others, driver flips to partial state. Fold: driver requires ALL 3 anchors absent for RED-CONFIRMED. ANY of 3 present triggers GREEN-UNEXPECTED. The partial state is itself a signal that bundle sync is in-flight.

**F2 — anchor text `cli#332 cure` is a comment marker.** HTML comment markers may get stripped by future markdown processing. Fold: driver anchors on the semantic marker (comment IS the authoritative source-of-truth tag for this cure). If markdown processing strips the comment later, that is itself a separate defect worth catching.

**F3 — scope creep risk: 3 skills in one driver.** Driver tests become hard to understand when one file greps multiple files. Fold: UC + risk ledger name the 3-file scope explicitly. Driver output names each file's state in the stdout line.

## Lens 2 — Linus Torvalds (adopter stability)

**L1 — adopter edits one SKILL.md and driver still asserts PRE-cure.** If an adopter forks their own cli and edits /build SKILL.md locally, their fork's dist/lite diverges. Driver is CI-only; local forks run their own CI. Fold: no change — driver scope is adopter-regression against upstream-shipped bundle.

**L2 — three cure anchors could be reduced to one.** Peer could have landed one cure in one file. They chose three for a reason (per-skill honesty). Fold: driver respects peer's design — three anchors, three greps, one aggregate signal.
