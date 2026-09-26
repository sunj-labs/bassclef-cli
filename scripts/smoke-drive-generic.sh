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

  if [ -n "$spawn_args_str" ]; then
    # shellcheck disable=SC2086
    drive_start "$scratch_dir" "$spawn_cmd" $spawn_args_str || return $?
  else
    drive_start "$scratch_dir" "$spawn_cmd" || return $?
  fi

  drive_expect "$ready" "$timeout"
  drive_send "$prompt"
  drive_expect "$done_pat" "$timeout"
  drive_end
  return $?
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
