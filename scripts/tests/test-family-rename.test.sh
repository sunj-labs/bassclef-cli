#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/test-family-rename.test.sh
#
# Tier 0 characterization + fix test for cli#407 — test family rename.
# Keeps smoke-drive-e2e-* (dev-standard). Renames smoke-drive-adopter-*
# to smoke-drive-regression-*. Collapses 3 of 4 smoke-drive-flow-* into
# the regression family. Keeps 1 flow (install-first-commit) as a real
# flow test.
#
# Beck RED-first: fails against pre-rename state; passes after rename
# lands plus symlink aliases plus ADR-011 update plus CI workflow glob
# update.
#
# @pattern patterns/code/feathers/characterization-test.md

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS_DIR="$REPO_ROOT/scripts/tests"
ADR_FILE="$REPO_ROOT/docs/adrs/ADR-011-cli-side-cure-anchor-drivers-and-flow-layer.md"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/lite-adopter-smoke.yml"

# test-list:
# [x] T01 at least 21 smoke-drive-regression-*.test.sh files exist
# [x] T02 no smoke-drive-adopter-*.test.sh REGULAR files (symlinks ok)
# [x] T03 smoke-drive-regression-launch-local-serve-phone.test.sh exists (from flow)
# [x] T04 smoke-drive-regression-write-marker-use-marker.test.sh exists (from flow)
# [x] T05 smoke-drive-regression-agent-write-hook-scan.test.sh exists (from flow)
# [x] T06 smoke-drive-flow-install-first-commit.sh stays as flow
# [x] T07 workflow glob includes smoke-drive-regression-*.test.sh
# [x] T08 ADR-011 body uses "regression" vocabulary

PASS=0
FAIL=0
FAIL_MSGS=()

fail() { FAIL=$((FAIL + 1)); FAIL_MSGS+=("$1"); }
ok()   { PASS=$((PASS + 1)); }

# T01 — regression file count
REGRESSION_COUNT=$(ls "$TESTS_DIR"/smoke-drive-regression-*.test.sh 2>/dev/null | wc -l | tr -d ' ')
if [ "$REGRESSION_COUNT" -ge 21 ]; then
  ok
else
  fail "T01: expected ≥21 smoke-drive-regression-*.test.sh files; got $REGRESSION_COUNT"
fi

# T02 — no adopter REGULAR files; symlinks ok
ADOPTER_REGULAR=0
for f in "$TESTS_DIR"/smoke-drive-adopter-*.test.sh; do
  [ -e "$f" ] || continue
  if [ -f "$f" ] && [ ! -L "$f" ]; then
    ADOPTER_REGULAR=$((ADOPTER_REGULAR + 1))
  fi
done
if [ "$ADOPTER_REGULAR" -eq 0 ]; then
  ok
else
  fail "T02: $ADOPTER_REGULAR smoke-drive-adopter-*.test.sh files are regular (should be renamed; symlinks ok)"
fi

# T03-T05 — flow files collapsed into regression
for sub in launch-local-serve-phone write-marker-use-marker agent-write-hook-scan; do
  if [ -e "$TESTS_DIR/smoke-drive-regression-$sub.test.sh" ]; then
    ok
  else
    fail "T03-5: missing smoke-drive-regression-$sub.test.sh (expected from flow rename)"
  fi
done

# T06 — the one real flow stays
if [ -e "$TESTS_DIR/smoke-drive-flow-install-first-commit.sh" ]; then
  ok
else
  fail "T06: smoke-drive-flow-install-first-commit.sh should stay as a real flow test"
fi

# T07 — workflow glob includes regression
if grep -q "smoke-drive-regression-\*.test.sh" "$WORKFLOW_FILE"; then
  ok
else
  fail "T07: $WORKFLOW_FILE missing smoke-drive-regression-*.test.sh glob"
fi

# T08 — ADR-011 uses "regression" vocabulary
if grep -q "regression" "$ADR_FILE"; then
  ok
else
  fail "T08: ADR-011 missing 'regression' vocabulary"
fi

echo "pass=$PASS fail=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  %s\n' "${FAIL_MSGS[@]}"
  exit 1
fi
exit 0
