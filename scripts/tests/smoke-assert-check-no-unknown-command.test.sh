#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/lib/smoke-assert.sh new check_no_unknown_command
# + 5 per-skill positive-artifact checks + check_output_contains helper.
# Parent ticket: sunj-labs/bassclef-cli#217
# Design chain: docs/decompositions/2026-09-22c-cli-217-drive-shape-cure.md
# RFC folds: docs/rfcs/RFC-cli-217-drive-shape-council.md
# Pre-mortem folds: F1 (positive artifact is load-bearing), S1 (fail-safe on missing dir), S2 (exact grep)

# test-list:
# [ ] T01 check_no_unknown_command PASS — capture has no "Unknown command:" line
# [ ] T02 check_no_unknown_command FAIL — capture has one "Unknown command:" line at start
# [ ] T03 check_no_unknown_command FAIL — capture has "Unknown command:" after whitespace
# [ ] T04 check_no_unknown_command PASS — capture mentions "unknown" in prose but no "Unknown command:" exact
# [ ] T05 check_no_unknown_command MISSING — capture file does not exist
# [ ] T06 check_output_contains PASS — needle present
# [ ] T07 check_output_contains FAIL — needle absent
# [ ] T08 check_output_contains MISSING — capture file absent
# [ ] T09 check_temperance_marker PASS — marker file exists under workdir
# [ ] T10 check_temperance_marker FAIL — no marker file under workdir (fail-safe on missing dir per S1)
# [ ] T11 check_luminary_norman_artifact PASS — capture contains "Norman"
# [ ] T12 check_luminary_norman_artifact FAIL — capture contains no Norman token
# [ ] T13 check_kiss_words_artifact PASS — capture contains ≥2 of [rewritten, grade, words] (RFC fold N3)
# [ ] T14 check_kiss_words_artifact FAIL — capture contains only 1 of the 3 tokens
# [ ] T15 check_state_a_problem_artifact PASS — capture contains "Problem:"
# [ ] T16 check_state_a_problem_artifact FAIL — capture contains none of Problem:/Who:/What:
# [ ] T17 check_whats_the_plan_artifact PASS — capture contains "Plan:"
# [ ] T18 check_whats_the_plan_artifact FAIL — capture contains none of Plan:/Step/chain

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/smoke-assert.sh"

# shellcheck disable=SC1090
source "$LIB"

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1] got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] not in output"; }

mk_capture() {
  local file
  file=$(mktemp)
  printf '%s' "$1" > "$file"
  echo "$file"
}

