#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Tier 0 tests for scripts/lib/smoke-assert.sh check_artifact_exists.
#
# Session A R-C5 fold — every driver asserts an output artifact exists,
# not just exit code. Closes cli#319 class.

# test-list:
# [ ] T01 PASS — glob matches one non-empty file
# [ ] T02 PASS — glob matches multiple non-empty files
# [ ] T03 FAIL — glob matches zero files
# [ ] T04 FAIL — glob matches one file but it is empty
# [ ] T05 FAIL — exact path to nonexistent file
# [ ] T06 PASS — exact path to non-empty file
# [ ] T07 FAIL — empty pattern argument
# [ ] T08 FAIL — glob matches files all empty

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

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

# T01 — single non-empty match
echo "hello" > "$TMP_BASE/t01.json"
out="$(check_artifact_exists "$TMP_BASE/t01.json" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T01 rc"
assert_contains "$out" "PASS" "T01 PASS token"

# T02 — glob matches multiple non-empty
echo "a" > "$TMP_BASE/t02a.json"
echo "b" > "$TMP_BASE/t02b.json"
out="$(check_artifact_exists "$TMP_BASE/t02*.json" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T02 rc"
assert_contains "$out" "PASS" "T02 PASS token"
assert_contains "$out" "2 non-empty" "T02 counts matches"

# T03 — glob matches zero
out="$(check_artifact_exists "$TMP_BASE/nomatch*.xyz" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T03 rc"
assert_contains "$out" "FAIL" "T03 FAIL token"

# T04 — one match, empty file
: > "$TMP_BASE/t04.json"
out="$(check_artifact_exists "$TMP_BASE/t04.json" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T04 rc"
assert_contains "$out" "FAIL" "T04 FAIL token"

# T05 — exact path, nonexistent
out="$(check_artifact_exists "$TMP_BASE/does-not-exist.txt" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T05 rc"
assert_contains "$out" "FAIL" "T05 FAIL token"

# T06 — exact path, non-empty
echo "content" > "$TMP_BASE/t06.txt"
out="$(check_artifact_exists "$TMP_BASE/t06.txt" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T06 rc"
assert_contains "$out" "PASS" "T06 PASS token"

# T07 — empty pattern
out="$(check_artifact_exists "" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T07 rc"
assert_contains "$out" "empty pattern" "T07 empty-pattern msg"

# T08 — glob matches but all empty
: > "$TMP_BASE/t08a.log"
: > "$TMP_BASE/t08b.log"
out="$(check_artifact_exists "$TMP_BASE/t08*.log" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T08 rc"
assert_contains "$out" "all empty" "T08 all-empty msg"

echo ""
echo "============================================"
echo "smoke-assert-check-artifact-exists.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
