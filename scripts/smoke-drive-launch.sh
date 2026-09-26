#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
#
# smoke-drive-launch.sh — Strategy for /launch drive.
#
# Sub-step 3 of cli#254 — real body.
#
# Same shape as smoke-drive-interactive-onboard-repo.sh with /launch
# defaults. Env-var-driven configuration keeps the DriveScript
# positional signature stable (Ousterhout O1 fold).
#
# Env-var config (per pre-mortem O6 fold):
#   SMOKE_DRIVE_SPAWN_CMD     — process to drive (default: `claude`)
#   SMOKE_DRIVE_SPAWN_ARGS    — space-separated args (default: empty)
#   SMOKE_DRIVE_READY_PATTERN — Tcl regex for ready prompt (default: `READY>|>`)
#   SMOKE_DRIVE_DONE_PATTERN  — Tcl regex for completion (default: `DONE>|done|complete`)
#   SMOKE_DRIVE_PROMPT_TEXT   — text to send after ready (default: `run /launch`)
#
# Default timeout 240s reflects /launch's larger artifact set
# (docs/prototypes/, docs/specs/) per pre-mortem O9.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/smoke-expect.sh
source "$SCRIPT_DIR/lib/smoke-expect.sh"
# shellcheck source=lib/smoke-drives-registry.sh
source "$SCRIPT_DIR/lib/smoke-drives-registry.sh"

# main — per DriveScript interface in decompose doc.
# Arguments:
#   $1 — SCRATCH_DIR (absolute path; must exist)
#   $2 — CLI_VERSION (e.g. 1.9.4)
#   $3 — TIMEOUT_SEC (default 240)
# Returns:
#   0 on all-expects-matched; 10-14 per smoke-expect exit-code vocabulary.
main() {
  local scratch_dir="${1:?SCRATCH_DIR required}"
  local cli_version="${2:?CLI_VERSION required}"
  local timeout_sec="${3:-240}"

  : "$cli_version"

  local spawn_cmd="${SMOKE_DRIVE_SPAWN_CMD:-claude}"
  local ready_pattern="${SMOKE_DRIVE_READY_PATTERN:-READY>|>}"
  local done_pattern="${SMOKE_DRIVE_DONE_PATTERN:-DONE>|done|complete}"
  local prompt_text="${SMOKE_DRIVE_PROMPT_TEXT:-run /launch}"

  local spawn_args_str="${SMOKE_DRIVE_SPAWN_ARGS:-}"
  if [ -n "$spawn_args_str" ]; then
    # shellcheck disable=SC2086
    drive_start "$scratch_dir" "$spawn_cmd" $spawn_args_str || return $?
  else
    drive_start "$scratch_dir" "$spawn_cmd" || return $?
  fi

  drive_expect "$ready_pattern" "$timeout_sec"
  drive_send "$prompt_text"
  drive_expect "$done_pattern" "$timeout_sec"
  drive_end
  return $?
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
