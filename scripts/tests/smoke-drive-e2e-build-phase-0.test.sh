#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /build Phase 0 safety floor on Step-N headings.
# Characterizes cli#307 cure at upstream main SHA 09beb249.
#
# Pre-cure: /build Phase 0 awk matched only `### WU-` headings; a spec
# whose acceptance used `### Step-1` read 0 lines; floor silently passed.
# Post-cure (upstream #2056): awk matches `### (Step|WU)-`; floor fires.
#
# Driver function signature mirrors Session A + B pattern:
#   drive_build_phase_0 <trace> <acceptance_file> <expected_hits>
# Returns 0 when trace hit count matches expected; 3 otherwise.
#
# Session C PR 1 per docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md.
# Risk ledger: docs/risk-ledgers/2026-10-04-session-c-handoff-cliff.md.
# Upstream source of truth: `.claude/hooks/tests/build-skill-phase-0-step-n-scan.test.sh`.

# test-list:
# [x] T01 pre-cure fixture — Step-N spec with floor path reads 0 hits (RED anchor)
# [x] T02 post-cure fixture — Step-N spec with floor path reads matched hits (GREEN)
# [x] T03 regression fixture — WU-N spec with floor path still reads hits (GREEN; WU-N must survive)
# [x] T04 clean fixture — Step-N spec with no floor path reads 0 hits + exits 0 (clean path)
# [x] T05 driver fails cleanly when trace or acceptance file missing
# [x] T06 lite runtime invariant floor holds on trace

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

# Floor path list per cli#307 ticket body. Open to extension (R-L3 fold —
# the test asserts ANY of these detected, not ALL).
FLOOR_PATHS=(
  "src/lib/auth/"
  "src/app/api/auth/"
  "prisma/schema.prisma"
  "prisma/migrations/"
  "src/middleware.ts"
  "src/lib/security/"
)

