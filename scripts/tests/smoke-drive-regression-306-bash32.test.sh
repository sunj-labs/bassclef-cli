#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-306-bash32.test.sh
#
# Characterization driver — cli#306 /onboard-repo label step fails on
# macOS bash 3.2. The Phase 1.1 block in dist/lite/.claude/skills/
# onboard-repo/SKILL.md uses `declare -A LABELS=(...)`. macOS ships
# bash 3.2 which has no associative arrays. Adopter runs the block,
# bash errors, no labels get created, script keeps going.
#
# This driver asserts the GREEN signal: #306 cure is present in the
# shipped bundle. Session G bundle sync (v1.7.0 → v1.7.1) brought the
# upstream cure for #306 (strip `declare -A`, use a while-read loop).
# From Session G forward this driver is a durable regression anchor —
# if a future bundle sync ever re-ships `declare -A` in this SKILL.md,
# the driver fails loud and surfaces the regression on CI.
#
# Semantics flipped in Session G per
# docs/next-session-plan-2026-10-05-session-g-v1-7-1-bundle-sync.md L48.
# Walking skeleton origin: Session F per
# docs/next-session-plan-2026-10-05-session-f-driver-build-out.md L41-67.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (0 declare -A hits; cure present in shipped bundle)
#   1  — RED-REGRESSION (declare -A back in shipped bundle; cure regressed)
#   77 — SKIP (bundle not generated; run prepublish script first)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/dist/lite/.claude/skills/onboard-repo/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "SKIP|driver-306|bundle not generated (run \`npm run bundle\` first)"
  exit 77
fi

# Narrow grep per risk ledger F1 fold — match `declare -A` at the
# start of a line (optionally indented). Does NOT match `[[` from
# markdown examples; does NOT match free-form prose that references
# declare -A.
match_count=$(grep -cE '^[[:space:]]*declare[[:space:]]+-A' "$SKILL_FILE" 2>/dev/null || echo 0)
match_count=${match_count//[^0-9]/}
match_count=${match_count:-0}

if [[ "$match_count" -eq 0 ]]; then
  echo "GREEN-CONFIRMED|driver-306|0 declare -A hits — cure present in shipped SKILL.md"
  echo "PASS: #306 cure holds; shipped substrate uses no bash 3.2 associative arrays"
  exit 0
fi

echo "RED-REGRESSION|driver-306|${match_count} declare -A hit(s) returned in shipped SKILL.md"
echo "FAIL: #306 regressed — bash 3.2 break is back in shipped substrate"
exit 1
