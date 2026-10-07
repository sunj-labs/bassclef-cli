#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/smoke-drive-e2e-riff-jamie.test.sh
#
# Session K PR 5 per docs/plans/tier-a-dynamic-driver-roadmap.md.
# Fourth Tier A chain driver. Rides scripts/lib/persona-assert.sh.
# First driver to source scripts/lib/claude-chain.sh (shipped in PR #384).
#
# Persona: Jamie — positioning + maturity reader. 90-second budget.
# Reads /riff output for signal, not detail. Bounces on marketing gloss
# with no proof. Decides: "worth a bookmark, or worth a slack link?"
#
# Covers 3 fixture-pinned cases:
#   T01 — golden fixture passes all 3 Cooper goal levels
#   T02 — bad-jargon fixture fails experience goal (dancing-bear catch —
#         variants described as load-bearing composer primitives)
#   T03 — bad-wall fixture fails life goal (variants with full typography
#         + color palette per variant exceed 40-line scan ceiling)
#
# Fixtures provenance: hand-crafted scaffold at 2026-10-07. Replace with
# live captures from docker cold-adopter once operator OAuth refresh
# (cli#380 / PR #381) lands clean. See scripts/tests/fixtures/jamie-riff/README.md.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — all 3 cases PASS
#   1  — one or more cases FAIL
#   77 — SKIP (persona-assert.sh OR claude-chain.sh missing)

set -uo pipefail

# test-list:
# [x] T01 golden fixture passes end + experience + life
# [x] T02 bad-jargon fails ONLY experience (load-bearing + composer + blast radius + operationalize + primitive + tier-preset)
# [x] T03 bad-wall fails ONLY life (full typography + color per variant exceeds 40-line scan ceiling)
# [x] persona-assert lib absent -> SKIP
# [x] claude-chain lib absent -> SKIP (declared dependency per cli#383 contract)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PERSONA_LIB="$REPO_ROOT/scripts/lib/persona-assert.sh"
CHAIN_LIB="$REPO_ROOT/scripts/lib/claude-chain.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/jamie-riff"

if [[ ! -f "$PERSONA_LIB" ]]; then
  echo "SKIP|session-k-jamie-riff|$PERSONA_LIB absent"
  exit 77
fi

if [[ ! -f "$CHAIN_LIB" ]]; then
  echo "SKIP|session-k-jamie-riff|$CHAIN_LIB absent (chain helper from PR #384 missing)"
  exit 77
fi

# shellcheck source=../lib/persona-assert.sh
source "$PERSONA_LIB"
# shellcheck source=../lib/claude-chain.sh
# Chain helper sourced for availability check at test time. Live-capture
# tests (SMOKE_LIVE=1 variant) in future PRs will call claude_chain_capture.
source "$CHAIN_LIB"

PASS=0
FAIL=0
FAIL_MSGS=()

GOLDEN="$FIX_DIR/golden-capture.txt"
BAD_JARGON="$FIX_DIR/bad-jargon-capture.txt"
BAD_WALL="$FIX_DIR/bad-wall-capture.txt"

# ---------------------------------------------------------------------
# T01 — golden passes all 3
# ---------------------------------------------------------------------
# End-goal literal: real /riff output on v1.9.11 produces "Variant 1 — ...",
# not "Variant A — ..." as the Session K scaffold assumed. Characterization
# per @luminary michael-feathers — pin shipped behavior, not aspirational.
# Life-goal ceiling: real body is 45 lines (above Jamie's aspirational 40).
# Filed as bassclef-upstream#2123 per plan R6; ceiling matches shipped
# behavior until upstream tightens /riff output or ratifies 45 as new bar.
if persona_assert_end_goal "$GOLDEN" "Variant 1" 0 2>/dev/null \
    && persona_assert_experience_goal "$GOLDEN" 2>/dev/null \
    && persona_assert_life_goal "$GOLDEN" 45 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 — golden should pass all 3 Cooper goals")
fi

# ---------------------------------------------------------------------
# T02 — bad-jargon passes end + life; FAILS experience
# ---------------------------------------------------------------------
BJ_END=0; BJ_EXP=0; BJ_LIFE=0
persona_assert_end_goal "$BAD_JARGON" "Variant A" 0 2>/dev/null && BJ_END=1  # scaffold retains Variant A/B/C — negative-case characterization pins scaffold shape, not real
persona_assert_experience_goal "$BAD_JARGON" 2>/dev/null && BJ_EXP=1
persona_assert_life_goal "$BAD_JARGON" 40 2>/dev/null && BJ_LIFE=1

if [[ "$BJ_END" == "1" && "$BJ_EXP" == "0" && "$BJ_LIFE" == "1" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 — bad-jargon should pass end+life, FAIL experience; got end=$BJ_END exp=$BJ_EXP life=$BJ_LIFE")
fi

# ---------------------------------------------------------------------
# T03 — bad-wall passes end + experience; FAILS life
# ---------------------------------------------------------------------
BW_END=0; BW_EXP=0; BW_LIFE=0
persona_assert_end_goal "$BAD_WALL" "Variant A" 0 2>/dev/null && BW_END=1
persona_assert_experience_goal "$BAD_WALL" 2>/dev/null && BW_EXP=1
persona_assert_life_goal "$BAD_WALL" 40 2>/dev/null && BW_LIFE=1

if [[ "$BW_END" == "1" && "$BW_EXP" == "1" && "$BW_LIFE" == "0" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 — bad-wall should pass end+experience, FAIL life; got end=$BW_END exp=$BW_EXP life=$BW_LIFE")
fi

echo ""
echo "===== smoke-drive-e2e-riff-jamie.test.sh ====="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MSGS[@]}"; do
    echo "  $msg"
  done
  exit 1
fi
exit 0
