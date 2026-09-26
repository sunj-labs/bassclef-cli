#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/lib/shadow-detection.sh — detect_stale_bassclef_shadows.
# Parent ticket: sunj-labs/bassclef-cli#247
# Design chain: docs/use-cases/UC-247-shadow-detection.md
# Pre-mortem folds: N2 (warning names bypass flag inline), S1 (fail-safe on missing sentinel)

# test-list:
# [ ] T01 shadow_present_no_bypass  — sentinel exists + no bypass → exit 1 + warning to stderr names path
# [ ] T02 shadow_present_no_bypass_names_options — stderr names three options (mv aside, rm -rf, SMOKE_ALLOW_SHADOW=1)
# [ ] T03 shadow_absent — no adjacent bassclef dir → exit 0 silently (empty stderr apart from optional log line)
# [ ] T04 shadow_dir_present_sentinel_missing — dir exists but sentinel file absent → exit 0 (S1 fold — no false positive)
# [ ] T05 shadow_present_with_bypass  — sentinel exists + SMOKE_ALLOW_SHADOW=1 → exit 0 + warning still emitted
# [ ] T06 shadow_present_bypass_message — bypass path emits a log line naming the bypass to stderr
# [ ] T07 workdir_trailing_slash — dirname handles workdir with trailing slash (S5 sanity — bash dirname is POSIX safe)
# [ ] T08 warning_names_shadow_path — the warning message contains the literal path string of the shadow

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/shadow-detection.sh"

if [[ ! -f "$LIB" ]]; then
  echo "SETUP FAIL: expected lib at $LIB (Beck RED phase — not yet implemented)" >&2
  # Continue running so we see all-red output not a hard crash
fi

# shellcheck disable=SC1090
if [[ -f "$LIB" ]]; then
  source "$LIB"
fi

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1] got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] not in output [$1]"; }

# Fixture builder — creates a tmp parent + workdir + optional shadow dir + optional sentinel
mk_fixture() {
  local shadow_kind="$1"  # none | dir-only | sentinel
  local parent
  parent=$(mktemp -d)
  local workdir="$parent/workdir"
  mkdir -p "$workdir"
  local shadow="$parent/bassclef"
  case "$shadow_kind" in
    none) ;;
    dir-only) mkdir -p "$shadow" ;;
    sentinel)
      mkdir -p "$shadow/presence/install"
      touch "$shadow/presence/install/bassclef-hook-connect.sh"
      ;;
  esac
  echo "$parent"
}

rm_fixture() {
  local parent="$1"
  [[ -d "$parent" ]] && rm -rf "$parent"
}