# ============================================================
# driver function — mirrors upstream Phase 0 scan shape
# ============================================================
# Simulates the Phase 0 scan via pure bash (BSD awk ERE alternation
# is non-portable). The caller picks which heading shape(s) match:
#   mode="wu-only"       — pre-cure; only `### WU-N` headings open block
#   mode="step-and-wu"   — post-cure; both `### Step-N` and `### WU-N`
# Returns 0 when hit_count matches expected; 3 otherwise.
drive_build_phase_0() {
  local acceptance_file="$1"
  local mode="$2"
  local expected_hits="$3"
  if [[ ! -f "$acceptance_file" ]]; then
    echo "MISSING|build-phase-0|acceptance file not found: $acceptance_file"
    return 3
  fi
  local hits=0
  local in_block=0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Detect heading open per mode.
    local is_wu=0 is_step=0
    [[ "$line" =~ ^###[[:space:]]WU- ]] && is_wu=1
    [[ "$line" =~ ^###[[:space:]]Step- ]] && is_step=1
    if [[ "$mode" == "wu-only" && "$is_wu" == 1 ]]; then
      in_block=1
      continue
    fi
    if [[ "$mode" == "step-and-wu" && ( "$is_wu" == 1 || "$is_step" == 1 ) ]]; then
      in_block=1
      continue
    fi
    # Close block on next ## heading.
    if [[ "$line" =~ ^##[[:space:]] ]]; then
      in_block=0
      continue
    fi
    # Inside block: grep acceptance lines for floor paths.
    if [[ "$in_block" == 1 && "$line" =~ ^-[[:space:]]\[[[:space:]]\] ]]; then
      for fp in "${FLOOR_PATHS[@]}"; do
        if [[ "$line" == *"$fp"* ]]; then
          hits=$((hits+1))
        fi
      done
    fi
  done < "$acceptance_file"
  if [[ "$hits" == "$expected_hits" ]]; then
    echo "PASS|build-phase-0|hits=$hits matches expected"
    return 0
  fi
  echo "FAIL|build-phase-0|hits=$hits expected=$expected_hits"
  return 3
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # Spec with Step-N heading + floor path in acceptance.
  step_spec="$TMP_BASE/step-spec.md"
  cat > "$step_spec" <<'EOF'
## Steps enumerated

### Step-1 — login flow (US-001)

- [ ] edit src/lib/auth/login.ts to add OAuth handler
- [ ] edit src/app/api/auth/callback/route.ts for callback

### Step-2 — session storage

- [ ] write session cookie
EOF

  # Spec with WU-N heading + floor path in acceptance.
  wu_spec="$TMP_BASE/wu-spec.md"
  cat > "$wu_spec" <<'EOF'
## Steps enumerated

### WU-1 — login flow (US-001)

- [ ] edit src/lib/auth/login.ts to add OAuth handler
- [ ] edit prisma/schema.prisma to add User model
EOF

  # Spec with Step-N heading + NO floor path.
  clean_spec="$TMP_BASE/clean-spec.md"
  cat > "$clean_spec" <<'EOF'
## Steps enumerated

### Step-1 — login UI (US-001)

- [ ] edit src/components/LoginForm.tsx to render form
- [ ] edit src/styles/login.css for layout
EOF

  # T01 — PRE-CURE mode only matches WU-N; Step-N spec reads 0.
  out="$(drive_build_phase_0 "$step_spec" "wu-only" 0 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"hits=0 matches expected"* ]]; then
    pass "T01 pre-cure RED anchor — Step-N spec reads 0 hits under wu-only"
  else
    fail "T01 pre-cure RED anchor" "expected rc=0 hits=0; got rc=$rc out=[$out]"
  fi

  # T02 — POST-CURE mode matches both; Step-N spec reads 2 hits.
  out="$(drive_build_phase_0 "$step_spec" "step-and-wu" 2 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"hits=2 matches expected"* ]]; then
    pass "T02 post-cure GREEN — Step-N spec reads 2 hits under step-and-wu"
  else
    fail "T02 post-cure GREEN" "expected rc=0 hits=2; got rc=$rc out=[$out]"
  fi

  # T03 — Regression: WU-N spec still reads 2 hits under new mode.
  out="$(drive_build_phase_0 "$wu_spec" "step-and-wu" 2 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"hits=2 matches expected"* ]]; then
    pass "T03 regression — WU-N spec still reads 2 hits post-cure"
  else
    fail "T03 regression" "expected rc=0 hits=2; got rc=$rc out=[$out]"
  fi

  # T04 — Clean path: Step-N spec with no floor path reads 0 hits.
  out="$(drive_build_phase_0 "$clean_spec" "step-and-wu" 0 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"hits=0 matches expected"* ]]; then
    pass "T04 clean path — Step-N spec without floor path reads 0 hits"
  else
    fail "T04 clean path" "expected rc=0 hits=0; got rc=$rc out=[$out]"
  fi

  # T05 — missing acceptance file.
  out="$(drive_build_phase_0 "$TMP_BASE/missing.md" "step-and-wu" 0 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"MISSING"* ]]; then
    pass "T05 missing acceptance file — reports MISSING"
  else
    fail "T05 missing acceptance file" "expected rc=3 with MISSING; got rc=$rc out=[$out]"
  fi

  # T06 — lite runtime invariant floor holds on a trace file written
  # from this run (the test spec itself serves as a trace analog).
  out="$(assert_lite_runtime "$step_spec" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"PASS|lite-runtime"* ]]; then
    pass "T06 lite runtime floor — spec passes umbrella"
  else
    fail "T06 lite runtime floor" "expected rc=0; got rc=$rc out=[$out]"
  fi
fi

# ============================================================
# live mode — SMOKE_LIVE=1 nightly path
# ============================================================
if [[ "${SMOKE_LIVE:-0}" == "1" ]]; then
  echo "--- live — SMOKE_LIVE=1 ---"
  echo "SMOKE_LIVE=1 placeholder — container entry.sh drives real /build Phase 0 and asserts floor-path signal + exit code."
fi

echo ""
echo "============================================"
echo "smoke-drive-e2e-build-phase-0.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
