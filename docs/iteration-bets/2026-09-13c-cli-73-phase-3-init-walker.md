---
tier: standard
title: cli#73 Phase 3 + Phase 4 — init walker reads dist/lite/, drops substrate/, MAJOR 1.0.0
date: 2026-09-13
authored: 2026-09-13
authored_by: agent
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
parent_drivers:
  - cli#73 (umbrella execution plan; Phases 3 + 4 remaining)
  - bassclef-upstream ADR-055 D1 + D4 + D5 (reader contract; verbatim copy, fail-loud, hook-count banner)
  - bassclef-upstream v0.39.0 wiring manifest (tagged 2026-09-13, schema v2.0.0)
authoring_luminaries:
  primary: michael-nygard
  supporting:
    - michael-feathers
    - linus-torvalds
    - alan-cooper
appetite: 90-160 turns
scope: cli init walks dist/lite/ tree, copies verbatim, fails loudly on manifest gap or schema mismatch, prints hook-count banner, substitutes placeholders. Drops substrate/ from tarball under MAJOR 1.0.0 bump. Includes Phase 4-agent tarball smoke on cold-adopter-1 profile dir.
out_of_scope:
  - Actually publishing 1.0.0 to npm (operator dispatches morning after Phase 4 smoke greenlit)
  - Cold-adopter Claude Code sandbox open + hooks fire verification (operator smoke in morning)
  - Standard-tier and ultra-tier packages (@thebassclef/standard, @thebassclef/ultra) — separate scope
  - Runtime hook resolution beyond what dist/lite/ ships (whether user-scope hooks fire correctly is Phase 4 smoke finding)
references:
  - docs/adrs/ADR-002-bassclef-init-safety-contract.md (safety contract; amend with exit codes 4+5)
  - docs/adrs/ADR-005-npm-distribution-architecture.md (Sam demo acceptance; matches after Phase 3)
  - docs/adrs/ADR-007-npm-lite-substrate-bundling.md (bundle path lock D1; Phase 3 MAJOR drops substrate/)
  - docs/adrs/ADR-009-manifest-as-init-contract-source.md (cli-side pointer to ADR-055)
  - docs/use-cases/UC-init.md (Phase 1 rewrite; postconditions verbatim from coord doc)
  - docs/decompositions/npm-install-harness-domain.md (harness domain; adopter-session simulator)
  - bassclef-upstream architecture/decisions/ADR-055-wiring-manifest-as-init-contract.md D1-D7
  - bassclef-upstream scripts/build-adopter-tree.sh (schema-check pattern + tier hierarchy)
  - bassclef-upstream .claude/hooks/tests/init-output-parity.test.sh (Feathers parity test shape)
  - bassclef-upstream docs/coordination/2026-09-12e-cli-boundary.md (Cockburn UC-init verbatim)
---

# cli#73 Phase 3 + Phase 4 — init walker + substrate/ drop + tarball smoke

## Problem (≤500 chars)

