#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# E2E cascade driver for /temperance — session-shape surface #3.
# Red-first anchor against cli#328 finding 6: "/temperance says
# `git add` a marker that `.gitignore` blocks. Known as upstream #1694.
# The skill text still says to add it."
#
# Characterization scope — the git-add silent-fail class. Adopter
# with `.gitignore` entry for `state/markers/` runs /temperance, writes
# the marker, tries to `git add` it, and git silently ignores (exit 0
# with no staging). The driver forces this outcome to become auditable:
# either git-add reports the ignore (RED signal — tells adopter to
# cure gitignore) OR the marker is tracked (GREEN — current main-track
# path per `.claude/rules/session-artifacts.md` L14-25).
#
# Characterizes driver logic in two modes:
#   SMOKE_LIVE unset (default) — mock fixture mode. Tier 0 ships GREEN by
#     verifying driver correctly reports RED on gitignored fixture AND
#     GREEN on tracked fixture.
#   SMOKE_LIVE=1 — placeholder for live container run.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md L96
#   "/temperance — marker format fits the /build flow (addresses cli#328
#    observation)"
#
# Risk ledger: docs/risk-ledgers/2026-10-04-session-b-session-shape.md R-F4, R-L4
# RFC: docs/rfcs/2026-10-04-session-b-session-shape.md F-MN-2 (TMP_BASE scoping)

# test-list:
# [x] T01 pre-cure fixture gitignores state/markers/ — git-add is silent (RED anchor)
# [x] T02 post-cure fixture tracks state/markers/ — git-add stages the marker (GREEN)
# [x] T03 marker body carries required 5 fields (date, branch, goal, scope-decision, drift-trigger)
# [x] T04 marker path shape: state/markers/temperance/<branch-slug>.marker
# [x] T05 driver fails cleanly when fixture dir missing

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
# Helper — build a scratch git repo with chosen .gitignore state.
# ============================================================
# $1 — scratch dir path (must be under TMP_BASE)
# $2 — "ignore" or "track" (controls .gitignore shape)
build_scratch_repo() {
  local dir="$1"
  local mode="$2"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q
    git config user.email "driver@test.local"
    git config user.name "driver"
    if [[ "$mode" == "ignore" ]]; then
      echo "state/markers/" > .gitignore
    else
      # tracked — gitignore excludes something else so .gitignore exists but allows markers
      echo "node_modules/" > .gitignore
    fi
    git add .gitignore
    git commit -q -m "init"
    mkdir -p state/markers/temperance
  )
}

# ============================================================
# driver function — reusable by SMOKE_LIVE path too
# ============================================================
# $1 — scratch repo dir (built via build_scratch_repo)
# $2 — branch slug for the marker filename
# $3 — marker body content
#
# Returns 0 when marker lands AND git-add stages it (tracked flow); 3
# when marker lands but git-add is silent (gitignored flow, the cli#328
# finding 6 shape); 3 also when scratch dir missing or marker shape wrong.
drive_temperance() {
  local repo_dir="$1"
  local branch_slug="$2"
  local body="$3"
  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "MISSING|temperance-repo|scratch repo not initialized: $repo_dir"
    return 3
  fi
  local marker_path="$repo_dir/state/markers/temperance/${branch_slug}.marker"
  if [[ ! -d "$(dirname "$marker_path")" ]]; then
    echo "MISSING|temperance-dir|markers dir not initialized under: $repo_dir"
    return 3
  fi
  printf '%s' "$body" > "$marker_path"
  # Marker body must carry 5 fields per /temperance SKILL.md shape.
  local required_fields=("date:" "branch:" "goal:" "scope-decision:" "drift-trigger:")
  local field
  for field in "${required_fields[@]}"; do
    if ! grep -qF "$field" "$marker_path" 2>/dev/null; then
      echo "FAIL|temperance-body|marker missing required field: $field"
      return 3
    fi
  done
  # Try git-add and detect the gitignored class per cli#328 finding 6.
  (
    cd "$repo_dir"
    # Capture git-add dry-run behavior. When path is gitignored, git
    # prints a hint containing "ignored"; this is the cli#328 anchor
    # shape — adopter runs the recommended command, sees the hint only,
    # loses the audit trail because the marker never stages.
    local add_dryrun
    add_dryrun=$(git add --dry-run "$marker_path" 2>&1 || true)
    if [[ "$add_dryrun" == *"ignored"* ]]; then
      echo "FAIL|temperance-gitignore|cli#328 anchor — marker gitignored, git add refuses to stage"
      exit 3
    fi
    # Not gitignored — proceed to actual add + verify staging.
    git add "$marker_path"
    local staged
    staged=$(git diff --cached --name-only)
    if [[ "$staged" != *"${branch_slug}.marker"* ]]; then
      echo "FAIL|temperance-stage|git-add ran but marker not staged"
      exit 3
    fi
    echo "PASS|temperance-stage|marker staged cleanly"
    exit 0
  )
}

