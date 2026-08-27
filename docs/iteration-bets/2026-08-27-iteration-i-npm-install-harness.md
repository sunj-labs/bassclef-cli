---
bet: 2026-08-27-iteration-i-npm-install-harness
title: Iteration i — install harness for @thebassclef/core with full OOAD ceremony
project: bassclef-cli
tier: standard
status: in_flight
authored: 2026-08-27
authored_by: agent
in_flight_bet: true
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
parent_roadmap: bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md
prep_source: docs/next-longrun-prep-2026-08-13-npm-install-harness.md
appetite: 120-180 turns
appetite_source: |
  Prep doc L109 grounds the range against bet 2026-08-06b actuals — WU-1 through
  WU-5 shipped ~350 turns across 6 sessions (~60 turns per WU with heavy test
  setup). WU-3 sync command was the closest shape (~90 turns, deep decomposition
  + fixture-heavy). Iteration i is bigger (crosses filesystem + tarball + install
  + CLI invocation) but the OOAD ceremony front-loads design decisions. Wider
  top of the range covers characterization-test discovery per Feathers.
authoring_luminaries:
  primary: [michael-feathers, alistair-cockburn]
  supporting: [alan-cooper, michael-nygard, sophia-prater, john-ousterhout]
lead_lens: michael-feathers
tickets: []
references:
  - {type: bet, id: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md, anchor: parent goal — Goal A launch @thebassclef/core}
  - {type: prep, id: docs/next-longrun-prep-2026-08-13-npm-install-harness.md, anchor: authoritative scope + step table for iteration i Option b}
  - {type: roadmap, id: bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md, anchor: parent roadmap — bassclef-lite market entry}
  - {type: adr, id: docs/adrs/ADR-005-npm-distribution-architecture.md, anchor: two-road split the harness verifies}
  - {type: adr, id: docs/adrs/ADR-002-bassclef-init-safety-contract.md, anchor: init behavior the harness exercises}
  - {type: adr, id: docs/adrs/ADR-004-publish-pipeline-safety-contract.md, anchor: publish pipeline the harness rides after}
  - {type: rule, id: bassclef-upstream/.claude/rules/oo-ad-entry-point.md, anchor: OOAD ceremony matrix — new lib + hook = fully-dressed}
  - {type: rule, id: bassclef-upstream/.claude/rules/testing-tier-config.md, anchor: Tier 0 strict TDD applies to harness}
  - {type: rule, id: bassclef-upstream/.claude/rules/loop-discipline.md, anchor: 6-step cycle plus 3 sub-steps this run honors}
