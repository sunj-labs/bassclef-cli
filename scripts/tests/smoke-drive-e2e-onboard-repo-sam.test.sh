#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/smoke-drive-e2e-onboard-repo-sam.test.sh
#
# Session I walking skeleton (per docs/plans/tier-a-dynamic-driver-roadmap.md).
# Thinnest end-to-end persona-assertion driver — proves the pattern per
# @luminary alistair-cockburn (walking skeleton) + @luminary alan-cooper
# (Cooper 3-level goals: end + experience + life).
#
# Persona: Sam — cold install, first 5 min. Fresh npm install -g
# @thebassclef/lite. No bassclef vocab. Follows README CTA (/onboard-repo).
#
# Covers 3 fixture-pinned cases:
#   T01 — golden fixture passes all 3 Cooper goal levels
#   T02 — bad-jargon fixture fails experience goal (dancing-bear catch)
#   T03 — bad-chain-failure fixture fails end goal (exit non-zero)
#
# Walking skeleton assertion layer. Live-claude invocation stays in
# docker-smoke V2 Step 6 (scripts/smoke-drive-onboard-repo.sh); this
# test proves the assertion library works end-to-end against captures.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — all 3 cases PASS
#   1  — one or more cases FAIL
#   77 — SKIP (persona-assert.sh missing)

set -uo pipefail

# test-list:
# [x] T01 golden fixture passes end-goal + experience-goal + life-goal
# [x] T02 bad-jargon fixture passes end-goal + life-goal; FAILS experience-goal
# [x] T03 bad-chain-failure fixture FAILS end-goal (exit=3)
# [x] persona-assert lib absent → SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/persona-assert.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/sam-onboard-repo"

if [[ ! -f "$LIB" ]]; then
  echo "SKIP|session-i-sam|$LIB absent"
  exit 77
fi

# shellcheck source=scripts/lib/persona-assert.sh
source "$LIB"

PASS=0
FAIL=0
FAIL_MSGS=()

GOLDEN="$FIX_DIR/golden-capture.txt"
BAD_JARGON="$FIX_DIR/bad-jargon-capture.txt"
BAD_CHAIN="$FIX_DIR/bad-chain-failure-capture.txt"

# ----- T01 golden passes all 3 -----

if persona_assert_end_goal "$GOLDEN" ".claude/settings.json" 0 2>/dev/null \
    && persona_assert_experience_goal "$GOLDEN" 2>/dev/null \
    && persona_assert_life_goal "$GOLDEN" 40 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL — golden fixture did not pass all 3 Cooper goal levels")
fi

# ----- T02 bad-jargon fails ONLY experience goal -----

T02_END=$(persona_assert_end_goal "$BAD_JARGON" ".claude" 0 2>/dev/null && echo pass || echo fail)
T02_EXP=$(persona_assert_experience_goal "$BAD_JARGON" 2>/dev/null && echo pass || echo fail)
T02_LIFE=$(persona_assert_life_goal "$BAD_JARGON" 40 2>/dev/null && echo pass || echo fail)

# Dancing bear catch: end + life pass; experience FAILS (jargon landed on Sam's screen)
if [[ "$T02_END" == "pass" && "$T02_EXP" == "fail" && "$T02_LIFE" == "pass" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL — bad-jargon expected end=pass exp=fail life=pass; got end=$T02_END exp=$T02_EXP life=$T02_LIFE")
fi

# ----- T03 bad-chain-failure fails end goal -----

T03_END=$(persona_assert_end_goal "$BAD_CHAIN" ".claude/settings.json" 0 2>/dev/null && echo pass || echo fail)
if [[ "$T03_END" == "fail" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL — bad-chain-failure should fail end-goal; got $T03_END")
fi

# ----- Report -----

TOTAL=$((PASS + FAIL))
echo "session-i-sam | $PASS/$TOTAL cases passed"
if [[ "$FAIL" -gt 0 ]]; then
  printf '  %s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi
exit 0
