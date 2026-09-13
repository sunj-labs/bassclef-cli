---
tier: lite
goal: 2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite
title: cli#25 Phase 2 — publish workflow ships dist/lite/ alongside substrate/ (MINOR bump 0.1.3 → 0.2.0)
project: bassclef-cli
execution_repo: sunj-labs/bassclef-cli
status: proposed
authored: 2026-09-13
authored_by: agent
in_flight_goal: null
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
time_budget: 80-120 turns
time_budget_source: |
  Phase 1 (cli#68 OOAD docs-only) shipped at ~35 turns. Phase 2 adds
  code — prepublish script gains inline build logic (filter manifest +
  emit settings.json + copy 4 templates). Tier 0 tests owed for the new
  logic. Similar-shape sessions ground the range: goal 28d Steps 4-5
  (prepublish script + workflow change) shipped at ~50 turns per whereami
  L59; iteration i (harness + tests) shipped at ~90 turns per L169. This
  goal ships both a workflow change AND new script logic with tests +
  6 doc edits (ADR-001 + ADR-007 D1 amend + goal doc + risk ledger +
  session log + PR).
authoring_luminaries:
  primary: [john-ousterhout, michael-nygard]
  supporting: [michael-feathers, linus-torvalds, alan-cooper, jerome-saltzer-and-michael-schroeder]
lead_lens: john-ousterhout
tickets: [25, 73]
references:
  - {type: parent_bet, id: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md, anchor: parent goal — npm distribution for @thebassclef}
  - {type: ticket, id: 25, anchor: cli-side publish workflow reads dist/lite/ (this Phase 2 closes)}
  - {type: ticket, id: 73, anchor: umbrella plan tying Phases 1-4}
  - {type: adr, id: ADR-055, anchor: bassclef-upstream — reader-side contract D1 pins dist/<tier>/ path}
  - {type: adr, id: ADR-009, anchor: cli-side — manifest as init contract source (shipped Phase 1)}
  - {type: adr, id: ADR-001, anchor: cli-side — build toolchain + files whitelist (amended in Step 4)}
  - {type: adr, id: ADR-007, anchor: cli-side — bundling contract D1 (amended in Step 5)}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.md, anchor: pre-mortem light — 3 lenses × 3 risks}
adr_references:
  - ADR-001 — amended in Step 4 (files whitelist extends to dist/lite/)
  - ADR-007 D1 — amended in Step 5 (bundle path lock adds dist/<tier>/ path)
  - ADR-009 — read-only reference (shipped Phase 1)
---

# cli#25 Phase 2 — publish workflow ships dist/lite/ alongside substrate/

## Problem

