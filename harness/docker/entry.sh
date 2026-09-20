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
  # V1 preflight: minimal checks. Docker daemon check skipped in test mode.
  if [[ "${HARNESS_TEST_MODE:-0}" != "1" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      echo "ERROR: docker not on PATH. Install OrbStack (macOS) or Docker Engine (Linux)." >&2
      return 20
    fi
    if ! docker info >/dev/null 2>&1; then
      echo "ERROR: docker daemon not responding. Start OrbStack or Docker Desktop." >&2
      return 20
    fi
  fi
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
    set -e 2>/dev/null || true

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
        4) return "$EXIT_SKILL_HARDCODE" ;;
        5) return "$EXIT_SKILL_TIMEOUT" ;;
        *) return "$EXIT_UNKNOWN" ;;
      esac
      ;;
    smoke-assert-hooks)
      case "$raw_code" in
        0) return "$EXIT_OK" ;;
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
    set -e 2>/dev/null || true

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

  # Action 3: smoke
  set +e
  _docker_harness_run_smoke
  local smoke_code=$?
  set -e 2>/dev/null || true

  # Action 4: propagate
  _docker_harness_emit_evidence_row "harness_complete" "final exit code $smoke_code"
  exit "$smoke_code"
}

# Only run main when this file is invoked directly, not when sourced (test path).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
