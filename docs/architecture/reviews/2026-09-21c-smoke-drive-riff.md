---
tier: lite
primary_lens: michael-feathers
supporting_lenses: [kent-beck, jerome-saltzer-and-michael-schroeder, alistair-cockburn]
date: 2026-09-21
scope: Epic #199 Story 1 — smoke-drive-riff
prior_review: none — first review under Epic #199
coverage_marker: state/markers/architect-review/2026-09-21c-smoke-drive-riff.marker
verdict: READY-with-followups
---

# Architect review — smoke-drive-riff (Epic #199 Story 1)

Primary lens: Feathers — this drive IS a characterization test against the `/riff` skill. Supporting: Beck (RED-first commits verified in git log), Saltzer-Schroeder (scratch-dir + path validation), Cockburn (walking-skeleton scope).

## Sources read

- `scripts/smoke-drive-riff.sh` L1-224 (drive under review)
- `scripts/smoke-drive-onboard-repo.sh` L1-142 (sibling template)
- `harness/docker/entry.sh` L370-412 (Step 6 + new Step 7 wire)
- `tests/harness/smoke-drive-riff.test.ts` L1-190 (10 tests)
- `tests/harness/fixtures/smoke-drive-riff/*.sh` (6 fixtures)
- `docs/rfcs/2026-09-21c-smoke-drive-riff-council.md` (RFC folds F1-F5)
- `docs/decompositions/2026-09-21c-smoke-drive-riff.md` Interfaces 1-4

## Verdict

**READY-with-followups.** Ship the PR. Cure F-AR-1 (token list) inline before merge. Track F-AR-2 (Step 7 wire coverage) as follow-on to Story 6. No blocker findings.

Test state: 10/10 characterization GREEN. Full suite 468/468 GREEN. Typecheck clean.

## RFC fold verification

| Fold | Design intent (RFC) | Code location | Verified? |
|---|---|---|---|
| F1 path traversal | Validate + refuse root, bare $HOME, bare /tmp | `_validate_scratch_dir()` L82-115 + tests L157-163 | **PASS** |
| F2 assertion sub-classes | REASON code no-html / empty-html / no-h2 | `_assert_variants()` L191-217 + tests L100-131 | **PASS** |
| F3 env-miss token list | playwright / mcp / screenshot / puppeteer / chromium / **browser** | `_check_env_miss()` L179-186 | **PARTIAL** — `browser` missing; `mcp` narrowed to `mcp not enabled` |
| F4 tag lines | PASS / FAIL:sub / TIMEOUT / ENV_DEGRADED:tok / SETUP_FAIL:reason | every exit path L67-166 | **PASS** |

## Findings

### F-AR-1 [MODERATE · Feathers] — env-miss token list narrower than RFC spec

**Evidence:** `scripts/smoke-drive-riff.sh` L184 pattern `playwright|mcp not enabled|cannot screenshot|puppeteer|chromium` compared against RFC F3 spec at `docs/rfcs/2026-09-21c-smoke-drive-riff-council.md` calling for `playwright|mcp|screenshot|puppeteer|chromium|browser`.

Warrant: the drive's grep pattern narrows `mcp` to `mcp not enabled` (misses a `/riff` BLOCK message that says e.g., "MCP server not connected"). It also drops the `browser` token entirely (some Playwright errors reference `browser` without naming Playwright). Both narrowings shrink the env-degraded detection surface. Real-world false-negatives will map to exit 3 (assertion) instead of exit 6 (env-degraded), reversing the F3 discipline.

**Cure inline:** expand the pattern before merge to `playwright|mcp|screenshot|puppeteer|chromium|browser`. Add a Tier 0 fixture for each new token. Est: 10-15 turns.

### F-AR-2 [MODERATE · Cockburn] — walking-skeleton gap on the wire

**Evidence:** `harness/docker/entry.sh` L394-412 (Step 7 wire) has no Tier 0 test spawning entry.sh with fixture scripts_dir. Every test in `tests/harness/smoke-drive-riff.test.ts` exercises the drive DIRECTLY via `spawnSync('bash', [DRIVE, ...])` — never through entry.sh.

Warrant: Cockburn's walking-skeleton principle says exercise every architectural layer end-to-end. This session exercised layers 1-2 (drive + fixtures) but not layer 3 (harness wire). A rename of the drive script or a shape change in `_docker_harness_emit_evidence_row` breaks Step 7 silently until real Docker runs at Story 6.

**Disposition:** ACCEPT — file as follow-on ticket. Story 6 (verification against a real Docker run) closes the loop. Adding an entry.sh-fixture test now would duplicate Story 6's coverage at a small cost.

### F-AR-3 [LOW · Cooper] — RFC F5 (smoke-report.sh exit-6 awareness) not verified

