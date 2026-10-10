#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-2138-install-written-paths.test.sh
#
# Characterization driver — bassclef-upstream#2036 Finding #8 (Session N / Kunal).
# Anchors the Class A cure (install-written-paths mediation lib).
#
# dist/lite/lib/install-written-paths.sh exposes the 5-verb API that
# discipline hooks consult via `is_install_written_path`. Prior to v1.9.2
# this lib did not ship in the lite bundle; cold adopters hit false-positive
# BLOCKs on dispatcher-written files. v1.9.2 bundled it; v1.9.3 (per
# bassclef-upstream#2138) added the CLI init.manifest.json fallback so
# the lib reads the npm-side manifest when its primary state file is empty.
#
# Driver asserts dist/lite/lib/install-written-paths.sh carries:
#   1. install_written_paths_register (writer registration verb)
#   2. is_install_written_path (reader verb used by discipline hooks)
#   3. the bassclef-upstream#2138 CLI fallback anchor comment
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (bundle carries lib + 2138 fallback)
#   1  — regression (lib missing or 2138 anchor gone)
#   77 — SKIP (bundle not available; run `npm run build && node scripts/prepublish-bundle-substrate.mjs`)

set -euo pipefail

# test-list:
# [x] Case 1 — dist/lite/lib/install-written-paths.sh exists in the bundle
# [x] Case 2 — lib exposes install_written_paths_register verb
# [x] Case 3 — lib exposes is_install_written_path verb
# [x] Case 4 — lib carries the bassclef-upstream#2138 fallback anchor

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/dist/lite/lib/install-written-paths.sh"

if [[ ! -f "$LIB" ]]; then
  echo "SKIP|driver-2138|$LIB absent (run \`npm run build && node scripts/prepublish-bundle-substrate.mjs\` first)"
  exit 77
fi

missing=()
grep -qE '^install_written_paths_register\(\)' "$LIB" || missing+=("install_written_paths_register verb")
grep -qE '^is_install_written_path\(\)' "$LIB" || missing+=("is_install_written_path verb")
grep -qE 'bassclef-upstream#2138' "$LIB" || missing+=("bassclef-upstream#2138 fallback anchor")

if (( ${#missing[@]} > 0 )); then
  echo "FAIL|driver-2138|regression: cure anchors missing: ${missing[*]}"
  exit 1
fi

echo "PASS|driver-2138|GREEN-CONFIRMED: install-written-paths lib + 2138 fallback shipped"
exit 0
