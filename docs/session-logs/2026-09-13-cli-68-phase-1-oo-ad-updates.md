---
tier: lite
title: cli#68 Phase 1 — OOAD updates matching upstream ADR-055 reader contract
date: 2026-09-13
authored_by: agent
goal: 2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot
session_started: 2026-09-12T21:41:35Z
session_ended: 2026-09-13T00:40:00Z
duration_hours: ~3
turn_count: ~35
outcome: shipped
pr: 74
merge_commit: 46eb4ec1228abe4774863c17d9045a0fa243bfe6
---

# Session log — cli#68 Phase 1 OOAD updates

## What shipped

PR #74 merged to main at 2026-09-13T00:39:53Z (squash commit `46eb4ec1`). Phase 1 of the 4-phase execution plan named at cli#73. Seven commits on `feat/cli-68-oo-ad-updates-post-adr-007-pivot`.

Six doc edits:

- **New ADR-009** — `docs/adrs/ADR-009-manifest-as-init-contract-source.md`. Cross-cites bassclef-upstream ADR-055 D1-D7 by number without re-authoring semantics (V1 pre-mortem catch).
- **ADR-002 amendment** — file-list extends from 3 named files to full `dist/<tier>/` tree walk. Every safety invariant preserved unchanged (L1 pre-mortem catch).
- **ADR-005 amendment** — Sam demo acceptance criterion rewritten per ADR-055 D5 hook-count banner. Prior criterion preserved as historical context (L2 pre-mortem catch).
- **ADR-007 amendment** — `## Acceptance delta` section names which D1-D7 carry forward, which get superseded, and which ADR-005 criteria this ADR partial_supersedes. Frontmatter adds `partial_supersedes: [ADR-005]` + `extended_by: [ADR-009]`.
- **UC-init rewrite** — postconditions match coord doc §Cockburn UC-init verbatim (V2 pre-mortem catch). Prior 3-file text preserved in git history + `## History` section.
- **Decomposition amendment** — `npm-install-harness-domain.md` adds 7th entity `AdopterSessionSimulator`. BCE class Boundary; GRASP role Indirection. Quoted from coord doc §Jacobson BCE + §GRASP verbatim (V3 pre-mortem catch).

## Sources read

