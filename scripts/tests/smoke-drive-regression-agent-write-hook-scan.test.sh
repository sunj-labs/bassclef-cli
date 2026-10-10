#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-flow-agent-write-hook-scan.sh
#
# Flow driver — agent-write → hook-scan (per ADR-011 D3; Session N
# cold-adopter flow #4).
#
# Characterizes the pre-commit-gate matcher cure (bassclef-upstream#2139).
# Prior to the cure, the matcher fired on every bash call that contained
# the literal string "git commit" — including `echo 'running git commit'`.
# Cure tightens the matcher to anchor on the actual command invocation.
#
# Flow asserts the shipped hook at dist/lite/.claude/hooks/pre-commit-gate.sh:
#   1. Ships in the bundle
#   2. Passes bash -n syntax check
#   3. Carries the bassclef-upstream#2139 cure anchor comment
#   4. Does NOT contain the specific pre-cure loose matcher `grep -q 'git commit'`
#      WITHOUT additional specificity around it
#
# @pattern patterns/code/cockburn/walking-skeleton.md
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — flow passed through all steps
#   1  — flow broke at a named step
#   77 — SKIP (bundled hook not available)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/dist/lite/.claude/hooks/pre-commit-gate.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "SKIP|flow-agent-write-hook-scan|$HOOK absent (run bundle sync first)"
  exit 77
fi

if ! bash -n "$HOOK" 2>/dev/null; then
  echo "FAIL|flow-agent-write-hook-scan|step=syntax: hook fails bash -n syntax check"
  exit 1
fi

if ! grep -qE 'bassclef-upstream#2139' "$HOOK"; then
  echo "FAIL|flow-agent-write-hook-scan|step=anchor: bassclef-upstream#2139 cure anchor missing"
  exit 1
fi

# The hook's cure comment should name the prior loose matcher explicitly.
# If the comment disappears, the cure's documentation surface is at risk.
if ! grep -qE "prior matcher.*git commit" "$HOOK"; then
  echo "FAIL|flow-agent-write-hook-scan|step=context: cure anchor missing 'prior matcher' context note"
  exit 1
fi

echo "PASS|flow-agent-write-hook-scan|pre-commit-gate matcher cure anchor + context shipped"
exit 0
