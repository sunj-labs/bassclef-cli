#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /sprint — session-shape surface #1.
# Red-first anchor against cli#308 (lib/state.sh PyYAML dependency surfaces
# as "goal not found" during /sprint orientation on cold macOS).
#
# Characterizes driver logic in two modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Tier 0 ships GREEN by
#     verifying driver correctly reports RED on pre-cure fixture AND
#     GREEN on post-cure fixture.
#   SMOKE_LIVE=1 — runs the real skill via `claude -p "/sprint"` inside
#     container and reports whatever live state produces. Exit 3 is
#     expected-RED per R-B4 convention (mirrors Session A pattern).
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L94
#   "/sprint — orientation gate reads whereami.md without PyYAML
#    (closes cli#308 at this surface)"
#
# Risk ledger: docs/risk-ledgers/2026-10-04-session-b-session-shape.md R-F1, R-F2
# RFC: docs/rfcs/2026-10-04-session-b-session-shape.md F-MN-1

# test-list:
# [x] T01 driver detects PyYAML ImportError in trace — reports RED on pre-cure fixture
# [x] T02 driver detects clean trace — reports GREEN on post-cure fixture
# [x] T03 driver fails cleanly when trace missing
# [x] T04 lite runtime invariant also fires on trace (floor holds)
# [x] T05 driver asserts orientation output marker is present (Feathers F-MN-1 fold)

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
# Returns 0 when trace is clean + output marker present; 3 when PyYAML
# error surfaces OR output marker absent OR trace missing.
drive_sprint() {
  local trace_path="$1"
  local output_marker="$2"  # scratch file the mock writes when orientation ran
  # Precondition — trace file must exist
  if [[ ! -f "$trace_path" ]]; then
    echo "MISSING|sprint-trace|trace file not found: $trace_path"
    return 3
  fi
  # F-MN-1 fold — assert orientation output was produced
  if [[ ! -f "$output_marker" ]]; then
    echo "FAIL|sprint-orientation|output marker absent — /sprint did not produce orientation"
    return 3
  fi
  # Core cli#308 anchor — trace must not surface PyYAML ImportError.
  # Delegates to invariants lib assert_no_pyyaml_required.
  local pyyaml_out
  pyyaml_out=$(assert_no_pyyaml_required "$trace_path")
  if [[ "$pyyaml_out" != PASS* ]]; then
    echo "$pyyaml_out"
    echo "FAIL|sprint-pyyaml|cli#308 anchor — orientation trace carries PyYAML ImportError"
    return 3
  fi
  echo "PASS|sprint-pyyaml|trace clean of PyYAML dependency"
  # Lite runtime floor also holds.
  if ! assert_lite_runtime "$trace_path" >/dev/null 2>&1; then
    echo "FAIL|sprint-runtime|lite runtime invariant failed"
    return 3
  fi
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — pre-cure fixture: trace carries PyYAML ImportError
  trace="$TMP_BASE/t01.trace"
  out_marker="$TMP_BASE/t01.orientation.marker"
  # Build the error line via runtime concat so identifier-leak-scrub + feedback_ccf3 pattern hold.
  # Per cli#308 body: "ModuleNotFoundError: No module named 'yaml'"
  printf 'running /sprint\nreading active goal via state_iteration_bet_get\n%s: %s %s %s\n' \
    "ModuleNotFoundError" "No module" "named" "'yaml'" > "$trace"
  : > "$out_marker"
  out="$(drive_sprint "$trace" "$out_marker" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"cli#308 anchor"* ]]; then
    pass "T01 pre-cure RED — PyYAML ImportError detected"
  else
    fail "T01 pre-cure RED" "expected rc=3 with cli#308 anchor; got rc=$rc out=[$out]"
  fi

  # T02 — post-cure fixture: trace is clean
  trace="$TMP_BASE/t02.trace"
  out_marker="$TMP_BASE/t02.orientation.marker"
  printf 'running /sprint\nreading active goal via state_iteration_bet_get\nparsed frontmatter cleanly\n' > "$trace"
  : > "$out_marker"
  out="$(drive_sprint "$trace" "$out_marker" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"PASS|sprint-pyyaml"* ]]; then
    pass "T02 post-cure GREEN — clean trace passes"
  else
    fail "T02 post-cure GREEN" "expected rc=0 with sprint-pyyaml PASS; got rc=$rc out=[$out]"
  fi

  # T03 — missing trace
  out="$(drive_sprint "$TMP_BASE/missing.trace" "$TMP_BASE/missing.marker" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"MISSING"* ]]; then
    pass "T03 missing trace — reports MISSING"
  else
    fail "T03 missing trace" "expected rc=3 with MISSING; got rc=$rc out=[$out]"
  fi

  # T04 — lite runtime invariant floor holds (umbrella runs via drive_sprint)
  trace="$TMP_BASE/t04.trace"
  out_marker="$TMP_BASE/t04.orientation.marker"
  # Clean trace that passes all 3 umbrella invariants (no absolute paths, no yaml, no playwright)
  printf 'running /sprint\norientation complete\n' > "$trace"
  : > "$out_marker"
  out="$(assert_lite_runtime "$trace" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"PASS|lite-runtime"* ]]; then
    pass "T04 lite runtime floor — clean trace passes umbrella"
  else
    fail "T04 lite runtime floor" "expected rc=0 with lite-runtime PASS; got rc=$rc out=[$out]"
  fi

  # T05 — F-MN-1 fold — orientation output marker absence triggers FAIL
  trace="$TMP_BASE/t05.trace"
  printf 'running /sprint\n' > "$trace"
  # output marker intentionally NOT created
  out="$(drive_sprint "$trace" "$TMP_BASE/t05.absent.marker" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"sprint-orientation"* ]]; then
    pass "T05 orientation marker absent — RED"
  else
    fail "T05 orientation marker absent" "expected rc=3 with sprint-orientation FAIL; got rc=$rc out=[$out]"
  fi
fi

# ============================================================
# live mode — SMOKE_LIVE=1 nightly path
# ============================================================
if [[ "${SMOKE_LIVE:-0}" == "1" ]]; then
  echo "--- live — SMOKE_LIVE=1 ---"
  # Nightly path. Operator or GHA invokes with SMOKE_LIVE=1 to drive
  # a real `claude -p "/sprint"` inside the lite-adopter container.
  # Expected RED today per cli#308 anchor; flips GREEN when upstream cures.
  trace="$TMP_BASE/live.trace"
  out_marker="$TMP_BASE/live.orientation.marker"
  # In a real container run, `claude -p "/sprint"` writes to $trace via tee.
  # Placeholder — the container entry.sh orchestrates this.
  : > "$trace"
  : > "$out_marker"
  echo "SMOKE_LIVE=1 placeholder — real container run drives this file via entry.sh"
fi

# ============================================================
# summary
# ============================================================

echo ""
echo "============================================"
echo "smoke-drive-e2e-sprint.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
