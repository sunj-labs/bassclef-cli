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
# This driver asserts the GREEN signal: #331 cure is present in the
# shipped bundle. Session G bundle sync (v1.7.0 → v1.7.1) brought the
# upstream cure (PR #2069) which added the `## Lite procedure` H2
# anchor to the shipped /autonomous SKILL.md. From Session G forward
# this driver is a durable regression anchor — if a future bundle
# sync ever drops the anchor, the driver fails loud and surfaces the
# regression on CI.
#
# Semantics flipped in Session G per
# docs/next-session-plan-2026-10-05-session-g-v1-7-1-bundle-sync.md L48.
# Session F origin — peer bassclef-upstream-9b priority 1 (2026-10-05).
# Pattern matches scripts/tests/smoke-drive-adopter-306-bash32.test.sh.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (lite procedure anchor present; cure in bundle)
#   1  — RED-REGRESSION (anchor absent; cure removed from bundle)
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

if [[ "$match_count" -gt 0 ]]; then
  echo "GREEN-CONFIRMED|driver-331|${match_count} lite procedure anchor hit(s) — cure present in bundle"
  echo "PASS: #331 cure holds; shipped /autonomous SKILL.md carries the lite procedure block"
  exit 0
fi

echo "RED-REGRESSION|driver-331|lite procedure anchor missing — cure removed from bundle"
echo "FAIL: #331 regressed — the ## Lite procedure H2 block is gone from shipped substrate"
exit 1
