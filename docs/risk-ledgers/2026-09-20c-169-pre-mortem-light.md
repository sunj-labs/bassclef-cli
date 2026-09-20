---
tier: project
title: Pre-mortem light — cli#169 vitest test-run history + release cascade
id: 2026-09-20c-169-pre-mortem-light
authored: 2026-09-20
goal_doc: docs/iteration-bets/2026-09-20c-169-vitest-test-run-history-plus-release-cascade.md
mode: light — 3 lenses × 5 risks each, 30 min per Klein workshop shape
lenses:
  - kent-beck
  - michael-nygard
  - andreas-zeller
---

# Pre-mortem light — cli#169 + release cascade v1.2.2

## Sources read

- `docs/iteration-bets/2026-09-20c-169-vitest-test-run-history-plus-release-cascade.md` — the goal doc
- `docs/specs/spec-169-test-run-history.md` — the shipped contract
- `docs/decompositions/2026-09-20c-169-vitest-instrumentation.md` — BCE split + test-list
- `vitest.config.ts` — current config; no reporters block yet
- `.gitignore` — verified `state/events/test-runs/` absent
- `.claude/luminaries/kent-beck.md`, `michael-nygard.md`, `andreas-zeller.md` — anchor lenses

## Frame — Klein pre-mortem

Assume six weeks from now this session's ship has failed. What went wrong? Each lens surfaces 5 candidate failure paths. Strongest concerns fold into the design before code.

---

## Beck lens (RED-cycle + test-first risks)

**B1. Tests coupled to specific fixture content — brittle to vitest version bump.**
Failure path: vitest 2.1 changes the JSON reporter shape by one field. Fixtures + aggregator break. All 13 tests go RED for the wrong reason.
Severity: **MEDIUM**. Detectable via CI on any vitest bump.
Cure: characterize the fields we USE, not the whole JSON. Aggregator uses only `testResults[].name` + `testResults[].status` + `testResults[].duration`. Fixture files include ONLY those three fields plus a comment noting other vitest fields are present-but-ignored.

**B2. Test names hardcoded in fixtures — real tests renamed → fixtures drift silently.**
Failure path: someone renames a real test; fixtures still name the old test; tests pass on synthetic data but the aggregator's real output diverges from what maintainers expect.
Severity: **LOW**. Fixtures are self-contained — they don't reference real test names.
Cure: fixtures use synthetic names (`tests/synthetic/A.test.ts`, `tests/synthetic/B.test.ts`). Real tests never mixed in.

**B3. RED phase skipped if test file created after implementation.**
Failure path: agent authors aggregator first, then tests. Tests pass first try. Testing-tier-enforce hook doesn't fire because both files have same mtime. No RED signal.
Severity: **MEDIUM**. This is the Beck discipline the substrate guards.
Cure: author test file FIRST (touch it). Then run vitest — must see 13 RED. Only then write the implementation. Commit RED evidence in the commit body.

**B4. Fixture JSON does not match actual vitest 2.0.0 output shape → tests pass but real integration breaks.**
Failure path: I wrote fixtures from memory of vitest JSON. Real `npm test` produces a different shape. Aggregator crashes on the first live run.
Severity: **HIGH**. Direct integration failure.
Cure: BEFORE writing fixtures, run vitest with the JSON reporter once against a trivial test to CAPTURE the real shape. Use that capture as the fixture template.

**B5. Test-list block missing → sufficiency rubric not tracked.**
Failure path: I forget to open the test file with `# test-list:` per `.claude/rules/test-list-discipline.md`. Reviewer can't see intended vs implemented assertions.
Severity: **LOW**. Reviewer catches at PR time.
Cure: open test file with the 13-line test-list block from decomposition doc verbatim.

---

## Nygard lens (release-cascade + operational risks)

