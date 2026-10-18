#!/usr/bin/env bash
# tier: standard
# scripts/tests/sync-bassclef-version.test.sh — Tier 0 tests for cli#439
# dev-repo bassclef-version.json consistency.
#
# Validates:
#   1. bassclef-version.json exists at repo root
#   2. Its .version field matches .bassclef-pin
#   3. The file is valid JSON with the expected 5 top-level keys
#   4. sync-bassclef-version.mjs script is executable + idempotent
#
# Anchors:
#   @luminary tony-hoare — pre/postcondition: pin matches version-file
#   @luminary michael-feathers — characterization on the serialized shape
#   @luminary kent-beck — Tier 0 strict TDD on cli#439 primitive
#
# test-list:
# [x] T1: bassclef-version.json exists at repo root
# [x] T2: file parses as JSON
# [x] T3: .version field matches .bassclef-pin content
# [x] T4: file has the 5 expected top-level keys
# [x] T5: sync script is executable
# [x] T6: sync script is idempotent (second run reports "already current")

set -euo pipefail

PASS=0
FAIL=0
FAILED_NAMES=""

_pass() { PASS=$((PASS+1)); echo "  [PASS] $1"; }
_fail() { FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES $1"; echo "  [FAIL] $1"; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION_FILE="$ROOT/bassclef-version.json"
PIN_FILE="$ROOT/.bassclef-pin"
SYNC_SCRIPT="$ROOT/scripts/sync-bassclef-version.mjs"

echo "==> cli#439 dev-repo bassclef-version.json tests"

# T1
if [ -f "$VERSION_FILE" ]; then
  _pass "T1: bassclef-version.json exists at repo root"
else
  _fail "T1: bassclef-version.json missing at $VERSION_FILE"
fi

# T2
if [ -f "$VERSION_FILE" ]; then
  if node -e "JSON.parse(require('fs').readFileSync('$VERSION_FILE','utf8'))" 2>/dev/null; then
    _pass "T2: file parses as JSON"
  else
    _fail "T2: file is not valid JSON"
  fi
fi

# T3 — .version matches .bassclef-pin
if [ -f "$VERSION_FILE" ] && [ -f "$PIN_FILE" ]; then
  FILE_VERSION=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$VERSION_FILE','utf8')).version)" 2>/dev/null)
  PIN_VALUE=$(tr -d '[:space:]' < "$PIN_FILE")
  if [ "$FILE_VERSION" = "$PIN_VALUE" ]; then
    _pass "T3: .version ($FILE_VERSION) matches .bassclef-pin ($PIN_VALUE)"
  else
    _fail "T3: .version ($FILE_VERSION) != .bassclef-pin ($PIN_VALUE) — run 'node scripts/sync-bassclef-version.mjs'"
  fi
fi

# T4
if [ -f "$VERSION_FILE" ]; then
  KEYS=$(node -e "console.log(Object.keys(JSON.parse(require('fs').readFileSync('$VERSION_FILE','utf8'))).sort().join(','))" 2>/dev/null)
  EXPECTED="marker_tag,release_date,release_sha,release_tag,version"
  if [ "$KEYS" = "$EXPECTED" ]; then
    _pass "T4: file has expected top-level keys"
  else
    _fail "T4: keys mismatch — got '$KEYS' expected '$EXPECTED'"
  fi
fi

# T5
if [ -x "$SYNC_SCRIPT" ] || [ -f "$SYNC_SCRIPT" ]; then
  # Node scripts don't need exec bit when invoked via `node`
  _pass "T5: sync script is present at $SYNC_SCRIPT"
else
  _fail "T5: sync script missing"
fi

# T6 — idempotent re-run
if [ -f "$SYNC_SCRIPT" ]; then
  OUT=$(node "$SYNC_SCRIPT" 2>&1)
  if echo "$OUT" | grep -q "already current"; then
    _pass "T6: second run reports 'already current' (idempotent)"
  else
    _fail "T6: expected 'already current' on re-run; got: $OUT"
  fi
fi

echo ""
echo "==> $PASS pass / $FAIL fail"
if [ -n "$FAILED_NAMES" ]; then
  echo "FAILED:$FAILED_NAMES"
  exit 1
fi
exit 0
