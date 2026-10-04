#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /personas (full). Red-first anchor against two
# cli tickets:
#
#   cli#320 — /personas builds default slug from git email; leaks
#     account id or handle (privacy class, Torvalds adopter floor).
#   cli#318 — /personas and /jtbd-tasks conflict on persona path;
#     the write-side half ships here. Read-side half ships in PR 3's
#     /jtbd-tasks driver.
#
# Characterizes driver logic in two modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Both pre-cure
#     (RED) and post-cure (GREEN) fixtures characterized per anchor.
#   SMOKE_LIVE=1 — runs real `claude -p /personas` in container; exit
#     3 is expected-RED per R-B4 convention.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L74-75
# Supersedes smoke-drive-e2e-personas-stub.test.sh (stub stays as
# cheaper nightly fallback per architect F-AR-4 no-change finding).

# test-list:
# [x] T01 slug-anchor pre-cure RED — persona slug matches git email local part
# [x] T02 slug-anchor post-cure GREEN — persona slug is a plain name
# [x] T03 path-anchor pre-cure RED — persona file at wrong path
# [x] T04 path-anchor post-cure GREEN — persona file at canonical path
# [x] T05 both anchors clean on a well-formed persona
# [x] T06 chain-shape — /interpret-input upstream artifact present

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
# driver functions — one per anchor
# ============================================================
# cli#320 — persona slug must not match git email local part.
drive_personas_slug_anchor() {
  local persona_file="$1"
  local git_email="$2"
  if ! check_artifact_exists "$persona_file" >/dev/null 2>&1; then
    echo "FAIL|personas-slug-missing|persona file absent"
    return 3
  fi
  local email_local
  email_local="${git_email%%@*}"
  if [[ -z "$email_local" ]]; then
    echo "FAIL|personas-slug-bad-email|cannot parse git email"
    return 3
  fi
  local slug
  slug=$(grep -E '^(slug|name):' "$persona_file" | head -1 | awk '{print $2}' | tr -d '"')
  if [[ "$slug" == "$email_local" ]]; then
    echo "FAIL|personas-slug-leak|cli#320 anchor — slug [$slug] matches git email local part (RED anchor)"
    return 3
  fi
  echo "PASS|personas-slug|slug [$slug] does not leak email"
  return 0
}

