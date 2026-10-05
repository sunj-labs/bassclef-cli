---
date: 2026-10-05
primary_lens: michael-feathers
prior_review: docs/architecture/reviews/2026-10-04-session-b-session-shape.md
coverage_marker: state/markers/architect-review/2026-10-05.marker
scope: Session H driver sweep — 6 characterization drivers (PRs #367-#372)
---

# Architect review — Session H driver sweep

## Verdict

**READY-WITH-ONE-FOLLOWUP.** 6 characterization drivers shipped end-to-end. All RED-CONFIRMED. All CI GREEN. All merged. One moderate finding filed as follow-up ticket.

## Scope

Session H shipped 6 bash Tier 0 characterization drivers for Session F open queue:

| PR | Ticket | Defect |
|---|---|---|
| #367 | cli#311 | artifact-ingestion-gate false-positive on parent_bet: null |
| #368 | cli#323 | save-state.sh auto-save commits unreviewed prototype edits |
| #369 | cli#326 | /build Phase 2b slug mismatch picks operator mode |
| #370 | cli#324 | /launch calls /ux-migration MUST; /ux-migration says skip for greenfield |
| #371 | cli#312 | structural_hints.verb_goal_pairs has no producer |
| #372 | cli#325 | /launch mocks have no contrast check |

Also upstream filing bassclef-upstream#2087 — hook header vs wiring manifest tier disagreement on 14 hooks.

## Dynamic verification pass

All 6 drivers run clean against shipped `dist/lite/` v1.7.1 bundle:

```
311: RED-CONFIRMED (hook BLOCKs on parent_bet: null)
323: RED-CONFIRMED (shipped hook stages docs/ broadly without exclusion)
326: RED-CONFIRMED (/build uses path-based lookup not field read)
324: RED-CONFIRMED (/launch MUST + /ux-migration Skip-greenfield both present)
312: RED-CONFIRMED (reads=2 writers=0)
325: RED-CONFIRMED (/launch contrast refs=0; usability rule floor=1)
```

Full vitest suite: **498/498 GREEN** (after `npm run build` to refresh dist/).

## Static comprehension pass

### Component architecture
Unchanged. 6 characterization drivers under `scripts/tests/`. No `src/` edits. No lib changes. Standalone test files reading from `dist/lite/` bundle only.

### Testing coverage per @luminary kent-beck
+6 Tier 0 driver test files. Each with 3 Tier 0 cases (RED anchor + semantic anchor + SKIP). Beck RED-first discipline applied — each driver verified RED locally before commit.

### Characterization-test gate per @luminary michael-feathers
**SATISFIED.** This session's entire output IS characterization — 6 drivers pin REAL defects before any upstream cure. Pattern mirrors Session F precedent (#306, #322, #329, #331, #332). No refactor-without-test anti-pattern.

### Adopter contract per @luminary linus-torvalds
Preserved. Session added only Tier 0 test files; no behavior change to shipped bundle. Drivers run read-only against `dist/lite/`.

### Complete mediation per @luminary saltzer-schroeder
Each driver's SKIP path verified via code inspection (bundle-absent case). Each driver's semantic exit codes documented in header.

### ADR fitness
No ADR touched. All drivers mark `outcome: ADR-honored` in state/markers/adr-deviation/.

### CLAUDE.md fitness
Unchanged this session. Previous reviews flagged nothing stale.

### Stability patterns per @luminary michael-nygard
Driver 5 (cli#312) iteration 1 surfaced bash `set -e` interaction with grep-returns-1-on-zero-match pattern. Cured on iteration 2 with `|| true` wrap. Pattern now shared across drivers 5+6. Driver 1-4 do not reuse the pattern (direct grep -c count works).

## Coverage checklist

- [x] Component architecture — no changes; drivers isolated to scripts/tests/
- [x] Data flow — not touched this session
- [x] Auth + security — not touched; drivers run read-only
- [x] Queue + workers — not touched
- [x] External dependencies — jq used, available on CI runner; drivers SKIP cleanly without it
- [x] Error handling — each driver has 3 exit codes documented
- [x] Database — n/a
- [x] Testing coverage — +6 Tier 0 driver files, 498/498 vitest GREEN
- [x] Performance — drivers run in milliseconds (grep-only); no regression
- [x] ADR fitness — no ADR class touched
- [x] CLAUDE.md fitness — unchanged
- [x] SOLID + Clean Architecture — single-responsibility per driver
- [SKIP] DDD — not applicable to Tier 0 characterization drivers
- [x] Stability patterns — bash set -e + grep interaction cured iteration 1

## Findings

### Finding 1 — MODERATE — dist/ staleness after version bump

**Observed.** Initial `npm test` after Session H close ran against stale `dist/index.js` from Session G. 4 tests failed with "expected 1.9.10 to be 1.9.9". `npm run build` refreshed dist/; subsequent run GREEN.

**Class.** Build-artifact staleness. Session G's `scripts/bump-version.mjs` updates `src/index.ts` + `package.json` + `README.md` + `CHANGELOG.md` but does NOT run `npm run build`. The dist/ bundle keeps the prior version until the next explicit build. Operators (or CI) running tests between the bump and the build hit the version mismatch class.

**Primary lens.** @luminary tony-hoare — pre/postcondition contract. The bump script's postcondition should include "dist/ bundle reflects new version" OR the test suite's precondition should include "fresh build".

**Cure path (operator decision).**
- (a) Add `npm run build` to `scripts/bump-version.mjs` tail. Guarantees fresh dist/ post-bump.
- (b) Add a Tier 0 test that fails loud if `package.json` version ≠ `dist/index.cjs` embedded version. Catches staleness at test time.
- (c) Document in `scripts/bump-version.mjs` header: "run `npm run build` after every bump".

Recommend (a) — cheapest, mechanical, hard-to-forget.

**Severity.** MODERATE. Caused cross-session test failures that could mask real regressions. One ticket filed per Step 8.

## Recommendations by priority

1. **MODERATE** — Finding 1 (dist/ staleness). File ticket for the bump-build sequencing cure.

Nothing in the SIGNIFICANT or CRITICAL buckets.

## Component map

Session H added only to `scripts/tests/` subtree:

```
scripts/tests/
├── smoke-drive-adopter-311-artifact-ingestion-null-parent.test.sh (NEW)
├── smoke-drive-adopter-312-verb-goal-pairs-no-producer.test.sh (NEW)
├── smoke-drive-adopter-323-save-state-prototype-exclude.test.sh (NEW)
├── smoke-drive-adopter-324-launch-ux-migration-must-skip.test.sh (NEW)
├── smoke-drive-adopter-325-launch-mocks-contrast-check.test.sh (NEW)
├── smoke-drive-adopter-326-build-preview-state-slug.test.sh (NEW)
└── (existing Session F drivers 306/322/329/331/332 unchanged)
```

## Next review

Auto-dispatch from next /longrun closeout. Or operator ask. 7 commits added to main this session; the 10-commit threshold is at next session.