**N1. `state/events/test-runs/` not in `.gitignore` → operator commits test-run JSON accidentally → leaks maintainer machine paths.**
Failure path: `.gitignore` edit forgotten OR added under wrong path. `git add -A` in a future session sweeps the JSON. Push publishes maintainer stack traces.
Severity: **HIGH**. Same class as memory `feedback_never_git_add_all_in_adopter_repos.md`.
Cure: `.gitignore` edit ships in the SAME PR as the vitest reporter config. Both together, or neither. Add explicit Tier 0 test that greps `.gitignore` for the path.

**N2. Vitest reporter with dynamic filename fails silently under CI mode.**
Failure path: `outputFile: 'state/events/test-runs/${Date.now()}.json'` works locally. CI has different working dir. File writes to wrong path or fails silently. `npm test` in CI produces no record.
Severity: **MEDIUM**. Detected only when someone runs `npm run test:report` after CI.
Cure: use static filename pattern via vitest's own timestamp field OR wrap in a config function that logs the resolved path once on init. Document in spec that CI runs are captured only when local (not intended for CI — that's for #170).

**N3. Aggregator crash on new vitest JSON shape version breaks `npm test:report` for maintainers.**
Failure path: vitest 3.0 lands, ship JSON shape changes, aggregator errors on jq parse.
Severity: **LOW**. Only affects `npm test:report`, not `npm test`. Fail-soft cure obvious.
Cure: aggregator handles parse errors per file (already in decomposition failure paths). Bad file → WARN + skip. No cascade.

**N4. Release cascade merges break each other's assumptions.**
Failure path: PR #167 (CLAUDE.md ADRs) merges after #163 (Docker harness). But #167 was authored against main pre-Docker. Merge conflict in CLAUDE.md between "ADR list extension" and "Docker harness reference" (if any).
Severity: **MEDIUM**. Rebase resolves; costs 2-5 turns per PR.
Cure: check each PR's mergeability against updated main BEFORE merging. Merge order: #163 first (largest, sets the baseline), then #168 (vitest coverage, additive), then #167 (CLAUDE.md, doc-only), then #169 (this session's).

**N5. Publish workflow provenance flake — v1.2.2 tag pushed but package not on npm.**
Failure path: `.github/workflows/publish.yml` runs, provenance signing fails (rare but seen 2026-09-17 briefly), tag exists on git but npm never gets the tarball.
Severity: **HIGH**. Requires operator Touch ID retry + risk of double-publish.
Cure: verify per prior runbook — read publish log for `+ pkg@1.2.2`, then `npm view @thebassclef/lite@1.2.2` (allow 3-min registry lag). If fail: re-run workflow via `gh workflow run publish.yml`. Never move the tag.

---

## Zeller lens (hypothesis-test pairing + flake calc correctness)

**Z1. Flake calc math wrong — division-by-zero when run_count is 0 for a test.**
Failure path: test T ran in fixtures 1 + 3 but not fixture 2. Aggregator counts pass_rate = passes / runs_containing_T. If a test is empty for a run window, denominator is 0 → NaN.
Severity: **MEDIUM**. Silent corruption of flake output.
Cure: aggregator uses `passes / total_records_including_absent_as_null_run`. Tests never in fixtures → pass_rate undefined, excluded from flake list. Test case in Tier 0.

**Z2. "Deterministic" hypothesis doesn't hold for timing-based tests → all tests flag as flaky.**
Failure path: duration varies +/- 20% between runs. Nothing wrong with the test. Duration histogram is noisy.
Severity: **LOW**. Duration is informational, not a fail signal. Flake list is separate (only tracks pass rate).
Cure: keep duration + flake as separate sections. Duration is descriptive; flake is prescriptive. Document in spec.

**Z3. jq expression treats missing field as null vs missing → parse silently drops results.**
Failure path: `jq '.testResults[].status'` returns "null" if `status` is missing on some record. Aggregator counts null as pass (false).
Severity: **MEDIUM**. Silent miscount.
Cure: aggregator uses `jq '.testResults[] | select(.status)'` — explicit filter for records with a status field. Malformed records skipped with WARN.

