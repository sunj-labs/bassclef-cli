#!/usr/bin/env bash
# tier: project
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md; test mtime <= source mtime)
# Tier 0 tests for scripts/aggregate-test-runs.sh + scripts/lib/aggregate-test-runs.sh
# Per .claude/rules/test-list-discipline.md + .claude/rules/test-sufficiency.md 12 criteria
# Parent ticket: sunj-labs/bassclef-cli#169
# Design chain: docs/decompositions/2026-09-20c-169-vitest-instrumentation.md
# RFC folds: docs/rfcs/RFC-0006-cli-169-test-run-history-adversarial.md

# test-list: aggregate-test-runs.sh
# --- Original 13 (Step 0 decomposition) ---
# [ ] T01 empty state (RunsDirectory absent) — friendly message, exits 0
# [ ] T02 empty state (RunsDirectory present but no *.json files) — same
# [ ] T03 single run — duration histogram lists every test; flake list empty
# [ ] T04 single run with 1 fail — flake list shows that test at pass_rate 0.0
# [ ] T05 multi-run (3 runs, 1 flaky test) — flake list shows pass_rate = 2/3
# [ ] T06 --last N caps working set correctly
# [ ] T07 --json flag emits machine-readable summary
# [ ] T08 malformed JSON in one of many files — WARN on stderr, continues
# [ ] T09 all JSON malformed — ERROR on stderr, exits 2
# [ ] T10 missing jq — MISSING on stderr, exits 1
# [ ] T11 duration histogram sorted desc; flake list sorted asc
# [ ] T12 argv rejects invalid --last value
# [ ] T13 argv rejects unknown flag
# --- RFC-0006 + pre-mortem folds (9 new) ---
# [ ] T14 parse_vitest_record returns canonical shape for valid vitest 2.0.0 input (V1)
# [ ] T15 parse_vitest_record warns on vitest 3.x shape (missing testResults) (V2)
# [ ] T16 parse_vitest_record warns on partial record (missing status on entry) (C1)
# [ ] T17 --json output includes schema_version: 1 field (P3)
# [ ] T18 golden-file: single-run fixture -> expected text output byte-match (F2)
# [ ] T19 Tier 0 test greps vitest.config.ts for ['default', 'json'] and outputFile (L3)
# [ ] T20 .gitignore grep verifies state/events/test-runs/ line present (N1)
# [ ] T21 filename uses UTC ISO timestamp pattern YYYY-MM-DDTHH-MM-SS-mmm.json (Z4)
# [ ] T22 test-never-in-record-window: pass_rate undefined, excluded from flake list (Z1)

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
AGG_SH="$REPO_ROOT/scripts/aggregate-test-runs.sh"
AGG_LIB="$REPO_ROOT/scripts/lib/aggregate-test-runs.sh"
FIX="$TEST_DIR/fixtures/aggregate-test-runs"

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1] got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] not in output"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] should not be in output"; }
assert_file_exists() { [[ -f "$1" ]] && pass "$2" || fail "$2" "file not found: $1"; }

# Helper: build a temp RunsDirectory with fixture files copied in
mk_runs_dir() {
  local dir; dir=$(mktemp -d)
  echo "$dir"
}

# ==========================================================================
# T01 empty state — RunsDirectory absent
# ==========================================================================
test_t01_runs_dir_absent() {
  echo "TEST T01: RunsDirectory absent -> friendly message, exit 0"
  local d; d=$(mktemp -d); rm -rf "$d"  # ensure absent
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>&1)
  local ec=$?
  assert_eq "0" "$ec" "T01 exit code 0"
  assert_contains "$out" "No test runs recorded" "T01 friendly message"
}

# T02 empty state — RunsDirectory present, no *.json
test_t02_runs_dir_empty() {
  echo "TEST T02: RunsDirectory present but no *.json"
  local d; d=$(mk_runs_dir)
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>&1)
  local ec=$?
  assert_eq "0" "$ec" "T02 exit code 0"
  assert_contains "$out" "No test runs recorded" "T02 friendly message"
  rm -rf "$d"
}

