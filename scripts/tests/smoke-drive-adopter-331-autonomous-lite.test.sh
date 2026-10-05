#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-331-autonomous-lite.test.sh
#
# Characterization driver — cli#331 /autonomous SKILL.md pointed at
# strategy/ files that lite tier doesn't ship. Upstream PR #2069
# (merged 4a661adc) folded a self-contained `## Lite procedure`
# block into SKILL.md body so lite /autonomous start runs without
# the strategy/ sibling.
#
# This driver asserts the pre-cure RED state exists TODAY in the
# shipped bundle (bassclef pin pre v1.7.1): the `## Lite procedure`
# anchor is ABSENT. When cli bundle-syncs to v1.7.1+ with the cure,
# the anchor appears and this driver flips GREEN-UNEXPECTED. That
# flip is the signal that cure reached adopters; follow-up PR flips
# semantics and ticket closes.
#
# Session F pivot — peer bassclef-upstream-9b priority 1 (2026-10-05).
# Pattern matches scripts/tests/smoke-drive-adopter-306-bash32.test.sh.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (lite procedure anchor absent; pre-cure state)
#   1  — GREEN-UNEXPECTED (anchor present; cure reached adopters)
#   77 — SKIP (bundle not generated)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/dist/lite/.claude/skills/autonomous/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "SKIP|driver-331|bundle not generated (run \`npm run bundle\` first)"
  exit 77
fi

# Anchor pinned per risk ledger F1 fold — exact H2 heading from the cure
match_count=$(grep -cE '^##[[:space:]]+Lite procedure' "$SKILL_FILE" 2>/dev/null || echo 0)
match_count=${match_count//[^0-9]/}
match_count=${match_count:-0}

if [[ "$match_count" -eq 0 ]]; then
  echo "RED-CONFIRMED|driver-331|lite procedure anchor absent — bundle predates v1.7.1 cure"
  echo "PASS: #331 pre-cure state reproduces against shipped substrate"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-331|${match_count} lite procedure anchor hit(s) — cure reached adopters"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #331 close in next release PR"
exit 1
