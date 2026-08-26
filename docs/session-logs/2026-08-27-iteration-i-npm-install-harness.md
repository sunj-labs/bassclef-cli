---
date: 2026-08-27
session_id: 2026-08-27-iteration-i-npm-install-harness
duration_hours: ~3
mode: orchestrator-gated + agent-merges-within-scope
outcome: green
tier: standard
in_flight_goal: docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md
---

# Session log — Iteration i (install harness for @thebassclef/core)

## Operator recap

Iteration i shipped. The install harness lives at `harness/` in the cli repo. It packs the tarball, installs it into a fresh temp dir, runs three verbs (`--version`, `init`, `sync --dry-run`), and reports pass or fail. Two scenarios per ADR-006 — local pack from the working copy plus published fetch from the live npm registry (env-gated).

11 tests pass in 735ms locally. 1 test skipped by design (the published-fetch scenario runs only when `HARNESS_INCLUDE_PUBLISHED=1` is set — the CI workflow sets it on release-triggered runs; local dev defaults off to avoid network flake).

Full OOAD chain ran per operator direction — `/objectory-decompose` for the domain, `/use-case` for the Cockburn fully-dressed spec, `/decompose` for GRASP responsibility assignment, ADR-006 for the harness contract, R-NPM-014 for the requirement registry row, then the code + workflow. Every step had a pre-mortem light with 3 lenses × 3 risks; strongest concerns folded into scope.

## What shipped (7 commits on `feat/iteration-i-npm-install-harness`)

- **c30b2e7** — Steps 0-1: goal doc + Jacobson decomposition (6 entities + BCE)
- **6e27000** — Steps 2-3: fully-dressed UC + GRASP responsibility matrix
- **4efefc4** — Steps 4-5: ADR-006 harness contract + R-NPM-014 registry row
- **0757c24** — Step 6a: walking skeleton (test file + config + package.json script)
- **e0cc5c5** — Step 6a fixup: un-ignore harness/ tree; add 6 library files
- **19ec65d** — Step 6b: full 3-verb coverage + extension unit tests
- **31f17ad** — Steps 7-8: CI workflow + pattern annotation pass

## /loop iterations landed GREEN

Two code-shipping /loop iterations, both RED → GREEN in one cycle each.

**Iteration 1 (Step 6a walking skeleton).** RED — `npm install --prefix` without `-g` used local install layout; binary landed at `<prefix>/node_modules/.bin` not `<prefix>/bin`. Fix — add `-g` flag to InstallScope's npm invocation. GREEN in one cycle.

**Iteration 2 (Step 6b full coverage).** RED — old walking-skeleton test asserted `verbs.toHaveLength(1)` which broke once HarnessRun ran all 3 verbs on success. Fix — removed the redundant test since full-coverage test supersedes it. GREEN in one cycle.

Both iterations are exactly what Feathers characterization tests exist for — pin actual behavior at the adopter boundary, catch drift before the adopter does.

## /luminary shepherding

Primary lead — **Michael Feathers** (characterization tests as adopter contract). Sign-off marker at `bassclef-upstream/state/markers/lead-lens-signoff/feat-iteration-i-npm-install-harness.marker` cites specific finding IDs cleared; no rubber-stamp.

Primary co — **Alistair Cockburn** (walking skeleton first; fully-dressed use case drives design).

Supporting — Alan Cooper (Sam persona at adopter boundary), Michael Nygard (fail-safe cleanup + retry pattern for transient flakes), Sophia Prater (OOUX — object model before actions in Step 1), John Ousterhout (deep modules — every harness library file wraps rich internal logic behind a thin interface).

## /temperance re-anchors

- Session start — scope anchor at `bassclef-upstream/state/markers/temperance/feat-iteration-i-npm-install-harness.marker`
- Phase boundary after Step 3 — re-verified scope holds (design chain complete; build chain next)
- Phase boundary after Step 6 — re-verified scope holds (walking skeleton green; full coverage next)
- No drift trigger fired

## /pre-mortem light runs

Three pre-mortem light runs this session, all with 3 lenses × 3 risks:

- **Step 0** (session start) — 9 risks; strongest folded into goal doc Step 6-9 sequencing
- **Step 6b** (before extending) — 9 risks; strongest folded into HarnessRun and test-file scope (marker at `bassclef-upstream/state/markers/pre-mortem/*step-6b.marker`)
- **Step 7** (before workflow) — 9 risks; strongest folded into workflow file (marker at `bassclef-upstream/state/markers/pre-mortem/*step-7.marker`)

## Substrate defects surfaced (candidates for /promote)

**bassclef-upstream catalog gap — 3 patterns missing.** Step 8 annotation pass verified 4 declared `@pattern` paths against bassclef-upstream/patterns/. 1 exists (strategy.md), 3 missing:

- `patterns/code/fowler/test-fixture.md` (Meszaros / Fowler Test Fixture)
- `patterns/code/gof/command.md` (GoF Command)
- `patterns/code/gof/template-method.md` (GoF Template Method)

Follow-on candidate — dispatch `/agent-research-spawn` in bassclef-upstream to fill each entry per `.claude/rules/pattern-annotation.md` L46-49. Then re-add `@pattern` annotations to fixture.ts + cli-invocation.ts + harness-run.ts here.

**cli repo .gitignore rule ordering trap.** Bare `lib` pattern in bassclef-sync managed block at .gitignore L211 shadowed `harness/lib/` un-ignore above it. Root cause — git rule ordering means later patterns win. Fix — append `!harness` + `!harness/**` AFTER the managed block (commit e0cc5c5).

Follow-on candidate — file bassclef-upstream ticket noting the `lib` shadow risk in the sync-managed .gitignore pattern; adopters with `src/lib` today have `!src/lib` un-ignore that works only because the managed block's `lib` came later. If the managed block moves earlier in a future sync template revision, both `src/lib` AND `harness/lib` would re-break.

## What deferred to post-merge or follow-on

- **Runtime workflow verify** — cannot fire from a feature branch. Operator merges PR, then dispatches via `gh workflow run harness --ref main -f tag=v0.0.2`. Verify marker at `bassclef-upstream/state/markers/verify/*.marker` documents.
- **First real release-triggered run** — fires automatically on next `bassclef bump` + release publish.
- **UC extensions 4a, 2a, 8a, 9a** — routed to Step 9 workflow verify OR follow-on iteration. Test-list `[~]` rows in `harness/npm-install.test.ts` name each with rationale.
- **Pattern catalog fill** — 3 bassclef-upstream entries needed (named above).

## Cross-repo tickets

None filed this session. All follow-on candidates named above stay as notes here until operator triages.

## What's next

Per parent bet L124-129 acceptance list, remaining after iteration i:

- **WU-6 upstream cold-adopter harness check class** — bassclef-upstream side; separate goal
- **WU-7 Adam Sharpe security PRs** — deferred per parent bet L128; must land before 0.1.0 or 0.0.3
- **WU-8 Sam demo** — needs live 0.0.2 (live) + iteration i harness (this ship) + operator time
- **WU-9 first tagged 0.1.0 release** — after WU-6 + WU-7 + WU-8 land
- **/architect-review at bet close** — after WU-9

## Refs

- Goal doc — `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md`
- Prep doc — `docs/next-longrun-prep-2026-08-13-npm-install-harness.md`
- ADR-006 — `docs/adrs/ADR-006-install-harness.md`
- Domain decomposition — `docs/decompositions/npm-install-harness-domain.md`
- GRASP decomposition — `docs/decompositions/npm-install-harness.md`
- Fully-dressed UC — `docs/use-cases/UC-npm-install-harness.md`
- Requirement registry — `docs/requirements/2026-08-11-npm-distribution.md` (R-NPM-014 added)
- Feathers, *Working Effectively with Legacy Code* (Prentice Hall, 2004)
- Cockburn, *Writing Effective Use Cases* (Addison-Wesley, 2001)
- Jacobson, *Object-Oriented Software Engineering* (Addison-Wesley, 1992)
- Larman, *Applying UML and Patterns* (Prentice Hall, 3rd ed. 2004) ch 17
