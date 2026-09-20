---
tier: project
title: RFC-0006 — cli#169 test-run history adversarial council
id: RFC-0006-cli-169-test-run-history-adversarial
authored: 2026-09-20
council: 5 outside luminaries (not in authoring set)
goal_doc: docs/iteration-bets/2026-09-20c-169-vitest-test-run-history-plus-release-cascade.md
pre_mortem: docs/risk-ledgers/2026-09-20c-169-pre-mortem-light.md
---

# RFC-0006 — adversarial council on cli#169 test-run history

## Sources read

- `docs/iteration-bets/2026-09-20c-169-vitest-test-run-history-plus-release-cascade.md` — the goal doc under review
- `docs/specs/spec-169-test-run-history.md` — shipped contract
- `docs/use-cases/UC-script-169-aggregate-test-runs.md` — fully-dressed UC
- `docs/decompositions/2026-09-20c-169-vitest-instrumentation.md` — BCE decomposition
- `docs/risk-ledgers/2026-09-20c-169-pre-mortem-light.md` — pre-mortem light findings
- `.claude/luminaries/david-parnas.md`, `michael-feathers.md`, `alistair-cockburn.md`, `linus-torvalds.md`, `vaughn-vernon.md` — outside council lenses
- `vitest.config.ts` (this repo) — current shape

## Council picks (outside the authoring set)

Authoring set: Beck, Nygard, Zeller.

Outside council picked to catch what the authoring lenses miss:

- **David Parnas** — information hiding + module boundaries; will read the BCE split adversarially
- **Michael Feathers** — characterization tests for legacy code; will read the "capture real vitest JSON" step
- **Alistair Cockburn** — use case discipline; will interrogate whether extensions cover real failure paths
- **Linus Torvalds** — adopter contract / stability; will interrogate the observable `npm test` contract change
- **Vaughn Vernon** — anticorruption layer (DDD); will interrogate the aggregator's isolation from vitest's shape drift

Each lens reads the design chain and surfaces findings ranked HIGH / MEDIUM / LOW.

---

## Parnas — information hiding + module boundaries

**P1 (MEDIUM). Boundary/Control split leaks internals via shared file-list argv.**

The decomposition's Boundary calls `compute_duration_histogram "${FILES[@]}"`. That passes a file-list array through the module boundary — Control sees paths, not records. Control has to re-parse each file itself. Two responsibilities cross the boundary in one call.

**Cure**: Boundary reads all files into a single canonicalized shape (list of `{path, testResults}` objects) and passes THAT to Control. Control operates on the parsed records, not on file paths. Boundary owns "where records come from"; Control owns "what records mean."

**P2 (LOW). `SCRIPT_DIR` global in Boundary implies location-dependent module.**

Decomposition uses `source "$SCRIPT_DIR/lib/aggregate-test-runs.sh"`. If someone moves the entry script, sourcing breaks. Not a portability principle violation — it's how bash sourcing works — but Parnas would ask if the coupling is minimized.

**Cure**: pin the lib path relative to `${BASH_SOURCE[0]}` — the same discipline other bassclef scripts use. Test verifies the resolution.

**P3 (MEDIUM). `--json` flag exposes internal aggregation shape as public contract.**

`--json` emits a shape that mirrors internal data structures. If aggregator internals refactor, JSON output shape breaks callers (e.g., a future CI script reading it).

**Cure**: schema the `--json` output explicitly. Version it (`"schema_version": 1`). Adopters (or future us) can then depend on `schema_version: 1` and we flip to `schema_version: 2` if the shape changes. Test verifies `schema_version` field present.

---

## Feathers — characterization tests

**F1 (HIGH). Pre-mortem B4 cure is right in spirit but incomplete — the "capture" only characterizes ONE test.**

The pre-mortem says capture vitest JSON from a trivial test. That gives one record. Real suites have suites-of-tests, nested describes, skipped tests, timeouts. A one-test capture doesn't characterize the shape variance. First real run against 433 real tests could surface fields the fixture never saw.

**Cure**: capture vitest JSON from the ACTUAL current test suite (all 433 tests). Use that as the primary fixture. Derive synthetic fixtures from it by slicing. Characterization test discipline: pin what actually exists, not what a toy case implies.

**F2 (MEDIUM). No golden-file test for the shipped output format.**

Aggregator emits text output ("## Duration — top 10", "## Flake — ..."). Test-list checks input handling. Nothing pins the exact output shape a maintainer will see. Later refactor changes wording; no test catches.

**Cure**: add a golden-file test — one fixture → one expected output text file. Byte-compare. Cheap to update when output shape intentionally changes; catches drift when it doesn't.

