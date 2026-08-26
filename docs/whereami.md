---
tier: lite
---

# Whereami — bassclef-cli

Current project-state snapshot. Schema: `standards/whereami-schema.md`.
Read at session-start, updated at session-end.

## Project-level phase

phase: Construction
note: Execution home for Goal A — build + launch `@thebassclef/core` on npm. Bassclef substrate inherited via user-scope `~/.claude/hooks/bassclef-sync.sh`; this repo carries only the config layer + build artifacts. Model C direction (open core) locked in ADR-005 §Amendment 2026-08-12 pass 2.

## Active iteration

iteration_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
iteration_started: 2026-08-06
iteration_phase: WU-1 through WU-5 + iteration e (v0.0.2 live) + iteration i (install harness) SHIPPED. Iteration i landed 7 commits under feat/iteration-i-npm-install-harness — full OOAD chain (domain + UC + GRASP + ADR-006 + R-NPM-014 registry + harness code + CI workflow). WU-6 (upstream harness check class), WU-7 (Adam Sharpe security PRs, deferred), WU-8 (Sam demo), WU-9 (first tagged 0.1.0) remain.

## Operator recap

2026-08-27 session shipped iteration i — install harness for @thebassclef/core with full OOAD ceremony per operator direction. 7 commits on feat/iteration-i-npm-install-harness. 11 tests pass at 735ms local; 1 test skipped by design (published-fetch scenario env-gated). Two /loop iterations both RED → GREEN in one cycle each (npm -g flag defect at Step 6a; stale walking-skeleton assertion at Step 6b). Feathers lead lens signed off; Cockburn + Cooper + Nygard + Prater + Ousterhout supporting. 3 pre-mortem light runs (Step 0, Step 6b, Step 7); 27 total risks named + strongest folded per step. Step 8 pattern-annotation pass surfaced substrate gap — 3 bassclef-upstream catalog entries missing (fowler test-fixture, gof command, gof template-method); false annotations removed per pattern-annotation.md rule; follow-on candidate named in session log. Step 9 workflow verify deferred to post-merge (feature branch can't dispatch workflow_dispatch until file lands on default). PR awaits operator review.

previous_recap: Short 2026-08-18 followup session. Filed bassclef-upstream#1197 — meta-ticket for the OOAD-plus-traceability chain as a first-class bassclef offering, with a luminary consult ask on over-engineering guard + adopter tier boundary. Cross-commented on umbrella #1171. Closed stale PR #10 without merge (path b). No code shipped.

previous_recap: session 2026-08-13 shipped iteration e. @thebassclef/core@0.0.2 live on npm with provenance. Seven publish attempts before the seventh landed. Root cause was Node 20 shipping npm 10.x, and npm 10 silently omits trusted publisher headers. Pinning npm@11 cured the class.

previous_bet: —
next_bet: —

## Shipped (across session history)

**Base ship (WU-1 through WU-5 per goal doc):**

- PR #1 — chore/bassclef-bootstrap MERGED (substrate config layer)
- PR #3 — feat/wu-1-scaffold MERGED (scaffold shell + package.json + LICENSE + WU-1 tests)
- PR #4 — feat/wu-2-init MERGED (bassclef init command with ADR-002 safety contract)
- PR #5 — feat/wu-3-sync MERGED (bassclef sync command with ADR-003 safety contract)
- PR #6 — chore/decomp-diagrams-backfill MERGED (WU-2 + WU-3 state + sequence diagrams)
- PR #7 — feat/wu-4-publish MERGED (publish pipeline with ADR-004)
- PR #8 — docs(wu-5): backfill ADRs + interaction-design + use cases MERGED
- PR #9 — feat(wu-5): semver + changelog methodology + bump script MERGED

**Session 2026-08-11 to 2026-08-12 (audit + Model C arc):**

- PR #11 — feat(security): source-map exclusion before first tag MERGED (iteration a)
- PR #12 — docs(audit): OOAD audit outputs + Traceability Subsystem promote draft MERGED
- PR #13 — fix(docs): iteration b drift fix pass — 13 items MERGED
- PR #14 — docs(requirements): SysML requirement diagram MERGED (iteration f)
- PR #15 — feat(design): iteration c — 4 design decisions MERGED
- PR #17 — feat(traceability): iteration d — mechanical enforcement MERGED
- PR #18 — docs(traceability): sequence diagrams added to requirements + promote MERGED
- PR #21 — feat(traceability): iteration g — git pre-commit hook bridge MERGED
- PR #22 — docs(traceability): iteration h — substrate hook spec MERGED
- PR #23 — docs(promote): cross-reference filed ticket bassclef-upstream#1182 MERGED
- PR #24 — docs(adr): ADR-005 amendment — pivot to Model C MERGED
- PR #26 — docs(adr): ADR-005 second amendment — Model C contract accepted MERGED

**Session 2026-08-13 (iteration e + npm 11 cure):**

- PR #28 — chore: release v0.0.2 MERGED
- PR #29 — fix: sync src/index.ts version constant with package.json MERGED
- PR #30 — fix(ci): declare id-token permission at publish job level MERGED
- PR #31 — fix(ci): upgrade npm before publish for trusted publisher MERGED
- PR #32 — fix(ci): pin npm upgrade to @11 for node 20 compat MERGED
- npm publish landed on run 31688236246 — `@thebassclef/core@0.0.2` live with provenance

## In flight

- Iteration i — install harness SHIPPED 2026-08-27; PR on feat/iteration-i-npm-install-harness awaits operator review + merge.
- PR #10 — pre-existing stale session-close PR from 2026-08-08. Merge-conflict-dirty. Operator disposition pending (path a rebase / b close / c leave).
- bassclef-cli #25 — Model C reader implementation. Waits on bassclef-upstream #1184 shipping `scripts/build-lite-bundle.sh` + `dist/lite/` tree.
- bassclef-cli #16 — `@thebassclef/lite` reservation. Operator started this session; ticket stays open until `@thebassclef/lite@0.0.1` shows on npmjs.com.
- bassclef-cli #19 — `@thebassclef/standard` reservation. Lower priority.
- bassclef-cli #20 — `@thebassclef/ultra` reservation. Lower priority.

## Cross-repo tickets filed this session

- bassclef-upstream #1182 — Traceability Subsystem umbrella promote. Filed 2026-08-12. Awaits triage.
- bassclef-upstream #1184 comment 5265798011 — confirmation of (A) for lite tier extraction. Waits on upstream `/longrun` schedule.

## Active agents

- operator-gated-sequential (this session ran orchestrator-gated for the audit + fix arc)

## Subsystem phases

| Subsystem | Phase | Last iteration | Notes |
|-----------|-------|---------------|-------|
| npm package (`@thebassclef/core`) | Construction | 2026-08-12 | 12 audit-driven PRs merged; iteration e blocked on operator npm setup |
| CLI dispatcher | Construction | 2026-08-12 | Complete: init + sync + publish workflow all merged |
| Publish pipeline | Construction | 2026-08-12 | Two-job shape (checks + publish) with environment gate after checks green |
| Bump discipline | Construction | 2026-08-08 | `scripts/bump-version.mjs` + `standards/npm-versioning-and-changelog.md` + 27 tests |
| Requirement traceability | Construction | 2026-08-12 | Static diagram + Vitest enforcement + git pre-commit + upstream promote filed |
| npm 0.0.1 reservation | DONE | 2026-07-12 (pre-session) | `@thebassclef/core@0.0.1` on npm; verified via `npm view` this session |

## Gate progress (project-level)

### Inception — COMPLETE
- [x] Vision doc (goal at docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md)
- [ ] Risk register populated
- [x] Appetite set (8 WUs per goal)
- [x] Viability hypothesis written (goal doc)
- [x] Build/buy/defer decision (build — npm distribution)

### Elaboration — COMPLETE
- [x] Architecture decisions (ADR-001 through ADR-005 all accepted; ADR-005 twice amended for Model C direction + contract)
- [x] Standards defined (`standards/npm-versioning-and-changelog.md`; upstream ships `lite-manifest.json` for extraction contract)
- [ ] Design principles established (partial — luminary map + ADRs cover most surfaces)
- [x] Object model documented (interaction-design + 4 UCs + 5 decompositions + requirement diagram)

### Construction — IN PROGRESS
- [x] TypeScript + Vite scaffold — merged (PR #3)
- [x] package.json with `bin` + files array whitelist + Apache-2.0 LICENSE — merged (PR #3, whitelist tightened in PR #11)
- [x] Init command with safety contract (ADR-002) — merged (PR #4)
- [x] Sync command with safety contract (ADR-003) — merged (PR #5)
- [x] npm publish workflow with safety contract (ADR-004) — merged (PR #7, split into two jobs in PR #15)
- [x] Semver + changelog methodology — merged (PR #8, #9)
- [x] Source-map safety — merged (PR #11)
- [x] Static requirement diagram — merged (PR #14)
- [x] Traceability enforcement Vitest — merged (PR #17)
- [x] Model C direction + contract accepted — merged (PR #24, #26)
- [ ] Model C reader implementation (bassclef-cli #25) — waits on bassclef-upstream #1184
- [x] Install harness (iteration i) — 7 commits on feat/iteration-i-npm-install-harness; 11 tests pass + 1 env-gated skip
- [ ] Cold-adopter harness against npm path (WU-6 — bassclef-upstream side; separate from iteration i)
- [ ] Adam Sharpe security PRs (WU-7 — deferred per goal L128)
- [ ] Sam demo (WU-8 — needs live 0.0.2)

### Transition — PENDING
- [x] npm 0.0.1 name reservation (done 2026-07-12)
- [x] Trusted publisher config on npmjs.com (operator setup 2026-08-13)
- [x] GitHub Environment `npm-publish` with operator as required reviewer (operator setup)
- [x] First tagged 0.0.2 release (iteration e SHIPPED 2026-08-13; workflow run 31688236246)
- [x] Install harness (iteration i) — SHIPPED 2026-08-27; PR awaits operator merge
- [ ] `/architect-review` run at goal close
- [ ] Session log for goal close

## Open promote tickets

**bassclef-upstream:**

- #1167 — wire OOAD dispatch into /longrun
- #1168 — wire OOAD dispatch into /build
- #1169 — mechanize oo-ad-entry-point.md as PreToolUse hook
- #1170 — adr-discipline-check.sh warn on proposed ADRs after PRs merge
- #1171 — umbrella: OOAD artifacts as first-class inputs to /build /longrun /sprint
- #1182 — Traceability Subsystem umbrella (filed this session)
- #1184 — extract build implementation per ADR-051 D4 (awaits `/longrun` schedule)

## Risk register

- WU-7 (Adam Sharpe security PRs) deferred per goal L128 — must land before 0.1.0 or 0.0.3.
- Model C reader work (bassclef-cli #25) depends on bassclef-upstream #1184 shipping. If upstream deprioritizes, iteration e still ships (0.0.2 stays on the current story) but the Model C bundled shape slips.
- Paid tier extraction contract (Q4 from Model C amendment) pending. If deferred too long, could block a paid-tier launch when the moment comes.

## Last updated

2026-08-27T00:55:00Z — session-end (iteration i install harness shipped; 7 commits; PR awaits operator merge)
session: docs/session-logs/2026-08-27-iteration-i-npm-install-harness.md

## Configuration

See substrate.config.md for external resource references.
