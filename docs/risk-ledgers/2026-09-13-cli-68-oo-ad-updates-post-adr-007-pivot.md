---
tier: lite
title: Risk ledger — cli#68 Phase 1 OOAD updates
goal: 2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot
authored: 2026-09-13
authored_by: agent
premortem_mode: light
lenses:
  - michael-nygard
  - vaughn-vernon
  - linus-torvalds
---

# Risk ledger — cli#68 Phase 1 OOAD updates

## Method

Klein workshop shape, light mode. Three luminary lenses × three risks per lens. Phase 1 is docs-only. Risks scale accordingly.

## Nygard lens — ADR lifecycle across pivots

**N1 — Upstream ADR-055 gets amended after cli#68 ships.**

- Class: cross-repo ADR drift; cli-side citation goes stale
- Falsifier: bassclef-upstream ADR-055 has `status: accepted` on 2026-09-13; amendments would go through a new ADR extending ADR-055
- Cure: cli ADR-009 cross-cites ADR-055 by section number (D1-D7). Upstream amendment lands as an extending ADR with a new number; cli cites the extend chain at that point.
- Fold into: no scope change; documented in ADR-009 §Refs.

**N2 — Cli-side ADR-002 file-list drift from ADR-055 D2 five-field pin.**

- Class: cli ADR names fields the wiring manifest does not carry
- Falsifier: read ADR-055 D2 verbatim; cli ADR-002 amendment cites D2 fields by exact name (`id + hook + event + matcher + tier`)
- Cure: Step 2 amendment quotes ADR-055 D2 field list verbatim; no cli-side field invention.
- Fold into: Step 2 procedure.

**N3 — ADR-007 `partial_supersedes` frontmatter conflicts with existing bassclef-cli ADR discipline.**

- Class: ADR frontmatter shape unfamiliar to bassclef-cli's ADR reviewer discipline
- Falsifier: grep bassclef-cli `docs/adrs/` for prior `supersedes` or `partial_supersedes` fields
- Cure: Step 4 adds `partial_supersedes: [ADR-005]` if the ADR-007 schema allows it; otherwise use `## Acceptance delta` section prose alone and skip frontmatter. Non-blocking.
- Fold into: Step 4 procedure notes fallback path.

## Vernon lens — anticorruption between substrate and cli

**V1 — Cli ADR-009 becomes a duplicate authority parallel to ADR-055.**

- Class: two ADRs claim the same contract; adopters unclear which to read
- Falsifier: ADR-009 §Sources read cites ADR-055 as authority; ADR-009 §Decision references ADR-055 D1-D7 by number without re-authoring semantics
- Cure: Step 1 authors ADR-009 as a cli-side pointer, not a re-statement. Body cites "per ADR-055 D1" or "matches ADR-055 D2" for each decision.
- Fold into: Step 1 procedure.

**V2 — UC-init postconditions diverge from ADR-055 D1 verbatim.**

- Class: UC-init rewrite drifts from coord doc semantics; Phase 3 code reads a UC that does not match the shipped contract
- Falsifier: Step 5 UC rewrite pastes postcondition text verbatim from coord doc §Cockburn UC-init §Postconditions
- Cure: Step 5 procedure copies from coord doc §Postconditions block verbatim; no paraphrasing.
- Fold into: Step 5 procedure.

**V3 — Decomposition `AdopterSessionSimulator` BCE class disagrees with coord doc.**

- Class: cli decomposition classifies the new object differently from coord doc; GRASP role assignment drifts
- Falsifier: coord doc names `AdopterSessionSimulator` verb "verify hooks fire post-init" with BCE class Boundary; GRASP role Indirection
- Cure: Step 6 procedure quotes coord doc §Jacobson BCE + §GRASP verbatim.
- Fold into: Step 6 procedure.

## Torvalds lens — adopter invariant preservation

**L1 — ADR-002 file-list extension removes safety defaults.**

- Class: extending the file-list drops refuse-overwrite or path-scoping invariants
- Falsifier: read ADR-002 current §Invariants section; Step 2 amendment appends new file paths but does not touch invariant text
- Cure: Step 2 procedure names "extend file-list; preserve invariants unchanged" as an explicit contract.
- Fold into: Step 2 procedure + acceptance checkbox.

**L2 — ADR-005 rewrite breaks the Sam-demo acceptance test for existing adopters.**

- Class: current adopters on 0.1.x see the new acceptance criterion fail because their hooks block is empty
- Falsifier: ADR-005 amendment lists the pre-pivot Sam demo criterion in a §"Previous acceptance" bullet before naming the new one
- Cure: Step 3 amendment preserves the prior criterion as historical context. Current 0.1.x adopters cure at Phase 3 code ship, not at ADR read time.
- Fold into: Step 3 procedure.

**L3 — Phase 1 PR body cites tickets that a downstream reviewer cannot resolve.**

- Class: PR body references bassclef-upstream tickets (1615/1616/1617/12e) that reviewer without upstream access cannot open
- Falsifier: PR body cites each upstream ticket with a one-line context sentence; no reference stands alone
- Cure: Step 7 PR body carries `## Refs` section with plain-language context per referenced ticket.
- Fold into: Step 7 procedure.

## Strongest concerns folded into the plan

- **N2** — Step 2 quotes ADR-055 D2 verbatim; cli ADR-002 amendment references field list by exact name.
- **V2** — Step 5 UC rewrite copies from coord doc §Postconditions verbatim; no paraphrasing.
- **V3** — Step 6 decomposition amendment quotes coord doc §Jacobson BCE + §GRASP verbatim.
- **L1** — Step 2 procedure explicitly names invariant-preservation as a contract.

## Refs

- Goal doc — `docs/iteration-bets/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md`
- Coord doc — bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md`
- ADR-055 (bassclef-upstream) — reader-side contract
- ADR-051 (bassclef-upstream) — Consumers section
- Klein — *Sources of Power* (MIT Press, 1998) — pre-mortem method
- @luminary michael-nygard — ADR lens
- @luminary vaughn-vernon — anticorruption lens
- @luminary linus-torvalds — adopter contract lens
