#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
#
# smoke-drive-interactive-onboard-repo.sh — Strategy for /onboard-repo drive.
#
# WALKING SKELETON — Beck TDD RED phase for cli#254.
# Sources smoke-expect.sh anticorruption layer + smoke-drives-registry.
# main() returns unimplemented sentinel; real body lands in follow-on commit.
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
#   $1 — SCRATCH_DIR (absolute path)
#   $2 — CLI_VERSION (e.g. 1.9.4)
#   $3 — TIMEOUT_SEC (default 180)
# Returns:
#   0 on success; 10-19 per exit-code vocabulary; 42 on skeleton stub.
main() {
  local scratch_dir="${1:?SCRATCH_DIR required}"
  local cli_version="${2:?CLI_VERSION required}"
  local timeout_sec="${3:-180}"

  echo "smoke-drive-interactive-onboard-repo: skeleton — unimplemented" >&2
  echo "  scratch_dir=$scratch_dir cli_version=$cli_version timeout=$timeout_sec" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

# Run when invoked directly; skip when sourced by tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
