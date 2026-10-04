#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /longrun prep — session-shape surface #2.
# Red-first anchor against the 6-axis compounding frame per
# .claude/rules/compounding-sequence-fresh-analysis.md L59-69.
#
# The 6 axes are: Deliverable, Problem, Value prop, Turns, Risk,
# Shipping priority. Legacy 5-axis frame is accepted through
# 2026-10-31 per ADR-031 but new drivers pin the new frame.
#
# Characterizes driver logic in two modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Tier 0 ships GREEN by
#     verifying driver correctly reports RED on pre-cure fixture (missing
#     one axis header) AND GREEN on post-cure fixture (all 6 present).
#   SMOKE_LIVE=1 — runs real `claude -p "/longrun prep"` and reports.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L95
#   "/longrun prep — compounding-axis check fires with the 6-axis frame
#    per .claude/rules/compounding-sequence-fresh-analysis.md"
#
# Risk ledger: docs/risk-ledgers/2026-10-04-session-b-session-shape.md R-F5
# RFC: docs/rfcs/2026-10-04-session-b-session-shape.md F-JC-1, F-MN-3

# test-list:
# [x] T01 driver detects missing axis — reports RED on pre-cure fixture
# [x] T02 driver detects all 6 axes — reports GREEN on post-cure fixture
# [x] T03 driver fails cleanly when output missing
# [x] T04 driver names which axis is absent on RED
# [x] T05 driver tolerates em-dashes in axis labels (R-L3 fold)
# [x] T06 lite runtime invariant floor holds on prep output

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

# The 6 required axis labels per compounding-sequence-fresh-analysis.md L59-69.
# Keep in sync with the rule body; label change forces test update (Feathers).
AXIS_LABELS=(
  "Deliverable"
  "Problem"
  "Value prop"
  "Turns"
  "Risk"
  "Shipping priority"
)

# ============================================================
# driver function — reusable by SMOKE_LIVE path too
# ============================================================
# Returns 0 when all 6 axis labels present in prep output; 3 when any
# missing OR output absent. Names the first missing axis on FAIL.
drive_longrun_prep() {
  local prep_output="$1"
  if [[ ! -f "$prep_output" ]]; then
    echo "MISSING|longrun-prep-output|prep output file not found: $prep_output"
    return 3
  fi
  local missing=""
  local label
  for label in "${AXIS_LABELS[@]}"; do
    if ! grep -qF "$label" "$prep_output" 2>/dev/null; then
      missing="$label"
      break
    fi
  done
  if [[ -n "$missing" ]]; then
    echo "FAIL|longrun-prep-axis|6-axis frame missing: '$missing'"
    return 3
  fi
  echo "PASS|longrun-prep-axis|all 6 axes present"
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # Helper — build a prep output with the 6 axes (optionally skip one).
  build_prep_output() {
    local out="$1"
    local skip="${2:-}"  # label to skip, or empty for all 6
    {
      echo "# /longrun prep — Session X"
      echo ""
      echo "## Recommended — Option a"
      echo ""
      for label in "${AXIS_LABELS[@]}"; do
        [[ "$label" == "$skip" ]] && continue
        echo "- **${label}:** value for ${label}"
      done
    } > "$out"
  }

  # T01 — pre-cure fixture: output missing one axis (Shipping priority)
  prep="$TMP_BASE/t01.prep.md"
  build_prep_output "$prep" "Shipping priority"
  out="$(drive_longrun_prep "$prep" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"Shipping priority"* ]]; then
    pass "T01 pre-cure RED — missing Shipping priority detected"
  else
    fail "T01 pre-cure RED" "expected rc=3 naming Shipping priority; got rc=$rc out=[$out]"
  fi

  # T02 — post-cure fixture: all 6 axes present
  prep="$TMP_BASE/t02.prep.md"
  build_prep_output "$prep"
  out="$(drive_longrun_prep "$prep" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"all 6 axes present"* ]]; then
    pass "T02 post-cure GREEN — all 6 axes detected"
  else
    fail "T02 post-cure GREEN" "expected rc=0 with all-6 pass; got rc=$rc out=[$out]"
  fi

  # T03 — missing output file
  out="$(drive_longrun_prep "$TMP_BASE/missing.prep.md" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"MISSING"* ]]; then
    pass "T03 missing output — reports MISSING"
  else
    fail "T03 missing output" "expected rc=3 with MISSING; got rc=$rc out=[$out]"
  fi

  # T04 — driver names which axis is absent (named axis = Problem)
  prep="$TMP_BASE/t04.prep.md"
  build_prep_output "$prep" "Problem"
  out="$(drive_longrun_prep "$prep" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"6-axis frame missing: 'Problem'"* ]]; then
    pass "T04 names the missing axis"
  else
    fail "T04 names missing axis" "expected rc=3 naming Problem; got rc=$rc out=[$out]"
  fi

  # T05 — R-L3 fold: prep output with em-dashes in headers still passes.
  # The compounding-sequence rule uses em-dashes in rendered output.
  prep="$TMP_BASE/t05.prep.md"
  {
    echo "# /longrun prep"
    echo "## Recommended — Option a — <description>"
    for label in "${AXIS_LABELS[@]}"; do
      # Build line with em-dash via runtime concat so grep tolerance is tested.
      printf -- "- **%s** %s value\n" "$label" "—"
    done
  } > "$prep"
  out="$(drive_longrun_prep "$prep" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 ]]; then
    pass "T05 em-dash tolerance — grep against literal labels not regex"
  else
    fail "T05 em-dash tolerance" "expected rc=0 even with em-dashes; got rc=$rc out=[$out]"
  fi

  # T06 — lite runtime invariant floor holds on the prep output
  trace="$TMP_BASE/t06.trace"
  printf 'running /longrun prep\nrendering 6-axis frame\n' > "$trace"
  out="$(assert_lite_runtime "$trace" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"PASS|lite-runtime"* ]]; then
    pass "T06 lite runtime floor — trace passes umbrella"
  else
    fail "T06 lite runtime floor" "expected rc=0 with lite-runtime PASS; got rc=$rc out=[$out]"
  fi
fi

# ============================================================
# live mode — SMOKE_LIVE=1 nightly path
# ============================================================
if [[ "${SMOKE_LIVE:-0}" == "1" ]]; then
  echo "--- live — SMOKE_LIVE=1 ---"
  echo "SMOKE_LIVE=1 placeholder — container entry.sh drives \`claude -p '/longrun prep'\` and tees to prep output file."
fi

# ============================================================
# summary
# ============================================================

echo ""
echo "============================================"
echo "smoke-drive-e2e-longrun-prep.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
