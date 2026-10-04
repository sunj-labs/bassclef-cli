#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /interpret-input. Red-first anchor against cli#319
# (interpret-input.sh never writes the .intent field the skill promises).
#
# Characterizes driver logic in two modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Tier 0 ships GREEN by
#     verifying driver correctly reports RED on pre-cure fixture AND
#     GREEN on post-cure fixture.
#   SMOKE_LIVE=1 — runs the real skill via `claude -p` inside container
#     and reports whatever live state produces. Exit 3 is expected-RED
#     per R-B4 convention (mirrors docker-smoke).
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L72-78
# Session A walking skeleton. Chain-shape proof — PR 1b.

# test-list:
# [x] T01 driver detects .intent absent — reports RED on pre-cure fixture
# [x] T02 driver detects .intent present — reports GREEN on post-cure fixture
# [x] T03 driver fails cleanly when artifact missing
# [x] T04 invariants lib fires on trace (lite runtime floor holds)

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/tests/lib/lite-runtime-invariants.sh"
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
# driver function — reusable by SMOKE_LIVE path too
# ============================================================
# Returns 0 when artifact exists AND has .intent field; 3 when either missing.
drive_interpret_input() {
  local artifact_path="$1"
  local trace_path="$2"
  # Positive-artifact assertion per R-C5 fold.
  local art_out
  art_out=$(check_artifact_exists "$artifact_path" 2>&1)
  if [[ "$art_out" != PASS* ]]; then
    echo "$art_out"
    return 3
  fi
  # Core cli#319 anchor — artifact must carry .intent field.
  if ! grep -qE '"intent"[[:space:]]*:' "$artifact_path" 2>/dev/null; then
    echo "FAIL|interpret-input-intent|cli#319 anchor — artifact lacks .intent field (RED anchor; waits for upstream fix)"
    return 3
  fi
  echo "PASS|interpret-input-intent|.intent field present"
  # Lite runtime floor also holds.
  if ! assert_lite_runtime "$trace_path" >/dev/null 2>&1; then
    echo "FAIL|interpret-input-runtime|lite runtime invariant failed"
    return 3
  fi
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — pre-cure fixture: artifact lacks .intent
  art="$TMP_BASE/t01.artifact.json"
  trace="$TMP_BASE/t01.trace"
  cat > "$art" <<'JSON'
{
  "input": "sample input text",
  "classification": "narrative"
}
JSON
  printf 'read sample input\nparsed classification\n' > "$trace"
  out=$(drive_interpret_input "$art" "$trace" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "cli#319 anchor"; then
    pass "T01 pre-cure RED anchor fires correctly"
  else
    fail "T01 pre-cure" "expected rc=3 with cli#319 anchor message; got rc=$rc out=$out"
  fi

  # T02 — post-cure fixture: artifact carries .intent
  art="$TMP_BASE/t02.artifact.json"
  trace="$TMP_BASE/t02.trace"
  cat > "$art" <<'JSON'
{
  "input": "sample input text",
  "classification": "narrative",
  "intent": "operator wants to brainstorm product variants"
}
JSON
  printf 'read sample input\nparsed intent cleanly\n' > "$trace"
  out=$(drive_interpret_input "$art" "$trace" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "intent field present"; then
    pass "T02 post-cure GREEN flip works"
  else
    fail "T02 post-cure" "expected rc=0 with intent-present message; got rc=$rc out=$out"
  fi

  # T03 — artifact missing
  out=$(drive_interpret_input "$TMP_BASE/nonexistent.json" "$TMP_BASE/t02.trace" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "FAIL"; then
    pass "T03 missing artifact fails cleanly"
  else
    fail "T03 missing artifact" "expected rc=3 FAIL; got rc=$rc out=$out"
  fi

  # T04 — invariants lib fires on trace (floor holds)
  trace="$TMP_BASE/t04.trace"
  printf 'reading manifest.json cleanly\n' > "$trace"
  out=$(assert_lite_runtime "$trace" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]]; then
    pass "T04 invariants floor GREEN"
  else
    fail "T04 invariants" "expected rc=0; got rc=$rc"
  fi
else
  echo "--- SMOKE_LIVE=1 — invoking real claude ---"
  # Live mode. Scaffold scratch workdir. Run real skill. Driver reports outcome.
  WORKDIR="$TMP_BASE/live"
  mkdir -p "$WORKDIR"
  trace="$WORKDIR/trace"
  artifact="$WORKDIR/interpret-output.json"
  # Call real claude; redirect output. Timeout to prevent hang.
  timeout 120 claude -p '/interpret-input <<INPUT
Sample input: operator wants to spin up three product variants for cold storage.
INPUT' > "$trace" 2>&1 || echo "claude exit $?" >> "$trace"
  # Driver expects the skill to write artifact at a conventional path; for v1
  # we try the trace itself for the intent field (skill may emit inline).
  if [[ ! -f "$artifact" ]] && grep -qE '"intent"[[:space:]]*:' "$trace" 2>/dev/null; then
    artifact="$trace"
  fi
  out=$(drive_interpret_input "$artifact" "$trace" 2>&1)
  rc=$?
  echo "$out"
  echo "LIVE DRIVER rc=$rc"
  # Expected-RED convention per R-B4; rc=3 means waiting-for-upstream, not CI fail.
  exit "$rc"
fi

# ============================================================
# summary
# ============================================================
echo ""
echo "============================================"
echo "smoke-drive-e2e-interpret-input.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
