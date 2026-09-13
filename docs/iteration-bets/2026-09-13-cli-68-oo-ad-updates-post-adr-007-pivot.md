---
tier: lite
goal: 2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot
title: cli#68 Phase 1 — OOAD updates matching upstream ADR-055 reader contract
project: bassclef-cli
execution_repo: sunj-labs/bassclef-cli
status: proposed
authored: 2026-09-13
authored_by: agent
in_flight_goal: null
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
time_budget: 50-80 turns
time_budget_source: |
  Similar-shape OOAD-heavy sessions ground the range. Iteration i (2026-08-27)
  shipped 7 commits at ~90 turns per whereami L169. Goal 28d Steps 0-3.5
  (2026-08-29) shipped OOAD-only work at ~50 turns per whereami L61. Phase 1
  ships 1 new ADR + 3 amends + 1 UC rewrite + 1 decomposition amend = 6 doc
  edits + goal doc + session log + PR. Sits between the two grounding points.
authoring_luminaries:
  primary: [michael-nygard]
  supporting: [alistair-cockburn, ivar-jacobson, vaughn-vernon, alan-cooper, linus-torvalds]
lead_lens: michael-nygard
tickets: [68, 73]
references:
  - {type: parent_bet, id: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md, anchor: parent goal — npm distribution for @thebassclef}
  - {type: ticket, id: 68, anchor: cli-side ADR + OOAD updates ticket (this Phase 1 closes)}
  - {type: ticket, id: 73, anchor: umbrella plan tying #68 + #25 + init walker + smoke into 4 phases}
  - {type: adr, id: ADR-055, anchor: bassclef-upstream — reader-side contract with D1-D7 pins}
  - {type: adr, id: ADR-051, anchor: bassclef-upstream — Consumers section with cli MUST/MUST-NOT rules}
  - {type: coord, id: docs/coordination/2026-09-12e-cli-boundary.md, anchor: bassclef-upstream — Cockburn UC + Jacobson BCE + GRASP roles}
  - {type: rfc, id: RFC-0002, anchor: bassclef-upstream — wiring manifest tier extension; 19 outside-council findings folded}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md, anchor: pre-mortem light — 3 lenses × 3 risks}
adr_references:
  - ADR-002 (bassclef init safety contract) — file-list contract amended in Step 2
  - ADR-005 (npm distribution architecture) — Sam demo acceptance amended in Step 3
  - ADR-007 (npm-lite substrate bundling) — Acceptance delta added in Step 4
  - ADR-009 (new — manifest as init contract source) — authored in Step 1
---

# cli#68 Phase 1 — OOAD updates matching upstream ADR-055 reader contract

## Problem

Upstream 12e shipped v0.39.0 (tag `6cdff4a4`) with ADR-055 pinning the reader-side contract, ADR-051 Consumers section pinning cli MUST/MUST-NOT rules, and a coord doc carrying Cockburn UC-init + Jacobson BCE + GRASP roles. Cli-side ADR-002, ADR-005, and ADR-007 still describe the pre-pivot world. Cli UC-init postconditions still say "3 files written." Engineer-first here reproduces the exact class ADR-055 was written to prevent — cli code that outruns its contract.

## Value

OOAD-first, code-second. Phase 1 lands the doc edits that Phases 2-4 will read from. Ship 1 new cli-side ADR + 3 amends + 1 UC rewrite + 1 decomposition amend. No code. Unblocks cli#25 (Phase 2 publish workflow) and the init walker (Phase 3).

Per @luminary michael-nygard — the pivot chain across ADR-002 → ADR-005 → ADR-007 dropped acceptance criteria at each step. This goal closes that gap with `partial_supersedes` frontmatter and a new `## Acceptance delta` section.

Per @luminary alistair-cockburn — UC-init gets rewritten fully-dressed with postconditions matching the shipped `dist/<tier>/` tree walk. The current UC's "3 files" postcondition is a historical relic.

