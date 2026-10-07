#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/smoke-drive-e2e-build-jamie.test.sh
#
# Session K PR 7 — final Tier A driver. Harness covers 7 of 7 after merge.
#
# Persona: Jamie reads /build output (PRs opened, verify report,
# reviewer signoff, prod gate) for 90s "serious effort" signal.
#
# @pattern patterns/code/feathers/characterization-test.md

set -uo pipefail

# test-list:
# [x] T01 golden passes end + experience + life
# [x] T02 bad-jargon fails ONLY experience
# [x] T03 bad-wall fails ONLY life
# [x] persona-assert absent -> SKIP
# [x] claude-chain absent -> SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PERSONA_LIB="$REPO_ROOT/scripts/lib/persona-assert.sh"
CHAIN_LIB="$REPO_ROOT/scripts/lib/claude-chain.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/jamie-build"

if [[ ! -f "$PERSONA_LIB" ]]; then echo "SKIP|session-k-jamie-build|$PERSONA_LIB absent"; exit 77; fi
if [[ ! -f "$CHAIN_LIB" ]]; then echo "SKIP|session-k-jamie-build|$CHAIN_LIB absent"; exit 77; fi

# shellcheck source=../lib/persona-assert.sh
source "$PERSONA_LIB"
# shellcheck source=../lib/claude-chain.sh
source "$CHAIN_LIB"

PASS=0; FAIL=0; FAIL_MSGS=()

GOLDEN="$FIX_DIR/golden-capture.txt"
BAD_JARGON="$FIX_DIR/bad-jargon-capture.txt"
BAD_WALL="$FIX_DIR/bad-wall-capture.txt"

# End-goal literal: real /build on a cold adopter (no plan, no app code)
# refuses gracefully with a structured "pick one" guidance. The refusal
# itself is Jamie's first-touch /build experience. Characterization per
# @luminary michael-feathers — pin shipped behavior; aspirational Story-N
# shape ships only after /canvas or /spec lands a plan.
if persona_assert_end_goal "$GOLDEN" "pick one" 0 2>/dev/null \
    && persona_assert_experience_goal "$GOLDEN" 2>/dev/null \
    && persona_assert_life_goal "$GOLDEN" 40 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 — golden should pass all 3")
fi

BJ_END=0; BJ_EXP=0; BJ_LIFE=0
# bad-jargon uses "Primitive 1" instead of "Story 1" — end-goal pivots on different marker
persona_assert_end_goal "$BAD_JARGON" "Primitive 1" 0 2>/dev/null && BJ_END=1
persona_assert_experience_goal "$BAD_JARGON" 2>/dev/null && BJ_EXP=1
persona_assert_life_goal "$BAD_JARGON" 40 2>/dev/null && BJ_LIFE=1
if [[ "$BJ_END" == "1" && "$BJ_EXP" == "0" && "$BJ_LIFE" == "1" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 — bad-jargon end=$BJ_END exp=$BJ_EXP life=$BJ_LIFE")
fi

BW_END=0; BW_EXP=0; BW_LIFE=0
persona_assert_end_goal "$BAD_WALL" "Story 1" 0 2>/dev/null && BW_END=1  # scaffold retains Story 1 heading — negative-case pins scaffold shape
persona_assert_experience_goal "$BAD_WALL" 2>/dev/null && BW_EXP=1
persona_assert_life_goal "$BAD_WALL" 40 2>/dev/null && BW_LIFE=1
if [[ "$BW_END" == "1" && "$BW_EXP" == "1" && "$BW_LIFE" == "0" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 — bad-wall end=$BW_END exp=$BW_EXP life=$BW_LIFE")
fi

echo ""
echo "===== smoke-drive-e2e-build-jamie.test.sh ====="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MSGS[@]}"; do echo "  $msg"; done
  exit 1
fi
exit 0