**F3 (LOW). The Tier 0 tests are the ONLY tests — no integration test against real `npm test`.**

The 13 unit tests exercise fixture-driven Control logic. Nothing exercises the actual `npm test` → aggregator round-trip. First integration might reveal a class the units missed.

**Cure**: add one integration test that runs vitest against a minimal 2-test fixture, then runs the aggregator on the produced JSON. Slow (10s) but pins the round-trip once. Optional if F1 cure ships (full-suite characterization is functionally similar).

---

## Cockburn — use case discipline

**C1 (MEDIUM). Extension 5a covers "one file malformed" but not "one FIELD malformed within a record".**

The UC handles malformed JSON files. Real vitest JSON might have a valid file but a testResults[N] entry with a null status (partial write during CTRL-C). Aggregator with `jq | select(.status)` filter (per pre-mortem Z3) drops that record silently. UC doesn't name this class.

**Cure**: add UC extension 5b — "single record within a file has missing fields → aggregator counts records-with-status, warns if `records_with_status < total_records` on stderr." Test case in Tier 0.

**C2 (MEDIUM). Preconditions assume `jq` present but UC extension "jq missing" is `anywhere` — postconditions unclear.**

If `jq` is missing DURING the run (e.g., killed mid-loop), what's the postcondition? Full-fail? Partial-summary? UC doesn't say.

**Cure**: strengthen the precondition — check `jq` availability once at Boundary entry. If missing, exit 1 IMMEDIATELY. Never enter Control. Test verifies. This matches the decomposition's failure paths table but tightens the UC prose.

**C3 (LOW). Main success scenario step 6 skips "for each file, aggregate over all runs" — computing across files, not per file.**

Steps 5-6 read as per-file, but the actual compute is cross-file (mean across N runs). UC could confuse a future reader into thinking mean is per-file.

**Cure**: reword step 6 — "Across all parsed records, aggregator computes: per-test mean duration (grouped by test_name across records), per-test pass count / run count (same grouping)."

---

## Linus — adopter contract / stability

**L1 (HIGH). Adding a vitest reporter changes the observable `npm test` output for anyone with tooling that reads vitest stdout.**

The `default` reporter output stays the same. But `reporters: ['default', 'json']` adds a JSON blob on stderr (or wherever vitest sends it) that could confuse a CI grep or a git hook that parses `npm test` output.

**Cure**: verify vitest 2.0.0 with `reporters: ['default', 'json']` writes JSON ONLY to `outputFile`, NOT to stdout/stderr. Capture the run output pre-fold to confirm. If JSON does leak to stdout, use `reporters: [['default', { summary: true }], ['json', { outputFile: '...' }]]` explicit form.

**L2 (MEDIUM). `state/events/test-runs/` directory creation happens implicitly on first vitest run. First run's error message if directory perms fail will surface as a vitest failure, not a friendly cli message.**

Adopters (or maintainer on a locked-down machine) hit `EACCES` on state/events/test-runs/. Vitest reports the failure in its own words; the fix path is unclear.

**Cure**: `scripts/aggregate-test-runs.sh` also handles setup — first run creates the dir with a friendly message if `mkdir -p` fails. OR document in the runbook that vitest handles directory creation and points at the vitest error for perms failures. Second option is smaller.

**L3 (MEDIUM). Bumping vitest version in future breaks the observable contract that `npm test` writes to `state/events/test-runs/`.**

Some future PR bumps vitest from 2.0 → 3.0. If 3.0 changes the reporter config API (e.g., renames `outputFile`), `npm test` silently stops writing records. `npm test:report` silently reports empty state. No signal.

**Cure**: Tier 0 test (unit-level) verifies vitest config has `reporters: ['default', 'json']` with `outputFile` matching pattern. If someone bumps vitest and the config doesn't match, the test breaks. Signal preserved.

---

## Vernon — anticorruption layer (DDD)

**V1 (HIGH). Aggregator IS the anticorruption layer between vitest's evolving domain and cli's stable reporting domain — but the boundary is not explicit.**

The BCE split treats Boundary as argv/output. The REAL boundary is: aggregator translates from "vitest's JSON reporter output shape" (upstream, changes across versions) to "cli's per-test aggregate view" (our stable domain). Nothing names this translation. Future vitest upgrade will break the aggregator's Control layer directly.

**Cure**: introduce a translation step — a `parse_vitest_record(file) -> CanonicalRecord` function. `CanonicalRecord` is `{tests: [{name, status, duration_ms}], run_timestamp}`. Control operates on `CanonicalRecord`, never on raw vitest JSON. Vitest 3.0 changes → only `parse_vitest_record` needs a new branch. Rest of Control unaffected.

**V2 (MEDIUM). No versioning of vitest shape assumed.**

