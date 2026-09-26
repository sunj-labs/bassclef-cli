#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Tier 0 tests for scripts/smoke-drive-generic.sh + scripts/lib/smoke-drive-catalog.sh
# cli#254 Batch A.
#
# Iterates every skill in the Batch A catalog + runs the drive against
# fake_claude fixture. Aggregates PASS/FAIL across all skills per
# pre-mortem BA4 fold (per-skill blocks; failure counts continue).

# test-list:
# --- Static / interface ---
# [x] smoke-drive-generic.sh exists + executable
# [x] smoke-drive-catalog.sh exists (lib module)
# [x] generic driver sources catalog
# [x] generic driver sources smoke-expect
# [x] catalog defines _catalog_prompt / _ready / _done / _timeout / _list_batch / _all_skills
# --- Catalog lookups per skill ---
# [x] Every skill in batch-a resolves to prompt / ready / done / timeout
# --- Unknown skill guard ---
# [x] generic driver with unknown SKILL_NAME returns 13
# --- Per-skill drive against fake_claude ---
# [x] Every skill in batch-a happy-path returns 0 against fake_claude fixture
# [x] Every skill's session state + log file lands at SCRATCH_DIR
# --- Missing args ---
# [x] main without SKILL_NAME fails
# [x] main without SCRATCH_DIR fails
# [x] main without CLI_VERSION fails

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVE="$REPO_ROOT/scripts/smoke-drive-generic.sh"
CATALOG="$REPO_ROOT/scripts/lib/smoke-drive-catalog.sh"
FAKE_CLAUDE="$REPO_ROOT/scripts/tests/fixtures/fake_claude.sh"

PASS=0; FAIL=0; FAIL_MSGS=()

assert_true() {
  if eval "$2" >/dev/null 2>&1; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $1  (cmd: $2)"); fi
}
assert_exit() {
  local desc="$1" expected="$2"; shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $desc (expected $expected, got $actual)"); fi
}
assert_file() {
  if [ -f "$2" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAIL_MSGS+=("FAIL: $1 (path missing: $2)"); fi
}

trap 'rm -rf /tmp/smoke-generic-test-*' EXIT
mkscratch() { mktemp -d /tmp/smoke-generic-test-XXXXXX; }

# ============================================================
# Static / interface tests
# ============================================================
assert_true "generic driver exists" "[ -f '$DRIVE' ]"
assert_true "generic driver executable" "[ -x '$DRIVE' ]"
assert_true "catalog module exists" "[ -f '$CATALOG' ]"
assert_true "generic driver sources catalog" "grep -q 'smoke-drive-catalog.sh' '$DRIVE'"
assert_true "generic driver sources smoke-expect" "grep -q 'smoke-expect.sh' '$DRIVE'"
assert_true "catalog defines _catalog_prompt"    "grep -q '^_catalog_prompt()' '$CATALOG'"
assert_true "catalog defines _catalog_ready"     "grep -q '^_catalog_ready()' '$CATALOG'"
assert_true "catalog defines _catalog_done"      "grep -q '^_catalog_done()' '$CATALOG'"
assert_true "catalog defines _catalog_timeout"   "grep -q '^_catalog_timeout()' '$CATALOG'"
assert_true "catalog defines _catalog_list_batch" "grep -q '^_catalog_list_batch()' '$CATALOG'"
assert_true "catalog defines _catalog_all_skills" "grep -q '^_catalog_all_skills()' '$CATALOG'"

# Source catalog for direct lookup tests
# shellcheck disable=SC1090
source "$CATALOG"
set +e  # catalog sources cleanly; retain flag state for tests

# ============================================================
# Catalog lookup coverage — every Batch A skill resolves
# ============================================================
BATCH_A_SKILLS=$(_catalog_list_batch batch-a)
BATCH_B_SKILLS=$(_catalog_list_batch batch-b)
ALL_SKILLS=$(_catalog_all_skills)
assert_true "batch-a list non-empty" "[ -n '$BATCH_A_SKILLS' ]"
assert_true "batch-b list non-empty" "[ -n '$BATCH_B_SKILLS' ]"
assert_true "all-skills list non-empty" "[ -n '$ALL_SKILLS' ]"

for skill in $ALL_SKILLS; do
  prompt=$(_catalog_prompt "$skill" 2>/dev/null || echo "")
  ready=$(_catalog_ready "$skill" 2>/dev/null || echo "")
  done_pat=$(_catalog_done "$skill" 2>/dev/null || echo "")
  timeout=$(_catalog_timeout "$skill" 2>/dev/null || echo "")
  assert_true "catalog resolves prompt for $skill"  "[ -n '$prompt' ]"
  assert_true "catalog resolves ready for $skill"   "[ -n '$ready' ]"
  assert_true "catalog resolves done for $skill"    "[ -n '$done_pat' ]"
  assert_true "catalog resolves timeout for $skill" "[ -n '$timeout' ]"
done

# ============================================================
# Unknown skill guard — SKILL_NAME not in catalog → 13
# ============================================================
scratch_unknown=$(mkscratch)
assert_exit "unknown SKILL_NAME returns 13" 13 "$DRIVE" "totally-unknown-skill" "$scratch_unknown" "1.9.4" "5"

# ============================================================
# Missing args
# ============================================================
rc1=0; "$DRIVE" 2>/dev/null || rc1=$?
assert_true "main without SKILL_NAME fails" "[ '$rc1' -ne 0 ]"
rc2=0; "$DRIVE" "sprint" 2>/dev/null || rc2=$?
assert_true "main without SCRATCH_DIR fails" "[ '$rc2' -ne 0 ]"
rc3=0; "$DRIVE" "sprint" "/tmp/test" 2>/dev/null || rc3=$?
assert_true "main without CLI_VERSION fails" "[ '$rc3' -ne 0 ]"

# ============================================================
# Per-skill drive against fake_claude — every skill in the catalog
# ============================================================
for skill in $ALL_SKILLS; do
  scratch=$(mkscratch)
  export SMOKE_DRIVE_SPAWN_CMD="$FAKE_CLAUDE"
  export SMOKE_DRIVE_READY_PATTERN="READY>"
  export SMOKE_DRIVE_PROMPT_TEXT="hello $skill"
  export SMOKE_DRIVE_DONE_PATTERN="RESP: hello $skill"

  assert_exit "happy path — $skill" 0 "$DRIVE" "$skill" "$scratch" "1.9.4" "5"
  assert_file "session file — $skill" "$scratch/.smoke-drive-session"
  assert_file "log file — $skill" "$scratch/drive.log"

  unset SMOKE_DRIVE_SPAWN_CMD SMOKE_DRIVE_READY_PATTERN SMOKE_DRIVE_PROMPT_TEXT SMOKE_DRIVE_DONE_PATTERN
done

echo ""
echo "smoke-drive-generic.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then printf '  %s\n' "${FAIL_MSGS[@]}"; exit 1; fi
exit 0
