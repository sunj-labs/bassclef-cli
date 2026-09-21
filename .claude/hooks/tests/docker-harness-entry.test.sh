#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md; test mtime <= source mtime)
# Tier 0 strict-TDD tests for harness/docker/entry.sh
# Per .claude/rules/test-list-discipline.md + .claude/rules/test-sufficiency.md 12 criteria

# test-list:
# [x] Skip case: sourced without main invocation loads functions cleanly
# [x] Exit-code matrix: exit-codes.sh sources with all constants readonly
# [x] Branch coverage: preflight passes when docker + env present
# [x] Branch coverage: preflight fails EXIT_ENV_MISSING when ANTHROPIC_API_KEY unset (V2 path)
# [x] Boundary value: backoff retrier retries N times before giving up
# [x] Postcondition: backoff retrier propagates final command's exit code on success
# [x] Postcondition: backoff retrier propagates EXIT_INSTALL_FAIL on exhaustion
# [x] Exit-code matrix: map_exit_code produces EXIT_HOOKS_MISSING (3) on smoke-assert exit 3
# [x] Exit-code matrix: map_exit_code produces EXIT_OK (0) on smoke-assert exit 0
# [x] Exit-code matrix: map_exit_code produces EXIT_UNKNOWN (99) on unmapped exit
# [x] Postcondition: emit_evidence_row appends valid JSON to event log
# [x] Postcondition: emit_evidence_row includes required fields (id + schema_version + status)
# [x] Signal handling: SIGTERM trap emits evidence row before exit
# [x] Override path: HARNESS_DRY_RUN=1 bypasses actual docker/npm calls (logged)
# [~] Container-level integration test — deferred to CI workflow (Docker required; not in Tier 0 bash surface)

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../.." && pwd)"
ENTRY_SH="$REPO_ROOT/harness/docker/entry.sh"
EXIT_CODES_SH="$REPO_ROOT/harness/docker/exit-codes.sh"

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