Aggregator uses jq expressions that assume vitest 2.0.0's specific JSON keys (`testResults`, `status`, `duration`). No note in the code says "vitest 2.0.x shape assumed". Silent drift on upgrade.

**Cure**: `parse_vitest_record` (per V1) starts with a version detection — checks for a known-2.0.0-only field, warns if absent. Documents the assumption inline.

**V3 (LOW). `state/events/test-runs/` naming implies future eventing infrastructure.**

The directory name suggests a shared eventing pattern (`state/events/deploy-runs/`, `state/events/adopter-outcomes/`). Fine as long as siblings share the same "immutable JSON per event" shape. Vernon would ask if that shape is contracted anywhere.

**Cure**: informal — spec's Contract section names the pattern. If sibling directories land in #170 or #171, they inherit. No action this session.

---

## Ranked findings

### HIGH (fold before code ships)

- **F1** — capture real vitest JSON from full 433-test suite, not a trivial one, as fixture template.
- **L1** — verify vitest 2.0.0 with `['default', 'json']` writes JSON only to outputFile, not to stdout/stderr. Capture pre-fold.
- **V1** — introduce `parse_vitest_record(file) -> CanonicalRecord` translation function. Control operates on CanonicalRecord, never on raw vitest JSON.

### MEDIUM (fold at test-write time)

- **P1** — Boundary reads files into canonical shape before passing to Control. (Composes with V1.)
- **P3** — `--json` output includes `"schema_version": 1`. Test verifies.
- **F2** — golden-file test for shipped text output. One fixture → one expected output file. Byte-compare.
- **C1** — UC extension 5b: partial-record handling; aggregator counts records-with-status, warns if less than total.
- **C2** — `jq` check at Boundary entry, exits 1 immediately if missing.
- **L2** — runbook documents directory creation; vitest handles perms failures with its own error.
- **L3** — Tier 0 test verifies vitest config has expected reporters shape.
- **V2** — `parse_vitest_record` checks for a known-2.0.0-only field; warns on absence.

### LOW (accept + document)

- **P2** — pin lib path relative to `${BASH_SOURCE[0]}`. Standard bash idiom.
- **F3** — integration test optional if F1 lands (functionally similar).
- **C3** — reword UC step 6 to clarify cross-file computation.
- **V3** — no session action; note pattern in spec.

## Design edits from folds (extends pre-mortem folds)

1. **Decomposition — new module** — `scripts/lib/aggregate-test-runs.sh` gains a `parse_vitest_record(file)` function returning canonical shape. Control functions accept CanonicalRecord input, not file paths (per P1 + V1).
2. **Test-list amendment** — add:
   - `[ ]` `parse_vitest_record` returns canonical shape for valid vitest 2.0.0 input
   - `[ ]` `parse_vitest_record` warns on vitest 3.x shape (missing known-2.0.0 field)
   - `[ ]` `parse_vitest_record` handles partial records (missing status field on entry) with WARN
   - `[ ]` `--json` output includes `schema_version: 1` field
   - `[ ]` Golden-file: single-run fixture → expected text output byte-match
   - `[ ]` Tier 0 test greps `vitest.config.ts` for `['default', 'json']` and `outputFile`
3. **Spec — Failure modes section** — extend with:
   - "Partial vitest record (missing status field on one entry): counted only if status present; WARN on stderr with count of skipped entries."
4. **UC amendments** — extension 5b (partial record); Step 6 rewording.
5. **Runbook (post-code)** — one line documenting vitest handles `state/events/test-runs/` directory creation; if perms fail, vitest's own error message applies.

## Consequences of folding

- Aggregator gains one more function (`parse_vitest_record`). +5-10 lines.
- Tier 0 test count 13 → 19 (six new). +30-45 turns for tests.
- Golden-file fixture adds one new file. +10 turns.
- Total scope: +50-70 turns on the #169 half. Push my #169 estimate from 60-100 → 90-160.

## Consequences of NOT folding

- V1 skipped: first vitest 3.0 bump breaks aggregator silently. Debug cost ~20 turns.
- F1 skipped: first real `npm test` reveals shape misses in fixtures. Fix cost ~15 turns + potential test-scope reshape.
- L1 skipped: unknown risk to `npm test` grep-tooling. Adopter surface changes silently.

Folding is cheaper than defending against these three post-ship.

## Council closing

All 5 lenses converge on one theme — the aggregator's biggest risk is drift with vitest's evolving output. Vernon's anticorruption layer + Feathers' characterization + Linus's contract stability all point at the same cure: an explicit translation function pinned by a real-shape capture and a shape-version test.

Adopting all HIGH cures + all MEDIUM cures. Documenting all LOW findings for future us.
