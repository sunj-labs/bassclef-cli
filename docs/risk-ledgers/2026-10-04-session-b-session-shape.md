---
date: 2026-10-04
goal: Session B — session-shape drivers (/sprint, /longrun prep, /temperance)
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - michael-feathers
    - linus-torvalds
mode: pre-mortem light (3 lenses × 5 risks per lens, compact per 100-150 turn budget)
---

# Session B — risk ledger (pre-mortem light)

Three lenses × 5 risks = 15 risks. Folds pre-code at the end. Session A harness carries most of the mechanics; Session B rides on top with 3 drivers.

## Lens C — Cockburn (walking skeleton + adopter stability)

- **R-C1** `/sprint` ships only the mock mode, not the live mode. **Fold:** mock mode is the walking skeleton; live mode asserted via nightly on cli#308 cure.
- **R-C2** Driver tries to drive a real session-start (reads actual whereami.md). **Fold:** driver builds its own scratch whereami.md fixture; no session-level dependencies.
- **R-C3** 3 drivers end up as 3 look-alike boilerplates. **Fold:** each driver tests a distinct invariant — /sprint reads PyYAML-clean, /longrun prep has 6 axes, /temperance marker lands in a gitignored path.
- **R-C4** Scope creeps into fixing upstream cli#308 directly. **Fold:** driver RED today, becomes GREEN when upstream cures; no PyYAML cure in this session.
- **R-C5** 100-150 turn budget blown by ceremony re-authoring. **Fold:** compact ceremony — reuse Session A's harness; no new lib code.

## Lens F — Feathers (characterization tests at orientation surface)

- **R-F1** Driver asserts behavior that the skill doesn't actually guarantee. **Fold:** read SKILL.md body for each skill before writing assertions; cite line numbers in driver.
- **R-F2** Mock mode uses fake trace content that doesn't match real skill output shape. **Fold:** base mock trace on the actual bassclef sync output format (readable at state/bassclef-sync-status.json).
- **R-F3** Live-mode assertions get written but SMOKE_LIVE never runs. **Fold:** nightly workflow (lite-adopter-smoke.yml) already runs SMOKE_LIVE=1 across 3 releases per Session A; drivers inherit.
- **R-F4** Marker-format test for /temperance can't reproduce the cli#328 adopter failure. **Fold:** fixture includes a `.gitignore` that blocks `state/markers/` to characterize the exact cli#328 trip.
- **R-F5** 6-axis compounding frame test only covers 1 of 6 axes. **Fold:** test asserts all 6 headers present (Deliverable, Problem, Value prop, Turns, Risk, Shipping priority).

## Lens L — Linus (adopter contract on cold macOS)

- **R-L1** PyYAML-missing adopter sees no clearer error after Session B. **Fold:** driver is characterization-only this session; adopter-side cure rides cli#308 cure cadence.
- **R-L2** `/sprint` driver passes under test environment that has PyYAML. **Fold:** driver tests the trace content, not the local Python state; mock trace deliberately includes the error shape.
- **R-L3** `/longrun prep` driver blocks on grep against non-ASCII (6-axis frame carries em-dashes). **Fold:** test grep patterns use literal strings, not regex; the 6 axis labels tolerate the dash.
- **R-L4** `/temperance` driver on adopter machine fails because adopter's `.gitignore` differs from fixture. **Fold:** driver builds its own `.gitignore` scratch; does not read adopter's.
- **R-L5** Nightly runs expose a hidden PyYAML dep on cli#308 cure. **Fold:** nightly failure is a signal, not a session-A regression — treat as new ticket at cure time.

## Folds pre-code (session kickoff)

- **F1** (R-C5) Reuse Session A invariants lib + smoke-assert extension — no new lib code.
- **F2** (R-F1) Read each skill's SKILL.md body before writing driver; cite line numbers.
- **F3** (R-F4) /temperance fixture includes `.gitignore` entry for `state/markers/` to characterize cli#328.
- **F4** (R-F5) Test grep for all 6 axis headers, not just presence of any.
- **F5** (R-L2) Mock traces built via runtime concat per `feedback_ccf3_test_fixtures` memory (identifier-leak scrub).