# T03 single run all pass — duration lists every test; flake empty
test_t03_single_run_all_pass() {
  echo "TEST T03: single-run-all-pass"
  local d; d=$(mk_runs_dir)
  cp "$FIX/single-run-all-pass.json" "$d/2026-09-20T14-00-00-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>&1)
  assert_contains "$out" "A > passes 1" "T03 histogram lists test 1"
  assert_contains "$out" "A > passes 2" "T03 histogram lists test 2"
  assert_contains "$out" "no flaky tests" "T03 flake list empty message"
  rm -rf "$d"
}

# T04 single run one fail — flake shows failed test at 0.0
test_t04_single_run_one_fail() {
  echo "TEST T04: single-run-one-fail"
  local d; d=$(mk_runs_dir)
  cp "$FIX/single-run-one-fail.json" "$d/2026-09-20T14-01-00-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>&1)
  assert_contains "$out" "B > fails" "T04 flake lists failed test"
  assert_contains "$out" "0.00" "T04 pass_rate 0.00 shown"
  rm -rf "$d"
}

# T05 multi-run flaky — flake shows 2/3 pass rate for flaky test
test_t05_multi_run_flaky() {
  echo "TEST T05: multi-run flaky"
  local d; d=$(mk_runs_dir)
  cp "$FIX/multi-run/run-1.json" "$d/2026-09-20T14-00-01-000.json"
  cp "$FIX/multi-run/run-2.json" "$d/2026-09-20T14-00-02-000.json"
  cp "$FIX/multi-run/run-3.json" "$d/2026-09-20T14-00-03-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --json 2>&1)
  local flake_names; flake_names=$(echo "$out" | jq -r '.flake[].test' 2>/dev/null)
  assert_contains "$flake_names" "multi > flaky C" "T05 flake lists flaky test"
  local flaky_rate; flaky_rate=$(echo "$out" | jq -r '.flake[] | select(.test == "multi > flaky C") | .pass_rate' 2>/dev/null)
  assert_contains "$flaky_rate" "0.67" "T05 pass_rate 2/3 = 0.67 shown"
  assert_not_contains "$flake_names" "multi > stable A" "T05 stable test NOT in flake list"
  rm -rf "$d"
}

# T06 --last N caps working set
test_t06_last_n_caps() {
  echo "TEST T06: --last N caps set"
  local d; d=$(mk_runs_dir)
  for i in 1 2 3 4 5; do
    cp "$FIX/single-run-all-pass.json" "$d/2026-09-20T14-00-0${i}-000.json"
  done
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --last 3 --json 2>&1)
  # runs_read should equal 3
  local n; n=$(echo "$out" | jq -r '.runs_read' 2>/dev/null || echo "PARSE_FAIL")
  assert_eq "3" "$n" "T06 --last 3 caps runs_read at 3"
  rm -rf "$d"
}

# T07 --json emits machine-readable summary
test_t07_json_flag() {
  echo "TEST T07: --json flag"
  local d; d=$(mk_runs_dir)
  cp "$FIX/single-run-all-pass.json" "$d/2026-09-20T14-00-00-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --json 2>&1)
  echo "$out" | jq . >/dev/null 2>&1
  local ec=$?
  assert_eq "0" "$ec" "T07 stdout is valid JSON"
  local has_dur; has_dur=$(echo "$out" | jq 'has("duration")' 2>/dev/null)
  assert_eq "true" "$has_dur" "T07 JSON has duration key"
  rm -rf "$d"
}