Phase 1 (shipped as PR #74 on 2026-09-13) landed the OOAD contract. Cli publish workflow at `.github/workflows/publish.yml` reads sibling `sunj-labs/bassclef` public downstream at HEAD (not pinned) and writes to `substrate/` per ADR-007 D1. Phase 3 (init walker code) cannot ship until the tarball carries `dist/lite/` at the shape upstream ADR-055 D1 pins. `@thebassclef/lite@0.1.3` currently ships `substrate/` only; adopters running `bassclef init` write empty settings.json — the cold-adopter empty-hooks class since 0.1.0 that cli#68 was authored to close.

## Value

Ship the workflow change that puts `dist/lite/` at upstream v0.39.0's shape inside `@thebassclef/lite@0.2.0`. Dual-write approach preserves `substrate/` (backward compat for current cli code) alongside `dist/lite/` (for Phase 3 reader). Unblocks Phase 3.

Per @luminary john-ousterhout — the prepublish script stays a deep module. One entry point; hides the build logic behind a narrow interface. Callers see "populate the tarball" and get both trees.

Per @luminary michael-nygard — fail-fast on each build step. If upstream tag missing OR manifest missing OR templates missing, the script exits nonzero with a specific remediation.

Per @luminary michael-feathers — new tarball assertions land as Tier 0 tests before the code that ships them. Beck RED-first on the new dist/lite/ presence assertions.

Per @luminary linus-torvalds — no adopter breaks. Current 0.1.3 adopters upgrading to 0.2.0 keep the working substrate/ tree (dual-write). Bundle-path rename to dist-only is a Phase 3 concern.

Per @luminary alan-cooper — Sam does not see this change at Phase 2. Sam's init still writes an empty settings.json on 0.2.0. Phase 3 flips the reader; Sam sees the banner at Phase 3 ship.

Per @luminary jerome-saltzer-and-michael-schroeder — complete mediation. Every write through the existing prepublish script's error-check paths; every step fails loud on bad input.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` — parent goal (declared in frontmatter parent_bet); npm distribution parent; walked this session
- `docs/whereami.md` L17-35 — in-flight state; Phase 1 shipped, cli#25 next per next_bet field
- cli#25 body — Phase 2 scope enumeration
- cli#73 body — 4-phase execution plan
- bassclef-upstream ADR-055 (via local file `~/src/sunj-labs/bassclef/architecture/decisions/ADR-055-wiring-manifest-as-init-contract.md`) — D1 dist/<tier>/ path pin
- `docs/adrs/ADR-009-manifest-as-init-contract-source.md` (shipped Phase 1) — cli-side contract binding
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` — current D1 bundle path lock (substrate/); amended Phase 1 with Acceptance delta naming Phase 2 as the D1 amendment vehicle
- `docs/adrs/ADR-001-npm-package-build-toolchain.md` — files whitelist invariant to extend
- `.github/workflows/publish.yml` L97-180 — current workflow shape (clones public bassclef; runs prepublish; asserts substrate/ ≥ 100 files)
- `scripts/prepublish-bundle-substrate.mjs` L1-60 — reads sibling `lite-manifest.json`; writes to substrate/
- `package.json` L31-38 — files array whitelist; version 0.1.3
- `bassclef-upstream/scripts/build-adopter-tree.sh` at v0.39.0 (via `gh api` on bassclef-upstream) — 5-file output shape (`.claude/settings.json` + 4 templates)
- Public bassclef v0.39.0 tag SHA `38f906e9` (via `gh api`) — confirms release mirrored downstream
- Public bassclef `standards/bassclef-wiring-manifest.json` + `presence/dist-templates/` at v0.39.0 (via `gh api`) — confirms source assets present downstream

## What I'm NOT reading (with reason)

- bassclef-upstream v0.39.0 tarball contents beyond build script — cli sources from public bassclef; upstream is R&D-only per workflow L109-114
- Bassclef-upstream release-cascade config (which files ship to public bassclef) — out of scope; cli sources from public downstream regardless

## Steps

| Step | Problem + value | Produces | Consumes (from prior) | How builds on prior | Risk |
|---|---|---|---|---|---|
| **0** housekeeping | Session start; scope confirmed; markers absent | Goal doc + risk ledger + temperance/pre-mortem/luminary/ADR-consult/thread-walk/orientation markers | session-start | baseline | 🟢 |
| **1** amend prepublish script | Script reads `bassclef-wiring-manifest.json` + `presence/dist-templates/`; builds `dist/lite/` inline (filter manifest entries where tier ≤ lite + emit settings.json + copy 4 templates); dual-writes substrate/ (existing) + dist/lite/ (new) | `scripts/prepublish-bundle-substrate.mjs` extended | Step 0 | New logic layered on existing walk; existing substrate/ output preserved | 🟡 |
| **2** amend publish workflow | Workflow pins public bassclef checkout to v0.39.0 tag; existing prepublish step calls the extended script; new post-prepublish assertion checks dist/lite/ present | `.github/workflows/publish.yml` amended | Step 1 script contract | Tag-pin + assertion added to existing checkout step | 🟡 |
| **3** update package.json | `files` array adds `dist/lite/**`; new `bassclef` field records pinned upstream tag; version bump 0.1.3 → 0.2.0 MINOR per additive changes | `package.json` amended | Step 2 workflow output shape | Files whitelist + version bump | 🟢 |
| **4** amend ADR-001 | §Invariants "no source shipped" flips to "no source shipped except bassclef-upstream dist/<tier>/ per ADR-055 D1"; files whitelist extends | ADR-001 amended | Step 3 files shape | Invariant amendment names the source | 🟢 |
| **5** amend ADR-007 D1 | D1 bundle path lock adds `dist/<tier>/` as second accepted path alongside `substrate/`; Phase 3 will drop substrate/ | ADR-007 D1 amended | Step 4 ADR-001 alignment | Bundle path lock respects the semver contract | 🟢 |
| **6** Tier 0 tests | New Tier 0 test asserts tarball contains `dist/lite/.claude/settings.json` + `dist/lite/CLAUDE.md` + `dist/lite/whereami.md` + `dist/lite/.bassclef-source.json` + `dist/lite/.gitignore`; new prepublish tests characterize the inline build logic (manifest filter + template copy) | `tests/harness/prepublish-bundle.test.ts` extended + new dist/lite/ assertions | Step 5 ADR contract | Feathers characterization + Beck RED before source | 🟡 |
| **7** verify + PR + auto-merge | Full suite GREEN (232 + N new); PR opened; auto-merged within scope; session log; whereami flip | Suite GREEN; PR opened + merged; whereami updated | Union of Steps 0-6 | Ships Phase 2; unblocks Phase 3 | 🟢 |

## Compounding value per step

- **Step 1 prepublish** — payoff per-release; needs public bassclef v0.39.0 assets; teaches Ousterhout inline build logic; medium risk (build correctness gated by tests in Step 6)
- **Step 2 workflow** — payoff per-release; needs Step 1 script contract; teaches Nygard fail-fast at tag pin; medium risk (workflow yaml drift class)
- **Step 3 package.json** — payoff per-adopter; needs Step 2 output shape; teaches ADR-001 files whitelist discipline; low risk
- **Step 4 ADR-001** — payoff per-reviewer; needs Step 3 files array shape; teaches Nygard invariant amendment; low risk
- **Step 5 ADR-007 D1** — payoff per-reviewer; needs Step 4 shape alignment; teaches Nygard supersedes chain discipline; low risk
- **Step 6 tests** — payoff per-PR; needs Step 5 contract; teaches Feathers characterization; medium risk (new tarball assertions may surface build-time drift)
- **Step 7 verify + close** — payoff per-session; needs Steps 1-6; teaches auto-merge-within-scope; low risk

## Acceptance

- [ ] Step 1 — prepublish script builds dist/lite/ from public bassclef v0.39.0 assets (manifest + templates); dual-writes substrate/ + dist/lite/
- [ ] Step 2 — publish workflow pins public bassclef checkout to v0.39.0 tag; assertion checks dist/lite/ present after prepublish
- [ ] Step 3 — package.json files array adds dist/lite/**; version 0.2.0; bassclef.upstream_tag field records v0.39.0
- [ ] Step 4 — ADR-001 §Invariants amended to name dist/<tier>/ as allowed source
- [ ] Step 5 — ADR-007 D1 amended to add dist/<tier>/ as second accepted bundle path
- [ ] Step 6 — Tier 0 tests assert dist/lite/ 5-file tree present in tarball; new prepublish tests characterize inline build logic
- [ ] Step 7 — PR opened; full suite GREEN; auto-merged; whereami reflects Phase 2 shipped; ticket #25 closed by `Closes` keyword

## Out of scope

- Phase 3 (init walker code + fail-loud + hook-count banner) — separate /longrun; needs /pre-mortem light before code
- Phase 4 (cold-adopter smoke) — runs after Phase 3 ships live version
- Removing `substrate/` bundle path — Phase 3 drops it under ADR-007 D1 semver-lock (MAJOR bump)
- Sourcing from bassclef-upstream directly — cli keeps sourcing from public bassclef per workflow L109-114 design intent
- Retiring `lite-manifest.json` at public bassclef — existing script still reads it for substrate/ path; new dist/lite/ logic reads `bassclef-wiring-manifest.json`

## Refs

- Closes bassclef-cli#25 (Phase 2 scope closes here)
- Refs bassclef-cli#73 (parent execution plan; Phase 3 + 4 remain open)
- Refs bassclef-upstream ADR-055 D1 (reader-side contract; accepted 2026-09-13 at v0.39.0)
- Refs bassclef-cli ADR-009 (shipped Phase 1 PR #74)
- Refs bassclef-cli#68 (Phase 1 closed as of 2026-09-13T00:39:53Z)
- @luminary john-ousterhout — deep modules (lead)
- @luminary michael-nygard — fail-fast at each build step
- @luminary michael-feathers — characterization tests pin the new tarball shape
- @luminary linus-torvalds — adopter invariant preservation (dual-write)
- @luminary alan-cooper — Sam persona (banner ships at Phase 3 not Phase 2)
- @luminary jerome-saltzer-and-michael-schroeder — complete mediation across build steps