- bassclef-upstream ADR-055 L1-140 (via local file at `~/src/sunj-labs/bassclef/architecture/decisions/ADR-055-wiring-manifest-as-init-contract.md`)
- bassclef-upstream ADR-051 Consumers section (via `gh api` search on public bassclef)
- bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` (via `gh api` on bassclef-upstream)
- cli#73 body (execution plan; 4 phases)
- cli#68 body (Phase 1 scope; 6 doc edits named)
- `docs/whereami.md` L17-35 (in-flight state)
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` L1-259 (current file-list contract)
- `docs/adrs/ADR-005-npm-distribution-architecture.md` L1-238 (current Sam demo acceptance)
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` L1-294 (current bundle path)
- `docs/use-cases/UC-init.md` L1-150 (prior 3-file postconditions)
- `docs/decompositions/npm-install-harness-domain.md` L1-210 (prior 6-object model)

## Gate evidence

| Gate | Status | Evidence |
|---|---|---|
| Temperance | Fired at Step 0 prep | `state/markers/temperance/feat-cli-68-oo-ad-updates-post-adr-007-pivot.marker` — scope decision: Phase 1 OOAD updates only; no code; drift trigger names Phase 3 + test authoring + src/ edits |
| Pre-mortem light | Fired at Step 0 prep | `docs/risk-ledgers/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md` — 3 lenses (Nygard + Vernon + Torvalds) × 3 risks each; strongest folded into Steps 2 + 5 + 6 |
| Luminary | Fired at Step 0 prep | `state/markers/luminary/feat-cli-68-oo-ad-updates-post-adr-007-pivot.marker` — lead nygard; supporting cockburn + jacobson + vernon + cooper + torvalds |
| ADR-consult | Fired at Step 0 prep | `state/markers/adr-deviation/feat-cli-68-oo-ad-updates-post-adr-007-pivot.marker` — outcome ADR-honored; Phase 1 IS the ADR update that brings cli side into conformance with ADR-055 |
| Thread walk | Fired at Step 0 prep | `state/markers/thread-walk/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.marker` — walked cli#73 → cli#68 → parent goal 2026-08-06b (npm distribution) → root |
| Orientation gate | Fired at Step 0 prep | `state/markers/orientation-gate/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.marker` — whereami read at 2026-09-12T21:41:35Z |
| Tier 0 tests | GREEN (baseline preserved) | vitest 232/232 pass; no new tests owed for docs-only Phase 1 |
| Reviewer | Self-review + verbatim quote discipline | V2 + V3 pre-mortem catches enforced verbatim copy from coord doc; grep audit confirms |
| Verify | Full suite GREEN | `npx vitest run` — 31 test files pass; 232 tests pass; 2.58s duration |
| /architect-review auto | Skipped (docs-only) | Per skill Step 7.5 skip criteria — docs-only session; no code touched |

## What worked

**Verbatim-quote discipline on the coord doc paid off.** V2 pre-mortem catch (UC-init postconditions) + V3 pre-mortem catch (decomposition BCE + GRASP) both drove me to copy from the coord doc rather than paraphrase. Result: cli side matches upstream contract byte-for-byte on the postcondition + object-model surfaces. Future maintainers reading either side see the same words.

**Cross-citation over re-authoring.** V1 pre-mortem catch pushed ADR-009 to reference ADR-055 D1-D7 by number. ADR-009 is a cli-side pointer, not a duplicate authority. Adopters see one contract; readers see cli's binding to it.

**Adopter invariant preservation named explicitly.** L1 pre-mortem catch drove me to add "every safety invariant preserved" contracts to ADR-002 + ADR-005 + ADR-007 amendments. Refuse-overwrite, root refusal, symlink refusal, path scoping, atomic writes, complete mediation, escape-hatch matrix, exit codes — all stay. Amendments extended the file-list + rewrote the Sam demo criterion + added Acceptance delta. Nothing weakened.

**Marker hook + goal-slug matching.** The `bet-doc-gate.sh` hook expects `state/markers/arc-walk/<goal-slug>.marker`, not `state/markers/thread-walk/<branch-slug>.marker`. Discovered mid-session; wrote markers to both paths (both accepted per grace window). Compat-shim discipline held; no override used.

## What did not work

**Task list drift.** I marked Step 6 done + Step 7 in_progress incorrectly one turn — task 7 was still marked in_progress when I moved to Step 7. Caught by the task-list-drift reminder. Fixed with two TaskUpdate calls.

**Stash-and-pop for hook side-effects.** Merging the PR left `state/luminary-implementations/*.json` files in working state (hook side-effects from ADR reads). `git checkout main` refused; had to stash + checkout + pull + pop. Minor friction; no data loss. Follow-on candidate: gitignore the auto-tracked luminary state files, OR add them to a per-goal commit at Step 0.

## Session insights

**OOAD-first discipline held.** Operator directive was "engineer, not post facto — update OOAD first." I resisted every urge to touch src/. Phase 1 shipped as a pure docs change. Phase 3 will read from what Phase 1 wrote. That is the discipline the class ADR-055 was authored to prevent needing to name.

**The coord doc's fully-dressed UC-init became the reader-side contract.** The coord doc at bassclef-upstream carries Cockburn UC-init verbatim. Cli's UC-init now copies that verbatim. Two docs; one contract. If either drifts from the other, it is visible immediately.

**Pre-mortem light + verbatim-copy discipline together closed drift.** The three verbatim-copy catches (V2 + V3 + V1) predicted three specific drift classes at prep time. All three cures shipped verbatim in the code (docs edit) at write time. Nygard ADR lifecycle + Feathers characterization test discipline compose here.

## Next work

Phase 2 (cli#25 publish workflow) — separate /longrun. Needs its own prep + /pre-mortem light. Scope: workflow reads `dist/<tier>/` from bassclef-upstream v0.39.0 tarball; package.json `files` field amend; ADR-001 §Invariants amend (allow lite substrate tree).

Phase 3 (init walker code) — separate /longrun. Needs /pre-mortem light before code per loop discipline. Scope: cli init reads `dist/<tier>/` per ADR-009 D1; fail-loud paths per D4; hook-count banner per D5; substitution logic for CLAUDE.md + whereami.md + `.bassclef-source.json` placeholders.

Phase 4 (cold-adopter smoke) — runs after Phase 3 ships live version. Uses bassclef-upstream `.claude/hooks/tests/init-output-parity.test.sh` as the parity test.

## Refs

- Closes bassclef-cli#68
- Refs bassclef-cli#73 (parent execution plan; Phases 2-4 remain open)
- Refs bassclef-upstream ADR-055 (reader-side contract shipped at v0.39.0)
- Refs bassclef-upstream ADR-051 Consumers section
- Refs bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md`
- Refs `docs/iteration-bets/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md` (goal doc)
- Refs `docs/risk-ledgers/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md` (pre-mortem light)
- PR #74 (merge commit `46eb4ec1`)
