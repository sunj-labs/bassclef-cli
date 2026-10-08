#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-322-launch-template-jargon.test.sh
#
# Characterization driver — cli#322 /launch Phase 14 template jargon.
#
# dist/lite/.claude/skills/launch/SKILL.md Phase 14 goal template
# contains `scope-bounded` and `appetite:` — both are BLOCK terms per
# standards/bassclef-internal-jargon.md and ADR-040 vocabulary rename.
# When an agent follows the template word for word, substrate-clarity-gate.sh
# blocks the write. The skill's own output fails the framework's own
# check.
#
# Driver asserts the shipped template still carries at least one of the
# two BLOCK terms. When upstream rewrites the template (per ticket fix),
# both grep misses and driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (one or both jargon terms present in template)
#   1  — GREEN-UNEXPECTED (both gone — cure reached adopters)
#   77 — SKIP (bundle not generated)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/dist/lite/.claude/skills/launch/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "SKIP|driver-322|$SKILL_FILE absent (run \`npm run bundle\` first)"
  exit 77
fi

count_scope=$(grep -cE 'scope-bounded' "$SKILL_FILE" 2>/dev/null || echo 0)
count_appetite=$(grep -cE '^[[:space:]]*appetite:' "$SKILL_FILE" 2>/dev/null || echo 0)
count_scope=${count_scope//[^0-9]/}; count_scope=${count_scope:-0}
count_appetite=${count_appetite//[^0-9]/}; count_appetite=${count_appetite:-0}

total=$((count_scope + count_appetite))

# Flipped to GREEN-confirms per ADR-011 D2 (post-cure anchor).
# PASS when the jargon terms are absent. FAIL if either returns.
if [[ "$total" -gt 0 ]]; then
  echo "REGRESSION|driver-322|shipped template re-introduces jargon (scope-bounded=${count_scope} appetite=${count_appetite})"
  echo "FAIL: #322 template-fails-its-own-gate returned — cure reverted"
  exit 1
fi

echo "GREEN-CONFIRMED|driver-322|both jargon terms absent from /launch template; #322 cure holds"
exit 0