Per @luminary ivar-jacobson — the harness decomposition gains `AdopterSessionSimulator` — a new Boundary object that simulates Sam's post-init session-start.

Per @luminary vaughn-vernon — the new ADR-009 pins the wiring manifest as anticorruption layer between substrate authoring decisions and cli init behavior.

Per @luminary alan-cooper — Sam's cold-adopter empty-hooks class since 0.1.0 gets a documented cure path. Phase 3 code lands the cure; Phase 1 pins the contract that Phase 3 reads.

Per @luminary linus-torvalds — the ADR amendments preserve every current adopter invariant. Refuse-overwrite stays. Path scoping stays. Only the file-list extends.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` — parent goal; npm distribution parent; walked this session
- `docs/whereami.md` L17-35 — in-flight state; open threads name #68 waiting on upstream 12e
- cli#73 body — 4-phase execution plan tying #68 + #25 + init walker + smoke
- cli#68 body — Phase 1 scope enumeration; 6 doc edits named
- bassclef-upstream ADR-055 L59-89 — D1-D7 reader-side contract this goal cites
- bassclef-upstream ADR-051 Consumers section — cli MUST/MUST-NOT rules
- bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` — Cockburn UC-init + Jacobson BCE + GRASP
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` — current file-list contract (3 files)
- `docs/adrs/ADR-005-npm-distribution-architecture.md` — current Sam demo acceptance criterion
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` — current bundle path contract
- `docs/use-cases/UC-init.md` — current postconditions (3 files)
- `docs/decompositions/npm-install-harness-domain.md` — current 6-object model

## What I'm NOT reading (with reason)

- Full bassclef-upstream RFC-0002 body — cited by ADR-055 references; folds V1-V6 + O1-O6 + B1-B6 + K1-K5 + H1-H5 + P1-P4 + W1-W5 + C1-C5. The dispositions this goal cares about live in ADR-055 D1-D7 already.
- bassclef-upstream `standards/bassclef-wiring-manifest.schema.json` — Phase 3 code work reads this; Phase 1 cites its role via ADR-055 D2.
- Prior UC-init version history — this goal rewrites UC-init verbatim per coord doc; older versions stay in git history.

## Steps

