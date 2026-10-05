#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md; test mtime <= source mtime)
# Tier 0 tests for scripts/refresh-oauth-token.sh
# Parent ticket: sunj-labs/bassclef-cli#380
# Design chain: docs/use-cases/UC-script-cli-380-refresh-oauth-token.md
# Pre-mortem folds: docs/risk-ledgers/2026-10-06-cli-380-refresh-oauth-token.md (R1 atomic, R2 ts-backup, R3 chmod race, R4 regex anchor, R5 iso-probe HOME, R6 precond, R7 probe mandatory, R8 rollback invariant, R9 flag mutex, R10 length window, R13 trap cleanup)

# test-list:
# [ ] T01 missing_claude_binary — exit 3; stderr names "claude" + "PATH"
# [ ] T02 target_dir_not_writable — exit 3; stderr names dir perm
# [ ] T03 verify_only_pass — valid current file → exit 0; no setup-token fired; no file write
# [ ] T04 verify_only_fail — bad current file → exit 2; no file write
# [ ] T05 dry_run — no setup-token fired; no file write; exit 0; stdout names plan
# [ ] T06 happy_path_atomic_write — new token lands at target; backup created with .bak-<ts> suffix
# [ ] T07 happy_path_chmod_600 — new file mode is 600 after write
# [ ] T08 probe_fail_rolls_back — new token fails probe → target file UNCHANGED; exit 2
# [ ] T09 setup_token_exits_nonzero — fake claude setup-token fails → exit 1; file unchanged
# [ ] T10 token_regex_no_match — setup-token output has no sk-ant-oat01 → exit 1; file unchanged
# [ ] T11 file_override — --file PATH writes to that path, not default
# [ ] T12 backup_timestamped_no_overwrite — second run creates distinct backup, prior backup preserved
# [ ] T13 flag_mutex_verify_and_dry — both flags set → exit 3; stderr names conflict
# [ ] T14 token_length_below_window — 50-byte token → exit 1; stderr names length window
# [ ] T15 token_length_above_window — 200-byte token → exit 1; stderr names length window

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/refresh-oauth-token.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "SETUP: script not yet at $SCRIPT (Beck RED phase — expected)" >&2
fi

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1] got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] not in output [${1:0:200}]"; }
assert_file_exists() { [[ -f "$1" ]] && pass "$2" || fail "$2" "file does not exist: $1"; }
assert_file_absent() { [[ ! -f "$1" ]] && pass "$2" || fail "$2" "file unexpectedly exists: $1"; }
assert_file_contents_eq() { local actual; actual=$(cat "$1" 2>/dev/null); [[ "$actual" == "$2" ]] && pass "$3" || fail "$3" "file contents differ (expected [${2:0:40}...] got [${actual:0:40}...])"; }
assert_mode() { local m; m=$(stat -f '%A' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null); [[ "$m" == "$2" ]] && pass "$3" || fail "$3" "mode mismatch (expected $2 got $m)"; }

