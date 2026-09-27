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
# [x] smoke-drive-setup.sh exists (lib module)
# [x] generic driver sources catalog + smoke-expect + smoke-drive-setup
# [x] catalog defines all 8 accessors (prompt/ready/done/timeout/setup/teardown/list_batch/all_skills)
# [x] setup lib defines 5 setup + 2 teardown functions
# --- Catalog lookups per skill ---
# [x] Every skill in batches A/B/C resolves prompt/ready/done/timeout
# [x] _catalog_setup returns non-empty for onboard-repo/build/session-end/longrun-prep/promote
# [x] _catalog_setup returns empty for read-only skills (sprint/whereami)
# [x] _catalog_teardown returns non-empty for promote/build
# [x] _catalog_teardown returns empty for skills with no side effects
# --- Unknown skill guard ---
# [x] generic driver with unknown SKILL_NAME returns 13
# --- Per-skill drive against fake_claude ---
# [x] Every skill happy-path returns 0 against fake_claude fixture
# [x] Every skill's session state + log file lands at SCRATCH_DIR
# --- Setup helpers ---
# [x] setup_git_init_clean creates .git dir + commits smoke init
# [x] setup_chronicle_dir_writable creates docs/chronicle
# [x] setup_iteration_goals_dir_writable creates docs/iteration-bets
# [x] setup_gh_inject_smoke_label puts shim on PATH + logs invocations
# [x] setup_git_remote_scratch adds file:// origin
# --- gh shim behavior (against fake_gh backend) ---
# [x] shim injects --label smoke-drive on issue create
# [x] shim injects --label automated-run on issue create
# [x] shim passes through non-issue-create calls unchanged
# [x] shim logs every invocation as JSON to SMOKE_GH_LOG
# --- Missing args ---
# [x] main without SKILL_NAME fails
# [x] main without SCRATCH_DIR fails
# [x] main without CLI_VERSION fails

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVE="$REPO_ROOT/scripts/smoke-drive-generic.sh"
CATALOG="$REPO_ROOT/scripts/lib/smoke-drive-catalog.sh"
SETUP_LIB="$REPO_ROOT/scripts/lib/smoke-drive-setup.sh"
FAKE_CLAUDE="$REPO_ROOT/scripts/tests/fixtures/fake_claude.sh"
FAKE_GH="$REPO_ROOT/scripts/tests/fixtures/fake_gh.sh"

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
assert_true "setup lib exists" "[ -f '$SETUP_LIB' ]"
assert_true "fake_gh fixture exists" "[ -x '$FAKE_GH' ]"
assert_true "generic driver sources catalog" "grep -q 'smoke-drive-catalog.sh' '$DRIVE'"
assert_true "generic driver sources smoke-expect" "grep -q 'smoke-expect.sh' '$DRIVE'"
assert_true "generic driver sources setup lib" "grep -q 'smoke-drive-setup.sh' '$DRIVE'"
assert_true "catalog defines _catalog_prompt"    "grep -q '^_catalog_prompt()' '$CATALOG'"
assert_true "catalog defines _catalog_ready"     "grep -q '^_catalog_ready()' '$CATALOG'"
assert_true "catalog defines _catalog_done"      "grep -q '^_catalog_done()' '$CATALOG'"
assert_true "catalog defines _catalog_timeout"   "grep -q '^_catalog_timeout()' '$CATALOG'"
assert_true "catalog defines _catalog_setup"     "grep -q '^_catalog_setup()' '$CATALOG'"
assert_true "catalog defines _catalog_teardown"  "grep -q '^_catalog_teardown()' '$CATALOG'"
assert_true "catalog defines _catalog_list_batch" "grep -q '^_catalog_list_batch()' '$CATALOG'"
assert_true "catalog defines _catalog_all_skills" "grep -q '^_catalog_all_skills()' '$CATALOG'"
assert_true "setup lib defines setup_git_init_clean"           "grep -q '^setup_git_init_clean()' '$SETUP_LIB'"
assert_true "setup lib defines setup_chronicle_dir_writable"   "grep -q '^setup_chronicle_dir_writable()' '$SETUP_LIB'"
assert_true "setup lib defines setup_iteration_goals_dir_writable" "grep -q '^setup_iteration_goals_dir_writable()' '$SETUP_LIB'"
assert_true "setup lib defines setup_gh_inject_smoke_label"    "grep -q '^setup_gh_inject_smoke_label()' '$SETUP_LIB'"
assert_true "setup lib defines setup_git_remote_scratch"       "grep -q '^setup_git_remote_scratch()' '$SETUP_LIB'"
assert_true "setup lib defines teardown_close_smoke_tickets"   "grep -q '^teardown_close_smoke_tickets()' '$SETUP_LIB'"
assert_true "setup lib defines teardown_delete_created_branch" "grep -q '^teardown_delete_created_branch()' '$SETUP_LIB'"

# Source catalog for direct lookup tests
# shellcheck disable=SC1090
source "$CATALOG"
set +e  # catalog sources cleanly; retain flag state for tests

# ============================================================
# Catalog lookup coverage — every Batch A skill resolves
# ============================================================
BATCH_A_SKILLS=$(_catalog_list_batch batch-a)
BATCH_B_SKILLS=$(_catalog_list_batch batch-b)
BATCH_C_SKILLS=$(_catalog_list_batch batch-c)
ALL_SKILLS=$(_catalog_all_skills)
assert_true "batch-a list non-empty" "[ -n '$BATCH_A_SKILLS' ]"
assert_true "batch-b list non-empty" "[ -n '$BATCH_B_SKILLS' ]"
assert_true "batch-c list non-empty" "[ -n '$BATCH_C_SKILLS' ]"
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

