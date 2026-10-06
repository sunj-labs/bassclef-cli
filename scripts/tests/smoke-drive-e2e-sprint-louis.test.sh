#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/smoke-drive-e2e-sprint-louis.test.sh
#
# Session K PR 4 per docs/plans/tier-a-dynamic-driver-roadmap.md.
# Third Tier A chain driver. Rides scripts/lib/persona-assert.sh.
#
# Persona: Louis — context switcher. Has bassclef installed. Picks up
# a project after days away. Runs /sprint first to orient on in-flight
# work before deciding whether to dispatch /longrun prep.
#
# Covers 3 fixture-pinned cases:
#   T01 — golden fixture passes all 3 Cooper goal levels
#   T02 — bad-jargon fixture fails experience goal (dancing-bear catch)
#   T03 — bad-wall fixture fails life goal (output exceeds 40-line scan ceiling)
#
# Fixtures provenance: hand-crafted scaffold at 2026-10-07. Replace with
# live captures from docker cold-adopter once operator OAuth refresh
# (cli#380 / PR #381) lands clean. See scripts/tests/fixtures/louis-sprint/README.md.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — all 3 cases PASS
#   1  — one or more cases FAIL
#   77 — SKIP (persona-assert.sh missing)

set -uo pipefail

# test-list:
# [x] T01 golden fixture passes end + experience + life
# [x] T02 bad-jargon fails ONLY experience (dancing-bear catch — operationalize + load-bearing + primitive + blast radius + composer)
# [x] T03 bad-wall fails ONLY life (output exceeds 40-line scan ceiling for Louis's 90s budget)
# [x] persona-assert lib absent -> SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/persona-assert.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/louis-sprint"

if [[ ! -f "$LIB" ]]; then
  echo "SKIP|session-k-louis-sprint|$LIB absent"
  exit 77
fi

# shellcheck source=../lib/persona-assert.sh
source "$LIB"

PASS=0
FAIL=0
FAIL_MSGS=()

GOLDEN="$FIX_DIR/golden-capture.txt"
BAD_JARGON="$FIX_DIR/bad-jargon-capture.txt"
BAD_WALL="$FIX_DIR/bad-wall-capture.txt"

# ---------------------------------------------------------------------
# T01 — golden passes all 3 (end + experience + life)
# ---------------------------------------------------------------------
if persona_assert_end_goal "$GOLDEN" "Active goal:" 0 2>/dev/null \
    && persona_assert_experience_goal "$GOLDEN" 2>/dev/null \
    && persona_assert_life_goal "$GOLDEN" 40 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 — golden should pass all 3 Cooper goals")
fi

# ---------------------------------------------------------------------
# T02 — bad-jargon passes end + life; FAILS experience (jargon)
# ---------------------------------------------------------------------
BJ_END=0
BJ_EXP=0
BJ_LIFE=0
persona_assert_end_goal "$BAD_JARGON" "Active goal:" 0 2>/dev/null && BJ_END=1
persona_assert_experience_goal "$BAD_JARGON" 2>/dev/null && BJ_EXP=1
persona_assert_life_goal "$BAD_JARGON" 40 2>/dev/null && BJ_LIFE=1

if [[ "$BJ_END" == "1" && "$BJ_EXP" == "0" && "$BJ_LIFE" == "1" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 — bad-jargon should pass end+life, FAIL experience; got end=$BJ_END exp=$BJ_EXP life=$BJ_LIFE")
fi

# ---------------------------------------------------------------------
# T03 — bad-wall passes end + experience; FAILS life (over 40 lines)
# ---------------------------------------------------------------------
BW_END=0
BW_EXP=0
BW_LIFE=0
persona_assert_end_goal "$BAD_WALL" "Active goal:" 0 2>/dev/null && BW_END=1
persona_assert_experience_goal "$BAD_WALL" 2>/dev/null && BW_EXP=1
persona_assert_life_goal "$BAD_WALL" 40 2>/dev/null && BW_LIFE=1

if [[ "$BW_END" == "1" && "$BW_EXP" == "1" && "$BW_LIFE" == "0" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 — bad-wall should pass end+experience, FAIL life; got end=$BW_END exp=$BW_EXP life=$BW_LIFE")
fi

# ---------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------
echo ""
echo "===== smoke-drive-e2e-sprint-louis.test.sh ====="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MSGS[@]}"; do
    echo "  $msg"
  done
  exit 1
fi
exit 0