# ---------- fake-claude builder ----------
# Produces a fake `claude` binary that behaves differently per invocation.
# Modes (set via FAKE_CLAUDE_MODE in parent env):
#   good        — setup-token prints a 108-byte sk-ant-oat01 token; probe returns 0 + "hello"
#   expired     — setup-token prints token BUT probe returns 1 + "401 OAuth access token has expired"
#   setup_fail  — setup-token itself exits 1
#   no_token    — setup-token prints "did not get a token today" (no sk-ant-oat01 match)
#   short_token — setup-token prints a 50-byte sk-ant-oat01 token
#   long_token  — setup-token prints a 200-byte sk-ant-oat01 token
# Also probes current CLAUDE_CODE_OAUTH_TOKEN env for verify-only path.
mk_fake_claude() {
  local dir="$1"
  local mode="${2:-good}"
  mkdir -p "$dir"
  cat > "$dir/claude" <<EOF
#!/usr/bin/env bash
# Fake claude binary for refresh-oauth-token tests. Mode: $mode
MODE="${mode}"
if [[ "\$1" == "setup-token" ]]; then
  case "\$MODE" in
    good|expired)
      # 108-byte token (same shape as current production token)
      echo "Please visit https://auth.example.com/..."
      echo ""
      echo "Your token:"
      echo "sk-ant-oat01-$(head -c 94 /dev/urandom | base64 | tr -d '\n+/=' | head -c 94)"
      echo ""
      echo "Save this and use with: export CLAUDE_CODE_OAUTH_TOKEN=..."
      exit 0
      ;;
    setup_fail)
      echo "Error: could not open browser" >&2
      exit 1
      ;;
    no_token)
      echo "did not get a token today"
      exit 0
      ;;
    short_token)
      echo "sk-ant-oat01-\$(head -c 40 /dev/urandom | base64 | tr -d '\\n+/=' | head -c 40)"
      exit 0
      ;;
    long_token)
      # emit a 200+ byte token
      BIG=\$(head -c 400 /dev/urandom | base64 | tr -d '\\n+/=' | head -c 200)
      echo "sk-ant-oat01-\$BIG"
      exit 0
      ;;
  esac
elif [[ "\$1" == "-p" ]]; then
  # probe path
  case "\$MODE" in
    good)
      echo "hello"
      exit 0
      ;;
    expired|*)
      echo "Failed to authenticate. API Error: 401 OAuth access token has expired." >&2
      exit 1
      ;;
  esac
elif [[ "\$1" == "--version" ]]; then
  echo "2.1.258 (fake)"
  exit 0
fi
exit 0
EOF
  chmod +x "$dir/claude"
  echo "$dir"
}

# ---------- fixture builder ----------
mk_fixture() {
  local mode="${1:-good}"
  local parent; parent=$(mktemp -d)
  mkdir -p "$parent/bin" "$parent/config"
  mk_fake_claude "$parent/bin" "$mode" >/dev/null
  echo "$parent"
}

rm_fixture() {
  local parent="$1"
  [[ -d "$parent" ]] && rm -rf "$parent"
}

run_script() {
  # Run the script with isolated env: HOME=fixture, PATH=fixture-bin + /usr/bin + /bin
  local parent="$1"; shift
  local extra_env="$1"; shift
  env -i HOME="$parent" PATH="$parent/bin:/usr/bin:/bin" ${extra_env} bash "$SCRIPT" "$@"
}

# ================================================================
# T01 — claude binary missing on PATH → exit 3
# ================================================================
test_t01() {
  echo "T01: missing claude binary → exit 3"
  local parent; parent=$(mktemp -d)
  mkdir -p "$parent/bin"
  # NO fake claude
  local err; err=$(env -i HOME="$parent" PATH="$parent/bin:/usr/bin:/bin" bash "$SCRIPT" --dry-run 2>&1); local rc=$?
  assert_eq "3" "$rc" "T01 rc=3"
  assert_contains "$err" "claude" "T01 stderr names 'claude'"
  rm_fixture "$parent"
}

# ================================================================
# T02 — target dir not writable → exit 3
# ================================================================
test_t02() {
  echo "T02: target dir not writable → exit 3"
  local parent; parent=$(mk_fixture good)
  local ro_dir="$parent/readonly"
  mkdir -p "$ro_dir"
  chmod 500 "$ro_dir"
  local target="$ro_dir/oauth-token"
  local err; err=$(run_script "$parent" "" --dry-run --file "$target" 2>&1); local rc=$?
  chmod 700 "$ro_dir"  # restore for cleanup
  assert_eq "3" "$rc" "T02 rc=3"
  assert_contains "$err" "writable" "T02 stderr names 'writable'"
  rm_fixture "$parent"
}