# ============================================================
# characterization — Tier 0 (default)
# ============================================================
if [[ "${SMOKE_LIVE:-0}" != "1" ]]; then
  echo "--- characterization — Tier 0 (SMOKE_LIVE unset) ---"

  # Standard marker body for shared use. 5 required fields.
  BODY=$'# Temperance marker — test\n- date: 2026-10-04\n- branch: feature/test\n- goal: test the driver\n- scope-decision: narrow\n- drift-trigger: do not grow\n'

  # T01 — pre-cure fixture: gitignored state/markers/, git-add silent (RED anchor)
  repo="$TMP_BASE/t01-repo"
  build_scratch_repo "$repo" "ignore"
  out="$(drive_temperance "$repo" "feature-test-01" "$BODY" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"cli#328 anchor"* ]]; then
    pass "T01 pre-cure RED — gitignored marker refused by git add"
  else
    fail "T01 pre-cure RED" "expected rc=3 with cli#328 anchor; got rc=$rc out=[$out]"
  fi

  # T02 — post-cure fixture: tracked state/markers/, git-add stages cleanly
  repo="$TMP_BASE/t02-repo"
  build_scratch_repo "$repo" "track"
  out="$(drive_temperance "$repo" "feature-test-02" "$BODY" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 && "$out" == *"marker staged cleanly"* ]]; then
    pass "T02 post-cure GREEN — tracked marker stages"
  else
    fail "T02 post-cure GREEN" "expected rc=0; got rc=$rc out=[$out]"
  fi

  # T03 — marker body missing required field (drop drift-trigger)
  repo="$TMP_BASE/t03-repo"
  build_scratch_repo "$repo" "track"
  bad_body=$'# Temperance marker — test\n- date: 2026-10-04\n- branch: feature/test\n- goal: test\n- scope-decision: narrow\n'
  out="$(drive_temperance "$repo" "feature-test-03" "$bad_body" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"drift-trigger:"* ]]; then
    pass "T03 body missing drift-trigger — RED names the field"
  else
    fail "T03 body missing drift-trigger" "expected rc=3 naming drift-trigger; got rc=$rc out=[$out]"
  fi

  # T04 — marker path shape: state/markers/temperance/<branch-slug>.marker
  repo="$TMP_BASE/t04-repo"
  build_scratch_repo "$repo" "track"
  slug="feature-cli-999-pr-test"
  drive_temperance "$repo" "$slug" "$BODY" > /dev/null 2>&1 || true
  if [[ -f "$repo/state/markers/temperance/${slug}.marker" ]]; then
    pass "T04 marker path shape — state/markers/temperance/<slug>.marker"
  else
    fail "T04 marker path shape" "expected marker at state/markers/temperance/${slug}.marker"
  fi

  # T05 — missing scratch dir
  out="$(drive_temperance "$TMP_BASE/missing-repo" "feature-test-05" "$BODY" 2>&1)"
  rc=$?
  if [[ "$rc" == 3 && "$out" == *"MISSING"* ]]; then
    pass "T05 missing scratch dir — reports MISSING"
  else
    fail "T05 missing scratch dir" "expected rc=3 with MISSING; got rc=$rc out=[$out]"
  fi
fi

# ============================================================
# live mode — SMOKE_LIVE=1 nightly path
# ============================================================
if [[ "${SMOKE_LIVE:-0}" == "1" ]]; then
  echo "--- live — SMOKE_LIVE=1 ---"
  echo "SMOKE_LIVE=1 placeholder — container entry.sh drives real /temperance and asserts marker + git-add behavior."
fi

# ============================================================
# summary
# ============================================================

echo ""
echo "============================================"
echo "smoke-drive-e2e-temperance.test.sh — $_tests_passed/$_tests_total passed"
echo "============================================"

if [[ $_tests_failed -gt 0 ]]; then
  echo "FAILURES:"
  for msg in "${_failures[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
