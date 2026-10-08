#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-flows-registry.sh
#
# Flow driver registry per ADR-011 D4. Enumerates every flow driver + its
# one-line intent. Sister to the existing persona-driver registry
# (scripts/tests/smoke-drives-registry.sh, when it ships) — same
# discovery shape.
#
# Shape:
#   FLOWS=(
#     "<slug>|<intent>"
#     ...
#   )
#
# A harness that wants to enumerate flows parses the FLOWS array; each
# driver lives at scripts/tests/smoke-drive-flow-<slug>.sh. The one-line
# intent is operator-readable and names the sequence the flow characterizes.
#
# When invoked directly, this script prints the registry as a scan table
# (slug + status + intent) for operator review.

set -euo pipefail

FLOWS=(
  "install-first-commit|install → first commit (bassclef init → git add → git commit; proves bassclef-upstream#2036 F#8 convergence)"
  "launch-local-serve-phone|launch → serve → phone (local-serve.sh prints Wi-Fi-reachable LAN URL; proves bassclef-upstream#2143)"
  "write-marker-use-marker|skill writes marker → downstream skill reads marker (helper ships at lite tier; proves bassclef-upstream#2140)"
  "agent-write-hook-scan|agent writes file → pre-commit-gate matcher fires in cured shape (proves bassclef-upstream#2139)"
)

main() {
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  echo "Flow driver registry — bassclef-cli ADR-011 D4"
  echo
  printf "%-36s %-10s %s\n" "SLUG" "STATUS" "INTENT"
  printf "%-36s %-10s %s\n" "----" "------" "------"
  for entry in "${FLOWS[@]}"; do
    local slug="${entry%%|*}"
    local intent="${entry#*|}"
    local path="$REPO_ROOT/scripts/tests/smoke-drive-flow-${slug}.sh"
    local status
    if [[ -x "$path" ]]; then
      status="shipped"
    elif [[ -f "$path" ]]; then
      status="present"
    else
      status="MISSING"
    fi
    printf "%-36s %-10s %s\n" "$slug" "$status" "$intent"
  done
}

# When sourced (`source smoke-drive-flows-registry.sh`), only the FLOWS
# array is exported to the caller. When run directly, print the table.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
