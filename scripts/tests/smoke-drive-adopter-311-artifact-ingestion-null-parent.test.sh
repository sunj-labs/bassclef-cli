#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-311-artifact-ingestion-null-parent.test.sh
#
# Characterization driver — cli#311 artifact-ingestion-gate null-parent false-positive.
#
# dist/lite/.claude/hooks/artifact-ingestion-gate.sh L135-162 iterates over
# parent_roadmap, parent_bet, parent_canvas, parent_decomposition. The loop
# skips only when PARENT_VALUE is empty (-z check). It does NOT skip when
# PARENT_VALUE is the literal string "null" or "~".
#
# When a root goal doc declares `parent_bet: null`, the hook asks the author
# to cite "null" in Sources read — which is impossible. Only workaround is
# deleting the line. bassclef-upstream#70 cured the same bug in bet-doc-gate.sh;
# this hook still carries it.
#
# Driver asserts the shipped hook still fires BLOCK on a goal doc with
# parent_bet: null. When upstream applies the #70 fix pattern (skip null|~),
# the hook returns clean and the driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (hook emits BLOCK naming "parent_bet: null")
#   1  — GREEN-UNEXPECTED (hook accepts null parent — cure reached adopters)
#   77 — SKIP (bundle or jq not available)

set -euo pipefail

# test-list:
# [x] Case 1 — hook fires BLOCK on parent_bet: null (RED signal)
# [x] Case 2 — BLOCK message names "parent_bet: null" verbatim (anchor)
# [x] Case 3 — hook accepts parent_bet: null when Sources-read cites it literally (would mask the bug if present)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/dist/lite/.claude/hooks/artifact-ingestion-gate.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "SKIP|driver-311|$HOOK absent (run \`npm run bundle\` first)"
  exit 77
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP|driver-311|jq not available"
  exit 77
fi

# Fixture: root goal doc with parent_bet: null + valid Sources read block
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

FIXTURE="$TMPDIR/docs/iteration-bets/2026-10-05-root-goal-null-parent.md"
mkdir -p "$(dirname "$FIXTURE")"
cat > "$FIXTURE" << 'FIXTURE_END'
---
goal_id: 2026-10-05-root-goal-null-parent
parent_bet: null
parent_roadmap: null
authoring_luminaries:
  primary: [michael-feathers]
---

# Root goal — null parent

## Sources read

- `.claude/rules/testing-tier-config.md`
FIXTURE_END

# Shape PreToolUse Write JSON input (what Claude Code harness sends)
INPUT=$(jq -n \
  --arg path "$FIXTURE" \
  --arg content "$(cat "$FIXTURE")" \
  '{tool_name: "Write", tool_input: {file_path: $path, content: $content}}')

# Run hook; capture stderr (BLOCK messages go there)
STDERR_FILE="$TMPDIR/hook.stderr"
set +e
echo "$INPUT" | bash "$HOOK" 2>"$STDERR_FILE" >/dev/null
EXIT_CODE=$?
set -e

STDERR_BODY=$(cat "$STDERR_FILE" 2>/dev/null)

# Case 1 + Case 2: hook must BLOCK (exit 2) AND stderr must name "parent_bet: null"
if [[ "$EXIT_CODE" -eq 2 ]] && echo "$STDERR_BODY" | grep -qE 'parent_bet:[[:space:]]*null'; then
  echo "RED-CONFIRMED|driver-311|hook BLOCKs on parent_bet: null (exit=$EXIT_CODE; stderr names null parent)"
  echo "PASS: #311 null-parent false-positive reproduces"
  exit 0
fi

# Case 3: hook accepted — either cure landed OR hook body changed semantics
echo "GREEN-UNEXPECTED|driver-311|hook did not BLOCK on parent_bet: null (exit=$EXIT_CODE)"
echo "stderr: $STDERR_BODY"
echo "FAIL: driver no longer RED — flip semantics; cross-ref #311 close"
exit 1
