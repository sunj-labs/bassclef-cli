---
tier: standard
title: Risk ledger — cli#73 Phase 3 + Phase 4 (init walker, substrate/ drop, tarball smoke)
date: 2026-09-13
authored_by: agent
goal: docs/iteration-bets/2026-09-13c-cli-73-phase-3-init-walker.md
lenses:
  primary: michael-nygard
  supporting: [michael-feathers, linus-torvalds]
mode: pre-mortem-light
klein_shape: 3 lenses × 3-5 risks per lens (30 min budget)
---

# Risk ledger — cli#73 Phase 3 + Phase 4

## Sources read

- `docs/iteration-bets/2026-09-13c-cli-73-phase-3-init-walker.md` — goal doc authored this session
- `.claude/luminaries/michael-nygard.md` (via bassclef substrate) — anchor for fail-loud + stability patterns
- `.claude/luminaries/michael-feathers.md` — characterization testing anchor
- `.claude/luminaries/linus-torvalds.md` — adopter contract anchor (ADR-031 rule pointed here)
- `.claude/luminaries/alan-cooper.md` — Sam persona anchor (banner + errors)
- `docs/use-cases/UC-init.md` (Phase 1 rewrite) — reader contract source of truth
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` (2026-09-13 amendment) — safety invariants Phase 3 preserves

## Lens 1 — @luminary michael-nygard (fail-loud stability)

**N1. Silent skip returns.** Cli reads `dist/lite/` and finds no wiring manifest at `dist/lite/standards/bassclef-wiring-manifest.json`. Reader falls back to a default state instead of exiting non-zero. Adopter never sees the failure. Same class as the pre-ADR-055 empty-hooks bug.
- **Fold:** Step 4 fail-loud emits exit code 4 + structured error naming the expected path. Test asserts stderr contains "Wiring manifest missing at" + the path + the remediation phrase. No silent branch.

**N2. Schema major mismatch degrades to noise.** Cli built for schema major 2 finds a manifest at major 3. Reader parses partial fields and writes a corrupted settings.json. Adopter session-start hooks silently misfire.
- **Fold:** Step 4 emits exit code 5 + names expected major (2) and actual major (from manifest.version). Test asserts stderr contains both version numbers and the cure phrase. Assert BEFORE any settings.json write.

**N3. Fail-loud message uses jargon.** Sam reads "wiring manifest schema_version incompatible" and does not know what to do. Cure not clear.
- **Fold:** Message shape per ADR-055 D4: `"Wiring manifest missing at <path>. Cli built for schema_version <major>.x. Run \`npm install @thebassclef/<tier>@<latest>\` to fix."` — every message names the cause + the file + the command to run. Cooper C2 fold.

**N4. Publish 1.0.0 lands before Phase 4 smoke passes.** Operator dispatches publish workflow before verifying the tarball works end-to-end on a fresh dir. Adopters at 1.0.0 hit walker crashes.
- **Fold:** Publish workflow dispatch waits on operator morning greenlight. Phase 4-agent tarball smoke runs autonomously in this session; report result in session log. Operator opens cold-adopter-1 profile in morning; verifies hooks fire; only then dispatches publish.

**N5. Manifest write partial failure leaves adopter half-initialized.** Walker copies 4 of 5 files, then fails on file 5. Manifest.json records the 4 successful writes; the 5th file is missing. Next `bassclef sync` sees 4 files + expects 5; behavior unclear.
- **Fold:** Preserve current per-file `writeSafely` semantics — one file at a time; each failure logged with path + cause. Manifest records outcome per file. Exit code 2 on any error. Sync's existing "content differs" detection covers the recovery path.

## Lens 2 — @luminary michael-feathers (characterization tests)

**F1. Existing tests characterize substrate/ path.** Deleting substrate/ (Step 6.5) breaks tests that assert `<targetDir>/substrate/...` file paths or the 149-file count. Test suite goes red before Step 7 verify.
- **Fold:** At Step 6.5, run full test suite BEFORE deleting substrate/. Enumerate failing tests. Classify each as (a) delete-with-substrate, (b) update for dist/lite/, (c) preserve for Phase 3 shape. Land the classification in the commit body.

**F2. Parity test port is not faithful.** Upstream parity test asserts specific settings.json shape or file-count invariants that don't match cli's env. Ported test either passes trivially (weak assertion) or fails on shape difference cli should honor.
- **Fold:** Read upstream parity test verbatim before porting. Cite each assertion in the port with a comment naming the source line. When cli's shape genuinely differs (e.g., cli walks 5 files, upstream walks a larger set), amend the port with a comment stating why.

**F3. RED test passes trivially without walker code.** Step 1 RED test uses `expect(fn).not.toThrow()` where fn does nothing. Not really RED.
- **Fold:** Step 1 test asserts specific file list + content byte-identity vs `dist/lite/`. Before walker code lands, the file list at target dir is empty; assertion fails with a diff naming the missing files. Feathers characterization requires OBSERVABLE behavior.

**F4. Manifest write path silently changes shape.** Walker writes `.bassclef/init.manifest.json` with 5 entries (one per file); current shape uses 3 entries. Downstream sync tests break.
- **Fold:** Step 2 walker keeps the manifest write shape identical — same fields per entry (path, template, template_version, outcome, hash). Only the entry count grows to match dist/lite/. Sync tests validated in Step 7 verify.

## Lens 3 — @luminary linus-torvalds (adopter contract)

**L1. Silent regression on `bassclef init` semantics for existing 0.2.0 users.** Even at zero adopters, the semantic contract is a public API. MAJOR bump signals breaking. But the operator's own cold-adopter-1 profile IS an adopter — its state matters.
- **Fold:** MAJOR 1.0.0 documented in package.json + README + session log. Cold-adopter-1 profile smoke covers regression class. Every safety invariant per ADR-002 preserved (documented in Step 6.5 commit body).

**L2. `--force` semantics drift.** Current `--force` skips per-file existence check. New walker writes 5 files instead of 3. Adopters passing `--force` expect the old 3-file overwrite; get 5.
- **Fold:** UC-init amendment (Phase 1) already documents the extended file list. `--force` semantics stay: skips existence check per file. New file count is documented in `bassclef init --help` output (usage() function in init.ts).

**L3. Exit codes 4 + 5 collide with adopter scripts.** Adopters (or CI) reading `$?` may treat non-zero as generic failure. New codes 4 + 5 could be mistaken for kernel signal exits (SIGINT=130, SIGTERM=143 different range but adopters may script defensively).
- **Fold:** Exit codes 4 + 5 are non-conflicting with common signal exit codes (128+N). Documented in ADR-002 amendment. `bassclef init --help` names exit codes 0/1/2/3/4/5. Test suite covers each code path with structured stderr.

**L4. Adopter workflow surprised by mandatory manifest.** Adopter installs `@thebassclef/lite@1.0.0` from a broken build (missing wiring manifest). Every `bassclef init` fails with exit 4. Adopter cannot use the package until upstream rebuilds.
- **Fold:** Prepublish script preflight (Phase 2) already asserts the wiring manifest exists at source. Add Phase 3 postflight: assert `dist/lite/standards/bassclef-wiring-manifest.json` present + parses + version.major matches. Broken build cannot ship.

## Cross-cutting

**X1. /loop CI iteration takes 4+ rounds.** Phase 3 code touches many surfaces. First CI run reveals lint / typecheck / test failures across multiple files. /loop discipline iterates each round; agent burns turns.
- **Fold:** Run full local suite BEFORE opening PR. Fix all failures locally. `.claude/rules/loop-discipline.md` allows iteration but the goal is first-CI-round green.

**X2. Session compaction mid-work.** 90-160 turns hits at least one compaction boundary. Post-compaction re-orient must preserve Step-N state.
- **Fold:** TaskList carries the step sequence. Session log at Step 7 records completed steps. Post-compaction agent reads task list + last commit + goal doc to resume.

## Folds summary

- N1 → Step 4 emits exit 4 + assertion in test
- N2 → Step 4 emits exit 5 + version-in-message assertion
- N3 → All messages grade-8 per Cooper; cite ADR-055 D4 shape
- N4 → Phase 4 smoke gates publish dispatch (operator morning)
- N5 → Per-file writeSafely preserved; manifest records outcome
- F1 → Test enumeration BEFORE Step 6.5 delete
- F2 → Verbatim upstream parity test port + comments
- F3 → RED assertion on file list + byte-identity (not `not.toThrow`)
- F4 → Manifest shape preserved; entry count only changes
- L1 → MAJOR 1.0.0 documented; cold-adopter-1 smoke covers regression
- L2 → `--force` semantics preserved; usage() updated
- L3 → Exit codes documented; help text updated
- L4 → Prepublish postflight asserts wiring manifest in dist/lite/standards/
- X1 → Full local suite before PR open
- X2 → TaskList + session log carry state across compaction

## What I'm NOT covering (with reason)

- @luminary alan-cooper full lens — deferred to per-step check at Steps 4+5. Cooper's Sam persona check applies to specific message strings; running full 5-risk consult on the entire goal produces too much overlap with Nygard N3 above.
- @luminary saltzer-schroeder — Phase 3 preserves every existing safety invariant per ADR-002 amendment. No new writes to audit. Complete mediation already covered.
- @luminary john-ousterhout — walker refactor is a deep-module preservation, not a new module. Existing single-narrow-interface shape stays.

## Refs

- Goal doc: `docs/iteration-bets/2026-09-13c-cli-73-phase-3-init-walker.md`
- Loop discipline: `.claude/rules/loop-discipline.md` Step 0.5 (pre-mortem light required before code work)
- Klein workshop shape: 3 lenses × 3-5 risks each, 30 min budget (met — 12 folds landed)
