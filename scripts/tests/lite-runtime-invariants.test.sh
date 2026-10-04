#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Tier 0 tests for scripts/tests/lib/lite-runtime-invariants.sh — 5 narrow
# functions enforce cross-release invariants on every driver per plan doc
# docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L44-50.
#
# RFC F-HW-1 fold: narrow interface — 5 functions documented contract.
# RFC F-JC-1 fold: lib runs on OS matrix (ubuntu + macos), not container-only.
#
# @pattern patterns/code/gof/strategy.md — one function per invariant;
# same signature; caller composes via assert_lite_runtime umbrella.

# test-list:
# [ ] T01 assert_no_absolute_paths PASS — trace with only relative paths
# [ ] T02 assert_no_absolute_paths FAIL — trace with /Users/<name> absolute path
# [ ] T03 assert_no_absolute_paths FAIL — trace with /home/<name> absolute path
# [ ] T04 assert_no_absolute_paths MISSING — trace file does not exist
# [ ] T05 assert_bash_3_2_syntax PASS — script with POSIX test and no declare -A
# [ ] T06 assert_bash_3_2_syntax FAIL — script with declare -A assoc array
# [ ] T07 assert_bash_3_2_syntax FAIL — script with [[ double-bracket
# [ ] T08 assert_bash_3_2_syntax MISSING — script file does not exist
# [ ] T09 assert_no_pyyaml_required PASS — trace without pyyaml or ImportError
# [ ] T10 assert_no_pyyaml_required FAIL — trace with "import yaml" ImportError
# [ ] T11 assert_no_pyyaml_required FAIL — trace with "ModuleNotFoundError: No module named 'yaml'"
# [ ] T12 assert_no_playwright PASS — trace without playwright reference
# [ ] T13 assert_no_playwright FAIL — trace with "playwright" lowercase
# [ ] T14 assert_no_playwright FAIL — trace with "Playwright MCP" prose
# [ ] T15 assert_lite_runtime PASS — all 4 individual invariants pass on clean trace
# [ ] T16 assert_lite_runtime FAIL — one invariant fails; umbrella reports which

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
LIB="$REPO_ROOT/scripts/tests/lib/lite-runtime-invariants.sh"

if [[ ! -f "$LIB" ]]; then
  echo "FAIL: lib not found at $LIB"
  exit 1
fi
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

# ============================================================
# assert_no_absolute_paths
# ============================================================

echo "--- assert_no_absolute_paths ---"

# T01 — trace with only relative paths
trace="$TMP_BASE/t01.trace"
printf 'reading scripts/lib/foo.sh\nwriting docs/output.md\n' > "$trace"
out="$(assert_no_absolute_paths "$trace" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T01 rc"
assert_contains "$out" "PASS" "T01 PASS token"

# T02 — trace with user-home absolute path. Build at runtime per
# feedback_ccf3_test_fixtures memory — identifier-leak-scrub forbids
# the literal in source.
trace="$TMP_BASE/t02.trace"
printf 'reading %s/sam/project/foo.sh\n' "/Users" > "$trace"
out="$(assert_no_absolute_paths "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T02 rc"
assert_contains "$out" "FAIL" "T02 FAIL token"

# T03 — trace with Linux-home absolute path. Build at runtime.
trace="$TMP_BASE/t03.trace"
printf 'cd %s/louis/project\n' "/home" > "$trace"
out="$(assert_no_absolute_paths "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T03 rc"
assert_contains "$out" "FAIL" "T03 FAIL token"

# T04 — missing trace file
out="$(assert_no_absolute_paths "$TMP_BASE/missing.trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T04 missing rc"
assert_contains "$out" "MISSING" "T04 MISSING token"

# ============================================================
# assert_bash_3_2_syntax
# ============================================================

echo "--- assert_bash_3_2_syntax ---"

# T05 — bash 3.2 clean script
script="$TMP_BASE/t05.sh"
cat > "$script" <<'EOF'
#!/bin/bash
foo="bar"
if [ "$foo" = "bar" ]; then
  echo ok