# ================================================================
# T03 — --verify-only PASS on good token
# ================================================================
test_t03() {
  echo "T03: --verify-only passes on good token"
  local parent; parent=$(mk_fixture good)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "sk-ant-oat01-VALIDTOKEN$(head -c 80 /dev/urandom | base64 | tr -d '\n+/=' | head -c 80)" > "$target"
  local before_mtime; before_mtime=$(stat -f '%m' "$target" 2>/dev/null || stat -c '%Y' "$target")
  local err; err=$(run_script "$parent" "" --verify-only --file "$target" 2>&1); local rc=$?
  local after_mtime; after_mtime=$(stat -f '%m' "$target" 2>/dev/null || stat -c '%Y' "$target")
  assert_eq "0" "$rc" "T03 rc=0"
  assert_eq "$before_mtime" "$after_mtime" "T03 file unchanged (mtime)"
  rm_fixture "$parent"
}

# ================================================================
# T04 — --verify-only FAIL on bad token
# ================================================================
test_t04() {
  echo "T04: --verify-only fails on expired token"
  local parent; parent=$(mk_fixture expired)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "sk-ant-oat01-EXPIRED$(head -c 80 /dev/urandom | base64 | tr -d '\n+/=' | head -c 80)" > "$target"
  local err; err=$(run_script "$parent" "" --verify-only --file "$target" 2>&1); local rc=$?
  assert_eq "2" "$rc" "T04 rc=2"
  rm_fixture "$parent"
}

