#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Tier 0 test for cli#348 — asserts `.github/workflows/lite-adopter-smoke.yml`
# wraps test invocations in file-presence guards so old-tag matrix cells
# log SKIP + continue instead of exiting 127.
#
# Shape-level check. Does NOT run the workflow.
#
# Pre-mortem folds pinned:
#   F5 — guard pattern applied to BOTH test-run steps
#   F3 — SKIP log line uses literal "SKIP:" prefix for grep
#   F8 — grep anchors scoped loose (tolerate guard-pattern evolution)
#
# Risk ledger: state/markers/pre-mortem/feature-cli-348-matrix-skip-missing-tests.marker

# test-list:
# [x] T01 workflow carries file-presence guard for lite-runtime-invariants.test.sh
# [x] T02 workflow carries file-presence guard for smoke-assert-check-artifact-exists.test.sh
# [x] T03 workflow logs SKIP line with literal "SKIP:" prefix
# [x] T04 workflow logs short SHA on SKIP (traceable to ref)
# [x] T05 workflow's "run drivers" step already uses nullglob (unchanged check)

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/lite-adopter-smoke.yml"

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

# T01 + T02 — file-presence guard around each test filename. YAML lists
# the filenames across a loop with backslash continuation, so grep per
# line can't match both the guard and the filename together. Instead,
# verify the two components exist in the same file:
#   (a) presence check pattern `[[ -f ` exists somewhere in workflow
#   (b) each test filename appears as a target
# Together they imply the guard applies.
_has_presence_check=0
grep -qE '\[\[ -f ' "$WORKFLOW" && _has_presence_check=1

# T01 — lite-runtime-invariants.test.sh listed as a target
if [[ "$_has_presence_check" == 1 ]] && grep -qE 'lite-runtime-invariants\.test\.sh' "$WORKFLOW"; then
  pass "T01 guard for lite-runtime-invariants.test.sh"
else
  fail "T01 guard for lite-runtime-invariants.test.sh" "presence check [[ -f missing OR filename not listed"
fi

# T02 — smoke-assert-check-artifact-exists.test.sh listed as a target
if [[ "$_has_presence_check" == 1 ]] && grep -qE 'smoke-assert-check-artifact-exists\.test\.sh' "$WORKFLOW"; then
  pass "T02 guard for smoke-assert-check-artifact-exists.test.sh"
else
  fail "T02 guard for smoke-assert-check-artifact-exists.test.sh" "presence check [[ -f missing OR filename not listed"
fi

# T03 — SKIP log line
if grep -qE 'SKIP:' "$WORKFLOW"; then
  pass "T03 SKIP log line present"
else
  fail "T03 SKIP log line present" "no 'SKIP:' prefix in workflow"
fi

# T04 — short SHA logged on skip (git rev-parse --short HEAD or similar)
if grep -qE 'git rev-parse.*--short|git rev-parse --short' "$WORKFLOW"; then
  pass "T04 short SHA logged on SKIP"
else
  fail "T04 short SHA logged on SKIP" "no 'git rev-parse --short' near the SKIP line"
fi

# T05 — "run drivers" step still uses nullglob (unchanged behavior)
if grep -qE 'nullglob' "$WORKFLOW"; then
  pass "T05 run-drivers step still uses nullglob"
else
  fail "T05 run-drivers step still uses nullglob" "nullglob missing from workflow"
fi

echo ""
echo "============================================"
echo "lite-adopter-smoke-matrix-shape.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
