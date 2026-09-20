#!/usr/bin/env bash
# tier: project
# scripts/aggregate-test-runs.sh — Boundary for aggregate-test-runs
# Parent ticket: sunj-labs/bassclef-cli#169
# Design: docs/decompositions/2026-09-20c-169-vitest-instrumentation.md
# RFC folds: docs/rfcs/RFC-0006-cli-169-test-run-history-adversarial.md
#
# @pattern patterns/code/gof/strategy.md (text vs json output shape)
#
# Reads vitest JSON reporter records from state/events/test-runs/,
# aggregates via lib, emits summary (text or JSON via --json).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Boundary: Cockburn C2 fold — check jq FIRST
if ! command -v jq >/dev/null 2>&1; then
  echo "MISSING: jq required. Install with brew install jq." >&2
  exit 1
fi

source "$SCRIPT_DIR/lib/aggregate-test-runs.sh"

# Argv parse
LAST_N=20
FORMAT="text"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --last)
      LAST_N="${2:-}"
      if ! [[ "$LAST_N" =~ ^[0-9]+$ ]]; then
        echo "USAGE: aggregate-test-runs.sh [--last N] [--json]" >&2
        echo "  --last requires a positive integer" >&2
        exit 2
      fi
      shift 2
      ;;
    --json)
      FORMAT="json"
      shift
      ;;
    -h|--help)
      cat << EOF
USAGE: aggregate-test-runs.sh [--last N] [--json]

Aggregates vitest test-run history from state/events/test-runs/*.json.

Options:
  --last N   Cap the working set at newest N run files (default: 20)
  --json     Emit machine-readable JSON instead of text

Prints duration histogram (top 10 slowest tests) and flake list
(tests below 100% pass rate).
EOF
      exit 0
      ;;
    *)
      echo "USAGE: aggregate-test-runs.sh [--last N] [--json]" >&2
      echo "  unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# Locate runs dir — allow test override
RUNS_DIR="${BASSCLEF_TEST_RUNS_DIR:-$REPO_ROOT/state/events/test-runs}"

# Enumerate files
FILES=()
while IFS= read -r f; do
  [[ -n "$f" ]] && FILES+=("$f")
done < <(enumerate_run_files "$RUNS_DIR" "$LAST_N")

# Empty state check
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No test runs recorded in $RUNS_DIR. Run 'npm test' first."
  exit 0
fi

# Parse each file into a CanonicalRecord (Vernon V1)
RECORDS=()
PARSE_FAILURES=0
TOTAL_FILES="${#FILES[@]}"
for f in "${FILES[@]}"; do
  rec=$(parse_vitest_record "$f")
  if [[ -z "$rec" ]]; then
    PARSE_FAILURES=$((PARSE_FAILURES + 1))
  else
    # Also filter out records with empty tests array (e.g., malformed after jq empty passed)
    tcount=$(echo "$rec" | jq '.tests | length' 2>/dev/null || echo 0)
    if [[ "$tcount" -eq 0 ]]; then
      # Record has no tests — either malformed input (already warned) or an
      # empty run. Include so runs_read count matches actual files parsed.
      RECORDS+=("$rec")
    else
      RECORDS+=("$rec")
    fi
  fi
done

# Check: all files were malformed (T09)
if [[ ${#RECORDS[@]} -eq 0 ]]; then
  echo "ERROR: no valid test-run records found." >&2
  exit 2
fi

# Delegate to Control
HISTOGRAM=$(compute_duration_histogram "${RECORDS[@]}")
FLAKE=$(compute_flake_list "${RECORDS[@]}")

# Render
if [[ "$FORMAT" == "json" ]]; then
  render_json "$HISTOGRAM" "$FLAKE" "${#RECORDS[@]}"
else
  render_text "$HISTOGRAM" "$FLAKE" "${#RECORDS[@]}"
fi

exit 0
