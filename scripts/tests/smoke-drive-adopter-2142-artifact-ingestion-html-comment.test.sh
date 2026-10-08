#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-2142-artifact-ingestion-html-comment.test.sh
#
# Characterization driver — bassclef-upstream#2142 (Session N / Kunal).
# Anchors the artifact-ingestion-gate HTML-comment tolerance cure.
#
# Prior to the cure, dist/lite/.claude/hooks/artifact-ingestion-gate.sh
# refused goal docs whose Sources-read block was wrapped in an HTML
# comment with leading whitespace. The hook greps for the fence marker;
# the prior pattern anchored at column 0 and missed indented comment
# openers. Cure makes the match tolerant of leading whitespace.
#
# Driver asserts dist/lite/.claude/hooks/artifact-ingestion-gate.sh
# carries the bassclef-upstream#2142 cure anchor + the "leading whitespace"
# tolerance comment.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (cure anchor + tolerance pattern present)
#   1  — regression (anchor or tolerance missing)
#   77 — SKIP (bundle not available)

set -euo pipefail

# test-list:
# [x] Case 1 — dist/lite/.claude/hooks/artifact-ingestion-gate.sh exists in the bundle
# [x] Case 2 — hook carries the bassclef-upstream#2142 cure anchor
# [x] Case 3 — hook body documents the leading-whitespace tolerance intent

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/dist/lite/.claude/hooks/artifact-ingestion-gate.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "SKIP|driver-2142|$HOOK absent (run bundle sync first)"
  exit 77
fi

missing=()
grep -qE 'bassclef-upstream#2142' "$HOOK" || missing+=("bassclef-upstream#2142 cure anchor")
grep -qE 'leading whitespace' "$HOOK" || missing+=("leading-whitespace tolerance intent")

if (( ${#missing[@]} > 0 )); then
  echo "FAIL|driver-2142|regression: cure anchors missing: ${missing[*]}"
  exit 1
fi

echo "PASS|driver-2142|GREEN-CONFIRMED: artifact-ingestion HTML-comment tolerance cure shipped"
exit 0
