---
tier: lite
title: Next-session plan — Phase 3 init walker code + Phase 4 cold-adopter smoke
authored: 2026-09-13
authored_by: agent
authored_at: 2026-09-13T02:15:00Z
scope: overnight /longrun; runs after this session compacts
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
umbrella_ticket: 73
depends_on:
  - PR #74 (Phase 1 OOAD) — MERGED 2026-09-13T00:39:53Z as commit 46eb4ec
  - PR #75 (Phase 2 publish workflow) — MERGED 2026-09-13T01:06:23Z as commit 0212a152
  - bassclef-upstream v0.39.0 (tag 6cdff4a4) — STABLE
---

# Next-session plan — Phase 3 init walker + Phase 4 smoke

## State at compact

- Phase 1 SHIPPED — PR #74 (46eb4ec) — 6 doc edits landed (ADR-009 + ADR-002/005/007 amends + UC-init rewrite + decomposition amend)
- Phase 2 SHIPPED — PR #75 (0212a152) — prepublish gains inline dist/lite/ build + workflow pins v0.39.0 + package.json 0.2.0 + ADR-001/007 D1 amends + 6 new tests
- Suite: 238/238 GREEN on main
- Ticket #68 CLOSED. Ticket #25 CLOSED. Ticket #73 OPEN (umbrella; Phases 3+4 remain).
- Version: 0.2.0 on main; not yet published to npm (Phase 2 workflow ready to publish; adopter migration path stays clean on dispatch).

## Recommended session sequence

**Recommend:** Phase 3 (init walker code) as the sole scope for the next overnight /longrun. Phase 4 (smoke) waits on Phase 3 shipping + a live publish. Do NOT bundle Phase 4 into the same session — smoke runs against a live npm registry version.

**Scope:** Phase 3 only · 60-100 turns · risk 🟡 medium (code that adopters read at init time)

**Time budget grounding:** cli#68 Phase 1 (docs-only) shipped ~35t; cli#25 Phase 2 (code + docs + tests) shipped ~55t. Phase 3 adds more code surface than Phase 2 — new walker + fail-loud paths + banner + placeholder substitution + parity test. Sits at 60-100t between iteration i (~90t) and Phase 2 (~55t).

## Phase 3 step sequence (Cockburn fully-dressed contract per coord doc)

| Step | Produces | Consumes | Risk |
|---|---|---|---|
| **0** prep | goal doc + risk ledger + 7 markers; /pre-mortem light REQUIRED per loop discipline (code ships) | session-start | 🟢 |
| **1** RED Feathers parity | Copy bassclef-upstream `.claude/hooks/tests/init-output-parity.test.sh` shape into cli-side Tier 0 test; assert init writes adopter repo matching `dist/lite/` tree; Beck RED first | Step 0 | 🟢 |
| **2** walker in src/lib/copy-substrate.ts | Read `node_modules/@thebassclef/lite/dist/lite/` (bundled substrate) → walk tree → copy each file to adopter repo at matching path | Step 1 RED test | 🟡 |
| **3** verbatim settings.json copy | `dist/lite/.claude/settings.json` copied byte-for-byte (no cli composition; per ADR-055 D1) | Step 2 walker | 🟡 |
| **4** fail-loud on manifest/schema mismatch | New exit codes 4 (manifest missing) + 5 (schema major mismatch); structured error names path + remediation per ADR-055 D4 + UC-init §Extensions 4a | Step 3 shape | 🟡 |
| **5** hook-count banner | Print `N hooks armed (<tier> tier)` after settings.json writes; N counts hooks in the copied settings.json; per ADR-055 D5 + UC-init §Main success scenario step 5 | Step 4 fail-loud | 🟡 |
| **6** placeholder substitution | Substitute `[REPO_NAME]`, `[ISO_TIMESTAMP]`, `[TIER]` in CLAUDE.md + whereami.md + .bassclef-source.json per coord doc §UC-init step 5 | Step 5 banner | 🟢 |
| **7** verify + PR + auto-merge | Full suite GREEN (238 baseline + N new Phase 3 tests); PR opened; auto-merged within scope; session log; whereami flip; version bump 0.2.0 → 0.3.0 MINOR (new user-visible feature: banner + fail-loud) OR 1.0.0 MAJOR if substrate/ drops in same PR | Steps 0-6 | 🟢 |

## Sources to read at Step 0

