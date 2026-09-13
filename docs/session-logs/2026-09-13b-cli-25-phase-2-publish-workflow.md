---
tier: lite
title: cli#25 Phase 2 — publish workflow ships dist/lite/ alongside substrate/
date: 2026-09-13
authored_by: agent
goal: 2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite
session_started: 2026-09-13T00:45:00Z
session_ended: 2026-09-13T01:10:00Z
duration_hours: ~0.5
turn_count: ~55
outcome: shipped
pr: 75
merge_commit: 0212a152711d0568f99d2371132b3f3799caba9f
version: 0.2.0
---

# Session log — cli#25 Phase 2 publish workflow

## What shipped

PR #75 merged to main at 2026-09-13T01:06:23Z (squash commit `0212a152`). Ticket #25 closed with a summary comment. `@thebassclef/lite` version bumped 0.1.3 → 0.2.0 MINOR.

Seven commits on `feat/cli-25-phase-2-publish-workflow-dist-lite`:

- **Step 0** — goal doc + risk ledger (Nygard + Feathers + Torvalds; 3 lenses × 3 risks) + 7 gate markers
- **Step 1** — `scripts/prepublish-bundle-substrate.mjs` gains inline dist/lite/ build path. Reads `standards/bassclef-wiring-manifest.json` + `presence/dist-templates/` from sibling clone. Filters manifest entries by tier ≤ lite, emits settings.json, copies 4 templates. Dual-writes substrate/ (existing) + dist/lite/ (new). Env-gated with `BASSCLEF_BUILD_DIST_LITE`; default on.
- **Step 2** — `.github/workflows/publish.yml` pins both checkout-bassclef steps to `ref: v0.39.0`. New tag-existence assertion + new dist/lite/ 5-file floor assertion.
- **Step 3** — `package.json` bumps 0.2.0 MINOR + files array adds `dist/lite/**` + new `bassclef.*` field records `upstream_tag`, `wiring_manifest_schema_major`, `bundle_paths`, `phase_note`. `src/index.ts` version constant synced.
- **Step 4** — ADR-001 §Invariants amended. "No source shipped" extends to allow `dist/<tier>/**` + `substrate/**` (cli source under `src/` still never ships).
- **Step 5** — ADR-007 D1 bundle path lock amended. `dist/<tier>/` added as second accepted path. Phase 3 drops substrate/ under MAJOR bump per semver-lock.
- **Step 6** — 6 new Tier 0 tests: 2 happy path (dist/lite/ has 5 files; settings.json filters correctly) + 4 fail-fast (missing manifest, schema mismatch, missing templates, empty hooks).

## Sources read

- cli#25 body (Phase 2 scope; via `gh issue view 25`)
- cli#73 body (parent execution plan; from Phase 1 session)
- bassclef-upstream ADR-055 (local file; from Phase 1)
- Public bassclef v0.39.0 tag SHA `38f906e9` (via `gh api`)
- Public bassclef `standards/bassclef-wiring-manifest.json` at v0.39.0 (via `gh api`) — shape informs Node port of jq filter
- Public bassclef `presence/dist-templates/` at v0.39.0 (via `gh api`) — 4-template contract
- Public bassclef `scripts/build-adopter-tree.sh` at v0.39.0 (via `gh api` on bassclef-upstream) — jq filter logic ported to Node
- `.github/workflows/publish.yml` L97-180 (current workflow shape)
- `scripts/prepublish-bundle-substrate.mjs` L1-200 (current script; extended)
- `tests/harness/prepublish-bundle.test.ts` L1-278 (existing test shape; extended)
- `package.json` (current shape)
- ADR-001, ADR-005, ADR-007 (amended in Phase 1; further amended in Phase 2)

## Gate evidence

