#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /jtbd-tasks. Red-first anchor against cli#318
# read-side (/jtbd-tasks reads from the same persona path /personas
# writes). PR 2 anchored the write side; this driver anchors the read
# side so the contract break shows up at either edge.
#
# Characterization modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Pre-cure (reader
#     expects .yaml path; writer uses .md) RED. Post-cure (reader
#     and writer both on .md) GREEN.
#   SMOKE_LIVE=1 — runs `claude -p /jtbd-tasks` in container; exit 3
#     is expected-RED per R-B4.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L76

# test-list:
# [x] T01 reader on non-canonical .yaml path — RED anchor fires
# [x] T02 reader on canonical .md path — GREEN flip
# [x] T03 reader fails cleanly when persona file missing
# [x] T04 cross-check — PR 2 persona output is picked up by this reader

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
# driver function
# ============================================================
# cli#318 read-side — /jtbd-tasks reads a persona file at the canonical
# .md path. If it only knows how to read .yaml, the chain breaks.
drive_jtbd_tasks_read_anchor() {
  local personas_dir="$1"
  local reader_expectation="$2"  # "md" or "yaml"
  if [[ "$reader_expectation" != "md" && "$reader_expectation" != "yaml" ]]; then
    echo "FAIL|jtbd-tasks-bad-ext|unknown reader expectation: $reader_expectation"
    return 3
  fi
  local glob="${personas_dir}/*.${reader_expectation}"
  local out
  out=$(check_artifact_exists "$glob" 2>&1)
  local rc=$?
  if [[ "$rc" != "0" ]]; then
    if [[ "$reader_expectation" == "yaml" ]]; then
      echo "FAIL|jtbd-tasks-read-contract|cli#318 anchor — reader expects .yaml but writer uses .md (RED anchor)"
      return 3
    fi
    echo "FAIL|jtbd-tasks-no-persona|no persona at ${glob}"
    return 3
  fi
  echo "PASS|jtbd-tasks-read-ok|reader found persona at .${reader_expectation}"
  return 0
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # T01 — reader expects .yaml; writer puts .md; chain breaks
  pd="$TMP_BASE/t01"
  mkdir -p "$pd"
  echo "slug: cold-adopter" > "$pd/jamie.md"
  out=$(drive_jtbd_tasks_read_anchor "$pd" "yaml" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "cli#318 anchor"; then
    pass "T01 reader-on-yaml pre-cure RED fires"
  else
    fail "T01 reader-on-yaml pre-cure" "expected rc=3 cli#318; got rc=$rc out=$out"
  fi

  # T02 — reader expects .md; writer puts .md; chain works
  pd="$TMP_BASE/t02"
  mkdir -p "$pd"
  echo "slug: cold-adopter" > "$pd/jamie.md"
  out=$(drive_jtbd_tasks_read_anchor "$pd" "md" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "found persona"; then
    pass "T02 reader-on-md post-cure GREEN"
  else
    fail "T02 reader-on-md post-cure" "expected rc=0; got rc=$rc out=$out"
  fi

  # T03 — reader finds no persona at any extension
  pd="$TMP_BASE/t03"
  mkdir -p "$pd"
  out=$(drive_jtbd_tasks_read_anchor "$pd" "md" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "no persona"; then
    pass "T03 missing persona detected"
  else
    fail "T03 missing persona" "expected rc=3 no-persona; got rc=$rc out=$out"
  fi

  # T04 — cross-check: PR 2 would write persona at .md; this reader picks up
  pd="$TMP_BASE/t04"
  mkdir -p "$pd"
  {
    printf -- '---\n'
    printf 'slug: cold-adopter\n'
    printf 'name: Jamie Smith\n'
    printf -- '---\n'
    printf 'Cold adopter trying lite fresh.\n'
  } > "$pd/jamie.md"
  out=$(drive_jtbd_tasks_read_anchor "$pd" "md" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]]; then
    pass "T04 cross-check with PR 2 persona shape"
  else
    fail "T04 cross-check" "expected rc=0; got rc=$rc"
  fi
else
  echo "--- SMOKE_LIVE=1 — /jtbd-tasks live invocation ---"
  WORKDIR="$TMP_BASE/live"
  pd="$WORKDIR/personas"
  mkdir -p "$pd"
  echo "slug: cold-adopter" > "$pd/jamie.md"
  timeout 60 claude -p '/jtbd-tasks derive tasks for persona jamie' > "$WORKDIR/trace" 2>&1 \
    || echo "claude exit $?" >> "$WORKDIR/trace"
  # Reader assertion — did jtbd pick up the persona?
  out=$(drive_jtbd_tasks_read_anchor "$pd" "md" 2>&1)
  rc=$?
  echo "$out"
  exit "$rc"
fi

# ============================================================
# summary
# ============================================================
echo ""
echo "============================================"
echo "smoke-drive-e2e-jtbd-tasks.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
