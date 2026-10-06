#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/claude-chain.test.sh
#
# Tier 0 test for scripts/lib/claude-chain.sh — the claude -c multi-turn
# chain helper per cli#383. Ships before any Tier A driver sources the
# helper (Beck RED-first).
#
# The helper wraps `claude -p` (turn 1) and `claude -c -p` (turn N+1)
# with capture + timeout + exit-code preservation + env-var contract.
#
# Tests use CLAUDE_BIN pointing at a mock to stay offline. Live-claude
# invocation stays in the Tier A persona driver + docker-smoke harness.
#
# @pattern patterns/code/feathers/characterization-test.md

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/claude-chain.sh"
MOCK_DIR="$(mktemp -d)"
MOCK_CLAUDE="$MOCK_DIR/mock-claude.sh"
trap 'rm -rf "$MOCK_DIR"' EXIT

# test-list:
# [x] T01 lib file exists at scripts/lib/claude-chain.sh
# [x] T02 claude_chain_capture is a function after source
# [x] T03 claude_chain_continue is a function after source
# [x] T04 claude_chain_capture writes stdout to out-file
# [x] T05 claude_chain_capture preserves non-zero exit code from claude
# [x] T06 claude_chain_capture returns 127 when CLAUDE_BIN not on PATH
# [x] T07 claude_chain_continue passes -c flag to claude
# [x] T08 claude_chain_capture passes --dangerously-skip-permissions by default
# [x] T09 CLAUDE_PERMISSIONS=strict suppresses --dangerously-skip-permissions
# [x] T10 CLAUDE_CHAIN_TIMEOUT_SEC env var honored
# [x] T11 capture file carries 5-line header (skill, bin, timeout, mode, output marker)
# [x] T12 capture file carries === exit: N trailer so persona-assert.sh reads exit code (added after real-fixture header-shape audit)
# [~] T13 lib absent -> test suite skips cleanly — covered by T01's SKIP-77 branch at run time (verified RED-first)

PASS=0
FAIL=0
FAIL_MSGS=()

fail() {
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("$1")
}

ok() {
  PASS=$((PASS + 1))
}

# ---------------------------------------------------------------------
# Set up mock claude binary — captures its args + env + emits canned output
# ---------------------------------------------------------------------
cat > "$MOCK_CLAUDE" <<'MOCK_EOF'
#!/usr/bin/env bash
# mock-claude: records args to $MOCK_LOG, emits canned output, exits per $MOCK_EXIT
echo "$@" >> "${MOCK_LOG:-/dev/null}"
echo "mock-claude: canned output for prompt"
exit "${MOCK_EXIT:-0}"
MOCK_EOF
chmod +x "$MOCK_CLAUDE"

# ---------------------------------------------------------------------
# T01 — lib file exists
# ---------------------------------------------------------------------
if [[ -f "$LIB" ]]; then
  ok
else
  fail "T01 — lib file missing at $LIB"
  echo "SKIP|claude-chain|$LIB absent"
  echo "pass=$PASS fail=$FAIL"
  exit 77
fi

# shellcheck source=../lib/claude-chain.sh
source "$LIB"

# ---------------------------------------------------------------------
# T02 — claude_chain_capture is a function
# ---------------------------------------------------------------------
if declare -f claude_chain_capture >/dev/null 2>&1; then
  ok
else
  fail "T02 — claude_chain_capture not defined after source"
fi

# ---------------------------------------------------------------------
# T03 — claude_chain_continue is a function
# ---------------------------------------------------------------------
if declare -f claude_chain_continue >/dev/null 2>&1; then
  ok
else
  fail "T03 — claude_chain_continue not defined after source"
fi

# ---------------------------------------------------------------------
# T04 — claude_chain_capture writes stdout to out-file
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t04.out"
MOCK_LOG="$MOCK_DIR/t04.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  claude_chain_capture "/sprint" "$OUT_FILE" >/dev/null 2>&1 || true

if [[ -f "$OUT_FILE" ]] && grep -q "mock-claude: canned output" "$OUT_FILE"; then
  ok
else
  fail "T04 — out-file missing or lacks mock output"
fi

# ---------------------------------------------------------------------
# T05 — non-zero exit preserved
# ---------------------------------------------------------------------
MOCK_EXIT=3 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_DIR/t05.log" \
  claude_chain_capture "/sprint" "$MOCK_DIR/t05.out" >/dev/null 2>&1
RC=$?
if [[ "$RC" == "3" ]]; then
  ok
else
  fail "T05 — expected rc=3 got rc=$RC"
fi

# ---------------------------------------------------------------------
# T06 — CLAUDE_BIN not on PATH returns 127
# ---------------------------------------------------------------------
CLAUDE_BIN="/nonexistent/claude-$$" \
  claude_chain_capture "/sprint" "$MOCK_DIR/t06.out" >/dev/null 2>&1
