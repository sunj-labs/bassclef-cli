#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/smoke-drive-interactive-onboard-repo.sh
#
# Sub-step 2 real body — tests characterize the drive against
# fake_claude fixture (interface pinned; real-claude behavior deferred
# to sub-step 5 wire).

# test-list:
# --- Interface (kept from skeleton) ---
# [x] File exists + executable
# [x] Sources smoke-expect.sh
# [x] Sources smoke-drives-registry.sh
# [x] Defines main() function
# [x] Carries @pattern strategy annotation
# [x] main() without SCRATCH_DIR fails (non-zero exit)
# [x] main() without CLI_VERSION fails (non-zero exit)
# --- Real body behavior ---
# [x] main() with fake_claude + matching patterns returns 0 (happy path)
# [x] main() with mismatched done-pattern hits timeout → returns 11
# [x] main() respects SMOKE_DRIVE_SPAWN_CMD env override (defaults to `claude`)
# [x] main() respects SMOKE_DRIVE_PROMPT_TEXT env override
# [x] main() creates session state file + log at SCRATCH_DIR
# [~] main() with missing spawn cmd binary — not validated at drive level;
#     caller contract per env-driven config assumes valid spawn cmd.
#     Deferred to Docker CI validation at sub-step 5 (real claude binary must exist).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVE="$REPO_ROOT/scripts/smoke-drive-interactive-onboard-repo.sh"
FAKE_CLAUDE="$REPO_ROOT/scripts/tests/fixtures/fake_claude.sh"

PASS=0; FAIL=0; FAIL_MSGS=()

assert_true() {
  local desc="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAIL_MSGS+=("FAIL: $desc  (cmd: $cmd)")
  fi
}

assert_exit() {
  local desc="$1" expected="$2"; shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAIL_MSGS+=("FAIL: $desc  (expected $expected, got $actual)")
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAIL_MSGS+=("FAIL: $desc  (path not found: $path)")
  fi
}

trap 'rm -rf /tmp/smoke-onboard-repo-test-*' EXIT

mkscratch() { mktemp -d /tmp/smoke-onboard-repo-test-XXXXXX; }

# ============================================================
# Interface tests (Tests 1-7)
# ============================================================
assert_true "file exists" "[ -f '$DRIVE' ]"
assert_true "file executable" "[ -x '$DRIVE' ]"
assert_true "sources smoke-expect.sh" "grep -q 'source.*smoke-expect.sh' '$DRIVE'"
assert_true "sources smoke-drives-registry.sh" "grep -q 'source.*smoke-drives-registry.sh' '$DRIVE'"
assert_true "defines main()" "grep -qE '^main\\(\\) \\{|^main *\\(\\) *\\{' '$DRIVE'"
assert_true "carries @pattern strategy annotation" "grep -q '@pattern patterns/code/gof/strategy.md' '$DRIVE'"

# Missing arg tests
rc1=0
"$DRIVE" 2>/dev/null || rc1=$?
assert_true "main without SCRATCH_DIR fails" "[ '$rc1' -ne 0 ]"

rc2=0
"$DRIVE" "/tmp/test" 2>/dev/null || rc2=$?
assert_true "main without CLI_VERSION fails" "[ '$rc2' -ne 0 ]"

# ============================================================
# Real body — happy path against fake_claude (Test 8)
# ============================================================
scratch_happy=$(mkscratch)
export SMOKE_DRIVE_SPAWN_CMD="$FAKE_CLAUDE"
export SMOKE_DRIVE_READY_PATTERN="READY>"
export SMOKE_DRIVE_PROMPT_TEXT="hello onboard-repo"
export SMOKE_DRIVE_DONE_PATTERN="RESP: hello onboard-repo"
assert_exit "happy path with fake_claude returns 0" 0 "$DRIVE" "$scratch_happy" "1.9.4" "5"
unset SMOKE_DRIVE_SPAWN_CMD SMOKE_DRIVE_READY_PATTERN SMOKE_DRIVE_PROMPT_TEXT SMOKE_DRIVE_DONE_PATTERN

# ============================================================
# Real body — session artifacts created (Test 9-10)
# ============================================================
assert_file_exists "session state file created" "$scratch_happy/.smoke-drive-session"
assert_file_exists "drive log created" "$scratch_happy/drive.log"

# ============================================================
# Real body — timeout path (Test 11)
# ============================================================
scratch_to=$(mkscratch)
export SMOKE_DRIVE_SPAWN_CMD="$FAKE_CLAUDE"
export SMOKE_DRIVE_READY_PATTERN="READY>"
export SMOKE_DRIVE_PROMPT_TEXT="hello"
export SMOKE_DRIVE_DONE_PATTERN="PATTERN_NEVER_APPEARS_xyz"
assert_exit "mismatched done-pattern hits timeout returns 11" 11 "$DRIVE" "$scratch_to" "1.9.4" "2"
unset SMOKE_DRIVE_SPAWN_CMD SMOKE_DRIVE_READY_PATTERN SMOKE_DRIVE_PROMPT_TEXT SMOKE_DRIVE_DONE_PATTERN

echo ""
echo "smoke-drive-interactive-onboard-repo.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  printf '  %s\n' "${FAIL_MSGS[@]}"
  exit 1
fi
exit 0