# cli#318 write-side — persona file at canonical path.
drive_personas_path_anchor() {
  local personas_dir="$1"
  local canonical_glob="${personas_dir}/*.md"
  local non_canonical_glob="${personas_dir}/*.yaml"
  if check_artifact_exists "$canonical_glob" >/dev/null 2>&1; then
    if check_artifact_exists "$non_canonical_glob" >/dev/null 2>&1; then
      echo "FAIL|personas-path-both|cli#318 anchor — persona exists at BOTH .md and .yaml (RED anchor)"
      return 3
    fi
    echo "PASS|personas-path-canonical|persona at canonical .md path"
    return 0
  fi
  if check_artifact_exists "$non_canonical_glob" >/dev/null 2>&1; then
    echo "FAIL|personas-path-noncanonical|cli#318 anchor — persona at .yaml, not canonical .md (RED anchor)"
    return 3
  fi
  echo "FAIL|personas-path-missing|no persona file at any path under $personas_dir"
  return 3
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # Build email literal at runtime per feedback_ccf3_test_fixtures memory.
  OPERATOR_EMAIL=$(printf '%s@example.test' "jamie-smith")

  # T01 — slug leaks email local part
  pf="$TMP_BASE/t01.md"
  {
    printf -- '---\n'
    printf 'slug: jamie-smith\n'
    printf 'name: Jamie Smith\n'
    printf -- '---\n'
  } > "$pf"
  out=$(drive_personas_slug_anchor "$pf" "$OPERATOR_EMAIL" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "cli#320 anchor"; then
    pass "T01 slug-anchor pre-cure RED fires"
  else
    fail "T01 slug-anchor pre-cure" "expected rc=3 cli#320; got rc=$rc out=$out"
  fi

  # T02 — slug is a plain name, not email local part
  pf="$TMP_BASE/t02.md"
  {
    printf -- '---\n'
    printf 'slug: cold-adopter\n'
    printf 'name: Jamie Smith\n'
    printf -- '---\n'
  } > "$pf"
  out=$(drive_personas_slug_anchor "$pf" "$OPERATOR_EMAIL" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "does not leak"; then
    pass "T02 slug-anchor post-cure GREEN"
  else
    fail "T02 slug-anchor post-cure" "expected rc=0; got rc=$rc out=$out"
  fi

  # T03 — persona at .yaml (non-canonical) — PR 1b stub asserts .md only
  pd="$TMP_BASE/t03"
  mkdir -p "$pd"
  echo "slug: cold-adopter" > "$pd/jamie.yaml"
  out=$(drive_personas_path_anchor "$pd" 2>&1)
  rc=$?
  if [[ "$rc" == "3" ]] && echo "$out" | grep -q "cli#318 anchor"; then
    pass "T03 path-anchor pre-cure RED fires"
  else
    fail "T03 path-anchor pre-cure" "expected rc=3 cli#318; got rc=$rc out=$out"
  fi

  # T04 — persona at canonical .md
  pd="$TMP_BASE/t04"
  mkdir -p "$pd"
  echo "slug: cold-adopter" > "$pd/jamie.md"
  out=$(drive_personas_path_anchor "$pd" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]] && echo "$out" | grep -q "canonical"; then
    pass "T04 path-anchor post-cure GREEN"
  else
    fail "T04 path-anchor post-cure" "expected rc=0 canonical; got rc=$rc out=$out"
  fi

  # T05 — well-formed persona cleans both anchors
  pd="$TMP_BASE/t05"
  mkdir -p "$pd"
  {
    printf -- '---\n'
    printf 'slug: cold-adopter\n'
    printf 'name: Jamie Smith\n'
    printf -- '---\n'
  } > "$pd/jamie.md"
  out_slug=$(drive_personas_slug_anchor "$pd/jamie.md" "$OPERATOR_EMAIL" 2>&1)
  rc_slug=$?
  out_path=$(drive_personas_path_anchor "$pd" 2>&1)
  rc_path=$?
  if [[ "$rc_slug" == "0" && "$rc_path" == "0" ]]; then
    pass "T05 both anchors clean on well-formed persona"
  else
    fail "T05 both-clean" "slug rc=$rc_slug path rc=$rc_path"
  fi

  # T06 — chain-shape: upstream /interpret-input artifact present
  upstream="$TMP_BASE/t06.interpret.json"
  echo '{"intent":"sample"}' > "$upstream"
  out=$(check_artifact_exists "$upstream" 2>&1)
  rc=$?
  if [[ "$rc" == "0" ]]; then
    pass "T06 chain-shape upstream artifact detected"
  else
    fail "T06 chain-shape" "expected rc=0; got rc=$rc out=$out"
  fi
else
  echo "--- SMOKE_LIVE=1 — /personas live invocation ---"
  WORKDIR="$TMP_BASE/live"
  pd="$WORKDIR/personas"
  mkdir -p "$pd"
  OPERATOR_EMAIL=$(git config user.email 2>/dev/null || printf '%s@noreply' "adopter")
  timeout 60 claude -p '/personas scaffold a persona for cold adopter' > "$WORKDIR/trace" 2>&1 \
    || echo "claude exit $?" >> "$WORKDIR/trace"
  # Pick first persona file; prefer canonical .md
  pf=$(ls "$pd"/*.md 2>/dev/null | head -1)
  if [[ -z "$pf" ]]; then
    pf=$(ls "$pd"/*.yaml 2>/dev/null | head -1)
  fi
  if [[ -z "$pf" ]]; then
    echo "FAIL|live-no-persona|/personas produced no file"
    exit 3
  fi
  slug_out=$(drive_personas_slug_anchor "$pf" "$OPERATOR_EMAIL" 2>&1)
  slug_rc=$?
  path_out=$(drive_personas_path_anchor "$pd" 2>&1)
  path_rc=$?
  echo "$slug_out"
  echo "$path_out"
  if [[ "$slug_rc" == "0" && "$path_rc" == "0" ]]; then
    exit 0
  fi
  exit 3
fi

# ============================================================
# summary
# ============================================================
echo ""
echo "============================================"
echo "smoke-drive-e2e-personas.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"
if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do echo "  - $msg"; done
  exit 1
fi
exit 0
