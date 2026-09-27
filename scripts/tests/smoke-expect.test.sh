#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md; test mtime <= source mtime)
#
# Tier 0 strict-TDD tests for scripts/lib/smoke-expect.sh
# Per .claude/rules/test-list-discipline.md + .claude/rules/test-sufficiency.md
#
# Sub-step 1 real-body scope — replaces walking-skeleton sentinel tests
# with characterization tests against the fake_claude fixture.

# test-list:
# --- Interface (from walking skeleton) ---
# [x] Sources cleanly (no side effects on load)
# [x] Interface: drive_start function is defined
# [x] Interface: drive_send function is defined
# [x] Interface: drive_expect function is defined
# [x] Interface: drive_capture function is defined
# [x] Interface: drive_end function is defined
# [x] Interface: smoke_expect_version function is defined
# --- Constants ---
# [x] SMOKE_EXPECT_VERSION emits non-empty version string
# [x] SMOKE_EXPECT_VERSION is readonly
# --- drive_start preconditions (Saltzer-Schroeder S2/S4 folds) ---
# [x] drive_start with missing SCRATCH_DIR arg exits 13
# [x] drive_start with non-existent SCRATCH_DIR exits 13
# [x] drive_start with valid SCRATCH_DIR but missing SPAWN_CMD exits 13
# [x] drive_start with valid inputs returns 0
# --- drive_start postconditions (Ousterhout O5 + Hoare H2 folds) ---
# [x] drive_start creates session state file
# [x] drive_start creates queue file
# [x] drive_start creates log file
# [x] drive_start state file marks session OPEN
# --- drive_send session-guard (Saltzer S3) ---
# [x] drive_send without prior drive_start exits 10
# [x] drive_send after drive_start returns 0
# [x] drive_send appends a send line to the queue
# [x] drive_send with Tcl special chars ($ [ ]) survives escape (Saltzer S6)
# --- drive_expect session-guard + shape ---
# [x] drive_expect without prior drive_start exits 10
# [x] drive_expect after drive_start returns 0
# [x] drive_expect appends an expect block to the queue
# [x] drive_expect default timeout is 180 (per Feathers F2 fold)
# --- drive_end behavior (real expect subprocess) ---
# [x] drive_end without prior drive_start returns 0 (idempotent per O3/H4)
# [x] drive_end with queued matching send/expect against fake_claude returns 0
# [x] drive_end with queued timeout-bound expect returns 11 (Saltzer S5)
# [x] drive_end marks session state CLOSED
# [x] drive_end preserves the log file (Deming D1 side-effect assertion)
# --- drive_capture ---
# [x] drive_capture without session state file exits 10
# [x] drive_capture after drive_end copies log to DEST
# [x] drive_capture with unwritable DEST exits 14
# --- version function ---
# [x] smoke_expect_version emits non-empty version string
# --- onboarding dance (cli#254 Path A2, 2026-09-27) ---
# [x] drive_start default (env unset) emits no dance in queue
# [x] drive_start with SMOKE_DRIVE_ONBOARDING_ENTERS=0 emits no dance
# [x] drive_start with SMOKE_DRIVE_ONBOARDING_ENTERS=2 emits 2 send -- "\r" lines
# [x] drive_start with SMOKE_DRIVE_ONBOARDING_ENTERS=1 emits 1 send -- "\r" line
# [x] drive_start with dance emits sleep lines before + between + after sends

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/smoke-expect.sh"
FAKE_CLAUDE="$REPO_ROOT/scripts/tests/fixtures/fake_claude.sh"

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
  local actual
  actual=0
  eval "$cmd" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $desc  (expected exit $expected, got $actual)")
  fi
}

assert_file_exists() {
  local desc="$1"
  local path="$2"
  if [ -f "$path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $desc  (path not found: $path)")
  fi
}

assert_grep() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -q -- "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $desc  (pattern '$pattern' missing in $file)")
  fi
}

# Fresh scratch per assertion pair
mkscratch() {
  local dir
  dir=$(mktemp -d "${TMPDIR:-/tmp}/smoke-expect-test-XXXXXX")
  echo "$dir"
}

trap 'rm -rf /tmp/smoke-expect-test-*' EXIT

# ============================================================
# Fixture sanity — fixture works standalone
# ============================================================
[ -x "$FAKE_CLAUDE" ] || { echo "FAIL: fake_claude fixture missing or non-executable: $FAKE_CLAUDE" >&2; exit 1; }

# ============================================================
# Interface (Tests 1-8)
# ============================================================
assert_true "smoke-expect.sh source file exists" "[ -f '$LIB' ]"
assert_true "smoke-expect.sh sources cleanly" "source '$LIB'"

# shellcheck source=/dev/null
source "$LIB"
# The lib sets -euo pipefail on source; the test needs -e OFF so bare-return
# calls in tearDown sections don't exit the test runner.
set +e