# ================================================================
# T01 — shadow present + no bypass → exit 1
# ================================================================
test_t01() {
  echo "T01: shadow present + no bypass → exit 1 + warning to stderr"
  local parent; parent=$(mk_fixture sentinel)
  local workdir="$parent/workdir"
  local err; err=$(SMOKE_ALLOW_SHADOW= detect_stale_bassclef_shadows "$workdir" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T01 rc=1"
  assert_contains "$err" "shadow" "T01 stderr names shadow"
  rm_fixture "$parent"
}

# ================================================================
# T02 — stderr names three options
# ================================================================
test_t02() {
  echo "T02: warning names three options (mv aside, rm -rf, SMOKE_ALLOW_SHADOW)"
  local parent; parent=$(mk_fixture sentinel)
  local workdir="$parent/workdir"
  local err; err=$(SMOKE_ALLOW_SHADOW= detect_stale_bassclef_shadows "$workdir" 2>&1); local _rc=$?
  assert_contains "$err" "mv" "T02 stderr names mv"
  assert_contains "$err" "rm -rf" "T02 stderr names rm -rf"
  assert_contains "$err" "SMOKE_ALLOW_SHADOW" "T02 stderr names bypass flag"
  rm_fixture "$parent"
}

# ================================================================
# T03 — shadow absent → exit 0 silently
# ================================================================
test_t03() {
  echo "T03: shadow absent → exit 0"
  local parent; parent=$(mk_fixture none)
  local workdir="$parent/workdir"
  local err; err=$(SMOKE_ALLOW_SHADOW= detect_stale_bassclef_shadows "$workdir" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T03 rc=0"
  rm_fixture "$parent"
}

# ================================================================
# T04 — shadow dir present but sentinel missing → exit 0 (S1 fold)
# ================================================================
test_t04() {
  echo "T04: shadow dir exists but sentinel missing → exit 0 (fail-safe)"
  local parent; parent=$(mk_fixture dir-only)
  local workdir="$parent/workdir"
  local err; err=$(SMOKE_ALLOW_SHADOW= detect_stale_bassclef_shadows "$workdir" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T04 rc=0 (fail-safe on non-bassclef adjacent dir)"
  rm_fixture "$parent"
}

# ================================================================
# T05 — shadow present + bypass → exit 0
# ================================================================
test_t05() {
  echo "T05: shadow present + SMOKE_ALLOW_SHADOW=1 → exit 0"
  local parent; parent=$(mk_fixture sentinel)
  local workdir="$parent/workdir"
  local err; err=$(SMOKE_ALLOW_SHADOW=1 detect_stale_bassclef_shadows "$workdir" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T05 rc=0 (bypass honored)"
  rm_fixture "$parent"
}

# ================================================================
# T06 — bypass path emits a log line to stderr
# ================================================================
test_t06() {
  echo "T06: bypass path emits log to stderr naming the bypass"
  local parent; parent=$(mk_fixture sentinel)
  local workdir="$parent/workdir"
  local err; err=$(SMOKE_ALLOW_SHADOW=1 detect_stale_bassclef_shadows "$workdir" 2>&1); local _rc=$?
  assert_contains "$err" "SMOKE_ALLOW_SHADOW" "T06 bypass log names flag"
  rm_fixture "$parent"
}

# ================================================================
# T07 — workdir with trailing slash still resolves parent correctly
# ================================================================
test_t07() {
  echo "T07: workdir with trailing slash resolves parent correctly"
  local parent; parent=$(mk_fixture sentinel)
  local workdir="$parent/workdir/"  # trailing slash
  local err; err=$(SMOKE_ALLOW_SHADOW= detect_stale_bassclef_shadows "$workdir" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T07 rc=1 (parent resolves with trailing slash)"
  rm_fixture "$parent"
}

# ================================================================
# T08 — warning names literal shadow path (N2 fold)
# ================================================================
test_t08() {
  echo "T08: warning names literal shadow path"
  local parent; parent=$(mk_fixture sentinel)
  local workdir="$parent/workdir"
  local shadow="$parent/bassclef"
  local err; err=$(SMOKE_ALLOW_SHADOW= detect_stale_bassclef_shadows "$workdir" 2>&1); local _rc=$?
  assert_contains "$err" "$shadow" "T08 stderr contains shadow path"
  rm_fixture "$parent"
}

# ================================================================
# Runner
# ================================================================
if ! declare -F detect_stale_bassclef_shadows >/dev/null 2>&1; then
  echo "detect_stale_bassclef_shadows not defined — Beck RED phase (lib missing at $LIB)" >&2
  echo "  Skipping test bodies; RED expected."
  echo "  Tests: 0 total  0 passed  0 failed"
  exit 1
fi

test_t01
test_t02
test_t03
test_t04
test_t05
test_t06
test_t07
test_t08

echo ""
echo "======================================"
echo "Tests: $_tests_total total  $_tests_passed passed  $_tests_failed failed"
echo "======================================"

if (( _tests_failed > 0 )); then
  echo ""
  echo "FAILURES:"
  for f in "${_failures[@]}"; do echo "  - $f"; done
  exit 1
fi
exit 0
