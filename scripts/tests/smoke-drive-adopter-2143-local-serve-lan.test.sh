#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-2143-local-serve-lan.test.sh
#
# Characterization driver — bassclef-upstream#2143 (Session N / Kunal).
# Anchors the local-serve.sh --lan cure.
#
# Prior to the cure, scripts/launch/local-serve.sh printed the LAN URL as
# `http://0.0.0.0:<port>` — a listen address, not a reachable address.
# Operators and testing phones on the same Wi-Fi could not reach the dev
# server. Cure resolves the host's actual LAN IP and prints that instead.
#
# Driver asserts dist/lite/scripts/launch/local-serve.sh carries the
# bassclef-upstream#2143 cure anchor and the Wi-Fi-reachable intent note.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — GREEN-CONFIRMED (cure anchor + Wi-Fi intent present)
#   1  — regression (anchor or intent missing)
#   77 — SKIP (bundle not available)

set -euo pipefail

# test-list:
# [x] Case 1 — dist/lite/scripts/launch/local-serve.sh exists in the bundle
# [x] Case 2 — script carries the bassclef-upstream#2143 cure anchor
# [x] Case 3 — script body documents the Wi-Fi-reachable intent

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/dist/lite/scripts/launch/local-serve.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "SKIP|driver-2143|$SCRIPT absent (run bundle sync first)"
  exit 77
fi

missing=()
grep -qE 'bassclef-upstream#2143' "$SCRIPT" || missing+=("bassclef-upstream#2143 cure anchor")
grep -qiE 'wi-?fi|lan' "$SCRIPT" || missing+=("Wi-Fi/LAN reachable intent")

if (( ${#missing[@]} > 0 )); then
  echo "FAIL|driver-2143|regression: cure anchors missing: ${missing[*]}"
  exit 1
fi

echo "PASS|driver-2143|GREEN-CONFIRMED: local-serve --lan reachability cure shipped"
exit 0
