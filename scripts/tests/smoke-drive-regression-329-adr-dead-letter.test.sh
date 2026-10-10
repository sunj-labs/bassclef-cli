#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-329-adr-dead-letter.test.sh
#
# Characterization driver — cli#329 ADR hook DEAD-LETTER state.
#
# dist/lite/.claude/rules/adr-discipline.md:10 says the hook is
# "load-bearing" and that adr-discipline-check.sh fires on PreToolUse
# architectural-decision edits. But dist/lite/.claude/settings.json
# does not wire the hook. Adopters believe mediation fires; it does
# not. DEAD-LETTER class per .claude/rules/mechanism-fidelity.md.
#
# Driver asserts: hook file ships + settings.json lacks wiring.
# When upstream cures (either wires the hook OR removes it + reworks
# the rule), driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (DEAD-LETTER state)
#   1  — GREEN-UNEXPECTED (wiring present) OR PATH-CHANGED (hook removed)
#   77 — SKIP (settings.json absent)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

HOOK_FILE="$REPO_ROOT/dist/lite/.claude/hooks/adr-discipline-check.sh"
SETTINGS_FILE="$REPO_ROOT/dist/lite/.claude/settings.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "SKIP|driver-329|dist/lite/.claude/settings.json absent (run \`npm run bundle\` first)"
  exit 77
fi

# Precondition 1: hook file is shipped
if [[ ! -f "$HOOK_FILE" ]]; then
  echo "PATH-CHANGED|driver-329|hook file removed — alternative cure path may have landed"
  echo "FAIL: driver semantics need review"
  exit 1
fi

# Precondition 2: settings.json lacks the wiring
match_count=$(grep -cE 'adr-discipline-check\.sh' "$SETTINGS_FILE" 2>/dev/null || echo 0)
match_count=${match_count//[^0-9]/}
match_count=${match_count:-0}

if [[ "$match_count" -eq 0 ]]; then
  echo "RED-CONFIRMED|driver-329|DEAD-LETTER — adr-discipline-check.sh shipped but not wired in settings.json"
  echo "PASS: #329 adopter-visible mediation gap reproduces"
  exit 0
fi

echo "GREEN-UNEXPECTED|driver-329|${match_count} settings.json wiring hit(s) — ADR hook now mediates"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #329 close in release PR"
exit 1
