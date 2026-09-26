#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
#
# smoke-drive-launch.sh — Strategy for /launch drive.
#
# WALKING SKELETON — Beck TDD RED phase for cli#254.
# Real body walks gallery + spec + user stories + plan artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/smoke-expect.sh
source "$SCRIPT_DIR/lib/smoke-expect.sh"
# shellcheck source=lib/smoke-drives-registry.sh
source "$SCRIPT_DIR/lib/smoke-drives-registry.sh"

main() {
  local scratch_dir="${1:?SCRATCH_DIR required}"
  local cli_version="${2:?CLI_VERSION required}"
  local timeout_sec="${3:-240}"

  echo "smoke-drive-launch: skeleton — unimplemented" >&2
  echo "  scratch_dir=$scratch_dir cli_version=$cli_version timeout=$timeout_sec" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
