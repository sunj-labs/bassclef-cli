#!/usr/bin/env bash
# tier: standard
# Docker cold-adopter harness entrypoint per cli#162.
#
# Adopter user: uid=1000 gid=1000 home=/adopter (per RFC-0002 R11 Cooper persona).
# Contract-by-contract stages per Meyer (RFC-0002 R10).
# Facade pattern over scripts/smoke-*.sh family (per decomposition + RFC-0001 R3).
# All internal fns prefixed _docker_harness_ (Fowler R12 information hiding).
# Exit codes sourced from exit-codes.sh (Parnas R13 single source of truth).
#
# 4 actions only:
#   1. preflight — env + docker + auth checks
#   2. install — npm install -g @thebassclef/lite@$CLI_VERSION
#   3. smoke — invoke smoke-assert-settings-hooks.sh
#   4. propagate — map exit code + emit evidence row + exit
#
# No assertion logic in this file. Assertions live in scripts/smoke-*.sh.
#
# ENV VARS (per RFC-0002 R9 anticorruption layer):
#   CLI_VERSION         — target cli version (default: latest)
#   ANTHROPIC_API_KEY   — for V2 skill drive only; unused in V1
#   HARNESS_EVENT_LOG   — path to append evidence rows (default: state/events/evidence-status-changed.jsonl)
#   HARNESS_TEST_MODE   — set to 1 in Tier 0 tests to skip actual docker calls
#   HARNESS_DRY_RUN     — set to 1 to log operations without executing

# Locate the harness directory and source shared exit-code constants
_docker_harness_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./exit-codes.sh
source "${_docker_harness_source_dir}/exit-codes.sh"

# ---------------------------------------------------------------------------
# _docker_harness_emit_evidence_row
# Precondition: HARNESS_EVENT_LOG is a writable path OR test mode default applies
# Postcondition: one JSON line appended to the event log; return 0 on success
# ---------------------------------------------------------------------------
_docker_harness_emit_evidence_row() {
  local status="${1:-unknown}"
  local detail="${2:-}"

  local log_path="${HARNESS_EVENT_LOG:-state/events/evidence-status-changed.jsonl}"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  local ev_id
  ev_id="ev-$(date -u +'%Y-%m-%d')-$(printf '%03d' $((RANDOM % 1000)))"

  # Ensure parent dir exists
  mkdir -p "$(dirname "$log_path")" 2>/dev/null || true

  # Escape detail for JSON — replace " and \ minimally; bash literal is fine for tests
  local escaped_detail
  escaped_detail="${detail//\\/\\\\}"
  escaped_detail="${escaped_detail//\"/\\\"}"

  # Emit a schema-1.0 evidence row line
  printf '{"id":"%s","schema_version":"1.0","date":"%s","ticket_refs":[162],"problem_plain":"%s","trigger":{"skill":"docker-harness","operator_initiated":false},"agent":"docker-harness-entry","status":"%s","captured_at":"%s"}\n' \
    "$ev_id" "$(date -u +'%Y-%m-%d')" "$escaped_detail" "$status" "$ts" \
    >> "$log_path"

  return 0
}

# ---------------------------------------------------------------------------
# _docker_harness_signal_handler
# Precondition: none (installed as trap at entry)
# Postcondition: evidence row emitted with status=signal_<name>; exit with 130/131
# ---------------------------------------------------------------------------
_docker_harness_signal_handler() {
  local signal="${1:-UNKNOWN}"
  _docker_harness_emit_evidence_row "signal_${signal}" "signal ${signal} received; container terminating"
  case "$signal" in
    TERM) exit "$EXIT_SIGTERM" ;;
    INT)  exit "$EXIT_SIGINT" ;;
    *)    exit 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# _docker_harness_preflight_all
# Precondition: none
# Postcondition: return 0 if V1 preflight passes; specific non-zero exit code otherwise
# ---------------------------------------------------------------------------
_docker_harness_preflight_all() {
  # V1 preflight (inside-container concerns only).
  # Docker daemon check lives on the HOST (runbook L18-24 + workflow); not repeated here.
  # V1 has no in-container preflight — install stage validates its own preconditions.
  # This function exists so tests can characterize the preflight path shape.
  return 0
}

