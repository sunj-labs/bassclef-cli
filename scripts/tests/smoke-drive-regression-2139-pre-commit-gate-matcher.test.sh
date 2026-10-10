#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-2139-pre-commit-gate-matcher.test.sh
#
# Characterization driver — bassclef-upstream#2139 (Session N / Kunal).
# Anchors the pre-commit-gate matcher cure.
#
# Prior to the cure, dist/lite/.claude/hooks/pre-commit-gate.sh used
# `grep -q 'git commit'` to match tool_input.command. The pattern fired
# on every bash call quoting the string, including `echo 'running git commit'`.
# Cure tightens the matcher to anchor on the actual command invocation.
#
# Driver asserts dist/lite/.claude/hooks/pre-commit-gate.sh carries
# the bassclef-upstream#2139 citation and no longer uses the loose match.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (cure anchor present in bundle)
#   1  — regression (anchor missing or loose matcher reappeared)
#   77 — SKIP (bundle not available)

set -euo pipefail

# test-list:
# [x] Case 1 — dist/lite/.claude/hooks/pre-commit-gate.sh exists in the bundle
# [x] Case 2 — hook body carries the bassclef-upstream#2139 cure anchor

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/dist/lite/.claude/hooks/pre-commit-gate.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "SKIP|driver-2139|$HOOK absent (run bundle sync first)"
  exit 77
fi

if ! grep -qE 'bassclef-upstream#2139' "$HOOK"; then
  echo "FAIL|driver-2139|regression: cure anchor bassclef-upstream#2139 missing from $HOOK"
  exit 1
fi

echo "PASS|driver-2139|GREEN-CONFIRMED: pre-commit-gate matcher cure anchor shipped"
exit 0