# ================================================================
# T05 — --dry-run writes nothing, exits 0, plan on stdout
# ================================================================
test_t05() {
  echo "T05: --dry-run no write"
  local parent; parent=$(mk_fixture good)
  local target="$parent/config/oauth-token"
  local out; out=$(run_script "$parent" "" --dry-run --file "$target" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T05 rc=0"
  assert_file_absent "$target" "T05 target not written"
  assert_contains "$out" "plan" "T05 stdout contains 'plan'"
  rm_fixture "$parent"
}

# ================================================================
# T06 — happy path: new token lands at target; backup fires
# ================================================================
test_t06() {
  echo "T06: happy path atomic write + backup"
  local parent; parent=$(mk_fixture good)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "OLDTOKEN" > "$target"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T06 rc=0"
  assert_file_exists "$target" "T06 target exists"
  # confirm content is NOT OLDTOKEN
  local new_contents; new_contents=$(cat "$target")
  [[ "$new_contents" != "OLDTOKEN" ]] && pass "T06 target contents changed" || fail "T06 target contents changed" "still OLDTOKEN"
  # confirm backup exists (any .bak-* file next to target)
  local bak_count; bak_count=$(ls "${target}".bak-* 2>/dev/null | wc -l | tr -d ' ')
  [[ "$bak_count" -ge 1 ]] && pass "T06 backup created" || fail "T06 backup created" "no .bak-* file found"
  rm_fixture "$parent"
}

# ================================================================
# T07 — new file mode is 600
# ================================================================
test_t07() {
  echo "T07: new file mode 600"
  local parent; parent=$(mk_fixture good)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T07 rc=0"
  assert_mode "$target" "600" "T07 mode 600"
  rm_fixture "$parent"
}

# ================================================================
# T08 — probe fails after new token extracted → rollback; file unchanged
# ================================================================
test_t08() {
  echo "T08: probe fail → rollback"
  local parent; parent=$(mk_fixture expired)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "OLDTOKEN" > "$target"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "2" "$rc" "T08 rc=2"
  # file must still be OLDTOKEN
  assert_file_contents_eq "$target" "OLDTOKEN" "T08 target still OLDTOKEN"
  rm_fixture "$parent"
}

# ================================================================
# T09 — setup-token itself fails → exit 1; file unchanged
# ================================================================
test_t09() {
  echo "T09: setup-token exits non-zero"
  local parent; parent=$(mk_fixture setup_fail)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "OLDTOKEN" > "$target"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T09 rc=1"
  assert_file_contents_eq "$target" "OLDTOKEN" "T09 target unchanged"
  rm_fixture "$parent"
}

# ================================================================
# T10 — setup-token output has no token match → exit 1
# ================================================================
test_t10() {
  echo "T10: token regex no match"
  local parent; parent=$(mk_fixture no_token)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "OLDTOKEN" > "$target"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T10 rc=1"
  assert_file_contents_eq "$target" "OLDTOKEN" "T10 target unchanged"
  rm_fixture "$parent"
}

# ================================================================
# T11 — --file override lands at that path
# ================================================================
test_t11() {
  echo "T11: --file override"
  local parent; parent=$(mk_fixture good)
  local target="$parent/custom/path/oauth-token"
  mkdir -p "$(dirname "$target")"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "0" "$rc" "T11 rc=0"
  assert_file_exists "$target" "T11 override target exists"
  rm_fixture "$parent"
}

# ================================================================
# T12 — backup timestamped, no overwrite of prior backup
# ================================================================
test_t12() {
  echo "T12: timestamped backup, no overwrite"
  local parent; parent=$(mk_fixture good)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "RUN1OLD" > "$target"
  run_script "$parent" "" --file "$target" >/dev/null 2>&1
  local bak1; bak1=$(ls "${target}".bak-* 2>/dev/null | head -1)
  [[ -n "$bak1" ]] && pass "T12 first backup created" || fail "T12 first backup created" "no .bak-* after run 1"
  # second run should create a DIFFERENT backup, not overwrite
  sleep 1  # ensure timestamp differs
  run_script "$parent" "" --file "$target" >/dev/null 2>&1
  local bak_count; bak_count=$(ls "${target}".bak-* 2>/dev/null | wc -l | tr -d ' ')
  [[ "$bak_count" -ge 2 ]] && pass "T12 two distinct backups" || fail "T12 two distinct backups" "expected ≥2 backups; got $bak_count"
  rm_fixture "$parent"
}

# ================================================================
# T13 — --verify-only + --dry-run both set → exit 3
# ================================================================
test_t13() {
  echo "T13: flag mutex"
  local parent; parent=$(mk_fixture good)
  local target="$parent/config/oauth-token"
  local err; err=$(run_script "$parent" "" --verify-only --dry-run --file "$target" 2>&1); local rc=$?
  assert_eq "3" "$rc" "T13 rc=3"
  assert_contains "$err" "verify-only" "T13 stderr names conflict"
  rm_fixture "$parent"
}

# ================================================================
# T14 — token below length window → exit 1
# ================================================================
test_t14() {
  echo "T14: token too short"
  local parent; parent=$(mk_fixture short_token)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "OLDTOKEN" > "$target"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T14 rc=1"
  assert_file_contents_eq "$target" "OLDTOKEN" "T14 target unchanged"
  rm_fixture "$parent"
}

# ================================================================
# T15 — token above length window → exit 1
# ================================================================
test_t15() {
  echo "T15: token too long"
  local parent; parent=$(mk_fixture long_token)
  local target="$parent/config/oauth-token"
  mkdir -p "$(dirname "$target")"
  echo -n "OLDTOKEN" > "$target"
  local err; err=$(run_script "$parent" "" --file "$target" 2>&1); local rc=$?
  assert_eq "1" "$rc" "T15 rc=1"
  assert_file_contents_eq "$target" "OLDTOKEN" "T15 target unchanged"
  rm_fixture "$parent"
}

# ---------- run all tests ----------
if [[ ! -f "$SCRIPT" ]]; then
  echo ""
  echo "=== Beck RED phase: $SCRIPT not implemented yet ==="
  echo "Tests will all fail with 'file not found'. Expected. Implement to drive GREEN."
  echo ""
fi

echo "===== refresh-oauth-token.sh Tier 0 tests ====="
test_t01
test_t02
test_t03
test_t04
test_t05
test_t06
test_t07
test_t08
test_t09
test_t10
test_t11
test_t12
test_t13
test_t14
test_t15

echo ""
echo "===== results ====="
echo "total: $_tests_total  pass: $_tests_passed  fail: $_tests_failed"
if (( _tests_failed > 0 )); then
  echo ""
  echo "FAILURES:"
  for f in "${_failures[@]}"; do echo "  - $f"; done
  exit 1
fi
exit 0
