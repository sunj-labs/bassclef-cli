#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/smoke-drive-interactive-onboard-repo.sh (walking skeleton)

# test-list:
# [x] File exists + executable
# [x] Sources smoke-expect.sh (Saltzer-Schroeder S1 fold — complete mediation)
# [x] Sources smoke-drives-registry.sh
# [x] Defines main() function
# [x] Carries @pattern annotation (Strategy)
# [x] main() with valid args returns 42 (unimplemented sentinel)
# [x] main() without SCRATCH_DIR fails
# [x] main() without CLI_VERSION fails

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVE="$REPO_ROOT/scripts/smoke-drive-interactive-onboard-repo.sh"

PASS=0; FAIL=0; FAIL_MSGS=()

assert_true() { eval "$2" >/dev/null 2>&1 && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $1"); }; }
assert_exit() {
  local desc="$1"; local expected="$2"; shift 2
  set +e; "$@" >/dev/null 2>&1; local actual=$?; set -e
  [ "$actual" = "$expected" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $desc (expected $expected, got $actual)"); }
}

assert_true "file exists" "[ -f '$DRIVE' ]"
assert_true "file executable" "[ -x '$DRIVE' ]"
assert_true "sources smoke-expect.sh" "grep -q 'source.*smoke-expect.sh' '$DRIVE'"
assert_true "sources smoke-drives-registry.sh" "grep -q 'source.*smoke-drives-registry.sh' '$DRIVE'"
assert_true "defines main()" "grep -qE '^main\\(\\) \\{|^main *\\(\\) *\\{' '$DRIVE'"
assert_true "carries @pattern strategy annotation" "grep -q '@pattern patterns/code/gof/strategy.md' '$DRIVE'"

# Runtime tests
assert_exit "main with valid args returns 42 (skeleton)" 42 "$DRIVE" "/tmp/test" "1.9.4"

# Missing arg tests — bash `set -u` will exit non-zero
set +e; "$DRIVE" 2>/dev/null; rc1=$?; set -e
assert_true "main without SCRATCH_DIR fails (non-zero exit)" "[ '$rc1' -ne 0 ]"

set +e; "$DRIVE" "/tmp/test" 2>/dev/null; rc2=$?; set -e
assert_true "main without CLI_VERSION fails (non-zero exit)" "[ '$rc2' -ne 0 ]"

echo ""
echo "smoke-drive-interactive-onboard-repo.sh Tier 0 tests: $PASS passed, $FAIL failed"
[ $FAIL -gt 0 ] && { printf '  %s\n' "${FAIL_MSGS[@]}"; exit 1; }
exit 0