for fn in drive_start drive_send drive_expect drive_capture drive_end smoke_expect_version; do
  assert_true "$fn is defined" "declare -f $fn"
done

# ============================================================
# Constants (Tests 9-11)
# ============================================================
version_output=$(smoke_expect_version)
assert_true "smoke_expect_version emits non-empty" "[ -n '$version_output' ]"

readonly_exit=0
readonly_check=$(bash -c "source '$LIB' && SMOKE_EXPECT_VERSION=x 2>&1") || readonly_exit=$?
if [ $readonly_exit -ne 0 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("FAIL: SMOKE_EXPECT_VERSION should be readonly (reassignment succeeded)")
fi

# ============================================================
# drive_start preconditions (Tests 12-15)
# ============================================================
assert_exit_code "drive_start with no args exits 13" 13 "( _SMOKE_EXPECT_SESSION_STATE= drive_start )"
assert_exit_code "drive_start with non-existent dir exits 13" 13 "( _SMOKE_EXPECT_SESSION_STATE= drive_start /no/such/dir/xyz $FAKE_CLAUDE )"

scratch_missing_cmd=$(mkscratch)
assert_exit_code "drive_start missing spawn cmd exits 13" 13 "( _SMOKE_EXPECT_SESSION_STATE= drive_start $scratch_missing_cmd )"

# ============================================================
# drive_start postconditions (Tests 16-19)
# ============================================================
scratch_ok=$(mkscratch)
assert_exit_code "drive_start with valid inputs returns 0" 0 "( _SMOKE_EXPECT_SESSION_STATE= drive_start $scratch_ok $FAKE_CLAUDE )"
assert_file_exists "drive_start creates session state file" "$scratch_ok/.smoke-drive-session"
assert_file_exists "drive_start creates queue file" "$scratch_ok/.smoke-drive-queue.exp"
assert_file_exists "drive_start creates log file" "$scratch_ok/drive.log"
assert_grep "session state marks OPEN" "SMOKE_DRIVE_STATE=OPEN" "$scratch_ok/.smoke-drive-session"

# ============================================================
# drive_send session-guard + queue append (Tests 20-23)
# ============================================================
assert_exit_code "drive_send without session exits 10" 10 "( _SMOKE_EXPECT_SESSION_STATE= drive_send hello )"

scratch_send=$(mkscratch)
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_send" "$FAKE_CLAUDE" >/dev/null ) || true
# Session state is exported inside the same shell context; use env var.
export _SMOKE_EXPECT_SESSION_STATE="$scratch_send/.smoke-drive-session"
assert_exit_code "drive_send after drive_start returns 0" 0 "drive_send hello_world"
assert_grep "drive_send appends send line to queue" "send.*hello_world" "$scratch_send/.smoke-drive-queue.exp"
assert_exit_code "drive_send handles Tcl special chars" 0 'drive_send "cost is \$5 in [set]"'
unset _SMOKE_EXPECT_SESSION_STATE

# ============================================================
# drive_expect session-guard + queue append (Tests 24-27)
# ============================================================
assert_exit_code "drive_expect without session exits 10" 10 "( _SMOKE_EXPECT_SESSION_STATE= drive_expect Ready )"

scratch_exp=$(mkscratch)
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_exp" "$FAKE_CLAUDE" >/dev/null ) || true
export _SMOKE_EXPECT_SESSION_STATE="$scratch_exp/.smoke-drive-session"
assert_exit_code "drive_expect after drive_start returns 0" 0 'drive_expect Ready 30'
assert_grep "drive_expect appends expect block to queue" "expect" "$scratch_exp/.smoke-drive-queue.exp"
drive_expect "pat" >/dev/null 2>&1
assert_grep "drive_expect uses default timeout 180 when omitted" "set timeout 180" "$scratch_exp/.smoke-drive-queue.exp"
unset _SMOKE_EXPECT_SESSION_STATE

# ============================================================
# drive_end idempotent + real expect run (Tests 28-32)
# ============================================================
assert_exit_code "drive_end without session returns 0 (idempotent)" 0 "( _SMOKE_EXPECT_SESSION_STATE= drive_end )"

# Real expect run — happy path
scratch_run=$(mkscratch)
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_run" "$FAKE_CLAUDE" >/dev/null ) || true
export _SMOKE_EXPECT_SESSION_STATE="$scratch_run/.smoke-drive-session"
drive_expect 'READY>' 5 >/dev/null 2>&1
drive_send 'hello' >/dev/null 2>&1
drive_expect 'RESP: hello' 5 >/dev/null 2>&1
assert_exit_code "drive_end with matching queue returns 0" 0 "drive_end"
assert_grep "drive_end marks session CLOSED" "SMOKE_DRIVE_STATE=CLOSED" "$scratch_run/.smoke-drive-session"
assert_file_exists "drive_end preserves the log file" "$scratch_run/drive.log"
unset _SMOKE_EXPECT_SESSION_STATE

# Real expect run — timeout path
scratch_timeout=$(mkscratch)
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_timeout" "$FAKE_CLAUDE" >/dev/null ) || true
export _SMOKE_EXPECT_SESSION_STATE="$scratch_timeout/.smoke-drive-session"
drive_expect 'READY>' 5 >/dev/null 2>&1
drive_expect 'THIS_PATTERN_NEVER_APPEARS_xyz' 2 >/dev/null 2>&1
assert_exit_code "drive_end with timeout expect returns 11" 11 "drive_end"
unset _SMOKE_EXPECT_SESSION_STATE

# ============================================================
# drive_capture (Tests 33-35)
# ============================================================
assert_exit_code "drive_capture without session exits 10" 10 "( _SMOKE_EXPECT_SESSION_STATE= drive_capture /tmp/out )"

scratch_cap=$(mkscratch)
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_cap" "$FAKE_CLAUDE" >/dev/null ) || true
export _SMOKE_EXPECT_SESSION_STATE="$scratch_cap/.smoke-drive-session"
drive_expect 'READY>' 5 >/dev/null 2>&1
drive_end >/dev/null 2>&1
dest_out=$(mktemp)
assert_exit_code "drive_capture after drive_end returns 0" 0 "drive_capture $dest_out"
assert_true "drive_capture copies log content" "[ -s '$dest_out' ]"
assert_exit_code "drive_capture with unwritable DEST exits 14" 14 "drive_capture /no/such/dir/deep/out"
unset _SMOKE_EXPECT_SESSION_STATE
rm -f "$dest_out"

# ============================================================
# Onboarding dance (cli#254 Path A2, 2026-09-27)
# ============================================================
# drive_start emits sleep+send lines into the queue when
# SMOKE_DRIVE_ONBOARDING_ENTERS > 0. Verify queue file content per shape.

count_lines_containing() {
  local file="$1" needle="$2"
  grep -c -F -- "$needle" "$file" 2>/dev/null | tr -d ' \n'
}

# Default: env unset → no dance
scratch_no_dance=$(mkscratch)
unset SMOKE_DRIVE_ONBOARDING_ENTERS
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_no_dance" "$FAKE_CLAUDE" >/dev/null ) || true
send_count=$(count_lines_containing "$scratch_no_dance/.smoke-drive-queue.exp" 'send -- "\r"')
assert_true "default (env unset) emits no dance sends" "[ '$send_count' = '0' ]"

# Explicit 0 → no dance
scratch_zero=$(mkscratch)
export SMOKE_DRIVE_ONBOARDING_ENTERS=0
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_zero" "$FAKE_CLAUDE" >/dev/null ) || true
send_count=$(count_lines_containing "$scratch_zero/.smoke-drive-queue.exp" 'send -- "\r"')
assert_true "SMOKE_DRIVE_ONBOARDING_ENTERS=0 emits no dance sends" "[ '$send_count' = '0' ]"

# 2 enters → 2 sends
scratch_two=$(mkscratch)
export SMOKE_DRIVE_ONBOARDING_ENTERS=2
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_two" "$FAKE_CLAUDE" >/dev/null ) || true
send_count=$(count_lines_containing "$scratch_two/.smoke-drive-queue.exp" 'send -- "\r"')
assert_true "SMOKE_DRIVE_ONBOARDING_ENTERS=2 emits 2 sends" "[ '$send_count' = '2' ]"

# 1 enter → 1 send
scratch_one=$(mkscratch)
export SMOKE_DRIVE_ONBOARDING_ENTERS=1
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_one" "$FAKE_CLAUDE" >/dev/null ) || true
send_count=$(count_lines_containing "$scratch_one/.smoke-drive-queue.exp" 'send -- "\r"')
assert_true "SMOKE_DRIVE_ONBOARDING_ENTERS=1 emits 1 send" "[ '$send_count' = '1' ]"

# Dance emits sleep lines around sends (pre + between + trailing)
scratch_sleeps=$(mkscratch)
export SMOKE_DRIVE_ONBOARDING_ENTERS=2
( _SMOKE_EXPECT_SESSION_STATE= drive_start "$scratch_sleeps" "$FAKE_CLAUDE" >/dev/null ) || true
sleep_count=$(grep -c '^sleep ' "$scratch_sleeps/.smoke-drive-queue.exp" 2>/dev/null | tr -d ' \n')
# Expect: 1 pre + 1 between (after send 1, before send 2) + 1 trailing = 3
assert_true "dance emits pre+between+trailing sleeps" "[ '$sleep_count' = '3' ]"

unset SMOKE_DRIVE_ONBOARDING_ENTERS

# ============================================================
# Summary
# ============================================================
echo ""
echo "smoke-expect.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  printf '  %s\n' "${FAIL_MSGS[@]}"
  exit 1
fi
exit 0
