#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md; test mtime <= source mtime)
# Tier 0 strict-TDD tests for scripts/lib/smoke-expect.sh
# Per .claude/rules/test-list-discipline.md + .claude/rules/test-sufficiency.md

# test-list:
# [x] Skip case: sourced without main invocation loads functions cleanly
# [x] Interface: drive_start function is defined
# [x] Interface: drive_send function is defined
# [x] Interface: drive_expect function is defined
# [x] Interface: drive_capture function is defined
# [x] Interface: drive_end function is defined
# [x] Interface: smoke_expect_version function is defined
# [x] Exit-code matrix: drive_start returns SMOKE_EXPECT_UNIMPLEMENTED (42) on skeleton
# [x] Exit-code matrix: drive_send returns SMOKE_EXPECT_UNIMPLEMENTED (42) on skeleton
# [x] Exit-code matrix: drive_expect returns SMOKE_EXPECT_UNIMPLEMENTED (42) on skeleton
# [x] Exit-code matrix: drive_capture returns SMOKE_EXPECT_UNIMPLEMENTED (42) on skeleton
# [x] Exit-code matrix: drive_end returns SMOKE_EXPECT_UNIMPLEMENTED (42) on skeleton
# [x] Postcondition: smoke_expect_version emits a non-empty version string
# [x] Constant: SMOKE_EXPECT_UNIMPLEMENTED is 42 (walking-skeleton sentinel)
# [x] Constant: SMOKE_EXPECT_VERSION is readonly

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/smoke-expect.sh"

PASS=0
FAIL=0
FAIL_MSGS=()

assert_true() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $desc  (cmd: $cmd)")
  fi
}

assert_exit_code() {
  local desc="$1"
  local expected="$2"
  local cmd="$3"
  set +e
  eval "$cmd" >/dev/null 2>&1
  local actual=$?
  set -e
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $desc  (expected exit $expected, got $actual)")
  fi
}

# Test 1: file exists
assert_true "smoke-expect.sh source file exists" "[ -f '$LIB' ]"

# Test 2: sources cleanly (no side effects on load)
assert_true "smoke-expect.sh sources cleanly" "source '$LIB'"

source "$LIB"

# Tests 3-8: interface functions defined
for fn in drive_start drive_send drive_expect drive_capture drive_end smoke_expect_version; do
  assert_true "$fn is defined" "declare -f $fn"
done

# Tests 9-13: unimplemented functions return sentinel 42
assert_exit_code "drive_start returns 42 (skeleton)" 42 "drive_start /tmp"
assert_exit_code "drive_send returns 42 (skeleton)" 42 "drive_send hello"
assert_exit_code "drive_expect returns 42 (skeleton)" 42 "drive_expect pattern"
assert_exit_code "drive_capture returns 42 (skeleton)" 42 "drive_capture /tmp/out"
assert_exit_code "drive_end returns 42 (skeleton)" 42 "drive_end"

# Test 14: version function emits non-empty string
version_output=$(smoke_expect_version)
assert_true "smoke_expect_version emits non-empty" "[ -n '$version_output' ]"

# Test 15: sentinel constant is 42
assert_true "SMOKE_EXPECT_UNIMPLEMENTED is 42" "[ '$SMOKE_EXPECT_UNIMPLEMENTED' = '42' ]"

# Test 16: version constant is readonly
set +e
readonly_check=$(bash -c "source '$LIB' && SMOKE_EXPECT_VERSION=x 2>&1")
readonly_exit=$?
set -e
if [ $readonly_exit -ne 0 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("FAIL: SMOKE_EXPECT_VERSION should be readonly (reassignment succeeded)")
fi

echo ""
echo "smoke-expect.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  printf '  %s\n' "${FAIL_MSGS[@]}"
  exit 1
fi
exit 0
