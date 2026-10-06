#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/smoke-drive-e2e-launch-jamie.test.sh
#
# Session K PR 6 per docs/plans/tier-a-dynamic-driver-roadmap.md.
# Fifth Tier A chain driver. Sources chain helper + persona-assert.
#
# Persona: Jamie — positioning + maturity reader. Reads /launch output
# (mock gallery + buildable spec + INVEST stories) for the 90-second
# "serious effort" signal. Decides worth-bookmark vs demo-ware.
#
# @pattern patterns/code/feathers/characterization-test.md

set -uo pipefail

# test-list:
# [x] T01 golden passes end + experience + life — 3 variants + spec + 3 stories, under 40 lines
# [x] T02 bad-jargon fails ONLY experience — wordlist terms in variant descriptions
# [x] T03 bad-wall fails ONLY life — full typography + palette + per-variant spec exceeds scan ceiling
# [x] persona-assert absent -> SKIP
# [x] claude-chain absent -> SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PERSONA_LIB="$REPO_ROOT/scripts/lib/persona-assert.sh"
CHAIN_LIB="$REPO_ROOT/scripts/lib/claude-chain.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/jamie-launch"

if [[ ! -f "$PERSONA_LIB" ]]; then
  echo "SKIP|session-k-jamie-launch|$PERSONA_LIB absent"
  exit 77
fi
if [[ ! -f "$CHAIN_LIB" ]]; then
  echo "SKIP|session-k-jamie-launch|$CHAIN_LIB absent"
  exit 77
fi

# shellcheck source=../lib/persona-assert.sh
source "$PERSONA_LIB"
# shellcheck source=../lib/claude-chain.sh
source "$CHAIN_LIB"

PASS=0; FAIL=0; FAIL_MSGS=()

GOLDEN="$FIX_DIR/golden-capture.txt"
BAD_JARGON="$FIX_DIR/bad-jargon-capture.txt"
BAD_WALL="$FIX_DIR/bad-wall-capture.txt"

# T01 golden passes all 3
if persona_assert_end_goal "$GOLDEN" "Variant A" 0 2>/dev/null \
    && persona_assert_experience_goal "$GOLDEN" 2>/dev/null \
    && persona_assert_life_goal "$GOLDEN" 40 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 — golden should pass all 3 Cooper goals")
fi

# T02 bad-jargon
BJ_END=0; BJ_EXP=0; BJ_LIFE=0
persona_assert_end_goal "$BAD_JARGON" "Variant A" 0 2>/dev/null && BJ_END=1
persona_assert_experience_goal "$BAD_JARGON" 2>/dev/null && BJ_EXP=1
persona_assert_life_goal "$BAD_JARGON" 40 2>/dev/null && BJ_LIFE=1
if [[ "$BJ_END" == "1" && "$BJ_EXP" == "0" && "$BJ_LIFE" == "1" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 — bad-jargon end=$BJ_END exp=$BJ_EXP life=$BJ_LIFE")
fi

# T03 bad-wall
BW_END=0; BW_EXP=0; BW_LIFE=0
persona_assert_end_goal "$BAD_WALL" "Variant A" 0 2>/dev/null && BW_END=1
persona_assert_experience_goal "$BAD_WALL" 2>/dev/null && BW_EXP=1
persona_assert_life_goal "$BAD_WALL" 40 2>/dev/null && BW_LIFE=1
if [[ "$BW_END" == "1" && "$BW_EXP" == "1" && "$BW_LIFE" == "0" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 — bad-wall end=$BW_END exp=$BW_EXP life=$BW_LIFE")
fi

echo ""
echo "===== smoke-drive-e2e-launch-jamie.test.sh ====="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MSGS[@]}"; do echo "  $msg"; done
  exit 1
fi
exit 0