- `docs/iteration-bets/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md` (Phase 1 goal doc)
- `docs/iteration-bets/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.md` (Phase 2 goal doc — this session's parent)
- `docs/adrs/ADR-009-manifest-as-init-contract-source.md` (Phase 1 D1-D7 cli-side pointer)
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` + `## Amendment 2026-09-13` section (file-list contract)
- `docs/use-cases/UC-init.md` (Phase 1 rewrite; postconditions match coord doc verbatim)
- `docs/decompositions/npm-install-harness-domain.md` (Phase 1 amendment adds `AdopterSessionSimulator` object)
- bassclef-upstream ADR-055 D1-D7 (via `~/src/sunj-labs/bassclef/architecture/decisions/ADR-055-wiring-manifest-as-init-contract.md`)
- bassclef-upstream coord doc (via `gh api` on bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md`)
- bassclef-upstream `.claude/hooks/tests/init-output-parity.test.sh` (via `gh api`; parity test shape to port)
- Current cli `src/commands/init.ts` + `src/lib/copy-substrate.ts` (existing init logic that Phase 3 extends)
- Current cli `tests/init.test.ts` (existing test coverage baseline)

## Pre-mortem light — 3 lens candidates for Step 0

Draft fresh at prep time; these are candidates to seed the analysis:

- **@luminary michael-nygard** — fail-loud discipline; what breaks if the manifest is missing, malformed, or schema-incompatible at runtime; existing bare-catch class from #45/#60 must not reproduce
- **@luminary michael-feathers** — characterization tests; parity test port from bassclef-upstream must characterize current init behavior before the walker code lands
- **@luminary linus-torvalds** — adopter invariants; refuse-overwrite, root refusal, symlink refusal, path scoping, atomic writes ALL preserve per ADR-002 §Invariants; the walker cannot weaken any of them
- **@luminary alan-cooper** — Sam persona; banner text at grade 8 reading level; error messages name the remediation not the cause; first-time adopter sees `N hooks armed (lite tier)` and knows install worked

## Files likely to change

- `src/commands/init.ts` — orchestrates the new walker + banner
- `src/lib/copy-substrate.ts` — walker + verbatim copy logic; already exists per Phase 1 UC-init `governs_source`; extend for dist/lite/ path
- `src/lib/manifest-io.ts` — may need reader for `dist/lite/.claude/settings.json` shape (settings.json, not lite-manifest.json)
- `src/lib/write-safely.ts` — no change expected; walker calls existing writeSafely per ADR-002 complete mediation
- `tests/init.test.ts` — extend existing tests; add hook-count banner assertions
- `tests/init-output-parity.test.ts` — new file; ports bassclef-upstream parity test shape
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` — may need exit code additions (4 = manifest missing, 5 = schema mismatch) per UC-init §Minimal guarantee
- `package.json` — version bump 0.2.0 → 0.3.0 (or 1.0.0 if substrate/ drops)

## Out of scope for Phase 3

- Phase 4 (cold-adopter smoke) — runs AFTER Phase 3 ships live version; needs npm publish + fresh macOS profile
- Publishing 0.2.0 or 0.3.0 to npm — operator dispatch; separate from code ship
- Removing `substrate/` from tarball — if Phase 3 wraps into a MAJOR bump, this could ride; otherwise defer to a separate MAJOR-bump goal
- New tier packages (@thebassclef/standard, @thebassclef/ultra) — separate scope; requires upstream v0.40+ that emits `dist/standard/` + `dist/ultra/`

## Confirm at prep

Operator asks/reshapes:

1. Include the substrate/ drop in Phase 3 (MAJOR bump to 1.0.0)? OR keep dual-write through Phase 3 (MINOR bump to 0.3.0)? Recommend keeping dual-write for Phase 3 — cleaner Phase 3 boundary; substrate/ drop as its own goal after Phase 4 smoke confirms the walker works.
2. Publish 0.2.0 to npm before Phase 3 starts? OR skip 0.2.0 publish, go straight to 0.3.0 as the first Phase 3 release? Recommend skipping 0.2.0 publish (no adopter benefit; 0.2.0 has dist/lite/ in the tarball but cli code still reads substrate/) — publish 0.3.0 once Phase 3 ships the banner + fail-loud.

## Refs

- bassclef-cli#73 (parent execution plan; Phases 3+4 open)
- bassclef-cli#68 CLOSED via PR #74 (Phase 1)
- bassclef-cli#25 CLOSED via PR #75 (Phase 2)
- bassclef-upstream ADR-055 D1-D7 (accepted 2026-09-13 at v0.39.0)
- bassclef-upstream coord doc `docs/coordination/2026-09-12e-cli-boundary.md`
- Phase 1 session log — `docs/session-logs/2026-09-13-cli-68-phase-1-oo-ad-updates.md`
- Phase 2 session log — `docs/session-logs/2026-09-13b-cli-25-phase-2-publish-workflow.md`
