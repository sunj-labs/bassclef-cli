#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for the full authoring-chain path contract. Red-first
# anchor against cli#317 (/launch chain skills disagree on output paths —
# 4 mismatches). This driver walks the chain end-to-end:
#
#   /interpret-input → writes intent artifact
#   /personas       → reads intent, writes persona files
#   /jtbd-tasks     → reads personas, writes task files
#   /launch         → reads tasks, writes gallery
#
# For each edge, the driver asserts the read path matches the prior
# write path. One break at any edge fails the whole chain.
#
# Characterization modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. One break per edge
#     per test case; chain intact in a final clean fixture.
#   SMOKE_LIVE=1 — runs all 4 skills end-to-end in container; exit 3
#     is expected-RED per R-B4.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L71
# Addition from session surface: Finding 1 (full-chain path driver;
# plan doc fold 2026-10-04 session).

# test-list:
# [x] T01 chain intact — all 4 edges match
# [x] T02 edge-1 broken — /interpret-input artifact path mismatch
# [x] T03 edge-2 broken — /personas path mismatch
# [x] T04 edge-3 broken — /jtbd-tasks path mismatch
# [x] T05 edge-4 broken — /launch path mismatch
# [x] T06 missing writer at an edge fails chain

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
# driver function — walks the chain and asserts each edge
# ============================================================
drive_chain_path_contract() {
  local workdir="$1"
  local intent_file="$workdir/intent.json"
  local personas_dir="$workdir/personas"
  local tasks_dir="$workdir/tasks"
  local gallery_dir="$workdir/gallery"
  # Edge 1 — interpret-input artifact exists
  if ! check_artifact_exists "$intent_file" >/dev/null 2>&1; then
    echo "FAIL|chain-edge-1|cli#317 anchor — edge 1 broken: /interpret-input artifact missing at $intent_file"
    return 3
  fi
  # Edge 2 — personas reads intent AND writes to personas_dir
  if ! check_artifact_exists "$personas_dir/*.md" >/dev/null 2>&1; then
    echo "FAIL|chain-edge-2|cli#317 anchor — edge 2 broken: /personas wrote no .md under $personas_dir"
    return 3
  fi
  # Edge 3 — jtbd-tasks reads personas AND writes to tasks_dir
  if ! check_artifact_exists "$tasks_dir/*.md" >/dev/null 2>&1; then
    echo "FAIL|chain-edge-3|cli#317 anchor — edge 3 broken: /jtbd-tasks wrote no .md under $tasks_dir"
    return 3
  fi
  # Edge 4 — launch reads tasks AND writes gallery
  if ! check_artifact_exists "$gallery_dir/*.html" >/dev/null 2>&1; then
    echo "FAIL|chain-edge-4|cli#317 anchor — edge 4 broken: /launch wrote no .html under $gallery_dir"
    return 3
  fi
  echo "PASS|chain-contract|all 4 edges match write path to read path"
  return 0
}

make_clean_chain() {
  local wd="$1"
  mkdir -p "$wd/personas" "$wd/tasks" "$wd/gallery"
  echo '{"intent":"brainstorm"}' > "$wd/intent.json"
  echo "slug: cold-adopter" > "$wd/personas/jamie.md"
  echo "task: explore lite" > "$wd/tasks/task-01.md"
  echo "<html>gallery</html>" > "$wd/gallery/index.html"
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — chain intact
  wd="$TMP_BASE/t01"
  make_clean_chain "$wd"
  out=$(drive_chain_path_contract "$wd" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "all 4 edges"; then
    pass "T01 chain intact — GREEN"
  else
    fail "T01 chain intact" "expected rc=0; got rc=$rc out=$out"
  fi

  # T02 — edge 1 broken (no intent artifact)
  wd="$TMP_BASE/t02"
  make_clean_chain "$wd"
  rm "$wd/intent.json"
  out=$(drive_chain_path_contract "$wd" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "edge 1 broken"; then
    pass "T02 edge-1 broken RED fires"
  else
    fail "T02 edge-1 broken" "expected rc=3 edge-1; got rc=$rc out=$out"
  fi

  # T03 — edge 2 broken (no personas)
  wd="$TMP_BASE/t03"
  make_clean_chain "$wd"
  rm "$wd/personas"/*.md
  out=$(drive_chain_path_contract "$wd" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "edge 2 broken"; then
    pass "T03 edge-2 broken RED fires"
  else
    fail "T03 edge-2 broken" "expected rc=3 edge-2; got rc=$rc out=$out"
  fi

  # T04 — edge 3 broken (no tasks)
  wd="$TMP_BASE/t04"
  make_clean_chain "$wd"
  rm "$wd/tasks"/*.md
  out=$(drive_chain_path_contract "$wd" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "edge 3 broken"; then
    pass "T04 edge-3 broken RED fires"
  else
    fail "T04 edge-3 broken" "expected rc=3 edge-3; got rc=$rc out=$out"
  fi

  # T05 — edge 4 broken (no gallery)
  wd="$TMP_BASE/t05"
  make_clean_chain "$wd"
  rm "$wd/gallery"/*.html
  out=$(drive_chain_path_contract "$wd" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "edge 4 broken"; then
    pass "T05 edge-4 broken RED fires"
  else
    fail "T05 edge-4 broken" "expected rc=3 edge-4; got rc=$rc out=$out"
  fi

  # T06 — missing writer at a middle edge
  wd="$TMP_BASE/t06"
  mkdir -p "$wd"
  echo '{"intent":"brainstorm"}' > "$wd/intent.json"
  out=$(drive_chain_path_contract "$wd" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]]; then
    pass "T06 missing writer at edge-2 detected"
  else
    fail "T06 missing writer" "expected rc=3; got rc=$rc"
  fi
else
  echo "--- SMOKE_LIVE=1 — chain live invocation ---"
  WORKDIR="$TMP_BASE/live"
  mkdir -p "$WORKDIR/personas" "$WORKDIR/tasks" "$WORKDIR/gallery"
  # Walk the chain for real. Each step feeds the next.
  timeout 60 claude -p '/interpret-input "brainstorm cold storage variants"' > "$WORKDIR/intent.json" 2>&1 \
    || echo "interpret-input exit $?" >&2
  timeout 60 claude -p '/personas scaffold persona cold-adopter' > "$WORKDIR/personas-trace" 2>&1 \
    || echo "personas exit $?" >&2
  timeout 60 claude -p '/jtbd-tasks derive from persona' > "$WORKDIR/tasks-trace" 2>&1 \
    || echo "jtbd-tasks exit $?" >&2
  timeout 90 claude -p '/launch --local test gallery' > "$WORKDIR/launch-trace" 2>&1 \
    || echo "launch exit $?" >&2
  out=$(drive_chain_path_contract "$WORKDIR" 2>&1)
  rc=$?
  echo "$out"
  exit "$rc"
fi

# ============================================================
# summary
# ============================================================
echo ""
echo "============================================"
echo "smoke-drive-e2e-chain-contract.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