**Evidence:** `docs/rfcs/2026-09-21c-smoke-drive-riff-council.md` F5 required verifying `scripts/smoke-report.sh` distinguishes exit 6 from exit 3. I did not read the report script this session.

Warrant: F5 was labeled as an acceptance item in the spec. The verification path is a grep or a Tier 0 test against smoke-report's output. Without it, exit 6 may report as "fail" at the aggregator level, defeating F3's semantic split.

**Disposition:** DEFER — file follow-on ticket. Low risk because Story 6 will surface the aggregation issue if it exists.

### F-AR-4 [LOW · Feathers] — no characterization test for teardown-on-signal path

**Evidence:** `scripts/smoke-drive-riff.sh` L134-140 traps EXIT + INT + TERM. Only EXIT is exercised in tests.

Warrant: SIGINT and SIGTERM code paths are untested. Cure requires spawning the drive + sending SIGTERM mid-run + asserting scratch dir removed. Complexity is meaningful. Return on investment low — the trap is verbatim from the sibling template that has run in Docker for weeks without a reported teardown-on-signal bug.

**Disposition:** DEFER — note in the drive header. Story 6 catches real-world regressions.

## Coverage checklist

- [x] Component architecture — one script + one wire; boundary at claude subprocess + fs
- [x] Data flow — drive → fixture claude → capture file → assertion → tag line + exit code
- [SKIP] Auth + security — no auth surfaces in scope
- [SKIP] Queue + workers — not applicable
- [x] External dependencies — claude + perl + git; all preconditions checked
- [x] Error handling — 5-way exit-code map; no silent failures; every exit prepended with tag line
- [SKIP] Database — no DB in scope
- [x] Testing coverage — 10 characterization tests; full suite 468/468 GREEN
- [x] Performance — 300s default timeout; per-fixture test uses 2s (fast test)
- [x] ADR fitness — `state/markers/adr-deviation/feat-199-smoke-drive-riff.marker` outcome ADR-honored
- [SKIP] CLAUDE.md fitness — scope is one drive; CLAUDE.md audit out of scope
- [x] SOLID + Clean Architecture — single responsibility per function; pure `_check_env_miss` + `_assert_variants` + `_validate_scratch_dir`
- [x] DDD — BCE classification in decomp; boundaries clean (drive Control class thin; fixtures are Boundary)
- [x] Stability patterns — fail-loud with distinct exit codes; teardown on EXIT/INT/TERM

12 covered, 4 skipped, 0 deferred — coverage 100% within applicable areas per `.claude/rules/architect-review-discipline.md` A4.

## Test coverage assessment

- 10 characterization tests spawn the drive against 6 fixture claude mocks
- Each RFC fold has at least one test (F1: path traversal; F2: 3 sub-classes; F3: Playwright block; F4: every test asserts stderr tag)
- Sibling: `smoke-drive-onboard-repo.sh` has zero Tier 0 tests today — this drive raises the bar
- Full-suite test count went from 458 → 468 (10 new tests, all GREEN)

## SOLID + DDD + Stability findings

- **SRP:** `_validate_scratch_dir()`, `_check_env_miss()`, `_assert_variants()` each own one responsibility. Main sequence composes.
- **Pure functions:** `_check_env_miss` is pure over the capture file; `_assert_variants` is pure over the scratch dir.
- **BCE:** Boundary = fixture claude subprocess + capture file writer + argv parser. Control = main sequence. Entity = scratch dir state + capture file content. Clean.
- **Nygard stability:** teardown trap on EXIT+INT+TERM. Distinct exit codes per failure class. Env-degraded distinguished from assertion-fail. No silent-fail path.

## Recommendations

1. **Cure F-AR-1 inline before merge.** Expand env-miss token list. Add fixture(s) for new tokens. 10-15 turns.
2. **File F-AR-2 as follow-on.** Entry.sh Step 7 wire coverage lives in Story 6.
3. **File F-AR-3 as follow-on.** `scripts/smoke-report.sh` exit-6 awareness.
4. **Note F-AR-4 in drive header.** SIGINT/SIGTERM teardown untested; defer to Story 6.

## Refs

- `.claude/rules/architect-review-discipline.md` — two-method requirement
- `.claude/rules/testing-tier-config.md` — tier assignments
- `docs/rfcs/2026-09-21c-smoke-drive-riff-council.md` — RFC folds under verification
- `scripts/smoke-drive-onboard-repo.sh` — sibling baseline
- @luminary michael-feathers — primary
- @luminary kent-beck — supporting
- @luminary saltzer-schroeder — supporting
- @luminary alistair-cockburn — supporting (authoring set overlap acknowledged; walking-skeleton finding still surfaced)
