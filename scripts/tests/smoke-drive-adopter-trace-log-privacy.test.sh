#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter was trying to: run bassclef skills on their project without
# their machine username leaking into trace logs, staged git content,
# or pushed branches.
#
# Pins Kunal #2036 finding #1 (trace-log absolute paths) + finding #5
# (CCF-3 blocks adopter's own shipped file — gitignore cure).
#
# Upstream cure: bassclef-upstream PR #2041 (merged into release-2026-10-03-89ceaa15; tag v1.7.0).
# Pre-cure characterization: `git checkout <parent-of-#2041>` in the
# bassclef sibling + re-run this driver → exits 1 (log leaks /Users/).
# Post-cure (current main): exits 0 (sanitize strips repo root prefix).
#
# UC: docs/use-cases/UC-script-cli-294-driver-1-trace-log-privacy.md
# Risk ledger: docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md
# Parent: cli#294 Step 2

# test-list:
# [x] T01 trace_log from a /Users/<name>/ workdir writes no absolute path to the log file
# [x] T02 same workdir writes no /home/<name>/ either (Linux adopter view)
# [x] T03 shipped adopter .gitignore template contains docs/sdlc-traces/
# [x] T04 SKIP if trace-helper.sh is unreachable (dist/lite/ + sibling both absent)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Locate trace-helper.sh — adopter view first (dist/lite/), sibling fallback.
# Note: cli does NOT bundle presence/dist-templates/ into dist/lite/ (verified
# via find on 2026-10-03); the shipped .gitignore template lives in the
# bassclef sibling, not in dist/lite. Resolve each path independently.
TRACE_HELPER=""
GITIGNORE_TEMPLATE=""

# trace-helper.sh — prefer dist/lite (adopter view post-prepublish), sibling fallback
if [ -f "$REPO_ROOT/dist/lite/.claude/hooks/trace-helper.sh" ]; then
  TRACE_HELPER="$REPO_ROOT/dist/lite/.claude/hooks/trace-helper.sh"
elif [ -n "${BASSCLEF_SIBLING_ROOT:-}" ] && [ -f "$BASSCLEF_SIBLING_ROOT/.claude/hooks/trace-helper.sh" ]; then
  TRACE_HELPER="$BASSCLEF_SIBLING_ROOT/.claude/hooks/trace-helper.sh"
elif [ -f "$HOME/src/sunj-labs/bassclef/.claude/hooks/trace-helper.sh" ]; then
  TRACE_HELPER="$HOME/src/sunj-labs/bassclef/.claude/hooks/trace-helper.sh"
else
  echo "SKIP (T04): no trace-helper.sh reachable at dist/lite/ or sibling or ~/src/sunj-labs/bassclef/" >&2
  exit 77
fi

# .gitignore template — sibling-first (cli does not bundle this path), env override, home fallback
if [ -n "${BASSCLEF_SIBLING_ROOT:-}" ] && [ -f "$BASSCLEF_SIBLING_ROOT/presence/dist-templates/.gitignore" ]; then
  GITIGNORE_TEMPLATE="$BASSCLEF_SIBLING_ROOT/presence/dist-templates/.gitignore"
elif [ -f "$HOME/src/sunj-labs/bassclef/presence/dist-templates/.gitignore" ]; then
  GITIGNORE_TEMPLATE="$HOME/src/sunj-labs/bassclef/presence/dist-templates/.gitignore"
fi

# Mock workdir mimics an adopter home path
TMP_BASE="$(mktemp -d)"
MOCK_HOME="$TMP_BASE/Users/mockkunal/adopter-repo"
mkdir -p "$MOCK_HOME/docs/sdlc-traces"
trap "rm -rf '$TMP_BASE'" EXIT

cd "$MOCK_HOME"
git init -q 2>/dev/null || true
git config user.email test@example.local 2>/dev/null || true
git config user.name test 2>/dev/null || true

# Source + fire. trace_log signature per upstream contract: hook, trigger, outcome.
# shellcheck disable=SC1090
source "$TRACE_HELPER"

if ! declare -f trace_log >/dev/null 2>&1; then
  echo "FAIL (setup): trace_log function not exported after sourcing $TRACE_HELPER" >&2
  exit 2
fi

trace_log "fake-hook" "fake-trigger" "fake-outcome" >/dev/null 2>&1 || true

# Locate the written log
LOG_FILE="$(ls -1 docs/sdlc-traces/*.log 2>/dev/null | head -1)"
if [ -z "$LOG_FILE" ]; then
  echo "FAIL (setup): no log file written to docs/sdlc-traces/" >&2
  exit 2
fi

# T01 — no /Users/ absolute path in the log
if grep -q "/Users/" "$LOG_FILE"; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL: trace log contains /Users/ absolute path. Line: $(grep '/Users/' "$LOG_FILE" | head -1)")
else
  PASS=$((PASS + 1))
fi

# T02 — no /home/ absolute path (Linux adopter view)
if grep -q "/home/" "$LOG_FILE"; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: trace log contains /home/ absolute path. Line: $(grep '/home/' "$LOG_FILE" | head -1)")
else
  PASS=$((PASS + 1))
fi

# T03 — shipped adopter .gitignore template contains docs/sdlc-traces/
if [ ! -f "$GITIGNORE_TEMPLATE" ]; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: shipped .gitignore template not found at $GITIGNORE_TEMPLATE")
elif ! grep -q "docs/sdlc-traces" "$GITIGNORE_TEMPLATE"; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: shipped .gitignore ($GITIGNORE_TEMPLATE) missing docs/sdlc-traces/ entry")
else
  PASS=$((PASS + 1))
fi

# Summary
echo "driver-1 trace-log-privacy: $PASS pass / $FAIL fail (source: $TRACE_HELPER)"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
