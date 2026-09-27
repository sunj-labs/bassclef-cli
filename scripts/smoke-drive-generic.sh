#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
# @pattern patterns/code/gof/template-method.md
#
# smoke-drive-generic.sh — one driver, N skills.
#
# Cli#254 Batch A generic driver. Looks up per-skill patterns from
# scripts/lib/smoke-drive-catalog.sh and executes the same drive
# sequence as sub-steps 2-4 (drive_start → expect ready → send prompt
# → expect done → drive_end).
#
# Interface (per pre-mortem BA3 fold — distinct from walking-skeleton
# per-skill drives that use SCRATCH_DIR-first positional):
#   Arguments:
#     $1 — SKILL_NAME (must resolve via catalog)
#     $2 — SCRATCH_DIR (absolute path; must exist)
#     $3 — CLI_VERSION (e.g. 1.9.4)
#     $4 — TIMEOUT_SEC (optional; catalog default used when omitted)
#
# Env-var overrides (same names as sub-steps 2-4):
#   SMOKE_DRIVE_SPAWN_CMD     — process to drive (default: `claude`)
#   SMOKE_DRIVE_SPAWN_ARGS    — space-separated args (default: empty)
#   SMOKE_DRIVE_READY_PATTERN — override catalog default
#   SMOKE_DRIVE_DONE_PATTERN  — override catalog default
#   SMOKE_DRIVE_PROMPT_TEXT   — override catalog default
#
# Returns:
#   0 on success; 10-14 per smoke-expect exit-code vocabulary;
#   13 when SKILL_NAME is not in the catalog.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/smoke-expect.sh
source "$SCRIPT_DIR/lib/smoke-expect.sh"
# shellcheck source=lib/smoke-drive-catalog.sh
source "$SCRIPT_DIR/lib/smoke-drive-catalog.sh"
# shellcheck source=lib/smoke-drive-setup.sh
source "$SCRIPT_DIR/lib/smoke-drive-setup.sh"

main() {
  local skill_name="${1:?SKILL_NAME required (see smoke-drive-catalog.sh)}"
  local scratch_dir="${2:?SCRATCH_DIR required}"
  local cli_version="${3:?CLI_VERSION required}"
  local timeout_override="${4:-}"

  : "$cli_version"

  # Catalog lookups with env-var override precedence
  local catalog_prompt catalog_ready catalog_done catalog_timeout
  catalog_prompt=$(_catalog_prompt "$skill_name") || {
    echo "smoke-drive-generic: SKILL_NAME '$skill_name' not in catalog" >&2
    return 13
  }
  catalog_ready=$(_catalog_ready "$skill_name")
  catalog_done=$(_catalog_done "$skill_name")
  catalog_timeout=$(_catalog_timeout "$skill_name")

  local prompt="${SMOKE_DRIVE_PROMPT_TEXT:-$catalog_prompt}"
  local ready="${SMOKE_DRIVE_READY_PATTERN:-$catalog_ready}"
  local done_pat="${SMOKE_DRIVE_DONE_PATTERN:-$catalog_done}"
  local timeout="${timeout_override:-$catalog_timeout}"

  local spawn_cmd="${SMOKE_DRIVE_SPAWN_CMD:-claude}"
  local spawn_args_str="${SMOKE_DRIVE_SPAWN_ARGS:-}"

  # Per pre-mortem ST1 fold: setup runs first. Abort drive on setup fail.
  # Empty catalog return means "no setup needed" — driver skips the loop.
  local setup_fns teardown_fns fn setup_rc
  setup_fns=$(_catalog_setup "$skill_name" 2>/dev/null || echo "")
  for fn in $setup_fns; do
    if ! type -t "$fn" >/dev/null 2>&1; then
      echo "smoke-drive-generic: setup fn '$fn' not defined (catalog+setup drift)" >&2
      return 13
    fi
    setup_rc=0
    "$fn" "$scratch_dir" || setup_rc=$?
    if [ $setup_rc -ne 0 ]; then
      echo "smoke-drive-generic: setup '$fn' failed with rc=$setup_rc for skill '$skill_name'" >&2
      return 13
    fi
  done

  if [ -n "$spawn_args_str" ]; then
    # shellcheck disable=SC2086
    drive_start "$scratch_dir" "$spawn_cmd" $spawn_args_str || return $?
  else
    drive_start "$scratch_dir" "$spawn_cmd" || return $?
  fi

  drive_expect "$ready" "$timeout"
  drive_send "$prompt"
  drive_expect "$done_pat" "$timeout"

  local drive_rc=0
  drive_end || drive_rc=$?

  # Teardown runs regardless of drive result. Failures are logged
  # but do not override drive_rc unless drive_rc==0.
  teardown_fns=$(_catalog_teardown "$skill_name" 2>/dev/null || echo "")
  local teardown_failures=0
  for fn in $teardown_fns; do
    if type -t "$fn" >/dev/null 2>&1; then
      "$fn" "$scratch_dir" || teardown_failures=$((teardown_failures + 1))
    fi
  done
  if [ $drive_rc -eq 0 ] && [ $teardown_failures -gt 0 ]; then
    echo "smoke-drive-generic: $teardown_failures teardown failure(s) for skill '$skill_name'" >&2
    return 14
  fi
  return $drive_rc
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