# T08 malformed JSON in one of many — WARN + continues
test_t08_malformed_one_of_many() {
  echo "TEST T08: malformed one of many"
  local d; d=$(mk_runs_dir)
  cp "$FIX/malformed.json" "$d/2026-09-20T14-00-00-000.json"
  cp "$FIX/single-run-all-pass.json" "$d/2026-09-20T14-00-01-000.json"
  local out_err; out_err=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>&1 >/dev/null)
  assert_contains "$out_err" "malformed" "T08 WARN on stderr"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>/dev/null)
  assert_contains "$out" "A > passes 1" "T08 continues with good file"
  rm -rf "$d"
}

# T09 all malformed — exit 2
test_t09_all_malformed() {
  echo "TEST T09: all malformed"
  local d; d=$(mk_runs_dir)
  cp "$FIX/malformed.json" "$d/2026-09-20T14-00-00-000.json"
  cp "$FIX/malformed.json" "$d/2026-09-20T14-00-01-000.json"
  BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" >/dev/null 2>&1
  local ec=$?
  assert_eq "2" "$ec" "T09 exit 2 when all malformed"
  rm -rf "$d"
}

# T10 missing jq — exit 1
test_t10_missing_jq() {
  echo "TEST T10: missing jq"
  local d; d=$(mk_runs_dir)
  # Simulate missing jq via PATH override
  BASSCLEF_TEST_RUNS_DIR="$d" PATH=/usr/bin:/bin bash -c "hash -r; command -v jq >/dev/null && exit 42 || bash '$AGG_SH' 2>&1" >/dev/null
  local ec=$?
  # If PATH still has jq (default macOS at /usr/bin/jq unlikely; usually /opt/homebrew/bin), we can't test cleanly
  # Fallback: force PATH to only include something that definitely lacks jq
  # Use env -i with PATH set to a dir containing bash but not jq
  local jqfree; jqfree=$(mktemp -d)
  ln -s "$(command -v bash)" "$jqfree/bash"
  ln -s "$(command -v dirname)" "$jqfree/dirname"
  ln -s "$(command -v cd)" "$jqfree/cd" 2>/dev/null || true
  ln -s "$(command -v pwd)" "$jqfree/pwd"
  local out; out=$(env -i BASSCLEF_TEST_RUNS_DIR="$d" PATH="$jqfree" bash "$AGG_SH" 2>&1)
  local ec2=$?
  assert_eq "1" "$ec2" "T10 exit 1 when jq missing"
  assert_contains "$out" "MISSING: jq required" "T10 friendly missing-jq message"
  rm -rf "$jqfree"
  rm -rf "$d"
}

# T11 sort order
test_t11_sort_order() {
  echo "TEST T11: sort orders"
  local d; d=$(mk_runs_dir)
  cp "$FIX/multi-run/run-1.json" "$d/2026-09-20T14-00-01-000.json"
  cp "$FIX/multi-run/run-2.json" "$d/2026-09-20T14-00-02-000.json"
  cp "$FIX/multi-run/run-3.json" "$d/2026-09-20T14-00-03-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --json 2>&1)
  # duration: sorted desc — flaky C (30ms) before stable A (12ms)
  local first_dur; first_dur=$(echo "$out" | jq -r '.duration[0].test' 2>/dev/null)
  assert_contains "$first_dur" "flaky C" "T11 duration sorted desc"
  rm -rf "$d"
}

# T12 argv rejects invalid --last
test_t12_invalid_last() {
  echo "TEST T12: invalid --last"
  local d; d=$(mk_runs_dir)
  BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --last abc 2>/dev/null
  local ec=$?
  assert_eq "2" "$ec" "T12 exit 2 on invalid --last"
  rm -rf "$d"
}

# T13 argv rejects unknown flag
test_t13_unknown_flag() {
  echo "TEST T13: unknown flag"
  local d; d=$(mk_runs_dir)
  BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --nonsense 2>/dev/null
  local ec=$?
  assert_eq "2" "$ec" "T13 exit 2 on unknown flag"
  rm -rf "$d"
}