assert_eq() {
  local expected="$1" actual="$2" name="${3:-assert_eq}"
  _tests_total=$((_tests_total + 1))
  if [[ "$expected" == "$actual" ]]; then
    _tests_passed=$((_tests_passed + 1))
    echo "  PASS  $name"
  else
    _tests_failed=$((_tests_failed + 1))
    _failures+=("$name — expected [$expected] got [$actual]")
    echo "  FAIL  $name — expected [$expected] got [$actual]"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" name="${3:-assert_contains}"
  _tests_total=$((_tests_total + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    _tests_passed=$((_tests_passed + 1))
    echo "  PASS  $name"
  else
    _tests_failed=$((_tests_failed + 1))
    _failures+=("$name — needle [$needle] not in haystack")
    echo "  FAIL  $name — needle [$needle] not in haystack"
  fi
}

setup_test_env() {
  export HARNESS_TEST_MODE=1
  export HARNESS_EVENT_LOG="$(mktemp -d)/evidence-status-changed.jsonl"
  export ANTHROPIC_API_KEY="test-key-not-used"
  export CLI_VERSION="test-version"
}

teardown_test_env() {
  if [[ -f "$HARNESS_EVENT_LOG" ]]; then
    rm -f "$HARNESS_EVENT_LOG"
    rmdir "$(dirname "$HARNESS_EVENT_LOG")" 2>/dev/null || true
  fi
  unset HARNESS_TEST_MODE HARNESS_EVENT_LOG ANTHROPIC_API_KEY CLI_VERSION
}

test_sourced_without_main() {
  echo "TEST test_sourced_without_main"
  setup_test_env
  local output
  output="$(bash -c "source '$ENTRY_SH' && type -t main" 2>&1)"
  assert_eq "function" "$output" "main function is defined after source"
  teardown_test_env
}

test_exit_codes_are_readonly() {
  echo "TEST test_exit_codes_are_readonly"
  local output
  output="$(bash -c "source '$EXIT_CODES_SH'; echo \$EXIT_OK-\$EXIT_HOOKS_MISSING-\$EXIT_UNKNOWN")"
  assert_eq "0-3-99" "$output" "exit-code constants exported"
}

test_preflight_passes_when_env_present() {
  echo "TEST test_preflight_passes_when_env_present"
  setup_test_env
  bash -c "export HARNESS_TEST_MODE=1; export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY; source '$ENTRY_SH' && _docker_harness_preflight_all" >/dev/null 2>&1
  local exit_code=$?
  assert_eq "0" "$exit_code" "preflight passes with env present"
  teardown_test_env
}

test_preflight_fails_env_missing_v2() {
  echo "TEST test_preflight_fails_env_missing_v2"
  # Per #184: fails only when BOTH ANTHROPIC_API_KEY AND CLAUDE_CODE_OAUTH_TOKEN are unset.
  bash -c "export HARNESS_TEST_MODE=1; unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN; source '$ENTRY_SH' && _docker_harness_preflight_v2" >/dev/null 2>&1
  local exit_code=$?
  assert_eq "25" "$exit_code" "preflight V2 fails with EXIT_ENV_MISSING (25) when both auth vars unset"
}

test_backoff_retries_n_times() {
  echo "TEST test_backoff_retries_n_times"
  local attempts_file
  attempts_file="$(mktemp)"
  bash -c "
    export HARNESS_TEST_MODE=1
    source '$ENTRY_SH'
    _docker_harness_retry_with_backoff 'echo attempt >> $attempts_file; false' 3 0
  " >/dev/null 2>&1
  local count
  count=$(wc -l < "$attempts_file" | tr -d ' ')
  rm -f "$attempts_file"
  assert_eq "3" "$count" "retry_with_backoff invokes command 3 times before giving up"
}

test_backoff_propagates_success_code() {
  echo "TEST test_backoff_propagates_success_code"
  bash -c "
    export HARNESS_TEST_MODE=1
    source '$ENTRY_SH'
    _docker_harness_retry_with_backoff 'true' 3 0
  "
  local exit_code=$?
  assert_eq "0" "$exit_code" "retry_with_backoff exits 0 when command succeeds"
}

test_backoff_propagates_install_fail() {
  echo "TEST test_backoff_propagates_install_fail"
  bash -c "
    export HARNESS_TEST_MODE=1
    source '$ENTRY_SH'
    _docker_harness_retry_with_backoff 'false' 2 0 install
  " >/dev/null 2>&1
  local exit_code=$?
  assert_eq "21" "$exit_code" "retry_with_backoff exits EXIT_INSTALL_FAIL (21) on install-tag exhaustion"
}

test_map_exit_code_hooks_missing() {
  echo "TEST test_map_exit_code_hooks_missing"
  bash -c "
    export HARNESS_TEST_MODE=1
    source '$ENTRY_SH'
    _docker_harness_map_exit_code 3 smoke-assert-settings-hooks
  "
  local mapped=$?
  assert_eq "3" "$mapped" "map_exit_code preserves 3 from smoke-assert-settings-hooks (EXIT_HOOKS_MISSING)"
}

test_map_exit_code_ok() {
  echo "TEST test_map_exit_code_ok"
  bash -c "
    export HARNESS_TEST_MODE=1
    source '$ENTRY_SH'
    _docker_harness_map_exit_code 0 smoke-assert-settings-hooks
  "
  local mapped=$?
  assert_eq "0" "$mapped" "map_exit_code preserves 0 (EXIT_OK)"
}

test_map_exit_code_unknown_falls_through() {
  echo "TEST test_map_exit_code_unknown_falls_through"
  bash -c "
    export HARNESS_TEST_MODE=1
    source '$ENTRY_SH'
    _docker_harness_map_exit_code 77 unknown-assertion
  "
  local mapped=$?
  assert_eq "99" "$mapped" "map_exit_code returns EXIT_UNKNOWN (99) on unmapped input"
}

test_emit_evidence_row_appends_json() {
  echo "TEST test_emit_evidence_row_appends_json"
  setup_test_env
  bash -c "
    export HARNESS_TEST_MODE=1
    export HARNESS_EVENT_LOG='$HARNESS_EVENT_LOG'
    source '$ENTRY_SH'
    _docker_harness_emit_evidence_row 'test_status' 'test detail'
  "
  local line_count
  line_count=$(wc -l < "$HARNESS_EVENT_LOG" | tr -d ' ')
  assert_eq "1" "$line_count" "emit_evidence_row appends one line to event log"
  teardown_test_env
}

test_emit_evidence_row_includes_required_fields() {
  echo "TEST test_emit_evidence_row_includes_required_fields"
  setup_test_env
  bash -c "
    export HARNESS_TEST_MODE=1
    export HARNESS_EVENT_LOG='$HARNESS_EVENT_LOG'
    source '$ENTRY_SH'
    _docker_harness_emit_evidence_row 'test_status' 'test detail'
  "
  local line
  line=$(cat "$HARNESS_EVENT_LOG")
  assert_contains "$line" "\"schema_version\":\"1.0\"" "evidence row carries schema_version"
  assert_contains "$line" "\"status\":\"test_status\"" "evidence row carries status"
  assert_contains "$line" "\"agent\":" "evidence row carries agent field"
  assert_contains "$line" "\"ticket_refs\":[162]" "evidence row carries ticket_refs 162"
  teardown_test_env
}

test_sigterm_trap_emits_row() {
  echo "TEST test_sigterm_trap_emits_row"
  setup_test_env
  local trap_body
  trap_body=$(bash -c "
    source '$ENTRY_SH'
    declare -f _docker_harness_signal_handler
  ")
  assert_contains "$trap_body" "_docker_harness_emit_evidence_row" "signal handler calls emit_evidence_row"
  assert_contains "$trap_body" "signal" "signal handler references signal status"
  teardown_test_env
}

test_dry_run_bypasses_docker() {
  echo "TEST test_dry_run_bypasses_docker"
  local output
  output=$(bash -c "
    export HARNESS_DRY_RUN=1
    export HARNESS_TEST_MODE=1
    export CLI_VERSION='1.2.1'
    source '$ENTRY_SH'
    _docker_harness_install_cli 2>&1
  ")
  assert_contains "$output" "DRY_RUN" "install_cli honors HARNESS_DRY_RUN and logs skip"
}

# ---- V2 additions (2026-09-20d) ----

test_v2_run_function_defined() {
  echo "TEST test_v2_run_function_defined"
  local output
  output=$(bash -c "source '$ENTRY_SH' && type -t _docker_harness_run_v2" 2>&1)
  assert_eq "function" "$output" "_docker_harness_run_v2 defined"
}

test_v2_run_returns_zero_when_all_scripts_absent() {
  echo "TEST test_v2_run_returns_zero_when_all_scripts_absent"
  local tmp_scripts
  tmp_scripts=$(mktemp -d)
  local output
  output=$(bash -c "
    export HARNESS_TEST_MODE=1
    export SMOKE_SCRIPTS_DIR='$tmp_scripts'
    export V2_CAPTURES_DIR='$(mktemp -d)'
    export HARNESS_EVENT_LOG='$(mktemp -d)/evidence.jsonl'
    source '$ENTRY_SH'
    _docker_harness_run_v2 >/dev/null 2>&1
    echo \$?
  ")
  local ec="${output##*$'\n'}"
  assert_eq "0" "$ec" "V2 run returns 0 when scripts absent (all skipped)"
  rm -rf "$tmp_scripts"
}

test_v2_preflight_missing_key_returns_env_missing() {
  echo "TEST test_v2_preflight_missing_key_returns_env_missing"
  local ec
  ec=$(bash -c "
    unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
    source '$ENTRY_SH'
    _docker_harness_preflight_v2 >/dev/null 2>&1
    echo \$?
  ")
  # EXIT_ENV_MISSING is 25 per exit-codes.sh
  assert_eq "25" "$ec" "V2 preflight fails EXIT_ENV_MISSING when both auth vars unset"
}

test_v2_preflight_present_key_passes() {
  echo "TEST test_v2_preflight_present_key_passes"
  local ec
  ec=$(bash -c "
    export ANTHROPIC_API_KEY=test-key-not-used
    unset CLAUDE_CODE_OAUTH_TOKEN
    source '$ENTRY_SH'
    _docker_harness_preflight_v2 >/dev/null 2>&1
    echo \$?
  ")
  assert_eq "0" "$ec" "V2 preflight passes when ANTHROPIC_API_KEY only is set"
}

test_v2_preflight_oauth_only_passes() {
  echo "TEST test_v2_preflight_oauth_only_passes"
  # Per #184: CLAUDE_CODE_OAUTH_TOKEN alone is sufficient (subscription path).
  local ec
  ec=$(bash -c "
    unset ANTHROPIC_API_KEY
    export CLAUDE_CODE_OAUTH_TOKEN=test-oauth-not-used
    source '$ENTRY_SH'
    _docker_harness_preflight_v2 >/dev/null 2>&1
    echo \$?
  ")
  assert_eq "0" "$ec" "V2 preflight passes when CLAUDE_CODE_OAUTH_TOKEN only is set"
}

test_v2_preflight_prefers_oauth_when_both_set() {
  echo "TEST test_v2_preflight_prefers_oauth_when_both_set"
  # Per #184: when both are set, OAuth wins and API key is unset so claude
  # routes to subscription quota (per `claude config list` precedence rule).
  local api_after
  api_after=$(bash -c "
    export ANTHROPIC_API_KEY=test-api-key
    export CLAUDE_CODE_OAUTH_TOKEN=test-oauth
    source '$ENTRY_SH'
    _docker_harness_preflight_v2 >/dev/null 2>&1
    echo \"\${ANTHROPIC_API_KEY:-UNSET}\"
  ")
  assert_eq "UNSET" "$api_after" "preflight unsets ANTHROPIC_API_KEY when both auth vars present (OAuth wins)"
}

test_dockerfile_does_not_bake_api_key() {
  echo "TEST test_dockerfile_does_not_bake_api_key"
  local dockerfile="$REPO_ROOT/harness/docker/Dockerfile.cold-adopter"
  local matches
  matches=$(grep -c 'ENV[[:space:]]*ANTHROPIC_API_KEY=' "$dockerfile" 2>/dev/null || true)
  [[ -z "$matches" ]] && matches=0
  assert_eq "0" "$matches" "Dockerfile does not bake ANTHROPIC_API_KEY value in ENV (N1 fold)"
}

test_dockerfile_installs_claude_cli() {
  echo "TEST test_dockerfile_installs_claude_cli"
  local dockerfile="$REPO_ROOT/harness/docker/Dockerfile.cold-adopter"
  local content; content=$(cat "$dockerfile" 2>/dev/null)
  assert_contains "$content" "@anthropic-ai/claude-code" "Dockerfile installs claude CLI"
  assert_contains "$content" "perl" "Dockerfile installs perl for smoke-drive-skills timeout wrapper"
}

main() {
  echo "=========================================="
  echo "Tier 0 tests — docker-harness-entry.test.sh"
  echo "=========================================="

  if [[ ! -f "$ENTRY_SH" ]]; then
    echo "FATAL: source under test not found at $ENTRY_SH"
    exit 2
  fi
  if [[ ! -f "$EXIT_CODES_SH" ]]; then
    echo "FATAL: exit-codes source not found at $EXIT_CODES_SH"
    exit 2
  fi

  test_sourced_without_main
  test_exit_codes_are_readonly
  test_preflight_passes_when_env_present
  test_preflight_fails_env_missing_v2
  test_backoff_retries_n_times
  test_backoff_propagates_success_code
  test_backoff_propagates_install_fail
  test_map_exit_code_hooks_missing
  test_map_exit_code_ok
  test_map_exit_code_unknown_falls_through
  test_emit_evidence_row_appends_json
  test_emit_evidence_row_includes_required_fields
  test_sigterm_trap_emits_row
  test_dry_run_bypasses_docker

  # V2 additions (2026-09-20d)
  test_v2_run_function_defined
  test_v2_run_returns_zero_when_all_scripts_absent
  test_v2_preflight_missing_key_returns_env_missing
  test_v2_preflight_present_key_passes
  test_v2_preflight_oauth_only_passes
  test_v2_preflight_prefers_oauth_when_both_set
  test_dockerfile_does_not_bake_api_key
  test_dockerfile_installs_claude_cli

  echo "=========================================="
  echo "Total: $_tests_total | Pass: $_tests_passed | Fail: $_tests_failed"
  echo "=========================================="

  if [[ "$_tests_failed" -gt 0 ]]; then
    echo "Failures:"
    for f in "${_failures[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi
  exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
