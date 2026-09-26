#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
#
# smoke-drive-interactive-riff.sh — Strategy for /riff drive.
#
# Sub-step 4 of cli#254 — real body.
#
# Same shape as sub-steps 2+3 with /riff defaults. Env-var-driven
# config keeps DriveScript signature stable (Ousterhout O1 fold).
#
# NOTE: /riff full path depends on Playwright MCP (cli#241). Drive body
# ships the shape; SKIP_RIFF_INTERACTIVE=1 retains skip semantics for
# Docker CI until cli#241 lands.
#
# Env-var config (per pre-mortem O6 fold):
#   SMOKE_DRIVE_SPAWN_CMD     — process to drive (default: `claude`)
#   SMOKE_DRIVE_SPAWN_ARGS    — space-separated args (default: empty)
#   SMOKE_DRIVE_READY_PATTERN — Tcl regex for ready prompt (default: `READY>|>`)
#   SMOKE_DRIVE_DONE_PATTERN  — Tcl regex for completion (default: `DONE>|done|complete`)
#   SMOKE_DRIVE_PROMPT_TEXT   — text to send after ready (default: `run /riff`)
#   SKIP_RIFF_INTERACTIVE=1   — skip the drive (returns 0 immediately) per cli#241

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/smoke-expect.sh
source "$SCRIPT_DIR/lib/smoke-expect.sh"
# shellcheck source=lib/smoke-drives-registry.sh
source "$SCRIPT_DIR/lib/smoke-drives-registry.sh"

# main — per DriveScript interface in decompose doc.
# Arguments:
#   $1 — SCRATCH_DIR
#   $2 — CLI_VERSION
#   $3 — TIMEOUT_SEC (default 300; larger than /launch's 240 per pre-mortem F13)
# Returns:
#   0 on success (or SKIP); 10-14 per smoke-expect exit-code vocabulary.
main() {
  local scratch_dir="${1:?SCRATCH_DIR required}"
  local cli_version="${2:?CLI_VERSION required}"
  local timeout_sec="${3:-300}"

  : "$cli_version"

  # SKIP path — cli#241 (Playwright MCP sandbox gap) still open in Docker
  if [ "${SKIP_RIFF_INTERACTIVE:-0}" = "1" ]; then
    echo "smoke-drive-interactive-riff: SKIP per SKIP_RIFF_INTERACTIVE=1 (cli#241)" >&2
    return 0
  fi

  local spawn_cmd="${SMOKE_DRIVE_SPAWN_CMD:-claude}"
  local ready_pattern="${SMOKE_DRIVE_READY_PATTERN:-READY>|>}"
  local done_pattern="${SMOKE_DRIVE_DONE_PATTERN:-DONE>|done|complete}"
  local prompt_text="${SMOKE_DRIVE_PROMPT_TEXT:-run /riff}"

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