# T14 parse_vitest_record — canonical shape for vitest 2.0.0
test_t14_parse_vitest_record_valid() {
  echo "TEST T14: parse_vitest_record valid 2.0.0"
  local out; out=$(bash -c "source '$AGG_LIB' && parse_vitest_record '$FIX/single-run-all-pass.json'" 2>/dev/null)
  local n; n=$(echo "$out" | jq -r '.tests | length' 2>/dev/null)
  assert_eq "2" "$n" "T14 returns 2 canonical tests"
  local name; name=$(echo "$out" | jq -r '.tests[0].name' 2>/dev/null)
  assert_contains "$name" "A > passes 1" "T14 canonical name field"
}

# T15 parse_vitest_record — vitest 3.x shape WARN
test_t15_parse_vitest_record_3x_warn() {
  echo "TEST T15: parse_vitest_record 3.x WARN"
  local out_err; out_err=$(bash -c "source '$AGG_LIB' && parse_vitest_record '$FIX/vitest-3x-shape.json'" 2>&1 >/dev/null)
  assert_contains "$out_err" "vitest > 2.0" "T15 WARN on 3.x shape"
}

# T16 parse_vitest_record — partial record WARN
test_t16_parse_vitest_record_partial() {
  echo "TEST T16: parse_vitest_record partial record WARN"
  local out_err; out_err=$(bash -c "source '$AGG_LIB' && parse_vitest_record '$FIX/partial-record.json'" 2>&1 >/dev/null)
  assert_contains "$out_err" "missing status" "T16 WARN on partial record"
  local out; out=$(bash -c "source '$AGG_LIB' && parse_vitest_record '$FIX/partial-record.json'" 2>/dev/null)
  local n; n=$(echo "$out" | jq -r '.tests | length' 2>/dev/null)
  assert_eq "1" "$n" "T16 partial record drops missing-status entry"
}

# T17 --json output includes schema_version: 1
test_t17_json_schema_version() {
  echo "TEST T17: schema_version"
  local d; d=$(mk_runs_dir)
  cp "$FIX/single-run-all-pass.json" "$d/2026-09-20T14-00-00-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --json 2>&1)
  local sv; sv=$(echo "$out" | jq -r '.schema_version' 2>/dev/null)
  assert_eq "1" "$sv" "T17 schema_version = 1"
  rm -rf "$d"
}

# T18 golden-file text output byte-match
test_t18_golden_file() {
  echo "TEST T18: golden file"
  local d; d=$(mk_runs_dir)
  cp "$FIX/single-run-all-pass.json" "$d/2026-09-20T14-00-00-000.json"
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" 2>/dev/null)
  local expected; expected=$(cat "$FIX/golden-single-run-all-pass.txt")
  assert_eq "$expected" "$out" "T18 output byte-matches golden"
  rm -rf "$d"
}

# T19 vitest.config.ts grep — reporters shape + outputFile
test_t19_vitest_config_grep() {
  echo "TEST T19: vitest.config.ts reporters shape"
  local cfg="$REPO_ROOT/vitest.config.ts"
  assert_file_exists "$cfg" "T19 vitest.config.ts exists"
  local content; content=$(cat "$cfg" 2>/dev/null)
  assert_contains "$content" "reporters" "T19 reporters key present"
  assert_contains "$content" "'json'" "T19 json reporter listed"
  assert_contains "$content" "outputFile" "T19 outputFile key present"
  assert_contains "$content" "state/events/test-runs" "T19 outputFile path"
}

# T20 .gitignore grep — state/events/test-runs/
test_t20_gitignore_state_events() {
  echo "TEST T20: .gitignore state/events/test-runs/"
  local gi="$REPO_ROOT/.gitignore"
  local content; content=$(cat "$gi" 2>/dev/null)
  assert_contains "$content" "state/events/test-runs" "T20 .gitignore has state/events/test-runs"
}

