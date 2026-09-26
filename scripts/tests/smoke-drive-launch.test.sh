#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/smoke-drive-launch.sh — sub-step 3 real body.

# test-list:
# --- Interface (kept from skeleton) ---
# [x] File exists + executable
# [x] Sources smoke-expect.sh
# [x] Sources smoke-drives-registry.sh
# [x] Defines main()
# [x] Carries @pattern strategy annotation
# [x] main() without SCRATCH_DIR fails
# [x] main() without CLI_VERSION fails
# --- Real body ---
# [x] happy path against fake_claude returns 0
# [x] session state + log files created
# [x] mismatched done-pattern hits timeout returns 11
# [x] default timeout is 240 (larger than /onboard-repo's 180)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVE="$REPO_ROOT/scripts/smoke-drive-launch.sh"
FAKE_CLAUDE="$REPO_ROOT/scripts/tests/fixtures/fake_claude.sh"

PASS=0; FAIL=0; FAIL_MSGS=()

assert_true() {
  if eval "$2" >/dev/null 2>&1; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $1  (cmd: $2)"); fi
}
assert_exit() {
  local desc="$1" expected="$2"; shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $desc (expected $expected, got $actual)"); fi
}
assert_file() {
  if [ -f "$2" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $1 (path missing: $2)"); fi
}

trap 'rm -rf /tmp/smoke-launch-test-*' EXIT
mkscratch() { mktemp -d /tmp/smoke-launch-test-XXXXXX; }

# Interface
assert_true "file exists" "[ -f '$DRIVE' ]"
assert_true "file executable" "[ -x '$DRIVE' ]"
assert_true "sources smoke-expect.sh" "grep -q 'source.*smoke-expect.sh' '$DRIVE'"
assert_true "sources smoke-drives-registry.sh" "grep -q 'source.*smoke-drives-registry.sh' '$DRIVE'"
assert_true "defines main()" "grep -qE '^main *\\(\\) *\\{' '$DRIVE'"
assert_true "carries @pattern strategy" "grep -q '@pattern patterns/code/gof/strategy.md' '$DRIVE'"
assert_true "default timeout 240 (larger than onboard-repo's 180)" "grep -qE 'timeout_sec=\\\"?\\\$\\{3:-240\\}' '$DRIVE'"

rc1=0; "$DRIVE" 2>/dev/null || rc1=$?
assert_true "main without SCRATCH_DIR fails" "[ '$rc1' -ne 0 ]"
rc2=0; "$DRIVE" "/tmp/test" 2>/dev/null || rc2=$?
assert_true "main without CLI_VERSION fails" "[ '$rc2' -ne 0 ]"

# Real body — happy path
scratch_happy=$(mkscratch)
export SMOKE_DRIVE_SPAWN_CMD="$FAKE_CLAUDE"
export SMOKE_DRIVE_READY_PATTERN="READY>"
export SMOKE_DRIVE_PROMPT_TEXT="hello launch"
export SMOKE_DRIVE_DONE_PATTERN="RESP: hello launch"
assert_exit "happy path with fake_claude returns 0" 0 "$DRIVE" "$scratch_happy" "1.9.4" "5"
unset SMOKE_DRIVE_SPAWN_CMD SMOKE_DRIVE_READY_PATTERN SMOKE_DRIVE_PROMPT_TEXT SMOKE_DRIVE_DONE_PATTERN
assert_file "session state file created" "$scratch_happy/.smoke-drive-session"
assert_file "drive log created" "$scratch_happy/drive.log"

# Real body — timeout
scratch_to=$(mkscratch)
export SMOKE_DRIVE_SPAWN_CMD="$FAKE_CLAUDE"
export SMOKE_DRIVE_READY_PATTERN="READY>"
export SMOKE_DRIVE_PROMPT_TEXT="hello"
export SMOKE_DRIVE_DONE_PATTERN="PATTERN_NEVER_APPEARS_xyz"
assert_exit "mismatched done-pattern hits timeout returns 11" 11 "$DRIVE" "$scratch_to" "1.9.4" "2"
unset SMOKE_DRIVE_SPAWN_CMD SMOKE_DRIVE_READY_PATTERN SMOKE_DRIVE_PROMPT_TEXT SMOKE_DRIVE_DONE_PATTERN

echo ""
echo "smoke-drive-launch.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then printf '  %s\n' "${FAIL_MSGS[@]}"; exit 1; fi
exit 0
