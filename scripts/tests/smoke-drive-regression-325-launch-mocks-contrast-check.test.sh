#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-325-launch-mocks-contrast-check.test.sh
#
# Characterization driver — cli#325 /launch mocks have no contrast check.
#
# /launch generates mock directions. The shipped SKILL body carries zero
# references to contrast / wcag / 4.5:1 — the floor from usability rule
# item 6. A failing color (3.62:1) reached tokens unnoticed in a smoke run
# because the operator picked by eye.
#
# Driver asserts /launch SKILL has zero contrast references AND the
# usability rule still carries the 4.5:1 floor. When upstream adds a
# contrast step in Phase 4 or 10, driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (zero contrast refs + rule carries 4.5:1 floor)
#   1  — GREEN-UNEXPECTED (contrast step added OR rule removed floor)
#   77 — SKIP (bundle not generated)

set -euo pipefail

# test-list:
# [x] Case 1 — /launch SKILL has zero contrast references
# [x] Case 2 — usability rule carries the 4.5:1 floor
# [x] Case 3 — bundle-absent SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCH_SKILL="$REPO_ROOT/dist/lite/.claude/skills/launch/SKILL.md"
USABILITY_RULE="$REPO_ROOT/dist/lite/.claude/rules/usability.md"

if [[ ! -f "$LAUNCH_SKILL" ]] || [[ ! -f "$USABILITY_RULE" ]]; then
  echo "SKIP|driver-325|dist/lite launch SKILL or usability rule absent (run \`npm run bundle\` first)"
  exit 77
fi

# Case 1: /launch SKILL contrast reference count
contrast_count=$({ grep -ciE "contrast|wcag|4\.5[: ]1" "$LAUNCH_SKILL" 2>/dev/null || true; })
contrast_count=${contrast_count//[^0-9]/}; contrast_count=${contrast_count:-0}

# Case 2: usability rule carries 4.5:1 floor
floor_count=$({ grep -cE "4\.5:1" "$USABILITY_RULE" 2>/dev/null || true; })
floor_count=${floor_count//[^0-9]/}; floor_count=${floor_count:-0}

if [[ "$contrast_count" -eq 0 ]] && [[ "$floor_count" -gt 0 ]]; then
  echo "RED-CONFIRMED|driver-325|/launch SKILL contrast refs=${contrast_count} ; usability rule 4.5:1 floor count=${floor_count}"
  echo "PASS: #325 no-contrast-check reproduces"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-325|contrast=${contrast_count} floor=${floor_count}"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #325 close"
exit 1