fi
EOF
out="$(assert_bash_3_2_syntax "$script" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T05 rc"
assert_contains "$out" "PASS" "T05 PASS token"

# T06 — declare -A assoc array (bash 4+)
script="$TMP_BASE/t06.sh"
cat > "$script" <<'EOF'
#!/bin/bash
declare -A map
map[foo]=bar
EOF
out="$(assert_bash_3_2_syntax "$script" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T06 rc"
assert_contains "$out" "FAIL" "T06 FAIL token"

# T07 — [[ double-bracket (bashism, not strict POSIX)
script="$TMP_BASE/t07.sh"
cat > "$script" <<'EOF'
#!/bin/bash
foo="bar"
if [[ "$foo" == "bar" ]]; then
  echo ok
fi
EOF
out="$(assert_bash_3_2_syntax "$script" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T07 rc"
assert_contains "$out" "FAIL" "T07 FAIL token"

# T08 — missing script
out="$(assert_bash_3_2_syntax "$TMP_BASE/missing.sh" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T08 missing rc"
assert_contains "$out" "MISSING" "T08 MISSING token"

# ============================================================
# assert_no_pyyaml_required
# ============================================================

echo "--- assert_no_pyyaml_required ---"

# T09 — clean trace
trace="$TMP_BASE/t09.trace"
printf 'reading manifest.json\nparsing JSON cleanly\n' > "$trace"
out="$(assert_no_pyyaml_required "$trace" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T09 rc"
assert_contains "$out" "PASS" "T09 PASS token"

# T10 — ImportError on yaml
trace="$TMP_BASE/t10.trace"
printf 'Traceback (most recent call last):\n  File "lib/state.sh", line 42\nImportError: No module named yaml\n' > "$trace"
out="$(assert_no_pyyaml_required "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T10 rc"
assert_contains "$out" "FAIL" "T10 FAIL token"

# T11 — ModuleNotFoundError on yaml
trace="$TMP_BASE/t11.trace"
printf 'ModuleNotFoundError: No module named '\''yaml'\''\n' > "$trace"
out="$(assert_no_pyyaml_required "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T11 rc"
assert_contains "$out" "FAIL" "T11 FAIL token"

# ============================================================
# assert_no_playwright
# ============================================================

echo "--- assert_no_playwright ---"

# T12 — clean trace
trace="$TMP_BASE/t12.trace"
printf 'running /interpret-input\nwriting artifact\n' > "$trace"
out="$(assert_no_playwright "$trace" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T12 rc"
assert_contains "$out" "PASS" "T12 PASS token"

# T13 — lowercase playwright token
trace="$TMP_BASE/t13.trace"
printf 'using playwright for browser automation\n' > "$trace"
out="$(assert_no_playwright "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T13 rc"
assert_contains "$out" "FAIL" "T13 FAIL token"

# T14 — "Playwright MCP" prose
trace="$TMP_BASE/t14.trace"
printf 'Skill requires Playwright MCP to run\n' > "$trace"
out="$(assert_no_playwright "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T14 rc"
assert_contains "$out" "FAIL" "T14 FAIL token"

# ============================================================
# assert_lite_runtime — umbrella
# ============================================================

echo "--- assert_lite_runtime ---"

# T15 — all invariants pass
trace="$TMP_BASE/t15.trace"
printf 'reading manifest.json cleanly\nparsing docs/output.md\n' > "$trace"
out="$(assert_lite_runtime "$trace" 2>&1)"
rc=$?
assert_eq "0" "$rc" "T15 rc"
assert_contains "$out" "PASS" "T15 PASS token"

# T16 — one invariant fails; umbrella reports which. Build at runtime.
trace="$TMP_BASE/t16.trace"
printf 'reading %s/sam/foo.sh\n' "/Users" > "$trace"
out="$(assert_lite_runtime "$trace" 2>&1)"
rc=$?
assert_eq "1" "$rc" "T16 rc"
assert_contains "$out" "FAIL" "T16 FAIL token"
assert_contains "$out" "no-absolute-paths" "T16 names failing invariant"

# ============================================================
# summary
# ============================================================

echo ""
echo "============================================"
echo "lite-runtime-invariants.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
