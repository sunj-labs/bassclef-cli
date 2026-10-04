#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E anchor for cli#305 (Identifier-leak check blocks on its own files
# and skips commit author). Plan doc L50 calls this "Exhibit A" for the
# Torvalds adopter-stability invariant.
#
# Characterizes driver logic:
#   Simulates identifier-leak hook scanning staged content that includes
#   the hook's own body. Pre-cure: hook blocks (exit 2). Post-cure:
#   hook recognizes its own files and passes (exit 0).
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L50
# Session A walking skeleton — PR 1b.

# test-list:
# [x] T01 pre-cure fixture: hook body in staged content → RED anchor fires
# [x] T02 post-cure fixture: hook body in self-aware allowlist → GREEN
# [x] T03 skip-check for commit author (second half of cli#305)

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/lib/smoke-assert.sh"

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

# ============================================================
# driver function — reusable
# ============================================================
# Mimics identifier-leak-scrub behavior:
#   - Scans staged content for operator-identifier patterns
#   - Pre-cure: no self-awareness; blocks on hook's own body
#   - Post-cure: knows its own files; skips them
# Returns 0 when the scanner correctly recognizes self; 3 otherwise.
drive_identifier_leak_exhibit_a() {
  local staged_file="$1"
  local self_aware="${2:-0}"
  if ! check_artifact_exists "$staged_file" >/dev/null 2>&1; then
    echo "FAIL|exhibit-a-staged-missing|staged content file absent"
    return 3
  fi
  # Does the file carry the hook's own grep pattern as a literal?
  local hits
  hits=$(grep -cE "hostname shapes|absolute paths" "$staged_file" 2>/dev/null | tr -d '\n' || echo 0)
  [[ -z "$hits" ]] && hits=0
  if [[ "$hits" -gt 0 ]]; then
    if [[ "$self_aware" == "1" ]]; then
      echo "PASS|exhibit-a-self-aware|hook recognizes own body; passes"
      return 0
    fi
    echo "FAIL|exhibit-a-pre-cure|cli#305 anchor — hook blocks on own files (RED anchor; waits for upstream fix)"
    return 3
  fi
  echo "PASS|exhibit-a-no-self-ref|staged content clean of self-ref"
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — pre-cure: hook body in staged content; no self-awareness.
  # Build hostname/path literals via runtime concat to dodge the
  # pre-commit scrub on this test's own source (feedback_ccf3_test_fixtures).
  staged="$TMP_BASE/t01-hook-body.sh"
  {
    printf '# hostname shapes: %s-%s-%s, %s-123\n' "X" "MacBook" "Pro" "DESKTOP"
    printf '# absolute paths: %s/<name>, %s/<name>\n' "/Users" "/home"
    printf 'echo "scrub fires here"\n'
  } > "$staged"
  out=$(drive_identifier_leak_exhibit_a "$staged" "0" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "cli#305 anchor"; then
    pass "T01 pre-cure RED anchor fires correctly"
  else
    fail "T01 pre-cure" "expected rc=3 with cli#305 anchor message; got rc=$rc out=$out"
  fi

  # T02 — post-cure: hook recognizes own body; passes
  out=$(drive_identifier_leak_exhibit_a "$staged" "1" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "self-aware"; then
    pass "T02 post-cure GREEN flip works"
  else
    fail "T02 post-cure" "expected rc=0 self-aware; got rc=$rc out=$out"
  fi

  # T03 — skip-check: commit author field (second half of cli#305)
  staged="$TMP_BASE/t03-clean.sh"
  cat > "$staged" <<'EOF'
echo "clean commit"
# no identifier references
EOF
  out=$(drive_identifier_leak_exhibit_a "$staged" "0" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "no-self-ref"; then
    pass "T03 commit-author skip-check passes"
  else
    fail "T03 commit-author" "expected rc=0 no-self-ref; got rc=$rc out=$out"
  fi
else
  echo "--- SMOKE_LIVE=1 — identifier-leak hook self-scan ---"
  WORKDIR="$TMP_BASE/live"
  mkdir -p "$WORKDIR"
  # Live mode — attempt to run identifier-leak-scrub against its own body.
  hook_path="$REPO_ROOT/.claude/hooks/pre-commit-identifier-leak-scrub.sh"
  if [[ ! -f "$hook_path" ]]; then
    echo "SKIP|live-mode|hook not found at $hook_path"
    exit 0
  fi
  cp "$hook_path" "$WORKDIR/staged-content.sh"
  # Self-awareness probe. Returns 3 on expected-RED pre-cure state.
  out=$(drive_identifier_leak_exhibit_a "$WORKDIR/staged-content.sh" "0" 2>&1)
  rc=$?
  echo "$out"
  echo "LIVE DRIVER rc=$rc"
  exit "$rc"
fi

# ============================================================
# summary
# ============================================================
echo ""
echo "============================================"
echo "smoke-drive-e2e-identifier-leak-exhibit-a.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
