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

## Interface between Boundary and Control

Boundary (entry script) calls Control (lib) via:

```bash
# In scripts/aggregate-test-runs.sh
source "$SCRIPT_DIR/lib/aggregate-test-runs.sh"

# Parse args (Boundary responsibility)
LAST_N=20
FORMAT="text"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --last) LAST_N="$2"; shift 2 ;;
    --json) FORMAT="json"; shift ;;
    *) echo "USAGE: aggregate-test-runs.sh [--last N] [--json]" >&2; exit 2 ;;
  esac
done

# Delegate to Control
enumerate_run_files "$RUNS_DIR" "$LAST_N"  # emits paths, one per line
compute_duration_histogram "${FILES[@]}"    # emits (test, mean_ms) lines
compute_flake_list "${FILES[@]}"            # emits (test, pass_rate) lines

# Boundary formats output
if [[ "$FORMAT" == "json" ]]; then
  render_json ...
else
  render_text ...
fi
```

Test file exercises Control functions directly via `source` + call. Boundary is exercised via subshell invocation with argv.

## Failure paths

| Precondition violation | Where handled | Exit code |
|---|---|---|
| `jq` missing | Boundary — early check | 1 |
| RunsDirectory absent | Control — `enumerate_run_files` returns empty; Boundary prints friendly message | 0 |
| Individual JSON malformed | Control — `parse_run_file` catches jq error, warns on stderr, skips | continue |
| ALL JSON malformed | Control — reports count-of-valid=0; Boundary exits with error | 2 |
| Invalid `--last` value (non-integer) | Boundary — argv parser catches | 2 |

## Test-list (Tier 0 per .claude/rules/test-sufficiency.md)

```bash
# test-list: aggregate-test-runs.sh
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
```

13 tests. Covers 4 exit codes, 8 branches, argv-boundary + control layers, both JSON parse failure classes.

## Pattern annotations

- `@pattern patterns/code/gof/strategy.md` — `--json` vs text output shape (two Strategy implementations behind one Boundary).
- `@pattern patterns/code/eip/aggregator.md` — Control layer is an Aggregator (fixed-in messages → composite view).

(If those catalog paths do not exist under `~/src/sunj-labs/bassclef/patterns/`, treat as informational — annotation ships regardless per pattern-annotation.md rule.)

## Sequencing (RED first)

1. Write 13 Tier 0 tests referring to fixtures — RED.
2. Write `scripts/lib/aggregate-test-runs.sh` Control functions to satisfy per-function tests.
3. Write `scripts/aggregate-test-runs.sh` Boundary — argv parse + delegate + render.
4. Edit `vitest.config.ts` to add reporters. Verify one live run creates a JSON.
5. Edit `package.json` scripts to add `test:report`. Verify `npm run test:report` invokes cleanly.
6. Edit `.gitignore` to add `state/events/test-runs/`.
7. Run full suite. GREEN.

## What this does NOT decompose

- Adopter telemetry (cli#171). Out of scope this goal.
- DORA metrics (cli#170). Out of scope this goal.
- Web UI. Out of scope.
- The 3 satellite PRs in the release cascade (#163, #167, #168). Their own PRs carry their own decompositions if needed.