# ============================================================
# Catalog setup/teardown accessors — resolution by skill
# ============================================================
setup_onboard=$(_catalog_setup onboard-repo 2>/dev/null || echo "")
setup_build=$(_catalog_setup build 2>/dev/null || echo "")
setup_session=$(_catalog_setup session-end 2>/dev/null || echo "")
setup_longrun=$(_catalog_setup longrun-prep 2>/dev/null || echo "")
setup_promote=$(_catalog_setup promote 2>/dev/null || echo "")
setup_sprint=$(_catalog_setup sprint 2>/dev/null || echo "")
setup_whereami=$(_catalog_setup whereami 2>/dev/null || echo "")

assert_true "_catalog_setup non-empty for onboard-repo" "[ -n '$setup_onboard' ]"
assert_true "_catalog_setup non-empty for build" "[ -n '$setup_build' ]"
assert_true "_catalog_setup non-empty for session-end" "[ -n '$setup_session' ]"
assert_true "_catalog_setup non-empty for longrun-prep" "[ -n '$setup_longrun' ]"
assert_true "_catalog_setup non-empty for promote" "[ -n '$setup_promote' ]"
assert_true "_catalog_setup empty for sprint (read-only)" "[ -z '$setup_sprint' ]"
assert_true "_catalog_setup empty for whereami (read-only)" "[ -z '$setup_whereami' ]"

teardown_promote=$(_catalog_teardown promote 2>/dev/null || echo "")
teardown_build=$(_catalog_teardown build 2>/dev/null || echo "")
teardown_sprint=$(_catalog_teardown sprint 2>/dev/null || echo "")

assert_true "_catalog_teardown non-empty for promote" "[ -n '$teardown_promote' ]"
assert_true "_catalog_teardown non-empty for build" "[ -n '$teardown_build' ]"
assert_true "_catalog_teardown empty for sprint" "[ -z '$teardown_sprint' ]"

# ============================================================
# Setup helper behavior — source lib + call each helper
# ============================================================
# shellcheck disable=SC1090
source "$SETUP_LIB"
set +e

# setup_git_init_clean
scratch_gi=$(mkscratch)
setup_git_init_clean "$scratch_gi" >/dev/null 2>&1
assert_true "setup_git_init_clean creates .git dir" "[ -d '$scratch_gi/.git' ]"
assert_true "setup_git_init_clean creates .smoke-init file" "[ -f '$scratch_gi/.smoke-init' ]"

# setup_chronicle_dir_writable
scratch_cr=$(mkscratch)
setup_chronicle_dir_writable "$scratch_cr" >/dev/null 2>&1
assert_true "setup_chronicle_dir_writable creates docs/chronicle" "[ -d '$scratch_cr/docs/chronicle' ]"

# setup_iteration_goals_dir_writable
scratch_ig=$(mkscratch)
setup_iteration_goals_dir_writable "$scratch_ig" >/dev/null 2>&1
assert_true "setup_iteration_goals_dir_writable creates docs/iteration-bets" "[ -d '$scratch_ig/docs/iteration-bets' ]"

# setup_gh_inject_smoke_label — points shim at fake_gh
scratch_gh=$(mkscratch)
export SMOKE_GH_BIN="$FAKE_GH"
export SMOKE_GH_LOG="$scratch_gh/.gh-invocations.log"
setup_gh_inject_smoke_label "$scratch_gh" >/dev/null 2>&1
assert_true "gh shim script exists" "[ -x '$scratch_gh/.smoke-bin/gh' ]"
assert_true "PATH prepended with shim dir" "echo '$PATH' | grep -q '$scratch_gh/.smoke-bin'"

# Invoke shim: gh issue create should add labels + log
"$scratch_gh/.smoke-bin/gh" issue create --title "smoke test" --body "body" >/dev/null 2>&1
assert_true "shim logs issue create invocation" "grep -q 'issue.*create' '$SMOKE_GH_LOG'"

# Verify fake_gh saw the labels (log receives BOTH shim log entry + fake_gh log)
# The shim called: gh issue create --label smoke-drive --label automated-run --title "smoke test"...
# fake_gh logs its own args to same $SMOKE_GH_LOG so the log contains both.
assert_true "fake_gh received smoke-drive label from shim" "grep -q 'smoke-drive' '$SMOKE_GH_LOG'"
assert_true "fake_gh received automated-run label from shim" "grep -q 'automated-run' '$SMOKE_GH_LOG'"

# Invoke shim: gh repo view — should pass through without label injection
"$scratch_gh/.smoke-bin/gh" repo view --json name >/dev/null 2>&1
assert_true "shim passes through non-issue-create calls" "tail -1 '$SMOKE_GH_LOG' | grep -q 'repo.*view'"
assert_true "non-issue-create call does not carry smoke-drive label" "tail -1 '$SMOKE_GH_LOG' | grep -vq 'smoke-drive.*repo.*view'"

unset SMOKE_GH_BIN SMOKE_GH_LOG

# setup_git_remote_scratch — requires prior git init
scratch_gr=$(mkscratch)
setup_git_init_clean "$scratch_gr" >/dev/null 2>&1
setup_git_remote_scratch "$scratch_gr" >/dev/null 2>&1
assert_true "setup_git_remote_scratch creates bare repo" "[ -d '$scratch_gr/.smoke-remote.git' ]"
remote_url=$(cd "$scratch_gr" && git remote get-url origin 2>/dev/null || echo "")
assert_true "git origin points at scratch bare repo" "echo '$remote_url' | grep -q 'file://'"

echo ""
echo "smoke-drive-generic.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then printf '  %s\n' "${FAIL_MSGS[@]}"; exit 1; fi
exit 0
