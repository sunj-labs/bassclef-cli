---
tier: upstream
session: 2026-10-05-session-h-i-driver-sweep-plus-walking-skeleton
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - alistair-cockburn
    - alan-cooper
    - kent-beck
    - linus-torvalds
---

# Session H + I — characterization driver sweep + Tier A walking skeleton

Fired 2026-10-05 ~14:48Z after unexpected shutdown mid-session. Operator reopened with `/whereami was unexpectedlly shutdown`; prior Session G close was already clean on main. Operator picked PRIMARY (1) + (3) + /longrun prep on SECONDARY. Session rolled through driver sweep + Tier A walking skeleton without a hard boundary between them. 10 PRs merged.

## Problem

Session G shipped v1.7.1 bundle sync + cli v1.9.10 release but left two lite-tier defects RED (cli#322 + cli#329, both reopened early Session H). Session F remaining open queue (#311, #312, #323, #324, #325, #326) had no driver anchors. On top of that, the Tier A roadmap for dynamic chain drivers against @thebassclef/lite@latest had not been shaped at all — adopters hitting the first-5-min CTA skills (/onboard-repo, /riff, /launch, /build) saw friction from unfixed defects without any dynamic driver suite proving the chains.

## Value delivered

- 6 characterization drivers merged for Session F open queue — all RED-CONFIRMED against shipped v1.7.1 bundle.
- 2 reopened lite-tier tickets (cli#322, cli#329) carry explicit evidence trails on the mismatch between ticket-close state and bundle state.
- Upstream filing bassclef-upstream#2087 — hook header vs wiring manifest tier disagreement on 14 hooks (prior-art-found; proposed cure extends existing /tier-dependency-audit with a reconcile bucket).
- Session H architect-review landed READY-WITH-ONE-FOLLOWUP; filed cli#373 for dist/ staleness after version bump.
- Tier A dynamic driver roadmap persisted at `docs/plans/tier-a-dynamic-driver-roadmap.md`; tracking ticket cli#375.
- 2 Tier A walking-skeleton PRs shipped — scripts/lib/persona-assert.sh + 2 fixture-driven unit tests (Sam × /onboard-repo + Louis × /whereami).
- Session J prep plan converged at `docs/next-session-plan-2026-10-05-session-j-dynamic-driver-integration.md` with honest-gap note that fixtures are mocks and Session J must replace them with real captures.

## Scope class

Class a × 6 characterization drivers (Session H part) + Class c × 1 new shared lib (Session I walking skeleton — scripts/lib/persona-assert.sh) + Class c × 1 new chain-driver pattern + Class d modifier (upstream filing cross-repo). Per `/longrun` taxonomy at `.claude/skills/longrun/SKILL.md` § Step 0.86.

## PRs shipped

| PR | Change | Squash SHA | Merged |
|---|---|---|---|
| #367 | feat(#311): artifact-ingestion-gate null-parent characterization driver | `de4bcb2` | 2026-10-05T15:50Z |
| #368 | feat(#323): save-state.sh prototype-leak characterization driver | `c19ce14` | 2026-10-05T16:00Z |
| #369 | feat(#326): /build Phase 2b preview-state slug mismatch driver | `26a15e3` | 2026-10-05T16:10Z |
| #370 | feat(#324): /launch vs /ux-migration MUST-vs-skip conflict driver | `1f89661` | 2026-10-05T16:17Z |
| #371 | feat(#312): verb_goal_pairs no-producer characterization driver | `a1b2c48` | 2026-10-05T16:23Z |
| #372 | feat(#325): /launch mocks no-contrast-check characterization driver | `e44d036` | 2026-10-05T16:30Z |
| #374 | chore: architect review for Session H driver sweep | `eb6c14a` | 2026-10-05T16:38Z |
| #376 | feat(#375): walking skeleton for Tier A dynamic driver suite (Sam × /onboard-repo) | `55445b1` | 2026-10-05T20:14Z |
| #377 | feat(#375): Louis × /whereami Tier A chain driver | `b45e2e7` | 2026-10-05T20:30Z |
| #378 | chore: Session J prep plan + roadmap amendment | `6b47086` | 2026-10-05T20:50Z |

## Driver sweep signal (Session H part)

All 6 drivers RED-CONFIRMED against `dist/lite/` v1.7.1 bundle at exit 0:

| Driver | Signal | Target |
|---|---|---|
| 311 null-parent | hook BLOCKs on parent_bet: null | `.claude/hooks/artifact-ingestion-gate.sh` L135-162 |
| 323 prototype-leak | shipped hook stages docs/ broadly without exclusion | `.claude/hooks/save-state.sh` L211-212 |
| 326 build-slug | path-based preview-state lookup, no field read | `.claude/skills/build/SKILL.md` L374 |
| 324 MUST-vs-skip | /launch names /ux-migration MUST + /ux-migration says Skip for greenfield | `.claude/skills/{launch,ux-migration}/SKILL.md` |
| 312 verb_goal_pairs | reads=2 writers=0 schema asymmetry | `.claude/skills/build/SKILL.md` L404+L451 |
| 325 contrast | /launch SKILL contrast refs=0; usability rule 4.5:1 floor count=1 | `.claude/skills/launch/SKILL.md` |

## Walking skeleton (Session I part)

PR #376 shipped `scripts/lib/persona-assert.sh` with 3 Cooper 3-level assertion functions — `persona_assert_end_goal`, `persona_assert_experience_goal`, `persona_assert_life_goal`. PR #377 added Louis × /whereami fixtures proving pattern scales without lib changes. Both drivers 3/3 Tier 0 cases GREEN locally.

**Honest-gap acknowledged mid-session.** Operator caught that both PRs ran against hand-crafted mock fixtures — not real `claude -p` output against @thebassclef/lite. Cockburn's walking skeleton forbids mocks at any layer. Session J shifts scope to replace mock fixtures with real captures from docker-smoke before extending to /sprint + Jamie drivers.

## Upstream filing

bassclef-upstream#2087 — hook header `# tier:` disagrees with wiring manifest `.tier` on 14 of 91 hooks. For adr-discipline-check.sh: header=lite, manifest=standard. build-adopter-tree.sh reads manifest, so lite loses the hook. Prior art found: `/tier-dependency-audit` + `scripts/analyze-tier-dependencies.sh` already read both sources but classify into 4 buckets with no reconcile class. Proposed extension: add Bucket 5 — Reconcile mismatch. Parent class filed as bassclef-upstream#1335 (state-validate schema under-tag).

## Ceremony

Full /longrun discipline per `.claude/rules/loop-discipline.md`:

- **/temperance** — session-wide marker + 9 per-branch markers.
- **/pre-mortem light** — session-wide ledger at `docs/risk-ledgers/2026-10-05-session-h-driver-sweep.md`. 3 lenses × 13 risks + 7 folds applied pre-code (feathers + beck + torvalds).
- **/luminary** — primary michael-feathers (characterization) across all Session H drivers; shifted to alistair-cockburn + alan-cooper (walking skeleton + persona) for Session I. Shift documented in Session J prep.
- **/loop** iteration_count 1 on 9 of 10 PRs (one grep set-e cure on Driver 5 within iteration 1).
- **/architect-review** auto-dispatched PR #374 at Session H closeout per /longrun Step 7.5. Verdict READY-WITH-ONE-FOLLOWUP.

## Ticket moves

- cli#322, cli#329 — reopened with evidence trails (bundle still RED post v1.7.1)
- cli#279 — closed as intentional (operator confirmed no-gate ship was deliberate for current mode)
- cli#373 (new) — MODERATE finding from architect review: scripts/bump-version.mjs needs npm run build postcondition
- cli#375 (new) — Tier A dynamic driver roadmap tracker
- bassclef-upstream#2087 (new) — 14-hook tier header/manifest reconcile

## Gate Evidence

| Gate | Fired? | Marker/evidence |
|---|---|---|
| /temperance | yes | 10 markers under `state/markers/temperance/` |
| /pre-mortem light | yes | session-wide ledger at `docs/risk-ledgers/2026-10-05-session-h-driver-sweep.md` |
| /luminary | yes | 10 markers under `state/markers/luminary/` |
| /adr-deviation | yes | 10 markers under `state/markers/adr-deviation/` — all outcome=ADR-honored |
| /loop | yes | 10 markers under `state/markers/loop/` |
| /lead-lens-signoff | yes | 10 markers under `state/markers/lead-lens-signoff/` |
| /architect-review | yes | `docs/architecture/reviews/2026-10-05-session-h-driver-sweep.md` + marker `state/markers/architect-review/2026-10-05.marker` |
| /verify | n/a | characterization + fixture-unit tests only; CI test+typecheck covered |
| /diagnose | n/a | no fix work |

## Open threads

- Session J integration bridge — pending; converged prep plan on main
- 5 remaining Tier A drivers after integration bridge (/sprint × Louis, /riff × Jamie, /launch × Jamie, /build × Jamie, architect-review)
- cli#311, #312, #322, #323, #324, #325, #326, #329 — stay open until upstream cures land + bundle sync
- cli#361 — recurring 8 missing hooks diagnose (not touched this session)
- cli#373 — bump-version.mjs postcondition fix pending
- bassclef-upstream#2087 — awaiting upstream decision on reconcile bucket

## Key files changed

- 6 new drivers under `scripts/tests/smoke-drive-adopter-*.test.sh`
- 1 new shared lib `scripts/lib/persona-assert.sh`
- 2 new Tier A chain drivers under `scripts/tests/smoke-drive-e2e-*.test.sh`
- 2 fixture directories under `scripts/tests/fixtures/`
- 8 new use cases under `docs/use-cases/UC-script-*.md`
- 1 session-wide risk ledger `docs/risk-ledgers/2026-10-05-session-h-driver-sweep.md`
- 1 architect review `docs/architecture/reviews/2026-10-05-session-h-driver-sweep.md`
- 1 roadmap `docs/plans/tier-a-dynamic-driver-roadmap.md`
- 1 Session J prep plan `docs/next-session-plan-2026-10-05-session-j-dynamic-driver-integration.md`

## Session timing

- started_at: 2026-10-05T20:18:36+0530 (per /tmp/claude-session-timing)
- ended_at: 2026-10-05T22:09:45+0530
- duration: ~1h 51min elapsed; ~5h total session (two active segments across the day)
- PRs merged: 10
- Lenses used: michael-feathers (lead) + alistair-cockburn + alan-cooper + kent-beck + linus-torvalds

## Next session (Session J)

Per `docs/next-session-plan-2026-10-05-session-j-dynamic-driver-integration.md` — one PR, 40-60 turns, 🟡 med risk, P1 priority. Integration bridge: real captures from docker-smoke replace mock fixtures. Primary lenses shift to alistair-cockburn + michael-feathers.
