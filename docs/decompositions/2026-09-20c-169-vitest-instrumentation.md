---
tier: project
title: Decomposition — cli#169 vitest test-run history
id: 2026-09-20c-169-vitest-instrumentation
authored: 2026-09-20
parent_ticket: sunj-labs/bassclef-cli#169
spec: docs/specs/spec-169-test-run-history.md
uc: docs/use-cases/UC-script-169-aggregate-test-runs.md
authoring_luminaries:
  primary:
    - kent-beck
  supporting:
    - michael-nygard
    - andreas-zeller
---

# Decomposition — cli#169 vitest test-run history

## Sources read

- `docs/specs/spec-169-test-run-history.md` — the shipped contract; drives entity + interface split
- `docs/use-cases/UC-script-169-aggregate-test-runs.md` — the main success scenario + extensions; drives failure paths
- `vitest.config.ts` (this repo) — current shape; the reporter addition slots into the `test:` block
- `package.json` (this repo) — current scripts block; `test:report` slot is free
- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD on scripts/*.sh in bassclef substrate

## Domain entities (nouns)

- **TestRunRecord** — one JSON file written by vitest's JSON reporter per `npm test` invocation.
- **TestResultsArray** — the `testResults` field of a vitest run record.
- **PerTestDuration** — pair `(test_name, duration_ms)` from a single run.
- **PerTestPassStatus** — pair `(test_name, boolean)` from a single run.
- **DurationHistogram** — sorted list of `(test_name, mean_duration_ms)` across N runs.
- **FlakeList** — sorted list of `(test_name, pass_rate)` where pass_rate < 100%.
- **AggregationSummary** — the shipped output; text or JSON per flag.
- **RunsDirectory** — filesystem path `state/events/test-runs/` where records live.

## Actors

- **Maintainer** — invokes `npm run test:report`.
- **Vitest** — writes the JSON records (external actor; we configure it via reporter).
- **Aggregator script** — reads records, computes summary, writes output.

## BCE classification (Jacobson)

- **Boundary** — the aggregator's argv parser + stdout/stderr writer. Isolates external presentation.
- **Control** — the aggregation logic: file enumeration, N-cap, jq parsing loop, mean + pass-rate computation.
- **Entity** — TestRunRecord (immutable JSON on disk; we do not write it, we read it).

## Components + files

| File | Role | New? |
|---|---|---|
| `vitest.config.ts` | Adds `reporters: ['default', 'json']` + `outputFile` under `test:` block | edit |
| `scripts/aggregate-test-runs.sh` | The aggregator entry point | new |
| `scripts/lib/aggregate-test-runs.sh` | Reusable parse + compute functions (BCE Control separated for testability) | new |
| `scripts/tests/aggregate-test-runs.test.sh` | Tier 0 tests for the aggregator | new |
| `scripts/tests/fixtures/aggregate-test-runs/` | Fixture JSON files simulating vitest output | new dir |
| `package.json` | Adds `"test:report": "bash scripts/aggregate-test-runs.sh"` script | edit |
| `.gitignore` | Adds `state/events/test-runs/` | edit |

## Interface between Boundary and Control (RFC-0006 folds applied)

Per RFC-0006 V1 + P1 + V2, the boundary between vitest's evolving JSON and cli's stable aggregate view is explicit — a `parse_vitest_record` function acts as the anticorruption layer (Vernon). Boundary reads files into `CanonicalRecord` shape before passing to Control (Parnas).

```bash
# In scripts/aggregate-test-runs.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/aggregate-test-runs.sh"

# Boundary: check preconditions (Cockburn C2 fold)
command -v jq >/dev/null 2>&1 || {
  echo "MISSING: jq required. Install with brew install jq." >&2
  exit 1
}

# Parse args
LAST_N=20
FORMAT="text"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --last) LAST_N="$2"; shift 2 ;;
    --json) FORMAT="json"; shift ;;
    *) echo "USAGE: aggregate-test-runs.sh [--last N] [--json]" >&2; exit 2 ;;
  esac
done

# Boundary: enumerate + canonicalize (Parnas P1 + Vernon V1)
FILES=$(enumerate_run_files "$RUNS_DIR" "$LAST_N")
CANONICAL_RECORDS=()
for f in $FILES; do
  # parse_vitest_record returns CanonicalRecord JSON or empty on parse fail
  record=$(parse_vitest_record "$f" 2>>/dev/stderr) && CANONICAL_RECORDS+=("$record")
done

# Delegate to Control on CanonicalRecords, never raw vitest JSON
HISTOGRAM=$(compute_duration_histogram "${CANONICAL_RECORDS[@]}")
FLAKE=$(compute_flake_list "${CANONICAL_RECORDS[@]}")

# Boundary formats output
if [[ "$FORMAT" == "json" ]]; then
  render_json "$HISTOGRAM" "$FLAKE"  # includes schema_version: 1 per P3
else
  render_text "$HISTOGRAM" "$FLAKE"
fi
```

**CanonicalRecord shape** (Vernon anticorruption boundary):

```json
{
  "run_timestamp": "2026-09-20T14-30-00-123",
  "tests": [
    {"name": "path/to/test.ts > describe > it", "status": "pass", "duration_ms": 42}
  ]
}
```

Vitest 2.0.x → CanonicalRecord translation lives in `parse_vitest_record`. Vitest 3.x lands, `parse_vitest_record` grows a new branch. Control never changes.

Test file exercises Control functions directly via `source` + call using synthetic CanonicalRecords. Boundary + parse_vitest_record exercised via subshell invocation with fixture files.

## Failure paths

| Precondition violation | Where handled | Exit code |
|---|---|---|
| `jq` missing | Boundary — early check | 1 |
| RunsDirectory absent | Control — `enumerate_run_files` returns empty; Boundary prints friendly message | 0 |
| Individual JSON malformed | Control — `parse_run_file` catches jq error, warns on stderr, skips | continue |
| ALL JSON malformed | Control — reports count-of-valid=0; Boundary exits with error | 2 |
| Invalid `--last` value (non-integer) | Boundary — argv parser catches | 2 |

## Test-list (Tier 0 per .claude/rules/test-sufficiency.md; RFC-0006 folds appended)

```bash
# test-list: aggregate-test-runs.sh
# --- Original 13 (Step 0 decomposition) ---
# [ ] empty state (RunsDirectory absent) — prints friendly message, exits 0
# [ ] empty state (RunsDirectory present but no *.json files) — same
# [ ] single run — duration histogram lists every test; flake list empty (all pass)
# [ ] single run with 1 fail — flake list shows that test at pass_rate 0.0
# [ ] multi-run (3 runs, 1 flaky test) — flake list shows pass_rate = 2/3
# [ ] --last N caps working set correctly (5 files, --last 3 → uses newest 3)
# [ ] --json flag emits machine-readable summary
# [ ] malformed JSON in one of many files — WARN on stderr, continues
# [ ] all JSON malformed — ERROR on stderr, exits 2
# [ ] missing jq — MISSING on stderr, exits 1
# [ ] duration histogram sorted desc; flake list sorted asc
# [ ] argv rejects invalid --last value
# [ ] argv rejects unknown flag
# --- RFC-0006 folds (6 new) ---
# [ ] parse_vitest_record returns canonical shape for valid vitest 2.0.0 input (V1)
# [ ] parse_vitest_record warns on vitest 3.x shape (missing known-2.0.0 field) (V2)
# [ ] parse_vitest_record handles partial records (missing status on one entry) with WARN, counts records-with-status (C1)
# [ ] --json output includes schema_version: 1 field (P3)
# [ ] golden-file: single-run fixture → expected text output byte-match (F2)
# [ ] Tier 0 test greps vitest.config.ts for ['default', 'json'] and outputFile (L3)
# [ ] .gitignore grep test verifies state/events/test-runs/ line present (N1)
# [ ] filename uses UTC ISO timestamp pattern YYYY-MM-DDTHH-MM-SS-mmm.json (Z4)
# [ ] test-never-in-record-window: pass_rate undefined, excluded from flake list (Z1)
```

**22 tests** (13 original + 9 fold — pre-mortem Z1/Z4/N1 already surfaced, RFC-0006 adds 6 more). Covers 4 exit codes, 8+ branches, argv-boundary + parse layer + control layer + golden-output, both JSON parse failure classes plus canonical-shape drift class.

## Pattern annotations

- `@pattern patterns/code/gof/strategy.md` — `--json` vs text output shape (two Strategy implementations behind one Boundary).
- `@pattern patterns/code/eip/aggregator.md` — Control layer is an Aggregator (fixed-in messages → composite view).

(If those catalog paths do not exist under `~/src/sunj-labs/bassclef/patterns/`, treat as informational — annotation ships regardless per pattern-annotation.md rule.)

## Sequencing (RED first; RFC-0006 F1 fold)

1. **Step A — Live vitest JSON capture** (RFC-0006 F1 + L1). Add a temporary reporters config to a scratch `vitest.config.ts.tmp`, run `npm test` against a minimal 2-test fixture (OR the full 433-test suite), capture the raw JSON to `scripts/tests/fixtures/aggregate-test-runs/live-capture-2026-09-20.json`. Also verify JSON does NOT leak to stdout/stderr (Linus L1). Delete tmp config.
2. **Step B — 22 Tier 0 tests RED**. Fixtures include: minimal 2-test capture, synthetic 3-run flaky suite, malformed JSON, partial-record fixture, vitest-3.x-shape fixture (all synthetic — do not use the live capture directly). Test-list block heads the test file.
3. **Step C — Write `scripts/lib/aggregate-test-runs.sh`**. `parse_vitest_record` first (Vernon V1). Then `enumerate_run_files`, `compute_duration_histogram`, `compute_flake_list`, `render_text`, `render_json`.
4. **Step D — Write `scripts/aggregate-test-runs.sh`** — Boundary. jq check first (Cockburn C2). Argv parse. Delegate. Render.
5. **Step E — Edit `vitest.config.ts`** to add `reporters: ['default', 'json']` + `outputFile`. Verify one live `npm test` run creates a real JSON in `state/events/test-runs/`.
6. **Step F — Edit `package.json` scripts** to add `test:report`. Verify `npm run test:report` invokes cleanly.
7. **Step G — Edit `.gitignore`** to add `state/events/test-runs/`. Verify Tier 0 test passes.
8. **Step H — Run full suite** (both new Tier 0 + all existing). GREEN.

## What this does NOT decompose

- Adopter telemetry (cli#171). Out of scope this goal.
- DORA metrics (cli#170). Out of scope this goal.
- Web UI. Out of scope.
- The 3 satellite PRs in the release cascade (#163, #167, #168). Their own PRs carry their own decompositions if needed.
