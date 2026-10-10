#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-332-hosting-platform.test.sh
#
# Characterization driver — cli#332 hosting_platform cure across 3 skills.
# Upstream PR #2070 (merged 2026-10-04T21:45:22Z) landed cure markers in:
#   - dist/lite/.claude/skills/launch/SKILL.md     — Phase 0b hosting ask
#   - dist/lite/.claude/skills/build/SKILL.md      — Phase 7 branches
#   - dist/lite/.claude/skills/deploy-prod/SKILL.md — tier contract block
#
# Each cure block carries an HTML comment anchor `cli#332 cure`.
# Driver greps all 3 files for the anchor. All present after v1.7.1
# bundle sync landed. Driver asserts all 3 of 3 anchors remain
# present; any drop below 3 is a regression.
#
# Semantics flipped in Session G per
# docs/next-session-plan-2026-10-05-session-g-v1-7-1-bundle-sync.md L48.
# Session F origin — peer bassclef-upstream-9b priorities 2 + 3 (2026-10-05).
# Pattern matches #306 and #331 drivers.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (all 3 anchors present; cure holds)
#   1  — RED-REGRESSION (one or more anchors removed; cure regressed)
#   77 — SKIP (any one skill file absent in bundle)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SKILL_LAUNCH="$REPO_ROOT/dist/lite/.claude/skills/launch/SKILL.md"
SKILL_BUILD="$REPO_ROOT/dist/lite/.claude/skills/build/SKILL.md"
SKILL_DEPLOY="$REPO_ROOT/dist/lite/.claude/skills/deploy-prod/SKILL.md"

for f in "$SKILL_LAUNCH" "$SKILL_BUILD" "$SKILL_DEPLOY"; do
  if [[ ! -f "$f" ]]; then
    echo "SKIP|driver-332|$f absent (run \`npm run bundle\` first)"
    exit 77
  fi
done

# Count anchor hits per file. The cure marker is the HTML comment that
# names cli#332; it is the authoritative source-of-truth tag per PR #2070.
count_launch=$(grep -cE 'cli#332 cure' "$SKILL_LAUNCH" 2>/dev/null || echo 0)
count_build=$(grep -cE 'cli#332 cure' "$SKILL_BUILD" 2>/dev/null || echo 0)
count_deploy=$(grep -cE 'cli#332 cure' "$SKILL_DEPLOY" 2>/dev/null || echo 0)

count_launch=${count_launch//[^0-9]/}; count_launch=${count_launch:-0}
count_build=${count_build//[^0-9]/}; count_build=${count_build:-0}
count_deploy=${count_deploy//[^0-9]/}; count_deploy=${count_deploy:-0}

skills_with_cure=0
[[ "$count_launch" -gt 0 ]] && skills_with_cure=$((skills_with_cure + 1))
[[ "$count_build" -gt 0 ]] && skills_with_cure=$((skills_with_cure + 1))
[[ "$count_deploy" -gt 0 ]] && skills_with_cure=$((skills_with_cure + 1))

if [[ "$skills_with_cure" -eq 3 ]]; then
  echo "GREEN-CONFIRMED|driver-332|3 of 3 shipped skills carry cli#332 cure anchor (launch=${count_launch} build=${count_build} deploy-prod=${count_deploy})"
  echo "PASS: #332 cure holds across all 3 adopter-visible surfaces"
  exit 0
fi

echo "RED-REGRESSION|driver-332|only ${skills_with_cure} of 3 shipped skills carry cli#332 cure anchor (launch=${count_launch} build=${count_build} deploy-prod=${count_deploy}) — cure regressed on one or more surfaces"
echo "FAIL: #332 regressed — one or more surfaces dropped the cli#332 cure anchor"
exit 1