**Z4. Timezone in filename → aggregator sorts wrong (UTC vs local).**
Failure path: filenames written in local time (e.g., 2026-09-20T14-30-00.json), later files with different DST offset sort wrong lexicographically.
Severity: **LOW**. Sort discrepancy over DST boundary; rare.
Cure: filenames use UTC timestamp. Vitest reporter config forces `new Date().toISOString().replace(/[:.]/g, '-')`.

**Z5. Filename collision if two `npm test` runs fire in the same second → second overwrites first.**
Failure path: `Date.now()` returns same millisecond for two adjacent runs (rare on real dev machine, but possible under CI parallelization).
Severity: **LOW**. One record lost.
Cure: filename includes milliseconds (`.replace(/[:.]/g, '-')` on ISO with milliseconds keeps `-mmm` suffix). Two same-millisecond runs → second overwrites first with WARN. Documented; acceptable.

---

## Ranked concerns to fold pre-code

**HIGH severity (fold before writing any code):**

- **B4**: capture real vitest 2.0.0 JSON output shape as fixture template BEFORE writing tests. Fold into Step 3 sequencing.
- **N1**: `.gitignore` edit + verifying Tier 0 test both ship in Step 4 alongside the vitest config change. Not deferred.
- **N5**: release cascade Step 7 includes the runbook read (2026-09-17 v1.1.1 publish notes) for retry protocol. Cite in the goal doc.

**MEDIUM severity (fold at test-write time):**

- **B1**: fixture files include ONLY name + status + duration. Comment: "other vitest fields present in real output; aggregator ignores."
- **B3**: RED evidence captured in Step 3 commit body. Test file created + committed BEFORE implementation file.
- **N2**: vitest reporter config logs resolved output path once. Test verifies path resolves under `state/events/test-runs/`.
- **N4**: merge order #163 → #168 → #167 → #169. Rebase between merges if needed.
- **Z1**: aggregator excludes tests-never-in-record-window from flake list. Test case in Tier 0.
- **Z3**: `jq | select(.status)` filter. Not implicit.

**LOW severity (accept + document):**

- **B2**: fixtures use synthetic names.
- **B5**: test-list block from decomposition ships verbatim.
- **N3**: fail-soft per-file already in failure paths.
- **Z2**: duration = descriptive; flake = prescriptive.
- **Z4**: UTC timestamps.
- **Z5**: same-ms collision documented; acceptable.

## Design edits from folds

1. **Decomposition — sequencing revision** — Step 1a inserted BEFORE Step 1 (Tier 0 tests): run vitest once against a trivial test with `--reporter=json --outputFile=/tmp/vitest-shape-capture.json` to CAPTURE real 2.0.0 JSON shape. Use as fixture template.
2. **Test-list amendment** — add:
   - `[ ]` `.gitignore` grep test verifies `state/events/test-runs/` line present
   - `[ ]` filename uses UTC ISO timestamp (test asserts pattern `YYYY-MM-DDTHH-MM-SS-mmm.json`)
   - `[ ]` test-never-in-window: pass_rate undefined, excluded from flake list
3. **Spec — Failure modes section** — extend with: "Same-millisecond filename collision: second run overwrites first. Documented, not fixed in V1."
4. **Merge order** — goal doc Step 7 revised: #163 first → #168 → #167 → #169 (this session). Rebase check between each.
5. **Aggregator jq expression** — always use `select(.status)`. Never implicit.

## Confidence

3 lenses × 5 = 15 candidate failures. 3 HIGH folded into design edits above. 6 MEDIUM addressed at test-write or step-sequencing time. 6 LOW documented + accepted.

## What could still surprise us

Live vitest JSON might carry per-test suite hierarchy that fixtures don't capture. Fold on first live run — treat as B4 already handled.

Release workflow's `manifest_version` check might refuse v1.2.2 if bundle metadata drifts. Not in scope of any risk above; would surface in Step 7 as a distinct BLOCK. Cure per bassclef-upstream ADR-029 release ledger discipline.