RC=$?
if [[ "$RC" == "127" ]]; then
  ok
else
  fail "T06 — expected rc=127 for missing bin, got rc=$RC"
fi

# ---------------------------------------------------------------------
# T07 — claude_chain_continue passes -c flag
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t07.out"
MOCK_LOG="$MOCK_DIR/t07.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  claude_chain_continue "pick 1" "$OUT_FILE" >/dev/null 2>&1 || true

if grep -q -- '-c' "$MOCK_LOG" 2>/dev/null; then
  ok
else
  fail "T07 — -c flag not passed to claude"
fi

# ---------------------------------------------------------------------
# T08 — --dangerously-skip-permissions passed by default
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t08.out"
MOCK_LOG="$MOCK_DIR/t08.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  claude_chain_capture "/sprint" "$OUT_FILE" >/dev/null 2>&1 || true

if grep -q -- '--dangerously-skip-permissions' "$MOCK_LOG" 2>/dev/null; then
  ok
else
  fail "T08 — --dangerously-skip-permissions not passed by default"
fi

# ---------------------------------------------------------------------
# T09 — CLAUDE_PERMISSIONS=strict suppresses the flag
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t09.out"
MOCK_LOG="$MOCK_DIR/t09.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  CLAUDE_PERMISSIONS=strict \
  claude_chain_capture "/sprint" "$OUT_FILE" >/dev/null 2>&1 || true

if ! grep -q -- '--dangerously-skip-permissions' "$MOCK_LOG" 2>/dev/null; then
  ok
else
  fail "T09 — --dangerously-skip-permissions present under CLAUDE_PERMISSIONS=strict"
fi

# ---------------------------------------------------------------------
# T10 — CLAUDE_CHAIN_TIMEOUT_SEC honored (header reflects value)
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t10.out"
MOCK_LOG="$MOCK_DIR/t10.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  CLAUDE_CHAIN_TIMEOUT_SEC=42 \
  claude_chain_capture "/sprint" "$OUT_FILE" >/dev/null 2>&1 || true

if grep -q '=== timeout_sec: 42' "$OUT_FILE" 2>/dev/null; then
  ok
else
  fail "T10 — timeout header does not reflect CLAUDE_CHAIN_TIMEOUT_SEC=42"
fi

# ---------------------------------------------------------------------
# T11 — 5-line header shape in capture
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t11.out"
MOCK_LOG="$MOCK_DIR/t11.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  claude_chain_capture "/sprint" "$OUT_FILE" >/dev/null 2>&1 || true

HEADER_OK=1
grep -q '^=== skill: /sprint' "$OUT_FILE" 2>/dev/null || HEADER_OK=0
grep -q '^=== claude_bin:' "$OUT_FILE" 2>/dev/null || HEADER_OK=0
grep -q '^=== timeout_sec:' "$OUT_FILE" 2>/dev/null || HEADER_OK=0
grep -q '^=== mode: capture' "$OUT_FILE" 2>/dev/null || HEADER_OK=0
grep -q '^=== output ===' "$OUT_FILE" 2>/dev/null || HEADER_OK=0

if [[ "$HEADER_OK" == "1" ]]; then
  ok
else
  fail "T11 — 5-line header shape missing"
fi

# ---------------------------------------------------------------------
# T12 — === exit: N trailer so persona-assert.sh reads exit code
# ---------------------------------------------------------------------
OUT_FILE="$MOCK_DIR/t12-ok.out"
MOCK_LOG="$MOCK_DIR/t12-ok.log"
MOCK_EXIT=0 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG" \
  claude_chain_capture "/sprint" "$OUT_FILE" >/dev/null 2>&1 || true

OUT_FILE2="$MOCK_DIR/t12-err.out"
MOCK_LOG2="$MOCK_DIR/t12-err.log"
MOCK_EXIT=3 \
  CLAUDE_BIN="$MOCK_CLAUDE" \
  MOCK_LOG="$MOCK_LOG2" \
  claude_chain_capture "/sprint" "$OUT_FILE2" >/dev/null 2>&1 || true

TRAILER_OK=1
grep -q '^=== exit: 0$' "$OUT_FILE" 2>/dev/null || TRAILER_OK=0
grep -q '^=== exit: 3$' "$OUT_FILE2" 2>/dev/null || TRAILER_OK=0

if [[ "$TRAILER_OK" == "1" ]]; then
  ok
else
  fail "T12 — === exit: N trailer missing or wrong value"
fi

# ---------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------
echo ""
echo "===== claude-chain.test.sh ====="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MSGS[@]}"; do
    echo "  $msg"
  done
  exit 1
fi
exit 0
