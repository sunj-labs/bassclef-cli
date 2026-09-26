#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
#
# smoke-drive-interactive-onboard-repo.sh — Strategy for /onboard-repo drive.
#
# Sub-step 2 of cli#254 — real body.
#
# Drives an interactive `claude` (or fake_claude fixture) through the
# /onboard-repo skill flow using the 5 smoke-expect verbs. Waits for a
# ready prompt, sends the skill invocation, waits for a completion
# marker, tears down.
#
# Env-var-driven configuration (per pre-mortem O1 fold — no new
# positional args on main; extension via env only):
#   SMOKE_DRIVE_SPAWN_CMD     — process to drive (default: `claude`)
#   SMOKE_DRIVE_SPAWN_ARGS    — args to pass to spawn cmd (default: empty)
#   SMOKE_DRIVE_READY_PATTERN — Tcl regex for initial ready prompt
#                               (default: `READY>|>` matches both fake + real)
#   SMOKE_DRIVE_DONE_PATTERN  — Tcl regex for completion marker
#                               (default: `DONE>|done|complete` for fake + real)
#   SMOKE_DRIVE_PROMPT_TEXT   — text to send after ready
#                               (default: `run /onboard-repo`)
#
# See docs/decompositions/2026-09-26-cli-254-interactive-drives.md §
# "Control (business logic — one entity per skill)".

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
#   $3 — TIMEOUT_SEC (default 180 per Feathers F2 fold)
# Returns:
#   0 on all-expects-matched; 10-14 per exit-code vocabulary from smoke-expect.
main() {
  local scratch_dir="${1:?SCRATCH_DIR required}"
  local cli_version="${2:?CLI_VERSION required}"
  local timeout_sec="${3:-180}"

  # cli_version currently unused; passed for consistency across drives + future
  # version-aware branching. Referenced for shellcheck compliance.
  : "$cli_version"

  local spawn_cmd="${SMOKE_DRIVE_SPAWN_CMD:-claude}"
  local ready_pattern="${SMOKE_DRIVE_READY_PATTERN:-READY>|>}"
  local done_pattern="${SMOKE_DRIVE_DONE_PATTERN:-DONE>|done|complete}"
  local prompt_text="${SMOKE_DRIVE_PROMPT_TEXT:-run /onboard-repo}"

  # Step 1: start session. SPAWN_ARGS (env, space-separated) split via
  # IFS; empty-safe under bash 3.2 + set -u via ${:+} idiom.
  local spawn_args_str="${SMOKE_DRIVE_SPAWN_ARGS:-}"
  if [ -n "$spawn_args_str" ]; then
    # shellcheck disable=SC2086
    drive_start "$scratch_dir" "$spawn_cmd" $spawn_args_str || return $?
  else
    drive_start "$scratch_dir" "$spawn_cmd" || return $?
  fi

  # Step 2: wait for interactive ready prompt
  drive_expect "$ready_pattern" "$timeout_sec"

  # Step 3: launch the skill
  drive_send "$prompt_text"

  # Step 4: wait for completion marker
  drive_expect "$done_pattern" "$timeout_sec"

  # Step 5: teardown + return aggregate result
  drive_end
  return $?
}

# Run when invoked directly; skip when sourced by tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
