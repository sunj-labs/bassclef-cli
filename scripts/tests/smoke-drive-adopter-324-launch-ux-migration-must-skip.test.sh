#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-324-launch-ux-migration-must-skip.test.sh
#
# Characterization driver — cli#324 /launch vs /ux-migration conflict.
#
# /launch Phase 11 calls /ux-migration "the MUST gate". /ux-migration's
# own table says "Skip for greenfield — prototype is the spec". For a new
# app the agent is told to run a skill that tells it not to run.
#
# Driver asserts both halves of the conflict ship together in the lite
# bundle. When upstream rewrites /launch Phase 11 to pass "run Step 3b+3c
# only for greenfield", driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (both patterns ship together)
#   1  — GREEN-UNEXPECTED (cure landed)
#   77 — SKIP (bundle not generated)

set -euo pipefail

# test-list:
# [x] Case 1 — /launch Phase 11 names /ux-migration as a MUST gate
# [x] Case 2 — /ux-migration body carries "Skip for greenfield" row
# [x] Case 3 — bundle-absent SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCH_SKILL="$REPO_ROOT/dist/lite/.claude/skills/launch/SKILL.md"
UX_SKILL="$REPO_ROOT/dist/lite/.claude/skills/ux-migration/SKILL.md"

if [[ ! -f "$LAUNCH_SKILL" ]] || [[ ! -f "$UX_SKILL" ]]; then
  echo "SKIP|driver-324|dist/lite launch or ux-migration SKILL absent (run \`npm run bundle\` first)"
  exit 77
fi

# Case 1: /launch Phase 11 names /ux-migration MUST
count_must=$(grep -cE "/ux-migration[^A-Za-z].*MUST[[:space:]]*gate|MUST[[:space:]]*gate[^.]*ux-migration" "$LAUNCH_SKILL" 2>/dev/null || echo 0)
count_must=${count_must//[^0-9]/}; count_must=${count_must:-0}

# Case 2: /ux-migration body carries "Skip for greenfield"
count_skip=$(grep -cE "Skip.*greenfield|Greenfield.*Skip|greenfield.*prototype is the spec" "$UX_SKILL" 2>/dev/null || echo 0)
count_skip=${count_skip//[^0-9]/}; count_skip=${count_skip:-0}

if [[ "$count_must" -gt 0 ]] && [[ "$count_skip" -gt 0 ]]; then
  echo "RED-CONFIRMED|driver-324|/launch calls /ux-migration MUST (${count_must}) + /ux-migration says Skip-greenfield (${count_skip})"
  echo "PASS: #324 MUST-vs-skip conflict reproduces"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-324|/launch MUST count=${count_must}; /ux-migration Skip count=${count_skip}"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #324 close"
exit 1
