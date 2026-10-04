#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Chain-shape proof per R-C2 fold (pre-mortem Cockburn — walking skeleton
# needs chain integrity proven at PR 1, not PR 5). Stub driver that
# invokes /personas skill and asserts the skill writes an output file
# at the expected path. Full /personas anchors (cli#320 slug + cli#318
# path contract) land in PR 2.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L60
# Session A walking skeleton — PR 1b.

# test-list:
# [x] T01 stub detects missing output file — RED on pre-cure fixture
# [x] T02 stub detects output file present — GREEN on post-cure fixture
# [x] T03 chain-shape proof: /interpret-input artifact feeds /personas

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
# driver function — stub for chain-shape proof
# ============================================================
# Asserts: /personas writes to the path /jtbd-tasks reads from.
# PR 2 will extend with cli#320 slug anchor + cli#318 full path contract.
drive_personas_stub() {
  local output_dir="$1"
  local upstream_artifact="$2"
  # Chain-shape precondition: /interpret-input artifact exists.
  if ! check_artifact_exists "$upstream_artifact" >/dev/null 2>&1; then
    echo "FAIL|personas-upstream-missing|chain broken — /interpret-input artifact absent"
    return 3
  fi
  # Personas writes one or more .md files under output_dir.
  local out
  out=$(check_artifact_exists "$output_dir/*.md" 2>&1)
  local rc=$?
  if [[ "$rc" != "0" ]]; then
    echo "FAIL|personas-output-missing|chain broken — /personas wrote no .md files under $output_dir"
    return 3
  fi
  echo "PASS|personas-chain-shape|upstream artifact feeds /personas output cleanly"
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — pre-cure: /personas wrote no output
  upstream="$TMP_BASE/t01.interpret.json"
  echo '{"intent":"sample"}' > "$upstream"
  output_dir="$TMP_BASE/t01-personas-empty"
  mkdir -p "$output_dir"
  out=$(drive_personas_stub "$output_dir" "$upstream" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "no .md files"; then
    pass "T01 pre-cure RED chain-break fires correctly"
  else
    fail "T01 pre-cure" "expected rc=3 chain-break; got rc=$rc out=$out"
  fi

  # T02 — post-cure: /personas wrote persona file
  upstream="$TMP_BASE/t02.interpret.json"
  echo '{"intent":"sample"}' > "$upstream"
  output_dir="$TMP_BASE/t02-personas"
  mkdir -p "$output_dir"
  cat > "$output_dir/sam.md" <<'EOF'
---
name: Sam
role: cold adopter
---
Sam explores lite without prior context.
EOF
  out=$(drive_personas_stub "$output_dir" "$upstream" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "chain-shape"; then
    pass "T02 post-cure GREEN chain-shape works"
  else
    fail "T02 post-cure" "expected rc=0 chain-shape; got rc=$rc out=$out"
  fi

  # T03 — upstream missing: chain broken earlier
  output_dir="$TMP_BASE/t03-personas"
  mkdir -p "$output_dir"
  out=$(drive_personas_stub "$output_dir" "$TMP_BASE/nonexistent.json" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "upstream-missing"; then
    pass "T03 upstream-missing chain-break detected"
  else
    fail "T03 upstream-missing" "expected rc=3 upstream-missing; got rc=$rc out=$out"
  fi
else
  echo "--- SMOKE_LIVE=1 — /personas live invocation ---"
  WORKDIR="$TMP_BASE/live"
  upstream_dir="$WORKDIR/interpret"
  output_dir="$WORKDIR/personas"
  mkdir -p "$upstream_dir" "$output_dir"
  echo '{"intent":"sample live run"}' > "$upstream_dir/input.json"
  timeout 60 claude -p '/personas scaffold stub persona for cold adopter' > "$WORKDIR/trace" 2>&1 \
    || echo "claude exit $?" >> "$WORKDIR/trace"
  out=$(drive_personas_stub "$output_dir" "$upstream_dir/input.json" 2>&1)
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
echo "smoke-drive-e2e-personas-stub.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
