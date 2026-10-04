#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Tier 0 test for cli#340 — asserts .github/workflows/lite-adopter-smoke.yml
# carries pull_request trigger + paths filter + concurrency block per
# UC-script-cli-340-lite-smoke-pr-trigger.md.
#
# Shape-level check. Does NOT run the workflow. GHA runtime behavior
# stays untested at Tier 0 per `.claude/rules/testing-tier-config.md`
# (workflows are Tier 2 smoke — the workflow IS the test).
#
# Pre-mortem folds pinned:
#   F1 — paths filter scoped to workflow + driver + lib paths
#   F6 — concurrency block cancels superseded runs
#   F7 — nightly schedule unchanged (additive)
#
# Risk ledger: state/markers/pre-mortem/feature-cli-340-lite-smoke-pr-trigger.marker

# test-list:
# [x] T01 workflow file exists at expected path
# [x] T02 workflow carries `on.pull_request` trigger
# [x] T03 pull_request block has `paths:` filter
# [x] T04 paths filter includes workflow file glob
# [x] T05 paths filter includes smoke-drive-e2e-*.test.sh glob
# [x] T06 paths filter includes invariants lib + smoke-assert lib
# [x] T07 concurrency block exists (F6 fold)
# [x] T08 nightly schedule unchanged (F7 fold — additive)
# [x] T09 tag push trigger unchanged (F7 fold — additive)
# [x] T10 workflow_dispatch trigger unchanged (F7 fold — additive)

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

# T01 — workflow file exists
if [[ -f "$WORKFLOW" ]]; then
  pass "T01 workflow file exists"
else
  fail "T01 workflow file exists" "not found at $WORKFLOW"
  echo "FATAL: cannot proceed without workflow file"
  exit 1
fi

# T02 — pull_request trigger block exists
if grep -qE '^  pull_request:' "$WORKFLOW"; then
  pass "T02 on.pull_request trigger"
else
  fail "T02 on.pull_request trigger" "missing 'pull_request:' at top of 'on:' block"
fi

# T03 — pull_request block carries paths filter.
# Extract the pull_request block via awk (from 'pull_request:' to next sibling key or dedent).
PR_BLOCK=$(awk '
  /^  pull_request:/ {in_pr=1; print; next}
  in_pr && /^  [a-zA-Z_]+:/ {in_pr=0}
  in_pr {print}
' "$WORKFLOW")
if echo "$PR_BLOCK" | grep -qE '^[[:space:]]+paths:'; then
  pass "T03 pull_request has paths filter"
else
  fail "T03 pull_request has paths filter" "no 'paths:' key under pull_request block"
fi

# T04 — paths filter includes workflow file glob
if echo "$PR_BLOCK" | grep -qE '\.github/workflows/lite-adopter-smoke\.yml'; then
  pass "T04 paths includes workflow file glob"
else
  fail "T04 paths includes workflow file glob" "no workflow file ref under paths"
fi

# T05 — paths filter includes driver glob
if echo "$PR_BLOCK" | grep -qE 'scripts/tests/smoke-drive-e2e-\*|scripts/tests/smoke-drive-e2e'; then
  pass "T05 paths includes driver glob"
else
  fail "T05 paths includes driver glob" "no smoke-drive-e2e-*.test.sh ref under paths"
fi

# T06 — paths filter includes invariants lib + smoke-assert lib
if echo "$PR_BLOCK" | grep -qE 'lite-runtime-invariants|smoke-assert\.sh'; then
  pass "T06 paths includes lib files"
else
  fail "T06 paths includes lib files" "no invariants/smoke-assert lib refs under paths"
fi

# T07 — concurrency block exists (F6 fold — cancel superseded runs on force-push)
if grep -qE '^concurrency:' "$WORKFLOW"; then
  pass "T07 concurrency block exists (F6 fold)"
else
  fail "T07 concurrency block exists (F6 fold)" "no top-level 'concurrency:' key"
fi

# T08 — nightly schedule unchanged (F7 fold — additive)
if grep -qE "^    - cron: '0 7 \* \* \*'" "$WORKFLOW"; then
  pass "T08 nightly schedule unchanged"
else
  fail "T08 nightly schedule unchanged" "cron '0 7 * * *' missing or edited"
fi

# T09 — tag push trigger unchanged
if awk '
  /^  push:/ {in_push=1; next}
  in_push && /^  [a-zA-Z_]+:/ {in_push=0}
  in_push && /^[[:space:]]+-[[:space:]]+.v\*./ {found=1}
  END {exit !found}
' "$WORKFLOW"; then
  pass "T09 tag push trigger unchanged"
else
  fail "T09 tag push trigger unchanged" "tag 'v*' pattern missing under push block"
fi

# T10 — workflow_dispatch trigger unchanged
if grep -qE '^  workflow_dispatch:' "$WORKFLOW"; then
  pass "T10 workflow_dispatch trigger unchanged"
else
  fail "T10 workflow_dispatch trigger unchanged" "workflow_dispatch missing"
fi

echo ""
echo "============================================"
echo "lite-adopter-smoke-workflow-shape.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
