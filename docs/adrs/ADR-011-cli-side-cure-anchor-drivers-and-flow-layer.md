---
tier: standard
id: ADR-011
title: cli-side cure-anchor drivers + flow-layer test taxonomy
status: proposed
date: 2026-10-08
accepted: null
accepted_via: null
supersedes: null
superseded_by: null
extends: [ADR-006]
authoring_luminaries:
  primary: [michael-feathers]
  supporting: [alistair-cockburn, kent-beck, linus-torvalds]
lead_lens: michael-feathers
goal: Session N closeout + v1.9.3 fold
amendments:
  - date: 2026-10-09
    scope: taxonomy clarification per operator catch during Session N overnight run — D1 "adopter-anchor drivers" renamed to **regression tests** (plain name); D3 "flow-layer drivers" partially collapses because 3 of 4 files added in PR #403 grep file text and are actually regression tests. The real distinction stays — regression tests pin a single past bug; flow drivers walk a full user chain via Claude. The existing `smoke-drive-e2e-*.test.sh` family IS the flow driver family (Tier A persona chains per docs/plans/tier-a-driver-inventory-state.md). A fourth family emerged tonight at the shell-CLI layer (raw commands, no Claude dispatch) — kept narrow as **shell flow tests**. File renames tracked at cli#407. Testing infrastructure layer map lives in the inventory doc §"Testing infrastructure — which layer each family fires at".
references:
  - {type: adr, id: ADR-006, anchor: install harness contract — this ADR extends with two new test categories}
  - {type: ticket, id: 2138, anchor: install-written-paths mediation cure in v1.9.3}
  - {type: ticket, id: 2139, anchor: pre-commit-gate matcher cure in v1.9.3}
  - {type: ticket, id: 2140, anchor: write-state-marker lite tier cure in v1.9.3}
  - {type: ticket, id: 2142, anchor: artifact-ingestion HTML comment cure in v1.9.3}
  - {type: ticket, id: 2143, anchor: local-serve.sh --lan cure in v1.9.3}
  - {type: file, id: scripts/tests/smoke-drive-adopter-311-artifact-ingestion-null-parent.test.sh, anchor: existing adopter-anchor driver pattern this ADR formalizes}
---

# ADR-011 — cli-side cure-anchor drivers + flow-layer test taxonomy

## Sources read

- `scripts/tests/smoke-drive-adopter-311-artifact-ingestion-null-parent.test.sh` L1-50 — current driver shape, exit codes, read-from-dist/lite pattern
- `scripts/tests/smoke-drive-e2e-launch-local.test.sh` L1-45 — e2e cascade driver pattern with pre-cure RED + post-cure GREEN cases
- Session N chronicle `docs/chronicle/2026-10-08-session-n-cli-side-scope.md` — 5 upstream filings routed from cold-adopter smoke
- Session N retro turn in-session — 7 adjacency classes + the deepest adjacency: missing flow layer

## Context

