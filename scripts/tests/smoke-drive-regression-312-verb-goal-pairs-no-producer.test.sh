#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-312-verb-goal-pairs-no-producer.test.sh
#
# Characterization driver — cli#312 structural_hints.verb_goal_pairs has
# no producer.
#
# /build fills its plain-English plan from structural_hints.verb_goal_pairs
# in the InputArtifact. /launch + /objectory-decompose read structural_hints
# too. Nothing writes verb_goal_pairs. Text input leaves structural_hints
# as {}, repo input fills 5 other keys. Every paragraph-driven /launch →
# /build run hits those templates with nothing to fill.
#
# Driver counts reads vs writes of verb_goal_pairs across the shipped
# bundle AND cli's own scripts/lib/hooks. RED when reads > 0 AND writes = 0.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (reads exist; no writer)
#   1  — GREEN-UNEXPECTED (writer added OR reads removed)
#   77 — SKIP (bundle not generated)

set -euo pipefail

# test-list:
# [x] Case 1 — /build SKILL reads structural_hints.verb_goal_pairs
# [x] Case 2 — no producer writes verb_goal_pairs anywhere in bundle or cli
# [x] Case 3 — bundle-absent SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SKILL="$REPO_ROOT/dist/lite/.claude/skills/build/SKILL.md"

if [[ ! -f "$BUILD_SKILL" ]]; then
  echo "SKIP|driver-312|$BUILD_SKILL absent (run \`npm run bundle\` first)"
  exit 77
fi

# Case 1: reads in build SKILL
reads=$(grep -cE "structural_hints\.verb_goal_pairs|verb_goal_pairs" "$BUILD_SKILL" 2>/dev/null || echo 0)
reads=${reads//[^0-9]/}; reads=${reads:-0}

# Case 2: writers across cli's own scripts/lib + the full lite bundle
# A writer sets the key — detect assignment pattern
writers=0
# cli-side producers (grep exits 1 when zero matches; swallow)
cli_writers=$({ grep -rlE 'verb_goal_pairs"[[:space:]]*:|verb_goal_pairs[[:space:]]*=' "$REPO_ROOT/scripts" "$REPO_ROOT/lib" 2>/dev/null || true; } | wc -l | tr -d ' ')
cli_writers=${cli_writers:-0}
# bundle producers (any hook or lib under dist/lite)
bundle_writers=$({ grep -rlE 'verb_goal_pairs"[[:space:]]*:|verb_goal_pairs[[:space:]]*=' "$REPO_ROOT/dist/lite/.claude/hooks" 2>/dev/null || true; } | wc -l | tr -d ' ')
bundle_writers=${bundle_writers:-0}
writers=$((cli_writers + bundle_writers))

if [[ "$reads" -gt 0 ]] && [[ "$writers" -eq 0 ]]; then
  echo "RED-CONFIRMED|driver-312|verb_goal_pairs reads=${reads} writers=${writers} (schema asymmetry)"
  echo "PASS: #312 verb_goal_pairs no-producer reproduces"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-312|reads=${reads} writers=${writers}"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #312 close"
exit 1
