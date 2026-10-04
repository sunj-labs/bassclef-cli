#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/lib/lite-runtime-invariants.sh — 5 narrow functions enforce
# cross-release invariants on every driver per plan doc
# docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L44-50.
#
# Design refs:
#   docs/risk-ledgers/2026-10-04-session-a-walking-skeleton.md R-T1, R-C1
#   docs/rfcs/2026-10-04-session-a-walking-skeleton.md F-HW-1, F-JC-1
#
# Narrow interface (per @luminary john-ousterhout deep module):
#   assert_no_absolute_paths <trace-file>
#   assert_bash_3_2_syntax <script-file>
#   assert_no_pyyaml_required <trace-file>
#   assert_no_playwright <trace-file>
#   assert_lite_runtime <trace-file>           # umbrella — composes the 4 above
#
# Return contract:
#   0 — PASS; emits "PASS|<name>|<msg>" on stdout
#   1 — FAIL or MISSING; emits "FAIL|<name>|<msg>" or "MISSING|<name>|..."
#
# Sourced by scripts/tests/smoke-drive-e2e-*.test.sh at the top of every driver.
#
# @pattern patterns/code/gof/strategy.md — one function per invariant;
# same signature; caller composes via assert_lite_runtime umbrella.
#
# API version — bump policy documented in CONTRIBUTING.md under
# "Lite adopter test runtime". Bump on any signature change or
# return-code semantics change to the 5 public functions above.
# Added per cli#341 (F-AR-3) so callers can detect lib skew.
export LITE_RUNTIME_INVARIANTS_API_VERSION="1.0"

# Internal: precheck that a trace or script file exists.
_lri_precheck() {
  local file="$1"
  local invariant="$2"
  if [[ ! -f "$file" ]]; then
    echo "MISSING|${invariant}|file not found: $file"
    return 1
  fi
  return 0
}

# assert_no_absolute_paths — trace must not reference /Users/<name>
# or /home/<name> absolute paths. Trace output is the surface adopters
# see; skill body source may legitimately carry example paths in
# docstrings. Per R-T1 fold, this scans trace only.
assert_no_absolute_paths() {
  local trace_file="$1"
  _lri_precheck "$trace_file" "no-absolute-paths" || return 1
  local matches
  matches=$(grep -cE '(/Users/[a-zA-Z0-9._-]+|/home/[a-zA-Z0-9._-]+)' "$trace_file" 2>/dev/null | tr -d '\n' || echo 0)
  [[ -z "$matches" ]] && matches=0
  if [[ "$matches" -eq 0 ]]; then
    echo "PASS|no-absolute-paths|0 matches"
    return 0
  fi
  echo "FAIL|no-absolute-paths|${matches} match(es) — trace carries machine-identifier path"
  return 1
}

# assert_bash_3_2_syntax — script must not use bash 4+ features that
# break on macOS 3.2.57 stock bash. Catches `declare -A` (assoc arrays)
# and `[[` double-bracket conditionals. Per R-C1 fold + cli#306 class.
assert_bash_3_2_syntax() {
  local script_file="$1"
  _lri_precheck "$script_file" "bash-3-2-syntax" || return 1
  local matches=0
  if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$script_file" 2>/dev/null; then
    matches=$((matches+1))
  fi
  if grep -qE '(^|[[:space:]])\[\[[[:space:]]' "$script_file" 2>/dev/null; then
    matches=$((matches+1))
  fi
  if [[ "$matches" -eq 0 ]]; then
    echo "PASS|bash-3-2-syntax|clean"
    return 0
  fi
  echo "FAIL|bash-3-2-syntax|${matches} bashism(s) — declare -A or [[ found"
  return 1
}

# assert_no_pyyaml_required — trace must not show ImportError or
# ModuleNotFoundError on yaml. Catches cli#308 class — lib/state.sh
# needs PyYAML; stock macOS lacks it; adopter sees cryptic error.
assert_no_pyyaml_required() {
  local trace_file="$1"
  _lri_precheck "$trace_file" "no-pyyaml-required" || return 1
  local matches
  matches=$(grep -cE "(ImportError.*yaml|No module named ['\"]?yaml['\"]?)" "$trace_file" 2>/dev/null | tr -d '\n' || echo 0)
  [[ -z "$matches" ]] && matches=0
  if [[ "$matches" -eq 0 ]]; then
    echo "PASS|no-pyyaml-required|0 matches"
    return 0
  fi
  echo "FAIL|no-pyyaml-required|${matches} match(es) — adopter machine lacks PyYAML"
  return 1
}

# assert_no_playwright — trace must not reference Playwright. Lite
# does not ship Playwright MCP; skills that assume it break on cold
# adopter machines. Per plan doc L130.
assert_no_playwright() {
  local trace_file="$1"
  _lri_precheck "$trace_file" "no-playwright" || return 1
  local matches
  matches=$(grep -icE 'playwright' "$trace_file" 2>/dev/null | tr -d '\n' || echo 0)
  [[ -z "$matches" ]] && matches=0
  if [[ "$matches" -eq 0 ]]; then
    echo "PASS|no-playwright|0 matches"
    return 0
  fi
  echo "FAIL|no-playwright|${matches} match(es) — skill assumes Playwright MCP"
  return 1
}

# assert_lite_runtime — umbrella. Runs the 4 trace-based invariants.
# Script-syntax invariant is NOT composed here; drivers call it per
# script path, not per trace. Caller composes:
#   assert_lite_runtime "$trace" || exit 1
#   assert_bash_3_2_syntax "$script" || exit 1
assert_lite_runtime() {
  local trace_file="$1"
  _lri_precheck "$trace_file" "lite-runtime" || return 1
  local overall=0
  local out
  out=$(assert_no_absolute_paths "$trace_file")
  echo "$out"
  [[ "$out" == PASS* ]] || overall=1
  out=$(assert_no_pyyaml_required "$trace_file")
  echo "$out"
  [[ "$out" == PASS* ]] || overall=1
  out=$(assert_no_playwright "$trace_file")
  echo "$out"
  [[ "$out" == PASS* ]] || overall=1
  if [[ "$overall" -eq 0 ]]; then
    echo "PASS|lite-runtime|3 trace invariants green"
    return 0
  fi
  echo "FAIL|lite-runtime|one or more trace invariants failed"
  return 1
}