| Step | Problem + value | Produces | Consumes (from prior) | How builds on prior | Risk |
|---|---|---|---|---|---|
| **0** housekeeping | Session start; scope confirmed; markers absent | Goal doc + risk ledger + temperance/pre-mortem/luminary/ADR-consult markers | session-start | baseline | 🟢 |
| **1** new ADR-009 | Cli has no ADR pinning "manifest is the init contract source"; new ADR cross-cites upstream ADR-055 D1-D7 | `docs/adrs/ADR-009-manifest-as-init-contract-source.md` | Step 0 goal doc | Anchors the cross-repo contract at cli side | 🟢 |
| **2** amend ADR-002 | ADR-002 file-list says 3 files; post-pivot init walks full `dist/<tier>/` tree | ADR-002 §File-list contract extended; refuse-overwrite invariant preserved | Step 1 ADR-009 anchor | Extends the contract without removing safety invariants | 🟢 |
| **3** amend ADR-005 | ADR-005 Sam demo acceptance says "confirm sync hook set up"; ADR-055 D5 pins hook-count banner | ADR-005 §Consequences rewritten; two-road split preserved | Step 2 ADR-002 shape | Rewrites the Sam acceptance criterion per D5 banner | 🟢 |
| **4** amend ADR-007 | ADR-007 pivoted Road 1 but did not name what acceptance changed | ADR-007 §Acceptance delta section + `partial_supersedes: [ADR-005]` frontmatter | Step 3 ADR-005 amend | Names the pivot delta explicitly per Nygard | 🟢 |
| **5** rewrite UC-init | UC-init postconditions say "3 files"; post-pivot init writes full tree | UC-init rewritten fully-dressed per coord doc Cockburn UC-init | Step 4 ADR-007 delta | Postconditions now match ADR-055 D1 verbatim | 🟢 |
| **6** amend decomposition | `npm-install-harness-domain` needs `AdopterSessionSimulator` object per coord doc | `docs/decompositions/npm-install-harness-domain.md` extended; new Boundary object with BCE + GRASP | Step 5 UC-init postconditions | Adds the harness object that simulates Sam's post-init session-start | 🟢 |
| **7** verify + PR + auto-merge | Full suite GREEN; PR body per rule; ticket close; whereami flip | 232 tests GREEN via vitest; PR opened + auto-merged within scope; session log; whereami update | Union of Steps 0-6 | Ships Phase 1; unblocks Phase 2 (cli#25) | 🟢 |

## Compounding value per step

- **Step 1 ADR-009** — payoff per-adopter (cli anchors upstream contract); fires per-release; needs coord doc; teaches Nygard cross-repo ADR anchor; low risk
- **Step 2 ADR-002** — payoff per-PR (file-list is reviewer contract); fires per-init-touching-PR; needs Step 1; teaches Feathers invariant preservation; low risk
- **Step 3 ADR-005** — payoff per-adopter (Sam demo test now matches shipped state); fires per-release; needs Step 2; teaches Cooper persona-anchored acceptance; low risk
- **Step 4 ADR-007** — payoff per-reviewer (delta names what pivoted); fires per-ADR-read; needs Step 3; teaches Nygard `supersedes` chain; low risk
- **Step 5 UC-init** — payoff per-PR (UC is the postcondition oracle); fires per-init-code-PR; needs Step 4; teaches Cockburn fully-dressed; low risk
- **Step 6 decomposition** — payoff per-Phase-3-PR (GRASP role guides walker code); fires per-implementation-PR; needs Step 5; teaches Jacobson BCE + Larman GRASP; low risk
- **Step 7 verify + close** — payoff per-session (whereami reflects Phase 1 shipped; Phase 2 unblocked); fires per-session; needs Steps 1-6; teaches auto-merge-within-scope; low risk

## Acceptance

- [ ] Step 1 — ADR-009 shipped with 7 decisions matching ADR-055 D1-D7 by cross-citation
- [ ] Step 2 — ADR-002 file-list extended to full `dist/<tier>/` tree walk
- [ ] Step 3 — ADR-005 Sam demo acceptance names hook-count banner per D5
- [ ] Step 4 — ADR-007 carries `## Acceptance delta` section + `partial_supersedes: [ADR-005]` frontmatter
- [ ] Step 5 — UC-init postconditions match `dist/<tier>/` tree walk verbatim
- [ ] Step 6 — decomposition adds `AdopterSessionSimulator` object with Boundary class + GRASP Indirection role
- [ ] Step 7 — PR opened; full suite GREEN; auto-merged; whereami reflects Phase 1 shipped; ticket #68 closed by `Closes` keyword

## Out of scope

- Phase 2 (cli#25 publish workflow) — separate /longrun; needs its own prep + pre-mortem
- Phase 3 (init walker code) — separate /longrun; needs /pre-mortem light before code per loop discipline
- Phase 4 (cold-adopter smoke) — runs after Phase 3 ships live version
- New tests — Phase 1 is docs-only; no test edits owed
- Retiring the current `substrate/` bundle path — Phase 2 handles the workflow change; ADR-007 amendment names the delta but does not remove the path

## Refs

- Closes bassclef-cli#68 (Phase 1 scope closes here)
- Refs bassclef-cli#73 (parent execution plan; Phases 2-4 remain open)
- Refs bassclef-upstream#1615 + #1616 + #1617 (all merged 2026-09-13 at v0.39.0)
- @luminary michael-nygard — ADR lifecycle across pivots (lead)
- @luminary alistair-cockburn — fully-dressed UC-init
- @luminary ivar-jacobson — BCE decomposition + AdopterSessionSimulator
- @luminary vaughn-vernon — anticorruption layer at manifest boundary
- @luminary alan-cooper — Sam persona anchor
- @luminary linus-torvalds — adopter invariant preservation