| Gate | Status | Evidence |
|---|---|---|
| Temperance | Fired at Step 0 prep | `state/markers/temperance/feat-cli-25-phase-2-publish-workflow-dist-lite.marker` — scope: Phase 2 dual-write only; drift trigger names Phase 3 boundary |
| Pre-mortem light | Fired at Step 0 prep | `docs/risk-ledgers/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.md` — 3 lenses × 3 risks; N1 + N2 + F1 + L1 folded verbatim into Steps 1 + 2 + 3 + 5 |
| Luminary | Fired at Step 0 prep | `state/markers/luminary/feat-cli-25-phase-2-publish-workflow-dist-lite.marker` — lead ousterhout; supporting nygard + feathers + torvalds + cooper + saltzer-schroeder |
| ADR-consult | Fired at Step 0 prep | `state/markers/adr-deviation/feat-cli-25-phase-2-publish-workflow-dist-lite.marker` — outcome ADR-honored; Phase 2 IS the ADR-001 + ADR-007 D1 amendment |
| Thread walk | Fired at Step 0 prep | `state/markers/arc-walk/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.marker` — walked cli#25 → cli#73 → parent goal 2026-08-06b → root |
| Orientation gate | Fired at Step 0 prep | whereami read from Phase 1 closeout |
| Tier 0 tests | GREEN 238/238 | 232 baseline + 6 new; vitest 3.38s duration |
| Reviewer | Self-review + verbatim quote discipline | V3 pre-mortem catch preserved (jq filter ported verbatim from bassclef-upstream v0.39.0) |
| Verify | Full suite GREEN | Confirmed at Step 6 close before Step 7 push |
| /architect-review auto | Skipped (small code scope) | Per skill Step 7.5 skip criteria — single logical concern (workflow + prepublish extension); no session-wide architecture shift |

## What worked

**Env-gate opt-out preserved existing tests.** `BASSCLEF_BUILD_DIST_LITE=0` in the `runScript` helper meant every existing test kept its shape without change. F1 pre-mortem catch predicted this exact class; the cure shipped inline at Step 1 write.

**Verbatim port of the jq filter from bassclef-upstream v0.39.0.** Fetched the build script via `gh api`, read the jq logic, ported to Node with identical semantics (tier field strip, empty-matcher-block pruning, empty-event pruning). Filter output shape matches upstream's build output at 24 lite entries for the local checkout smoke test.

**Fail-fast on every subcheck.** Nygard's discipline paid off at Step 6 — every fail-fast test PASSED first shot because the script's subcheck layout matched the pre-mortem folds one-to-one.

**Dual-write bought clean Phase 3 boundary.** Adopters at 0.1.3 upgrading to 0.2.0 see no runtime change (substrate/ still present + populated). Phase 3 flips the reader + drops substrate/ under a MAJOR bump; the boundary is clean.

## What did not work

**Rebuild required after version bump.** Step 3's version constant sync broke `tests/cli.test.ts` because `dist/cli.js` still carried the old 0.1.3 build output. Ran `npm run build` to refresh; suite returned GREEN. Follow-on candidate — consider auto-rebuild before vitest OR gate vitest on a build-check step. Not blocking for Phase 2.

**Substrate/ repopulation required after clean.** Cleaning `substrate/` + `dist/lite/` broke `init.test.ts` because those tests spawn `bassclef init` which reads bundled substrate at runtime. Ran prepublish script (BASSCLEF_BUILD_DIST_LITE=0 for baseline) to repopulate. Not a discipline miss — the tests correctly depend on prepublish output. Follow-on candidate — document the pre-test setup step in tests README.

## Session insights

**OOAD-first discipline paid off again.** Phase 1's ADR-007 `## Acceptance delta` section named "What Phase 2 (cli#25) will change" verbatim. Phase 2 read that section as a spec; the six ADR/workflow changes lined up 1:1 with the acceptance delta. No re-derivation.

**Pre-mortem catches predicted every test failure.** F1 (existing tests reference substrate/), F3 (tarball assertion extends), N2 (silent-empty guard), N3 (templates missing) — all four appeared in the actual work exactly as predicted. Klein workshop shape is calibrated well for docs+code sessions.

**MINOR bump discipline held.** L1 pre-mortem catch drove the 0.1.3 → 0.2.0 shape (not 0.1.4 patch, not 1.0.0 MAJOR). Additive changes fit MINOR; substrate/ preservation preserved every adopter invariant. Phase 3 will bump MAJOR when substrate/ drops.

## Next work

Phase 3 (init walker code) — separate /longrun. Scope: cli init reads `dist/lite/` from bundled substrate; writes to adopter repo; fails loudly on missing manifest OR schema mismatch (ADR-055 D4); prints `N hooks armed (<tier> tier)` banner (ADR-055 D5); substitutes placeholders in CLAUDE.md + whereami.md + `.bassclef-source.json`. Needs `/pre-mortem light` before code per loop discipline. Estimated 60-100 turns.

Phase 4 (cold-adopter smoke) — runs after Phase 3 ships live version. Estimated 20-40 turns.

## Refs

- Closes bassclef-cli#25
- Refs bassclef-cli#73 (parent execution plan; Phases 3 + 4 open)
- Refs bassclef-upstream ADR-055 D1 (v0.39.0 contract)
- Refs bassclef-cli ADR-009 (Phase 1 shipped)
- Refs `docs/iteration-bets/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.md`
- Refs `docs/risk-ledgers/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.md`
- PR #75 (merge commit `0212a152`)