Session N filed five upstream tickets (#2138, #2139, #2140, #2142, #2143) based on cold-adopter smoke findings. All five slipped past bassclef upstream's static tests + adopter-sim and only surfaced when a human ran the install from scratch. During the Session N retro turn, the operator asked whether cli-side has drivers that would catch these cure classes before they reach a cold adopter.

The audit result: cli has partial coverage only. The adopter-311 driver anchors ONE cure class (`parent_bet: null` in artifact-ingestion-gate). The 5 Session N cures all share the same shape — a bassclef substrate defect that cli bundles via `dist/lite/`. The existing `smoke-drive-adopter-<N>-<slug>.test.sh` pattern was authored once for cli#311 but not consistently extended for subsequent upstream cures.

The deeper gap: all 5 defects fired at FLOW boundaries, not at single-skill boundaries. Install → first commit. Launch → serve → phone. Agent-write → hook-scan. Write marker → use marker. The cli harness tests individual skills + hooks + utilities. It does not test adopter command sequences.

## Decision

Two test categories ship under the cli harness:

### D1 — adopter-anchor drivers

Per-cure characterization tests under `scripts/tests/smoke-drive-adopter-<upstream-ticket-N>-<slug>.test.sh`. Shape:

- Reads shipped `dist/lite/` artifacts post-bundle
- Asserts cured behavior OR pre-cure RED anchor (two shapes; see D2)
- Exit 0 = assertion matched; exit 1 = assertion missed; exit 77 = SKIP (bundle or tool unavailable)
- Header carries `tier: upstream`, `testing-tier: 0`, upstream ticket reference, cure anchor paragraph
- Ships one driver per filed upstream ticket cured in a bundled release

### D2 — driver assertion shapes

Two shapes compose. The driver's exit semantics stay stable; its assertion flips as the cure lands.

**Pre-flip RED-confirms** — asserts the defect is PRESENT in the current bundled `dist/lite/`. Fires PASS when the regression anchor matches. Used before a cure bundle sync lands at cli-side; useful when the cure is in flight at bassclef upstream.

**Post-flip GREEN-confirms** — asserts the cure IS PRESENT in the current bundled `dist/lite/`. Fires PASS when the cured behavior matches. Used after the cure bundle sync lands at cli-side.

Driver flips in the same PR as the bundle sync. The flip is a one-line assertion swap. Both shapes stay greppable by exit code (0 = PASS; 1 = defect- or cure-missing; 77 = SKIP).

### D3 — flow-layer drivers

New test category under `scripts/tests/smoke-drive-flow-<slug>.sh`. Runs an adopter command sequence end-to-end with assertions between steps. Shape:

- Reads from a docker cold-adopter container OR a scratched local workdir
- Runs commands as the adopter would (`bassclef init`, `git add -A && git commit`, `/launch --local --lan`, etc.)
- Asserts the state AFTER each step (file existence, exit code, printed output shape, state marker written at expected path)
- Fails when any step's postcondition breaks the flow
- Exit 0 = full flow succeeded; exit 1 = flow broke at a named step

Flow layer complements D1 adopter-anchor drivers. D1 pins a single-hook or single-skill cure. D3 pins the sequence of actions a real adopter runs. All 5 Session N defects fired at flow boundaries — D3 catches that class.

### D4 — flow registry

`scripts/tests/smoke-drive-flows-registry.sh` — bash array enumerating flow drivers + their intents. Mirror of the existing `smoke-drives-registry` for persona drivers. The harness picks up flows the same way it picks up persona drivers via the registry.

## Consequences

**Easier:**
- Each future bassclef cure that lands in a cli bundle ships with its anchor driver in the same PR (per Beck TDD rhythm, red-first on bundle sync).
- Future cold-adopter failures reproduce at cli-side via flow drivers before they reach adopters.
- The driver registry gives a scannable catalog of what cures cli-side anchors — adopter-visible contract.

**Harder:**
- Each driver adds test runtime (small; drivers are bash + grep against dist/lite).
- Flow drivers require careful fixture management — the cold-adopter container shape matters.
- Pre-flip vs post-flip discipline needs operator attention at bundle-sync time (one-line assertion swap).

**Enables:**
- Characterization audit per Michael Feathers at cli adopter boundary — every bundled cure has a test that would fire if it regressed.
- Flow-shaped regression coverage per Cockburn walking-skeleton — covers the sequence a cold adopter runs, not just the individual building blocks.
- Honest signal per Linus Torvalds adopter-contract — cli harness surfaces exactly what breaks when upstream regresses.

**Blocks:**
- v1.9.3 bundle sync PR ships 5 new adopter-anchor drivers for Session N cures AND the flow registry primitive. This ADR documents the pattern they instantiate.

## Alternatives considered (Peirce)

**A. Adopter-anchor drivers only, no flow layer.** Covers the 5 Session N cures but misses the sequence-boundary class the retro surfaced. Rejected because 4 of 5 Session N defects fired at flow boundaries; single-anchor coverage leaves the deeper class open.

**B. Flow layer only, no adopter-anchor drivers.** Covers sequences but drops the specific per-cure anchor that catches a precise regression. Rejected because flow drivers fire LATE in the chain; adopter-anchor drivers fire at the exact write surface. Both layers compose.

**C. Extend docker-smoke to run bassclef's own adopter-sim.** Lower cli-side cost but delegates characterization to bassclef upstream. Rejected because the 5 Session N defects proved bassclef adopter-sim misses this class.

## Composes with

- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD on hooks + scripts; drivers land Tier 0
- `.claude/rules/test-sufficiency.md` — criterion 11 path resolution under both install classes; drivers assert cli-bundled behavior
- `.claude/rules/sibling-smoke-after-substrate-change.md` — sister per-release smoke; drivers run per-PR docker-smoke
- `.claude/rules/cold-adopter-harness-discipline.md` — the harness this ADR extends with two new categories
- `.claude/rules/bootstrap-pair-discipline.md` — each driver ships with its upstream ticket cross-reference
- @luminary michael-feathers — characterization test lead
- @luminary alistair-cockburn — walking skeleton + flow-shaped scenarios
- @luminary kent-beck — Tier 0 RED-first drivers; test list before source
- @luminary linus-torvalds — adopter contract; honest signal on bundle sync

## Open questions

- Flow driver scope. The ADR commits to 4 initial flows for Session N cures. Additional flows ship per-cure as new upstream filings land.
- Harness integration. Docker-smoke currently runs persona drivers via the e2e matcher. Flow drivers need a matcher extension; the registry file is the discovery surface. Implementation lands in the v1.9.3 PR.
- Pre-flip vs post-flip ergonomics. Operator may want a flag that flips all drivers for a known-cured upstream version in one shot. Deferred to a follow-on.
