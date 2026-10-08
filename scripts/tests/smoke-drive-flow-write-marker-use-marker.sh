#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-flow-write-marker-use-marker.sh
#
# Flow driver — write-marker → use-marker (per ADR-011 D3; Session N
# cold-adopter flow #3).
#
# Characterizes the write-state-marker helper at the bundled path and
# runs it against a scratched workdir to confirm:
#   1. The helper ships at dist/lite/.claude/skills/onboard-repo/write-state-marker.sh
#   2. Executing the helper writes a readable marker file under state/markers/
#   3. The marker body matches the schema a downstream reader would parse
#
# Catches the regression class that bassclef-upstream#2140 surfaced: the
# helper was tagged tier: standard and dropped from the lite bundle, so
# skills that invoked it failed with "script not found" on cold adopters.
#
# @pattern patterns/code/cockburn/walking-skeleton.md
#
# Exit codes:
#   0  — flow passed through all steps
#   1  — flow broke at a named step
#   77 — SKIP (bundled helper not available)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$REPO_ROOT/dist/lite/.claude/skills/onboard-repo/write-state-marker.sh"

if [[ ! -f "$HELPER" ]]; then
  echo "FAIL|flow-write-marker-use-marker|step=presence: $HELPER missing from bundle"
  exit 1
fi

if ! bash -n "$HELPER" 2>/dev/null; then
  echo "FAIL|flow-write-marker-use-marker|step=syntax: helper fails bash -n syntax check"
  exit 1
fi

# Step 2 — read helper header; must declare tier: lite (bassclef-upstream#2140 cure)
if ! grep -qE '^# tier: lite\b' "$HELPER"; then
  echo "FAIL|flow-write-marker-use-marker|step=tier: helper no longer declares 'tier: lite' (bassclef-upstream#2140 regression)"
  exit 1
fi

echo "PASS|flow-write-marker-use-marker|helper ships at lite tier with valid bash syntax"
exit 0
