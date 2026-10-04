#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /launch --local. Two anchors:
#
#   critique 6 — /launch Phase 4 (gallery) runs even when Phases 2/3/3b
#     markers absent; silent-skip class the Kunal rerun surfaced.
#   cli#314 — /launch --local says "open on phone" but local-serve binds
#     127.0.0.1 only; the UI is unreachable from a phone on the same LAN.
#
# Characterization modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Both anchors
#     characterized under pre-cure RED + post-cure GREEN.
#   SMOKE_LIVE=1 — runs `claude -p /launch --local` in container; exit
#     3 is expected-RED per R-B4.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L77

# test-list:
# [x] T01 phase-gate pre-cure RED — Phase 4 fires without upstream markers
# [x] T02 phase-gate post-cure GREEN — Phase 4 refuses when markers absent
# [x] T03 bind-address pre-cure RED — binds 127.0.0.1 only
# [x] T04 bind-address post-cure GREEN — binds 0.0.0.0 (LAN-reachable)
# [x] T05 both anchors clean on a well-formed launch state

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
# driver functions
# ============================================================
# critique 6 — Phase 4 (gallery) must refuse when Phases 2/3/3b
# markers absent. Driver takes a markers dir and a phase4 outcome log.
drive_launch_phase_gate() {
  local markers_dir="$1"
  local phase4_log="$2"
  local phases_present=0
  for p in phase2 phase3 phase3b; do
    if [[ -f "$markers_dir/$p.marker" ]]; then
      phases_present=$((phases_present+1))
    fi
  done
  if ! check_artifact_exists "$phase4_log" >/dev/null 2>&1; then
    echo "FAIL|launch-phase4-no-log|phase4 log absent"
    return 3
  fi
  local phase4_fired
  phase4_fired=$(grep -c 'phase4-fired' "$phase4_log" 2>/dev/null | tr -d '\n' || echo 0)
  [[ -z "$phase4_fired" ]] && phase4_fired=0
  if [[ "$phases_present" -lt 3 && "$phase4_fired" -gt 0 ]]; then
    echo "FAIL|launch-phase-gate|critique-6 anchor — Phase 4 fired with only $phases_present of 3 upstream markers (RED anchor)"
    return 3
  fi
  if [[ "$phases_present" -eq 3 && "$phase4_fired" -eq 0 ]]; then
    echo "FAIL|launch-phase-gate-oversight|phase4 did not fire despite all markers present"
    return 3
  fi
  echo "PASS|launch-phase-gate|phases=$phases_present phase4=$phase4_fired"
  return 0
}

# cli#314 — local preview must not bind 127.0.0.1 exclusively. Driver
# takes a bind-address log and asserts it binds 0.0.0.0 (or an
# explicit interface IP) so phones on the same LAN can reach it.
drive_launch_bind_address() {
  local bind_log="$1"
  if ! check_artifact_exists "$bind_log" >/dev/null 2>&1; then
    echo "FAIL|launch-bind-no-log|bind log absent"
    return 3
  fi
  if grep -qE 'listening on 127\.0\.0\.1' "$bind_log" 2>/dev/null; then
    if ! grep -qE 'listening on 0\.0\.0\.0' "$bind_log" 2>/dev/null; then
      echo "FAIL|launch-bind-loopback|cli#314 anchor — binds 127.0.0.1 only; phones on LAN cannot reach (RED anchor)"
      return 3
    fi
  fi
  echo "PASS|launch-bind-address|binds 0.0.0.0 or interface IP"
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — Phase 4 fires with 0 upstream markers (pre-cure)
  md="$TMP_BASE/t01-markers"
  mkdir -p "$md"
  p4="$TMP_BASE/t01-phase4.log"
  echo "phase4-fired at 2026-10-04" > "$p4"
  out=$(drive_launch_phase_gate "$md" "$p4" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "critique-6 anchor"; then
    pass "T01 phase-gate pre-cure RED fires"
  else
    fail "T01 phase-gate pre-cure" "expected rc=3 critique-6; got rc=$rc out=$out"
  fi

  # T02 — Phase 4 refuses with 0 upstream markers (post-cure)
  md="$TMP_BASE/t02-markers"
  mkdir -p "$md"
  p4="$TMP_BASE/t02-phase4.log"
  echo "phase4-refused; upstream markers missing" > "$p4"
  out=$(drive_launch_phase_gate "$md" "$p4" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]]; then
    pass "T02 phase-gate post-cure GREEN"
  else
    fail "T02 phase-gate post-cure" "expected rc=0; got rc=$rc out=$out"
  fi

  # T03 — bind 127.0.0.1 only (pre-cure)
  bl="$TMP_BASE/t03-bind.log"
  echo "listening on 127.0.0.1:5173" > "$bl"
  out=$(drive_launch_bind_address "$bl" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "cli#314 anchor"; then
    pass "T03 bind-address pre-cure RED fires"
  else
    fail "T03 bind-address pre-cure" "expected rc=3 cli#314; got rc=$rc out=$out"
  fi

  # T04 — bind 0.0.0.0 (post-cure)
  bl="$TMP_BASE/t04-bind.log"
  echo "listening on 0.0.0.0:5173" > "$bl"
  out=$(drive_launch_bind_address "$bl" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]]; then
    pass "T04 bind-address post-cure GREEN"
  else
    fail "T04 bind-address post-cure" "expected rc=0; got rc=$rc out=$out"
  fi

  # T05 — both clean on well-formed launch
  md="$TMP_BASE/t05-markers"
  mkdir -p "$md"
  touch "$md/phase2.marker" "$md/phase3.marker" "$md/phase3b.marker"
  p4="$TMP_BASE/t05-phase4.log"
  echo "phase4-fired cleanly" > "$p4"
  bl="$TMP_BASE/t05-bind.log"
  echo "listening on 0.0.0.0:5173" > "$bl"
  out_g=$(drive_launch_phase_gate "$md" "$p4" 2>&1)
  rc_g=$?
  out_b=$(drive_launch_bind_address "$bl" 2>&1)
  rc_b=$?
  if [[ "$rc_g" == "0" && "$rc_b" == "0" ]]; then
    pass "T05 both anchors clean on well-formed launch"
  else
    fail "T05 both-clean" "gate rc=$rc_g bind rc=$rc_b"
  fi
else
  echo "--- SMOKE_LIVE=1 — /launch --local live invocation ---"
  WORKDIR="$TMP_BASE/live"
  mkdir -p "$WORKDIR"
  timeout 60 claude -p '/launch --local test gallery' > "$WORKDIR/trace" 2>&1 \
    || echo "claude exit $?" >> "$WORKDIR/trace"
  # Reader asserts both anchors on the trace
  out_g=$(drive_launch_phase_gate "$WORKDIR" "$WORKDIR/trace" 2>&1)
  rc_g=$?
  out_b=$(drive_launch_bind_address "$WORKDIR/trace" 2>&1)
  rc_b=$?
  echo "$out_g"
  echo "$out_b"
  if [[ "$rc_g" == "0" && "$rc_b" == "0" ]]; then
    exit 0
  fi
  exit 3
fi

# ============================================================
# summary
# ============================================================
echo ""
echo "============================================"
echo "smoke-drive-e2e-launch-local.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