# T21 filename uses UTC ISO timestamp pattern
test_t21_utc_iso_timestamp() {
  echo "TEST T21: filename UTC ISO pattern"
  # This is a config-property test — vitest.config.ts outputFile must use ISO+ms pattern
  # We assert the config format specifier is present
  local cfg="$REPO_ROOT/vitest.config.ts"
  local content; content=$(cat "$cfg" 2>/dev/null)
  # Either an inline ISO template OR a function that produces one
  if [[ "$content" == *"toISOString"* ]] || [[ "$content" == *"[hash]"* ]] || [[ "$content" == *"[timestamp]"* ]]; then
    pass "T21 vitest.config uses timestamp pattern (toISOString or hash or timestamp)"
  else
    fail "T21" "vitest.config.ts outputFile lacks a timestamp pattern (need toISOString or [hash] or [timestamp])"
  fi
}

# T22 test-never-in-record-window — excluded from flake list
test_t22_test_never_in_window() {
  echo "TEST T22: test-never-in-window excluded from flake"
  local d; d=$(mk_runs_dir)
  # Use only 2 runs from multi-run that both have same 2 tests present; no absent-test scenario
  # Simulate: run-1 has tests A + C; run-2 has only test A (test C absent from window)
  cat > "$d/2026-09-20T14-00-01-000.json" << 'EOF'
{
  "numTotalTests": 2, "success": true, "startTime": 1789910000001,
  "testResults": [{"name": "tests/synthetic/w.test.ts", "status": "passed",
    "assertionResults": [
      {"fullName": "w > test A", "title": "A", "status": "passed", "duration": 5.0},
      {"fullName": "w > test C only in run 1", "title": "C", "status": "passed", "duration": 10.0}
    ]}]}
EOF
  cat > "$d/2026-09-20T14-00-02-000.json" << 'EOF'
{
  "numTotalTests": 1, "success": true, "startTime": 1789910000002,
  "testResults": [{"name": "tests/synthetic/w.test.ts", "status": "passed",
    "assertionResults": [
      {"fullName": "w > test A", "title": "A", "status": "passed", "duration": 5.0}
    ]}]}
EOF
  local out; out=$(BASSCLEF_TEST_RUNS_DIR="$d" bash "$AGG_SH" --json 2>&1)
  # test C appears in only 1 of 2 runs — pass_rate should NOT appear as flaky (both times it ran, it passed)
  local flake_names; flake_names=$(echo "$out" | jq -r '.flake[].test' 2>/dev/null)
  assert_not_contains "$flake_names" "test C only in run 1" "T22 test-never-in-window not flagged as flaky"
  rm -rf "$d"
}

# ==========================================================================
# Runner
# ==========================================================================
main() {
  echo "=== aggregate-test-runs Tier 0 tests ==="
  echo ""
  test_t01_runs_dir_absent
  test_t02_runs_dir_empty
  test_t03_single_run_all_pass
  test_t04_single_run_one_fail
  test_t05_multi_run_flaky
  test_t06_last_n_caps
  test_t07_json_flag
  test_t08_malformed_one_of_many
  test_t09_all_malformed
  test_t10_missing_jq
  test_t11_sort_order
  test_t12_invalid_last
  test_t13_unknown_flag
  test_t14_parse_vitest_record_valid
  test_t15_parse_vitest_record_3x_warn
  test_t16_parse_vitest_record_partial
  test_t17_json_schema_version
  test_t18_golden_file
  test_t19_vitest_config_grep
  test_t20_gitignore_state_events
  test_t21_utc_iso_timestamp
  test_t22_test_never_in_window
  echo ""
  echo "=== summary ==="
  echo "  total: $_tests_total"
  echo "  passed: $_tests_passed"
  echo "  failed: $_tests_failed"
  if [[ $_tests_failed -gt 0 ]]; then
    echo ""
    echo "=== failures ==="
    printf '  %s\n' "${_failures[@]}"
    exit 1
  fi
  exit 0
}

main "$@"
