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
# This driver asserts the RED signal is observed TODAY. When upstream
# cures the ticket (strip `declare -A`, use a while-read loop per the
# ticket body), and cli bundle-syncs, this test fails. That failure
# is the signal to flip semantics — the characterization is done; the
# ticket closes via /release-close-sweep.
#
# Walking skeleton for Session F per
# docs/next-session-plan-2026-10-05-session-f-driver-build-out.md L41-67.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (declare -A present in shipped bundle)
#   1  — GREEN-UNEXPECTED (declare -A gone; cure may have landed)
#   77 — SKIP (bundle not generated; run `npm run bundle` first)

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

if [[ "$match_count" -gt 0 ]]; then
  echo "RED-CONFIRMED|driver-306|${match_count} declare -A hit(s) in shipped SKILL.md"
  echo "PASS: #306 bash 3.2 break reproduces against shipped substrate"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-306|0 declare -A hits — upstream may have cured #306"
echo "FAIL: driver no longer RED — flip semantics to assert GREEN; verify ticket body"
exit 1
