---
date: 2026-10-04
goal: Session B — session-shape drivers RFC
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - michael-feathers
    - linus-torvalds
mode: adversarial council (3 outside lenses × 3 findings per lens, compact)
---

# Session B — RFC adversarial council

Three outside lenses — Carmack (speed), Nygard (stability), Hyrum (observable behavior).

## F-JC (Carmack) — speed over ceremony

- **F-JC-1** `/longrun prep` driver's 6-axis grep is 6 separate greps; one combined pattern cuts I/O. **Resolution:** one grep -c pattern checking all 6 axis labels; faster + clearer.
- **F-JC-2** Each driver has its own scratch dir; shared helper would save boilerplate. **Resolution:** driver files inherit `scripts/lib/smoke-assert.sh`; no new helper needed — scope creep.
- **F-JC-3** Nightly runs 3 skills × 3 releases × 2 OS = 18 cells. **Resolution:** Session A nightly already carries 18 cells; adding 3 drivers adds zero cells (same workflow).

## F-MN (Nygard) — stability patterns

- **F-MN-1** `/sprint` driver assumes mock trace carries no PyYAML — but what if upstream fixes cli#308 and the error line disappears? Driver stays GREEN mockingly, misses the real cure signal. **Resolution:** driver asserts PRESENCE of orientation output AND absence of PyYAML — both; cure signal is live mode via nightly, not mock.
- **F-MN-2** `/temperance` driver fixture creates `.gitignore` entry — commits bleed to real repo if cleanup fails. **Resolution:** scratch `.gitignore` lives in TMP_BASE under mktemp; trap EXIT cleans; never touches real repo .gitignore.
- **F-MN-3** 6-axis frame is pulled from `.claude/rules/compounding-sequence-fresh-analysis.md`. Rule may change label text. **Resolution:** test cites the rule file + line number; label change forces test update (characterization intact per Feathers).

## F-HW (Hyrum) — observable behavior becomes contract

- **F-HW-1** Mock trace shape becomes a de-facto contract for /sprint output. **Resolution:** driver's mock trace cites plan doc L94 (the acceptance criterion) so the contract is explicit, not accidental.
- **F-HW-2** /temperance marker format path (`state/markers/temperance/<branch-slug>.marker`) becomes locked after driver ships. **Resolution:** format is already standard per `.claude/rules/sdlc-gates.md`; driver pins the existing contract, doesn't invent new.
- **F-HW-3** CONTRIBUTING.md update needed for the new drivers? **Resolution:** no — Session A CONTRIBUTING section lists the 5 invariants + 2 drivers; expanding to 9 drivers is noise. Leave as-is.

## Folds pre-code (adversarial)

- **F6** (F-JC-1) `/longrun prep` driver uses one grep over all 6 axis labels.
- **F7** (F-MN-1) `/sprint` driver asserts BOTH orientation output presence AND PyYAML absence.
- **F8** (F-MN-2) /temperance fixture `.gitignore` scoped to TMP_BASE; trap EXIT cleans.
- **F9** (F-HW-1) Mock traces cite plan doc line numbers (acceptance anchor).