# ---------------------------------------------------------------------------
# _docker_harness_preflight_v2
# Precondition: preflight_all passed
# Postcondition: return 0 if V2 preflight passes; EXIT_ENV_MISSING (25) otherwise
# ---------------------------------------------------------------------------
_docker_harness_preflight_v2() {
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "ERROR: ANTHROPIC_API_KEY not set. V2 skill drive requires it." >&2
    echo "Remediation: export ANTHROPIC_API_KEY=<your-key> before invoking the harness." >&2
    return "$EXIT_ENV_MISSING"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# _docker_harness_retry_with_backoff
# Precondition: cmd is a valid shell command string; max_attempts >= 1
# Postcondition: return final command's exit code on success; return EXIT_INSTALL_FAIL (21)
#                when tag=="install" and attempts exhaust; else return last exit code
# ---------------------------------------------------------------------------
_docker_harness_retry_with_backoff() {
  local cmd="${1:-true}"
  local max_attempts="${2:-3}"
  local base_delay="${3:-1}"
  local tag="${4:-}"

  local attempt=1
  local last_code=0
  while (( attempt <= max_attempts )); do
    # Run the command; capture exit code without triggering set -e
    set +e
    bash -c "$cmd"
    last_code=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns

    if (( last_code == 0 )); then
      return 0
    fi

    if (( attempt < max_attempts )); then
      local delay=$(( base_delay * (2 ** (attempt - 1)) ))
      if (( delay > 0 )); then
        sleep "$delay"
      fi
    fi
    attempt=$(( attempt + 1 ))
  done

  # Exhausted. Map by tag.
  case "$tag" in
    install) return "$EXIT_INSTALL_FAIL" ;;
    build)   return "$EXIT_BUILD_FAIL" ;;
    *)       return "$last_code" ;;
  esac
}

# ---------------------------------------------------------------------------
# _docker_harness_map_exit_code
# Precondition: raw_code is an integer 0-255; assertion_tag is a string
# Postcondition: return the mapped exit code per exit-codes.sh vocabulary
# ---------------------------------------------------------------------------
_docker_harness_map_exit_code() {
  local raw_code="${1:-99}"
  local assertion_tag="${2:-}"

  case "$assertion_tag" in
    smoke-assert-settings-hooks)
      # Contract: 0 = pass; 3 = hooks-missing
      case "$raw_code" in
        0) return "$EXIT_OK" ;;
        3) return "$EXIT_HOOKS_MISSING" ;;
        *) return "$EXIT_UNKNOWN" ;;
      esac
      ;;
    smoke-assert-skills)
      case "$raw_code" in
        0) return "$EXIT_OK" ;;
        3) return "$EXIT_HOOKS_MISSING" ;;  # generic "one or more checks failed" per script contract
        4) return "$EXIT_SKILL_HARDCODE" ;;
        5) return "$EXIT_SKILL_TIMEOUT" ;;
        *) return "$EXIT_UNKNOWN" ;;
      esac
      ;;
    smoke-assert-hooks)
      case "$raw_code" in
        0) return "$EXIT_OK" ;;
        3) return "$EXIT_HOOKS_MISSING" ;;  # generic "one or more checks failed" per script contract (cascade detected)
        6) return "$EXIT_MANIFEST_MISMATCH" ;;
        *) return "$EXIT_UNKNOWN" ;;
      esac
      ;;
    *)
      return "$EXIT_UNKNOWN"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# _docker_harness_install_cli
