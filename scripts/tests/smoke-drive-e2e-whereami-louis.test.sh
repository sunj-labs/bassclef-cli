#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/smoke-drive-e2e-whereami-louis.test.sh
#
# Session I PR 2 per docs/plans/tier-a-dynamic-driver-roadmap.md.
# Second Tier A chain driver. Rides scripts/lib/persona-assert.sh from
# PR #376 unchanged.
#
# Persona: Louis — context switcher. Has bassclef installed. Picks up a
# project after days away. Runs /whereami first to orient.
#
# Covers 3 fixture-pinned cases:
#   T01 — golden fixture passes all 3 Cooper goal levels
#   T02 — bad-jargon fixture fails experience goal (dancing-bear catch)
#   T03 — bad-wall fixture fails life goal (output exceeds scan ceiling)
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
# [x] T02 bad-jargon fails ONLY experience (dancing-bear catch)
# [x] T03 bad-wall fails ONLY life (output exceeds 40-line scan ceiling)
# [x] persona-assert lib absent → SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/persona-assert.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/louis-whereami"

if [[ ! -f "$LIB" ]]; then
  echo "SKIP|session-i-louis|$LIB absent"
  exit 77
fi

# shellcheck source=scripts/lib/persona-assert.sh
source "$LIB"

PASS=0
FAIL=0
FAIL_MSGS=()

GOLDEN="$FIX_DIR/golden-capture.txt"
BAD_JARGON="$FIX_DIR/bad-jargon-capture.txt"
BAD_WALL="$FIX_DIR/bad-wall-capture.txt"

# T01 — golden passes all 3
if persona_assert_end_goal "$GOLDEN" "**Phase**:" 0 2>/dev/null \
    && persona_assert_experience_goal "$GOLDEN" 2>/dev/null \
    && persona_assert_life_goal "$GOLDEN" 40 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL — golden did not pass all 3 goal levels")
fi

# T02 — bad-jargon: end pass, experience FAIL, life pass (dancing bear)
T02_END=$(persona_assert_end_goal "$BAD_JARGON" "**Phase**:" 0 2>/dev/null && echo pass || echo fail)
T02_EXP=$(persona_assert_experience_goal "$BAD_JARGON" 2>/dev/null && echo pass || echo fail)
T02_LIFE=$(persona_assert_life_goal "$BAD_JARGON" 40 2>/dev/null && echo pass || echo fail)

if [[ "$T02_END" == "pass" && "$T02_EXP" == "fail" && "$T02_LIFE" == "pass" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL — bad-jargon expected end=pass exp=fail life=pass; got end=$T02_END exp=$T02_EXP life=$T02_LIFE")
fi

# T03 — bad-wall: end pass, experience pass, life FAIL (scan ceiling)
T03_END=$(persona_assert_end_goal "$BAD_WALL" "**Phase**:" 0 2>/dev/null && echo pass || echo fail)
T03_EXP=$(persona_assert_experience_goal "$BAD_WALL" 2>/dev/null && echo pass || echo fail)
T03_LIFE=$(persona_assert_life_goal "$BAD_WALL" 40 2>/dev/null && echo pass || echo fail)

if [[ "$T03_END" == "pass" && "$T03_EXP" == "pass" && "$T03_LIFE" == "fail" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL — bad-wall expected end=pass exp=pass life=fail; got end=$T03_END exp=$T03_EXP life=$T03_LIFE")
fi

TOTAL=$((PASS + FAIL))
echo "session-i-louis | $PASS/$TOTAL cases passed"
if [[ "$FAIL" -gt 0 ]]; then
  printf '  %s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi
exit 0