adr_references:
  - ADR-005 (two-road split — harness verifies Road 1 npm path)
  - ADR-002 (init safety contract — harness exercises)
  - ADR-004 (publish pipeline — harness rides after)
  - ADR-031 (upstream — we don't break adopters; harness is the adopter contract test)
  - ADR-006 (this bet ships — pins harness contract)
---

# Iteration i — install harness for @thebassclef/core with full OOAD ceremony

## Sources read

- `bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` — parent_roadmap; 5-iteration lite market entry ACTIVE with parent_drivers naming 5 existing adopters + 9 waiting signups; authoring luminaries primary include michael-feathers (this bet's lead)
- `docs/next-longrun-prep-2026-08-13-npm-install-harness.md` — this bet's authoritative scope + step table (Option b recommended L67); the 10-step table below is copied from prep doc L88-101 with produces/consumes columns added
- `docs/whereami.md` — last updated 2026-08-18; iteration i named as in-flight at L69 with prep doc path cited; risk register L150 flags WU-7 as still deferred
- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` — parent bet; WU-1 through WU-5 merged per whereami L34-56; WU-6 through WU-9 remaining per whereami L123-125
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` — init default behavior (L67-98) the harness exercises; accepted via PR #4
- `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` — two-job publish pipeline (L99-151) the harness rides after; accepted via PR #7
- `docs/adrs/ADR-005-npm-distribution-architecture.md` — two-road split (Road 1 npm; Road 2 sync hook) with Model C amendment L133-201 pending upstream #1184
- `docs/session-logs/2026-08-13-iteration-e-plus-npm11-cure.md` — iteration e close; @thebassclef/core@0.0.2 live with provenance (workflow run 31688236246)
- `bassclef-upstream/.claude/rules/oo-ad-entry-point.md` — OOAD ceremony matrix; new lib + hook + adopter-facing code = fully-dressed use case + /decompose + ADR consult
- `bassclef-upstream/.claude/rules/loop-discipline.md` — 6-step per-PR cycle with 3 sub-steps (0.5 pre-mortem light + 2a lead-lens field + 5.5 lead-lens sign-off)
- `bassclef-upstream/.claude/rules/testing-tier-config.md` — Tier 0 strict TDD applies to substrate-adjacent test infra

## Problem

`@thebassclef/core@0.0.2` ships to npm with provenance (per cli whereami L60-66; workflow run 31688236246). No adopter-facing test today pulls the published tarball into a fresh temp dir and runs `bassclef --version` + `bassclef init` + `bassclef sync` end to end. First-adopter defects — missing `bin` entry, wrong permission bits on `dist/cli.js`, broken shebang, a runtime dep parked in `devDependencies` — will surface at Sam's install, not in cli's own tests. That failure mode is the highest-blast-radius moment per ADR-002 L37-38 framing.

## Value

Every future release runs through a real install path before it can publish. Sam's two-command install path (`npm install -g @thebassclef/core && bassclef init`) gets a characterization test at the adopter boundary per Feathers. The harness compounds — one write, every release verified — and slots into the same CI shape ADR-004 already ships. Also earns the OOAD discipline operator called out at prep doc L17-19: "harness should get deep treatment with /objectory-decompose /use-case and /decompose as needed with /luminary on board with 1) ADR creation 2) Appropriate annotation - @pattern, @requirement, etc. 3) traceability mechanics wired in from the start".

## Compounds

per-release · per-adopter-session · v0.0.2 already live on npm · yes (harness template for every future install-flow verification) · medium risk

## Adopter

Mechanism — harness runs on every release event AND on-demand via workflow_dispatch. Pulls the packed tarball, installs into a fresh temp dir, runs the three verbs, asserts exit codes + stdout. Visibility — CI green/red on the harness workflow lands on the release page. Sam does not see the harness; the harness catches what Sam would have hit first. Action — none by adopter.

## Luminary map

Primary lead: **Michael Feathers** (@luminary michael-feathers) — the harness IS the characterization test at the adopter boundary. Pins actual install behavior before adopter contact. Sign-off gate at Step 9 asks: does the harness catch the failure Sam would have hit first?

Primary co: **Alistair Cockburn** (@luminary alistair-cockburn) — walking skeleton first (thin end-to-end path in Step 6); fully-dressed use case at Step 2 drives design.

Supporting:
- **Alan Cooper** (@luminary alan-cooper) — adopter is Sam, not a developer; harness exercises the same interface Sam sees.
- **Michael Nygard** (@luminary michael-nygard) — fail-safe defaults on cleanup (temp dirs, background processes, mock npm registry state).
- **Sophia Prater** (@luminary sophia-prater) — object model before actions in Step 1 (OOUX).
- **John Ousterhout** (@luminary john-ousterhout) — deep modules for harness helpers (thin wrapper over rich fixture logic).

## Pre-mortem light — 3 lenses × 3 risks

Per `.claude/rules/loop-discipline.md` Step 0.5.

**Lens 1 — Michael Feathers (characterization tests as adopter contract):**

- R1.1 — Harness runs against source build (`npm pack` from working copy) instead of published tarball. Miss = pins current source, not shipped artifact. Fix: prep doc L47 already scoped this — use `npm pack` locally BUT also test the published version fetch path in a second scenario.
- R1.2 — Test asserts stdout format that changes across Node versions. Miss = flakes on npm update. Fix: assert exit codes + presence of key strings, not full stdout match.
- R1.3 — Harness runs once, then rots as the CLI evolves. Miss = characterization drifts silent. Fix: wire to release event (per ADR-004 shape); every release re-runs.

**Lens 2 — Alistair Cockburn (walking skeleton first):**

- R2.1 — Full OOAD ceremony (Steps 1-5) ships before any test code lands. Miss = 40+ turns spent on decomposition with no working end-to-end path proven. Fix: Step 6 walking skeleton lands after Step 5 ADR but before Steps 7-8 polish; break earlier if design surfaces a wall.
- R2.2 — Use case reads at fully-dressed depth but extensions section stays thin. Miss = harness handles happy path only. Fix: extensions section names install-fail modes (perm bits, missing bin, dep missing) as UC extensions.
- R2.3 — Prep doc Option b spec locks in ADR-006 before test code. Miss = ADR proposes shape that test code cannot honor. Fix: draft ADR-006 lands after decomposition (Step 3), before test code (Step 6); revise if test surfaces friction.

**Lens 3 — Michael Nygard (fail-safe defaults on cleanup):**

- R3.1 — Temp dir cleanup leaks on test failure. Miss = fills disk over CI runs. Fix: harness uses `fs.mkdtempSync` + `trap`-style cleanup in `afterEach` OR `fs.rmSync(dir, {recursive: true, force: true})` in `finally` block.
- R3.2 — Local npm global install pollutes the CI runner's user. Miss = state leaks across runs. Fix: install to a scoped local prefix (`--prefix $tempdir/.npm-global`) not `-g`.
- R3.3 — Fixture uses live npm registry; flakes when registry is slow. Miss = false red CI. Fix: `npm pack` local tarball IS the fixture; no network hop needed for the local scenario. Second scenario uses live registry with retry.

**Strongest concerns folded into scope:** R2.1 (walking skeleton timing) → Steps 6-9 explicitly break earlier if wall surfaces. R3.1 + R3.2 (cleanup + isolation) → harness ADR-006 pins scoped prefix + cleanup contract. R1.1 (source vs published) → prep doc L47 scoped local pack AND published fetch scenarios.

## Temperance (session scope anchor)

**Right thing.** Ship iteration i — install harness with full OOAD ceremony (Option b per prep doc L67). Not WU-6 upstream side. Not WU-7 Adam Sharpe PRs (deferred). Not re-do of already-merged WU-4 publish pipeline.

**Right way.** Orchestrator-gated. `/loop` on CI until green. `/luminary` shepherds primary Feathers + Cockburn plus 4 supporting lenses. Tier 0 strict TDD per bassclef-upstream `.claude/rules/testing-tier-config.md`. OOAD chain fires per prep doc Steps 1-3.

**Scope drift trigger.** If any step exceeds 1.5× its named risk (e.g., Step 6 walking skeleton exceeds 30 turns before green), pause + re-anchor. If a new class surfaces mid-stream (e.g., harness needs a new npm-side helper), file a ticket + defer rather than expand scope.

## Steps

Per prep doc L88-101 step table. Produces / Consumes per step per `.claude/rules/wu-sequencing-compounds.md`.

| Step | Produces | Consumes (from prior step) | Risk |
|---|---|---|---|
| **0** prep | goal doc (this file) + temperance + luminary + pre-mortem markers + parent goal walk read + feature branch | session-start | 🟢 low |
| **1** /objectory-decompose | 6-object domain enumeration at `docs/decompositions/npm-install-harness.md` (Fixture, TarballPack, InstallScope, CliInvocation, VerificationResult, HarnessRun) | Step 0 luminary map | 🟢 low |
| **2** /use-case UC-npm-install-harness | fully-dressed UC at `docs/use-cases/UC-npm-install-harness.md` — actors + preconditions + main success + extensions + guarantees | Step 1 objects | 🟢 low |
| **3** /decompose (GRASP) | responsibility assignment matrix inside `docs/decompositions/npm-install-harness.md` (which class owns what) | Step 1 objects + Step 2 UC | 🟢 low |
| **4** ADR-006 | pins harness contract at `docs/adrs/ADR-006-install-harness.md` — 5 decision points (harness/ dir, git-tracked, npm pack usage, CI triggers, tier alignment) | Step 2 UC + Step 3 GRASP | 🟡 medium |
| **5** R-NPM-014 registry row | requirement diagram + registry line at `docs/requirements/registry.md` (or equivalent per cli PR #14 shape) | Step 4 ADR | 🟢 low |
| **6** harness code + fixtures | `harness/npm-install.test.ts` — Tier 0 tests with `@verifies R-NPM-014` + test-list block per `.claude/rules/test-list-discipline.md` | Steps 1-5 as spec | 🟡 medium |
| **7** CI workflow | `.github/workflows/harness.yml` — wired on release event + workflow_dispatch | Step 6 test file | 🟢 low |
| **8** annotations pass | `@requirement R-NPM-014` on harness source; `@pattern` on any embodied patterns (Fixture, ScopedTempResource, Command Object) | Step 6 code | 🟢 low |
| **9** integration verify | full workflow fires green on a synthetic release event OR workflow_dispatch | Steps 6-8 | 🟡 medium |
| **10** session close | session log + whereami flip + PR + lead-lens sign-off marker | Steps 0-9 | 🟢 low |

## Per-step compounding

Straight chain. Each step's produces feeds the next. Step 8 (annotations) could ride any prior code step. Step 5 (registry) could parallel Step 4 (ADR) but stays sequenced for readability.

## Acceptance

- [ ] `docs/decompositions/npm-install-harness.md` — 6-object domain + GRASP matrix
- [ ] `docs/use-cases/UC-npm-install-harness.md` — fully-dressed UC per Cockburn
- [ ] `docs/adrs/ADR-006-install-harness.md` — 5 decision points, accepted
- [ ] `R-NPM-014` in requirement registry with satisfy + verify paths populated
- [ ] `harness/npm-install.test.ts` — Tier 0 tests with test-list block + `@verifies R-NPM-014`
- [ ] `.github/workflows/harness.yml` — fires on release event + workflow_dispatch
- [ ] `@pattern` annotations on any embodied patterns (Fixture, ScopedTempResource, Command Object)
- [ ] Full integration run fires green on synthetic release event
- [ ] Session log + whereami flip
- [ ] Lead-lens sign-off marker (Feathers) with finding IDs cleared OR "no findings"
- [ ] PR body carries `## /temperance + /luminary + /loop discipline` section per `.claude/rules/loop-discipline.md`

## Out of scope

- WU-6 upstream cold-adopter harness check class (bassclef-upstream side; separate ticket)
- WU-7 Adam Sharpe security PRs (deferred per parent bet L128; must land before 0.1.0 or 0.0.3)
- WU-8 Sam demo (needs live 0.0.2 — which is live — but scoped as follow-on iteration)
- Model C reader implementation (bassclef-cli #25; waits on bassclef-upstream #1184)
- Adopter-first-install checklist (Option c scope; defer to follow-on iteration if operator wants it)

## Discipline carry-forward

- Orchestrator-gated + agent-merges-within-scope + `/loop` till CI green + merge
- `/luminary` vigilance per every step — Feathers lead sign-off at Step 5.5
- `/temperance` re-anchor at every phase boundary (after Step 3, Step 6, Step 9)
- `/pre-mortem` light already fired at Step 0.5 (this doc, above)
- Sam-lens check at every code change — does the harness catch the regression Sam would hit first?
- Tier 0 strict TDD on all harness code

## Refs

- Prep doc — `docs/next-longrun-prep-2026-08-13-npm-install-harness.md`
- Parent bet — `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- ADRs — 002, 004, 005 (existing) + 006 (this bet ships)
- Upstream rule — `bassclef-upstream/.claude/rules/oo-ad-entry-point.md` (ceremony matrix)
- Upstream rule — `bassclef-upstream/.claude/rules/loop-discipline.md` (6-step cycle)
- Upstream rule — `bassclef-upstream/.claude/rules/testing-tier-config.md` (Tier 0 strict TDD)
- Session log (parent bet iteration e) — `docs/session-logs/2026-08-13-iteration-e-plus-npm11-cure.md`