# Precondition: preflight passed; CLI_VERSION set (default: latest)
# Postcondition: cli installed globally OR return EXIT_INSTALL_FAIL after retries
# ---------------------------------------------------------------------------
_docker_harness_install_cli() {
  local version="${CLI_VERSION:-latest}"

  if [[ "${HARNESS_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: would run: npm install -g @thebassclef/lite@${version}"
    return 0
  fi

  if [[ "${HARNESS_TEST_MODE:-0}" == "1" ]]; then
    echo "TEST_MODE: skipping npm install"
    return 0
  fi

  _docker_harness_retry_with_backoff \
    "npm install -g @thebassclef/lite@${version}" \
    3 15 install
}

# ---------------------------------------------------------------------------
# _docker_harness_init_adopter
# Precondition: cli installed globally; ADOPTER_TEST_DIR unset defaults to /adopter/test
# Postcondition: fresh git repo + bassclef init landed OR return EXIT_INIT_FAIL (23)
# ---------------------------------------------------------------------------
_docker_harness_init_adopter() {
  # Default to $HOME/test so bassclef init's home-guard passes without --allow-any-dir.
  local test_dir="${ADOPTER_TEST_DIR:-${HOME:-/home/adopter}/test}"

  if [[ "${HARNESS_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: would create $test_dir + git init + bassclef init"
    return 0
  fi

  if [[ "${HARNESS_TEST_MODE:-0}" == "1" ]]; then
    echo "TEST_MODE: skipping init"
    return 0
  fi

  mkdir -p "$test_dir"
  cd "$test_dir" || return "$EXIT_INIT_FAIL"

  git init -q 2>&1 || return "$EXIT_INIT_FAIL"

  # bassclef init needs git config user.email + user.name set; container has none.
  # Adopter machines usually have git config. Set fallback here.
  git config user.email "adopter@harness.local"
  git config user.name "Adopter Harness"

  if ! bassclef init 2>&1; then
    return "$EXIT_INIT_FAIL"
  fi

  # Export the test dir so smoke-assert can find .claude/settings.json
  export ADOPTER_CWD="$test_dir"
  return 0
}

# ---------------------------------------------------------------------------
# _docker_harness_run_smoke
# Precondition: cli installed; /adopter/test exists
# Postcondition: smoke-assert scripts invoked; captured exit codes emitted; final code returned
# ---------------------------------------------------------------------------
_docker_harness_run_smoke() {
  local scripts_dir="${SMOKE_SCRIPTS_DIR:-/adopter/scripts}"
  local raw_code=0
  local final_code=0

  # V1 assertion: settings-hooks-present
  if [[ -f "$scripts_dir/smoke-assert-settings-hooks.sh" ]]; then
    set +e
    bash "$scripts_dir/smoke-assert-settings-hooks.sh"
    raw_code=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns

    _docker_harness_map_exit_code "$raw_code" "smoke-assert-settings-hooks"
    final_code=$?
    _docker_harness_emit_evidence_row "smoke_assert_settings_hooks" "raw=${raw_code} mapped=${final_code}"

    if (( final_code != 0 )); then
      return "$final_code"
    fi
  else
    echo "ERROR: smoke-assert-settings-hooks.sh not found at $scripts_dir" >&2
    return "$EXIT_ASSERT_NOT_FOUND"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# _docker_harness_run_v2
# Precondition: V1 smoke passed; ANTHROPIC_API_KEY set; claude CLI on PATH
# Postcondition: 4 V2 scripts invoked; captured exit codes emitted; final code returned
#
# Runs the V2 pipeline: capture SessionStart hook output, drive 5 skills,
# assert on hook + skill captures, aggregate report. Each script's exit
# maps via _docker_harness_map_exit_code. Highest single-check code wins
# (C3 fold — preserves V1 exit code semantics).
# ---------------------------------------------------------------------------
_docker_harness_run_v2() {
  local scripts_dir="${SMOKE_SCRIPTS_DIR:-/adopter/scripts}"
  local captures_root="${V2_CAPTURES_DIR:-/adopter/state/harness-runs/$(date -u +%Y-%m-%dT%H-%M-%SZ)}"
  local worst_code=0

  mkdir -p "$captures_root/hooks" "$captures_root/skills"
  echo ">>> V2 skill drive starting" >&2
  echo "captures dir: $captures_root" >&2

  # V2 prep — mark the container's throwaway workspace as trusted so
  # claude -p does not block on the interactive trust dialog.
  # Scope: only /adopter/test (container path). Adopters running claude
  # in their own project still see the dialog on first run.
  # Per pre-mortem 09-20d cure — least-privilege trust at the caller.
  local workspace="${ADOPTER_CWD:-/adopter/test}"
  local claude_config="$HOME/.claude.json"
  jq -n --arg ws "$workspace" '{projects: {($ws): {hasTrustDialogAccepted: true}}}' > "$claude_config" 2>/dev/null || true
  echo "workspace trusted: $workspace" >&2

  # V2 Step 1 — smoke-capture (SessionStart hook output)
  if [[ -f "$scripts_dir/smoke-capture.sh" ]]; then
    set +e
    bash "$scripts_dir/smoke-capture.sh" --out "$captures_root/hooks"
    local raw=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns
    _docker_harness_emit_evidence_row "v2_capture" "exit=${raw}"
    (( raw > worst_code )) && worst_code=$raw
  else
    echo "WARN: smoke-capture.sh not found; skipping V2 hook capture" >&2
  fi

  # V2 Step 2 — smoke-drive-skills
  if [[ -f "$scripts_dir/smoke-drive-skills.sh" ]]; then
    set +e
    bash "$scripts_dir/smoke-drive-skills.sh" --out "$captures_root/skills" --timeout 120
    local raw=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns
    _docker_harness_emit_evidence_row "v2_drive" "exit=${raw}"
    (( raw > worst_code )) && worst_code=$raw
  else
    echo "WARN: smoke-drive-skills.sh not found; skipping V2 skill drive" >&2
  fi

  # V2 Step 3 — smoke-assert-hooks
  if [[ -f "$scripts_dir/smoke-assert-hooks.sh" ]]; then
    set +e
    bash "$scripts_dir/smoke-assert-hooks.sh" --capture-dir "$captures_root/hooks" --out "$captures_root/hooks-assertions.json"
    local raw=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns
    local final_code
    _docker_harness_map_exit_code "$raw" "smoke-assert-hooks"
    final_code=$?
    _docker_harness_emit_evidence_row "v2_assert_hooks" "raw=${raw} mapped=${final_code}"
    (( final_code > worst_code )) && worst_code=$final_code
  fi

  # V2 Step 4 — smoke-assert-skills
  if [[ -f "$scripts_dir/smoke-assert-skills.sh" ]]; then
    set +e
    bash "$scripts_dir/smoke-assert-skills.sh" --capture-dir "$captures_root/skills" --out "$captures_root/skills-assertions.json"
    local raw=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns
    local final_code
    _docker_harness_map_exit_code "$raw" "smoke-assert-skills"
    final_code=$?
    _docker_harness_emit_evidence_row "v2_assert_skills" "raw=${raw} mapped=${final_code}"
    (( final_code > worst_code )) && worst_code=$final_code
  fi

  # V2 Step 5 — smoke-report (no --publish; report to stdout via file)
  if [[ -f "$scripts_dir/smoke-report.sh" ]]; then
    set +e
    bash "$scripts_dir/smoke-report.sh" --captures-dir "$captures_root" --out "$captures_root/report.md"
    local raw=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns
    _docker_harness_emit_evidence_row "v2_report" "exit=${raw}"
    if [[ -f "$captures_root/report.md" ]]; then
      echo ""
      echo "===== V2 REPORT ====="
      cat "$captures_root/report.md"
      echo "===== end V2 report ====="
    fi
  fi

  # V2 Step 6 — smoke-drive-onboard-repo (per operator ask 2026-09-20 wrap)
  # Runs AFTER the 5-skill drive in its own scratch dir. Owns setup + drive
  # + assert + teardown so /onboard-repo's side effects never leak into the
  # main /adopter/test workspace. Exit codes: 0 pass, 3 assertion fail,
  # 5 timeout — folded into worst_code like the other V2 steps.
  if [[ -f "$scripts_dir/smoke-drive-onboard-repo.sh" ]]; then
    echo ">>> V2 Step 6 — /onboard-repo drive in fresh scratch dir" >&2
    set +e
    bash "$scripts_dir/smoke-drive-onboard-repo.sh" \
      --out "$captures_root/onboard" \
      --scratch "${HOME:-/tmp}/onboard-test" \
      --timeout 180
    local raw=$?
    # Deliberately keep set +e — V2 pipeline collects non-zero returns
    _docker_harness_emit_evidence_row "v2_onboard_repo" "exit=${raw}"
    (( raw > worst_code )) && worst_code=$raw
  else
    echo "WARN: smoke-drive-onboard-repo.sh not found; skipping V2 Step 6" >&2
  fi

  echo "<<< V2 skill drive done (worst mapped code=${worst_code})" >&2
  return "$worst_code"
}

# ---------------------------------------------------------------------------
# main — the 4-action orchestrator (RFC-0001 R3 cure)
# Precondition: sourced or invoked as script
# Postcondition: exit with a mapped code per exit-codes.sh vocabulary
# ---------------------------------------------------------------------------
main() {
  # Falsification-test banner (R8 cure)
  echo "=========================================="
  echo "bassclef-cli Docker cold-adopter harness"
  echo "target: @thebassclef/lite@${CLI_VERSION:-latest}"
  echo "expected: 0 on self-contained; non-zero on defect"
  echo "=========================================="

  # Signal traps (S3 cure)
  trap '_docker_harness_signal_handler TERM' TERM
  trap '_docker_harness_signal_handler INT' INT

  # Action 1: preflight
  if ! _docker_harness_preflight_all; then
    local code=$?
    _docker_harness_emit_evidence_row "preflight_fail" "V1 preflight failed with code $code"
    exit "$code"
  fi

  # Action 2: install
  if ! _docker_harness_install_cli; then
    local code=$?
    _docker_harness_emit_evidence_row "install_fail" "cli install failed with code $code"
    exit "$code"
  fi

  # Action 2b: init the adopter workspace (UC steps 6-7)
  if ! _docker_harness_init_adopter; then
    local code=$?
    _docker_harness_emit_evidence_row "init_fail" "bassclef init failed with code $code"
    exit "$code"
  fi

  # Action 3: smoke — invoked from the initialized adopter workspace
  cd "${ADOPTER_CWD:-/adopter/test}" || exit "$EXIT_INIT_FAIL"

  set +e
  _docker_harness_run_smoke
  local smoke_code=$?
  set -e 2>/dev/null || true

  # V1 gate — if V1 red, exit now (don't proceed to V2)
  if (( smoke_code != 0 )); then
    _docker_harness_emit_evidence_row "harness_complete" "V1 red; final exit code $smoke_code"
    exit "$smoke_code"
  fi

  # Action 4: V2 skill drive — only if API key set (N2 fold — degrade gracefully)
  local v2_code=0
  if _docker_harness_preflight_v2 2>/dev/null; then
    if [[ "${HARNESS_TEST_MODE:-0}" != "1" ]]; then
      set +e
      _docker_harness_run_v2
      v2_code=$?
      # Deliberately keep set +e — V2 pipeline collects non-zero returns
    fi
  else
    echo "" >&2
    echo "WARN: ANTHROPIC_API_KEY not set; V2 skill drive skipped." >&2
    echo "V1 result stands. To run V2, invoke with -e ANTHROPIC_API_KEY on docker run." >&2
    _docker_harness_emit_evidence_row "v2_skipped" "ANTHROPIC_API_KEY unset"
  fi

  # Action 5: propagate worst of V1 + V2
  local final_code=$smoke_code
  (( v2_code > final_code )) && final_code=$v2_code
  _docker_harness_emit_evidence_row "harness_complete" "V1=${smoke_code} V2=${v2_code} final=${final_code}"
  exit "$final_code"
}

# Only run main when this file is invoked directly, not when sourced (test path).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