# ================================================================
# T01-T05 — check_no_unknown_command
# ================================================================
test_t01() {
  echo "T01: check_no_unknown_command PASS — no Unknown command:"
  local f; f=$(mk_capture "some output line
another line
=== exit: 0")
  local out; out=$(check_no_unknown_command "$f" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T01 rc=0"
  assert_contains "$out" "PASS|no-unknown-command" "T01 message"
  rm -f "$f"
}

test_t02() {
  echo "T02: check_no_unknown_command FAIL — Unknown command: at line start"
  local f; f=$(mk_capture "Unknown command: /temperance
=== exit: 0")
  local out; out=$(check_no_unknown_command "$f" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T02 rc=1"
  assert_contains "$out" "FAIL|no-unknown-command" "T02 message"
  rm -f "$f"
}

test_t03() {
  echo "T03: check_no_unknown_command FAIL — Unknown command after whitespace"
  local f; f=$(mk_capture "some prefix
    Unknown command: /kiss
=== exit: 0")
  local out; out=$(check_no_unknown_command "$f" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T03 rc=1"
  rm -f "$f"
}

test_t04() {
  echo "T04: check_no_unknown_command PASS — 'unknown' in prose, no 'Unknown command:' exact"
  local f; f=$(mk_capture "The unknown command class was traced.
This talks about unknown things.
=== exit: 0")
  local out; out=$(check_no_unknown_command "$f" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T04 rc=0"
  rm -f "$f"
}

test_t05() {
  echo "T05: check_no_unknown_command MISSING — capture file absent"
  local out; out=$(check_no_unknown_command "/tmp/no-such-file-217-$$" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T05 rc=1 (missing file)"
  assert_contains "$out" "MISSING|precheck" "T05 precheck fails"
}

# ================================================================
# T06-T08 — check_output_contains
# ================================================================
test_t06() {
  echo "T06: check_output_contains PASS"
  local f; f=$(mk_capture "some text with needle in it
=== exit: 0")
  local out; out=$(check_output_contains "$f" "needle" "test-label" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T06 rc=0"
  assert_contains "$out" "PASS|contains-test-label" "T06 message"
  rm -f "$f"
}

test_t07() {
  echo "T07: check_output_contains FAIL"
  local f; f=$(mk_capture "text without the target
=== exit: 0")
  local out; out=$(check_output_contains "$f" "MISSING" "test-label" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T07 rc=1"
  assert_contains "$out" "FAIL|contains-test-label" "T07 message"
  rm -f "$f"
}

test_t08() {
  echo "T08: check_output_contains MISSING file"
  local out; out=$(check_output_contains "/tmp/no-such-file-217-$$" "x" "test" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T08 rc=1"
  assert_contains "$out" "MISSING|precheck" "T08 precheck fails"
}

# ================================================================
# T09-T10 — check_temperance_marker (workdir-scoped)
# ================================================================
test_t09() {
  echo "T09: check_temperance_marker PASS — marker file exists"
  local workdir; workdir=$(mktemp -d)
  mkdir -p "$workdir/state/markers/temperance"
  touch "$workdir/state/markers/temperance/test-branch.marker"
  local f; f=$(mk_capture "dispatched /temperance
=== exit: 0")
  local out; out=$(check_temperance_marker "$f" "$workdir" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T09 rc=0"
  assert_contains "$out" "PASS|temperance-marker" "T09 message"
  rm -f "$f"; rm -rf "$workdir"
}

test_t10() {
  echo "T10: check_temperance_marker FAIL — no marker (fail-safe on missing dir per S1)"
  local workdir; workdir=$(mktemp -d)
  # do NOT create the marker dir — must FAIL not PASS-by-skip
  local f; f=$(mk_capture "dispatched /temperance
=== exit: 0")
  local out; out=$(check_temperance_marker "$f" "$workdir" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T10 rc=1 (fail-safe)"
  assert_contains "$out" "FAIL|temperance-marker" "T10 message"
  rm -f "$f"; rm -rf "$workdir"
}

# ================================================================
# T11-T12 — check_luminary_norman_artifact
# ================================================================
test_t11() {
  echo "T11: check_luminary_norman_artifact PASS"
  local f; f=$(mk_capture "Don Norman's design principles include mapping and feedback.
=== exit: 0")
  local out; out=$(check_luminary_norman_artifact "$f" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T11 rc=0"
  rm -f "$f"
}

test_t12() {
  echo "T12: check_luminary_norman_artifact FAIL"
  local f; f=$(mk_capture "no reference to any luminary in this output.
=== exit: 0")
  local out; out=$(check_luminary_norman_artifact "$f" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T12 rc=1"
  rm -f "$f"
}

# ================================================================
# T13-T14 — check_kiss_words_artifact (RFC fold N3: AND-semantics ≥2 of 3)
# ================================================================
test_t13() {
  echo "T13: check_kiss_words_artifact PASS — ≥2 of [rewritten, grade, words]"
  local f; f=$(mk_capture "the text was rewritten to grade 8 level.
=== exit: 0")
  local out; out=$(check_kiss_words_artifact "$f" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T13 rc=0"
  rm -f "$f"
}

test_t14() {
  echo "T14: check_kiss_words_artifact FAIL — only 1 of 3 tokens"
  local f; f=$(mk_capture "just some plain words here about nothing.
=== exit: 0")
  local out; out=$(check_kiss_words_artifact "$f" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T14 rc=1"
  rm -f "$f"
}

# ================================================================
# T15-T16 — check_state_a_problem_artifact
# ================================================================
test_t15() {
  echo "T15: check_state_a_problem_artifact PASS"
  local f; f=$(mk_capture "Problem: session-start fires twice on cold installs.
=== exit: 0")
  local out; out=$(check_state_a_problem_artifact "$f" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T15 rc=0"
  rm -f "$f"
}

test_t16() {
  echo "T16: check_state_a_problem_artifact FAIL"
  local f; f=$(mk_capture "no framework tokens here.
=== exit: 0")
  local out; out=$(check_state_a_problem_artifact "$f" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T16 rc=1"
  rm -f "$f"
}

# ================================================================
# T17-T18 — check_whats_the_plan_artifact
# ================================================================
test_t17() {
  echo "T17: check_whats_the_plan_artifact PASS"
  local f; f=$(mk_capture "Plan: ship the fix in 3 steps.
Step 1 — write the test.
=== exit: 0")
  local out; out=$(check_whats_the_plan_artifact "$f" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T17 rc=0"
  rm -f "$f"
}

test_t18() {
  echo "T18: check_whats_the_plan_artifact FAIL"
  local f; f=$(mk_capture "nothing about plans here.
=== exit: 0")
  local out; out=$(check_whats_the_plan_artifact "$f" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T18 rc=1"
  rm -f "$f"
}

# ============================================================
# Runner
# ============================================================
echo "=== smoke-assert-check-no-unknown-command Tier 0 ==="

for t in test_t01 test_t02 test_t03 test_t04 test_t05 \
         test_t06 test_t07 test_t08 \
         test_t09 test_t10 \
         test_t11 test_t12 \
         test_t13 test_t14 \
         test_t15 test_t16 \
         test_t17 test_t18; do
  "$t"
done

echo ""
echo "=== Summary ==="
echo "  Total:  $_tests_total"
echo "  Passed: $_tests_passed"
echo "  Failed: $_tests_failed"

if [ "$_tests_failed" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for f in "${_failures[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
exit 0
