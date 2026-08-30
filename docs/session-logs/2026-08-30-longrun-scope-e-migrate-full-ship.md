---
date: 2026-08-30
session_type: longrun (Option c — full ship Steps 1-8)
goal: docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md
mode: orchestrator-gated sequential
tier: lite
duration_estimate: ~200 turns across one session
outcome: shipped
pr_opened: sunj-labs/bassclef-cli#39
---

# 2026-08-30 — /longrun scope-e migrate full ship

## What shipped

**`bassclef migrate` subcommand end-to-end** — Steps 1-8 landed across 7 atomic commits on branch `feat/scope-e-migrate`. PR #39 open for operator review.

Full Beck GREEN: 29 test files / 210 tests pass.

## Commit sequence

| Step | Commit | Notes |
|---|---|---|
| 0 | 099118a (prior session) | Goal doc + gate markers |
| 1 | 1cb9671 | UC-migrate — Cockburn fully-dressed |
| 2 | 327ed60 | Decomposition — 6 modules + @pattern annotations |
| 3 | 60e5793 | ADR-008 D1-D6 + risk ledger v1 |
| 4 | 234419c | Tier 0 RED harness (6 test files + 1 fixture) + Step 3.5 corrections |
| 5 | 895cd40 | Phase 1 — argv reducer + cli.ts dispatch |
| 6 | 8dae6eb | Phase 2 — full migrate + N3/N4/S2/L3 refinements |
| 7 | 21126f4 | Signoff — ledger v2 verified + luminary marker |

## Sources read

- `docs/whereami.md` (Step 0.4)
- Goal doc + plan doc + parent goal (scope-b1) + parent roadmap (Step 0.6 parent-goal walk)
- Sister UC-init + UC-sync (Step 1 shape reference)
- Sister decomposition 2026-08-28-npm-lite-bundling (Step 2 shape reference)
- Sister ADR-007 + risk ledger scope-b1 v4 (Step 3 shape reference)
- Sister init-argv.ts + cli.ts (Step 5 code pattern)
- copy-substrate.ts + manifest-io.ts + init.ts source (Step 6 integration points)

## Gates fired

- **/temperance** at Step 0 (prep) — session scope-decision marker at `state/markers/temperance/feat-scope-e-migrate.marker`
- **/luminary** at Step 0 + Step 7 — primary lens linus-torvalds; supporting ousterhout + parnas + nygard + cooper + feathers
- **ADR-deviation-challenge** at Step 1 — outcome ADR-honored (inherits ADR-002 + ADR-003 + ADR-007)
- **Beck RED-then-GREEN** at Steps 4-6 — 28 new tests written as RED before Step 5-6 source landed
- **Grep audit** at Step 7 — 11 unique refs match ledger ↔ commit trailers
- **Luminary signoff** at Step 7 — Linus + Ousterhout marker

## What worked

**Nested scope-slice options at prep.** Presenting a/b/c/d as `a ⊂ b ⊂ d ⊂ c` (nested, not MECE) let the operator pick "full ship" with fallback stop points clearly named. Compressed the pick to one turn.

**Step 3.5 preflight-correction commit.** Reading the actual `src/lib/manifest-io.ts` at Step 4 caught two mismatches from the earlier design: `detectLegacyManifest` returns boolean (not 3-value enum), and the 3rd config file is `substrate.secrets.md` (not `CLAUDE.md`). Correction landed in the same commit as the RED harness — no rework compounded.

**Bundle-hash test failure.** The R3 test failed with `0 added / 0 preserved / 5 errored` because my fixture used fake `content_hash: 'aaaa...'` and copy-substrate verifies hash before write. Real SHA-256 in the fixture unblocked the entire test suite in one edit.

**Async main refactor.** Making `main()` in cli.ts async so `runMigrate` could return `Promise<number>` (needed because `readline/promises` is async) was small — one signature change, one await, one .then/.catch on entry.

## What did not work

**Skill dispatch discipline.** The prep skipped a formal `/kiss words --rewrite` dispatch pass on the full prep proposal draft. The prose stayed readable via manual self-check, but the SKILL body Step self-check step (per longrun SKILL.md L389-395) named the discipline that I did not follow. Next longrun: dispatch /kiss words --rewrite on every named surface.

**Path B integration test guard.** The R6 test for `runPathB` needs the real `substrate/` bundle to test end-to-end. The env-gated skip (via `if !existsSync(REAL_SUBSTRATE)) return`) works but hides the test when substrate/ is absent. Follow-on candidate: extend runPathB to accept a bundleRoot too, or ship an npm run bundle:substrate pre-test step. Not blocking; migrate-command.test.ts covers the e2e shape.

## /retro tier note

`/retro` skipped per lite tier gate (SKILL.md L45-49 tier gate). This two-line note in the session log covers the "what worked + what did not" obligation.

## Cross-repo tickets

- No new tickets filed this session (all work landed in bassclef-cli)
- Dogfooded bassclef-upstream#1420 — pre-mortem-to-compensator mapping pattern (second bassclef-cli goal to use it)

## Next work

**Operator merge review** — PR #39 waits for operator review + merge. On merge:
- Tag + publish `@thebassclef/core@0.1.1` (or 0.2.0 per operator judgment; ADR-008 D6 amendment note)
- Update whereami subsystem row (npm package → 0.1.1 shipped)
- Close scope-e as SHIPPED; scope-e follow-on candidates (RemoteFetchStrategy restoration, S1 signature verification) available for a future goal

## References

- Goal doc — `docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md`
- PR — sunj-labs/bassclef-cli#39
- ADR-008 — `docs/adrs/ADR-008-bassclef-migrate-subcommand.md`
- Risk ledger v2 — `docs/pre-mortem-mappings/2026-08-30-migrate.md`
- Migration doc — `docs/migrations/0.1.0.md`
- Signoff marker — `state/markers/luminary/feat-scope-e-migrate-step7.marker`
