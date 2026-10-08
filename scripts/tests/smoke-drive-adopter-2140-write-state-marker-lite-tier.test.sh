#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-2140-write-state-marker-lite-tier.test.sh
#
# Characterization driver — bassclef-upstream#2140 (Session N / Kunal).
# Anchors the write-state-marker helper tier retag cure.
#
# Prior to the cure, scripts/onboard-repo/write-state-marker.sh carried
# `tier: standard`, so lite adopters' bundlers excluded the helper. Skills
# that invoke it (e.g., /onboard-repo marker-write step) failed with
# "script not found". Cure retags the file to `tier: lite` so it ships in
# the lite bundle and skills can call it.
#
# Driver asserts dist/lite/.claude/skills/onboard-repo/write-state-marker.sh
# ships in the bundle and declares tier: lite.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (helper shipped at lite tier)
#   1  — regression (helper missing or still tagged standard)
#   77 — SKIP (bundle not available)

set -euo pipefail

# test-list:
# [x] Case 1 — dist/lite/.claude/skills/onboard-repo/write-state-marker.sh exists in the bundle
# [x] Case 2 — helper declares tier: lite in its header
# [x] Case 3 — helper carries the bassclef-upstream#2140 cure anchor

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$REPO_ROOT/dist/lite/.claude/skills/onboard-repo/write-state-marker.sh"

if [[ ! -f "$HELPER" ]]; then
  echo "FAIL|driver-2140|regression: $HELPER missing from bundle (cure retag reverted)"
  exit 1
fi

missing=()
grep -qE '^# tier: lite\b' "$HELPER" || missing+=("tier: lite header")
grep -qE 'bassclef-upstream#2140' "$HELPER" || missing+=("bassclef-upstream#2140 cure anchor")

if (( ${#missing[@]} > 0 )); then
  echo "FAIL|driver-2140|regression: cure anchors missing: ${missing[*]}"
  exit 1
fi

echo "PASS|driver-2140|GREEN-CONFIRMED: write-state-marker lite tier cure shipped"
exit 0
