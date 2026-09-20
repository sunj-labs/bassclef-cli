#!/usr/bin/env bash
# tier: project
# scripts/lib/aggregate-test-runs.sh — Control lib for aggregate-test-runs
# Parent ticket: sunj-labs/bassclef-cli#169
# Design: docs/decompositions/2026-09-20c-169-vitest-instrumentation.md
# RFC folds: docs/rfcs/RFC-0006-cli-169-test-run-history-adversarial.md
#
# @pattern patterns/code/eip/aggregator.md
#
# Vernon anticorruption layer between vitest's evolving JSON reporter
# shape and cli's stable CanonicalRecord shape. Control operates on
# CanonicalRecords, never on raw vitest JSON.
#
# CanonicalRecord JSON shape (parse_vitest_record output):
#   {
#     "run_timestamp": "<derived from filename>",
#     "tests": [
#       {"name": "<fullName>", "status": "passed|failed|...", "duration_ms": <float>}
#     ]
#   }

set -uo pipefail

# parse_vitest_record <file_path>
#   Reads a vitest 2.0.0 JSON reporter output file, filters entries with a
#   status field (per RFC-0006 C1 fold), returns canonical shape on stdout.
#   Warns on stderr if:
#     - file is malformed (returns "" and skips)
#     - shape looks like vitest > 2.0 (missing testResults; per V2 fold)
#     - one or more entries missing status (per C1 fold)
parse_vitest_record() {
  local file="$1"

  # jq empty validates JSON without producing output
  if ! jq empty "$file" 2>/dev/null; then
    echo "WARN: $file is malformed; skipping." >&2
    return 0
  fi

  # RFC-0006 V2: check for vitest 2.0.0 shape marker
  local has_test_results
  has_test_results=$(jq 'has("testResults")' "$file" 2>/dev/null)
  if [[ "$has_test_results" != "true" ]]; then
    echo "WARN: $file may be from vitest > 2.0 — canonical parse may drop records." >&2
    # Continue with empty canonical shape rather than fail
    local run_ts
    run_ts=$(basename "$file" .json)
    jq -n --arg ts "$run_ts" '{run_timestamp: $ts, tests: []}'
    return 0
  fi

  # Count total entries vs entries with status (for C1 warn)
  local total_entries with_status_entries
  total_entries=$(jq '[.testResults[].assertionResults[]] | length' "$file" 2>/dev/null || echo 0)
  with_status_entries=$(jq '[.testResults[].assertionResults[] | select(.status)] | length' "$file" 2>/dev/null || echo 0)
  local missing_count=$((total_entries - with_status_entries))
  if [[ $missing_count -gt 0 ]]; then
    echo "WARN: $file has $missing_count records missing status; skipped." >&2
  fi

  # Emit canonical shape — filter select(.status)
  local run_ts
  run_ts=$(basename "$file" .json)
  jq --arg ts "$run_ts" '
    {
      run_timestamp: $ts,
      tests: [
        .testResults[].assertionResults[]
        | select(.status)
        | {
            name: .fullName,
            status: .status,
            duration_ms: (.duration // 0)
          }
      ]
    }
  ' "$file"
}

# enumerate_run_files <dir> <last_n>
#   Emits paths of newest N *.json files in dir, one per line.
#   Empty if dir absent or no files.
enumerate_run_files() {
  local dir="$1"
  local n="${2:-20}"
  [[ ! -d "$dir" ]] && return 0
  # Sort by filename descending (UTC ISO timestamps sort correctly)
  # Cap at N
  find "$dir" -maxdepth 1 -name '*.json' -type f 2>/dev/null \
    | sort -r \
    | head -n "$n"
}

# compute_duration_histogram <canonical_records_json...>
#   Input: one or more CanonicalRecord JSON strings as args.
#   Output: JSON array [{"test": "...", "mean_ms": ...}, ...] sorted desc, top 10.
compute_duration_histogram() {
  local records
  records=$(printf '%s\n' "$@" | jq -s '.')
  echo "$records" | jq '
    [.[] | .tests[]]
    | group_by(.name)
    | map({
        test: .[0].name,
        mean_ms: (map(.duration_ms) | add / length)
      })
    | sort_by(-.mean_ms)
    | .[0:10]
  '
}

# compute_flake_list <canonical_records_json...>
#   Input: one or more CanonicalRecord JSON strings as args.
#   Output: JSON array [{"test": "...", "pass_rate": ...}, ...] sorted asc pass_rate.
#   Only tests where pass_rate < 1.0 AND test appears at least once.
#   pass_rate = passes / (runs containing this test), not / total runs.
compute_flake_list() {
  local records
  records=$(printf '%s\n' "$@" | jq -s '.')
  echo "$records" | jq '
    [.[] | .tests[]]
    | group_by(.name)
    | map({
        test: .[0].name,
        pass_rate: (
          (map(select(.status == "passed")) | length) as $p
          | (. | length) as $n
          | ($p / $n * 100 | round / 100)
        )
      })
    | map(select(.pass_rate < 1.0))
    | sort_by(.pass_rate)
  '
}

# render_text <duration_json> <flake_json> <runs_count>
#   Emits human-readable text output.
render_text() {
  local dur="$1" flake="$2" n="$3"
  local run_word="runs"
  [[ "$n" == "1" ]] && run_word="run"

  echo "## Duration — top 10 slowest tests (across $n $run_word)"
  echo ""
  local dur_lines
  dur_lines=$(echo "$dur" | jq -r '.[] | "\(.mean_ms | . * 100 | round / 100 | tostring)|\(.test)"')
  if [[ -z "$dur_lines" ]]; then
    echo "  (no duration data)"
  else
    while IFS='|' read -r ms name; do
      # format ms to 2 decimals right-aligned in 8 chars
      printf "  %6.2f ms  %s\n" "$ms" "$name"
    done <<< "$dur_lines"
  fi

  echo ""
  echo "## Flake — tests with < 100% pass rate (across $n $run_word)"
  echo ""
  local flake_lines
  flake_lines=$(echo "$flake" | jq -r '.[] | "\(.pass_rate | . * 100 | round / 100 | tostring)|\(.test)"')
  if [[ -z "$flake_lines" ]]; then
    echo "  (no flaky tests found)"
  else
    while IFS='|' read -r rate name; do
      printf "  %4.2f  %s\n" "$rate" "$name"
    done <<< "$flake_lines"
  fi
}

# render_json <duration_json> <flake_json> <runs_count>
#   Emits machine-readable JSON summary including schema_version (P3 fold).
render_json() {
  local dur="$1" flake="$2" n="$3"
  local ts
  ts=$(date -u +%FT%TZ)
  jq -n \
    --argjson dur "$dur" \
    --argjson flake "$flake" \
    --arg ts "$ts" \
    --argjson n "$n" \
    '{
      schema_version: 1,
      generated_at: $ts,
      runs_read: $n,
      duration: $dur,
      flake: $flake
    }'
}