Adopters running `npx bassclef init` today read the substrate from `substrate/` — the legacy bundle path. Per bassclef-upstream ADR-055 D1+D4+D5 (v0.39.0), the reader contract requires walking `dist/lite/` from the bundled `@thebassclef/lite` package, failing loud on missing manifest or schema mismatch, and printing an `N hooks armed (<tier> tier)` banner. Phase 2 (PR #75) shipped `dist/lite/` alongside `substrate/`. Phase 3 flips the reader and drops the legacy path under MAJOR 1.0.0.

---

## Goal

Land the init walker code that consumes bassclef-upstream v0.39.0's wiring manifest per ADR-055 D1-D7. Drop `substrate/` from the tarball under a MAJOR 1.0.0 bump — no npm adopters exist today (operator confirmed 2026-09-13), so compat-shim discipline is null. Bundle Phase 4-agent tarball smoke on the cold-adopter-1 profile dir into the same session; publish workflow dispatch waits on operator morning confirmation.

## Evidence

- **Source:** `docs/next-session-plan-2026-09-13-phase-3-init-walker.md` (commit `e7d614d`) L36-45 names the 7-step Cockburn sequence and L88-93 names the two open decisions the operator resolved this session.
- **Warrant:** The plan doc was authored at end-of-session 2026-09-13b as the pickup handoff. It cites ADR-055 D1-D7 (upstream, tagged v0.39.0) as the contract. Operator confirmed MAJOR 1.0.0 + Phase 3+4 bundle + orchestrator-gated at prep. Time budget grounded on Phase 1 (~35t docs-only) + Phase 2 (~55t code+docs+tests); Phase 3 adds more code surface (walker + fail-loud + banner + placeholders + substrate/ drop + parity test) so 70-120t + Phase 4 smoke ~20-40t = 90-160t range.

## Approach

MECE (each step covers a different scope). Beck TDD — RED parity test before walker source.

### Steps

| Step | Produces | Consumes | Risk |
|---|---|---|---|
| **0** prep | This goal doc + risk ledger + 7 markers; /pre-mortem light REQUIRED per loop-discipline Step 0.5 | session-start | 🟢 |
| **1** RED Feathers parity test | `tests/init-output-parity.test.ts` port of bassclef-upstream shape; asserts adopter tree mirrors dist/lite/; FAILS RED before Step 2 lands | Step 0 markers | 🟢 |
| **2** walker in `src/lib/copy-substrate.ts` | Reads `dist/lite/` tree via bundle root resolution; walks recursively; delegates to writeSafely per file | Step 1 RED test | 🟡 |
| **3** verbatim `.claude/settings.json` copy | Byte-for-byte from `dist/lite/.claude/settings.json` (no cli composition per ADR-055 D1); replaces the current `init-templates/settings-json.ts` composition path | Step 2 walker | 🟡 |
| **4** fail-loud exit codes | Exit 4 (manifest missing) + exit 5 (schema major mismatch); structured error per ADR-055 D4 + UC-init Extensions 4a; wiring manifest lands at `dist/lite/standards/bassclef-wiring-manifest.json` via prepublish tweak; amend ADR-002 with new exit codes | Step 3 shape | 🟡 |
| **5** hook-count banner | Prints `N hooks armed (<tier> tier)` after settings.json write; counts hooks across all events in copied settings.json per ADR-055 D5; grade-8 message per Cooper | Step 4 fail-loud | 🟡 |
| **6** placeholder substitution | Substitutes `[REPO_NAME]` + `[ISO_TIMESTAMP]` + `[TIER]` in CLAUDE.md + whereami.md + .bassclef-source.json per UC-init Main step 5; skips settings.json (verbatim per D1) | Step 5 banner | 🟢 |
| **6.5** drop substrate/ MAJOR | Removes `substrate/**` from package.json files array; removes substrate/ build from prepublish script (only dist/lite/ ships); amends ADR-001 §Invariants ("no source shipped" allows dist/lite/** only); bumps 0.2.0 → 1.0.0; syncs src/index.ts version; deletes tests that assert substrate/ shape | Step 6 subst | 🟡 |
| **7** verify + PR + auto-merge | Full suite GREEN; session log; whereami flip; PR opened with pr-body-shape opener; /loop on CI until green | Steps 0-6.5 | 🟢 |
| **P4** tarball smoke | `npm pack` → fresh dir → `npm install ./tarball.tgz` → `npx bassclef init` → assert exit 0, banner text, settings.json byte-identical, hook count, placeholders substituted; test fail-loud paths (corrupt manifest → exit 4 or 5) | Step 7 merge | 🟡 |

### Per-step compounding

- **Where the payoff shows up:** every `npx bassclef init` after `1.0.0` publishes + every future manifest schema evolution + every fresh cold adopter
- **How often it fires:** per-adopter at first install; per-session at re-init; per-release at prepublish assertion
- **What must be true first:** Phase 2 tarball has `dist/lite/` populated (shipped PR #75); operator confirmation of zero npm adopters (given at prep)
- **Does this teach a shape later work reuses:** yes — the walker code is the template for `@thebassclef/standard` + `@thebassclef/ultra` when those packages ship; single-bundle-path shape carries forward
- **What breaks if we ship this half-done:** cold adopters at `1.0.0` hit a tarball with no `substrate/` + a cli that reads it (walker never wired) — install crashes with ENOENT on first init; Phase 4 smoke catches this before publish dispatch

## Acceptance

1. `bassclef init` in a fresh dir with `@thebassclef/lite@1.0.0` installed produces adopter repo tree matching `dist/lite/` verbatim per Feathers parity test
2. `bassclef init --dry-run` prints matching file list + count
3. Missing wiring manifest → exit 4 with structured error naming path + cure
4. Schema major mismatch → exit 5 with structured error naming expected + actual version
5. Successful init prints `N hooks armed (lite tier)` banner where N matches hook count in settings.json
6. Placeholders substituted in CLAUDE.md + whereami.md + .bassclef-source.json
7. Tarball contains `dist/lite/**` — `substrate/**` absent
8. Package.json version 1.0.0; src/index.ts version constant synced
9. Full test suite GREEN (baseline minus deleted substrate/ tests + new Phase 3 tests)
10. Phase 4-agent smoke passes on cold-adopter-1 profile dir; morning operator smoke pending

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` L1-30 — parent goal declaring npm distribution launch (parent_bet in this frontmatter); appetite range calibration derives from parent luminary triad's actuals
- `docs/next-session-plan-2026-09-13-phase-3-init-walker.md` (commit `e7d614d`) — plan doc pickup
- `docs/use-cases/UC-init.md` L1-207 (Phase 1 rewrite; postconditions verbatim from coord doc)
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` L1-345 (safety contract + 2026-09-13 amendment)
- `src/commands/init.ts` L1-432 (current init dispatcher)
- `src/lib/copy-substrate.ts` L1-240 (current walker; reads substrate/.bassclef/lite-manifest.json)
- `scripts/prepublish-bundle-substrate.mjs` L1-419 (current prepublish; builds both substrate/ + dist/lite/)
- bassclef-upstream `architecture/decisions/ADR-055-wiring-manifest-as-init-contract.md` D1-D7 via gh api
- bassclef-upstream `scripts/build-adopter-tree.sh` L1-150 via gh api (tier hierarchy + schema check pattern)
- `dist/lite/` current shape via local prepublish run — 5 files (settings.json + 4 templates)
- `dist/lite/.claude/settings.json` sample — 24 hook entries, hooks use `$HOME/.claude/hooks/*` + `$CLAUDE_PROJECT_DIR/.claude/hooks/*`

## Refs

- Closes bassclef-cli#73 (Phase 3 + Phase 4)
- Refs bassclef-upstream ADR-055 D1-D7 (reader contract)
- Refs bassclef-cli ADR-009 (cli-side pointer)
- Refs bassclef-cli ADR-002 (amended with exit codes 4+5 in this goal)
- Refs bassclef-cli ADR-007 D1 (MAJOR bump per semver-lock)
- Parent plan: `docs/next-session-plan-2026-09-13-phase-3-init-walker.md`
