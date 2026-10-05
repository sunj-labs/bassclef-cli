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

if [[ "$total" -gt 0 ]]; then
  echo "RED-CONFIRMED|driver-322|shipped template carries jargon (scope-bounded=${count_scope} appetite=${count_appetite})"
  echo "PASS: #322 adopter template-fails-its-own-gate reproduces"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-322|both jargon terms absent — template cured"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #322 close"
exit 1
