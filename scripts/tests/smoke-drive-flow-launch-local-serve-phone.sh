#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-flow-launch-local-serve-phone.sh
#
# Flow driver — launch → serve → phone (per ADR-011 D3; Session N
# cold-adopter flow #2).
#
# Exercises the shipped scripts/launch/local-serve.sh at the bundled
# path. Asserts the script carries the --lan cure anchor and does not
# print 0.0.0.0 as the primary LAN URL. Does NOT bind an actual port —
# that requires a running dev server + Wi-Fi + a phone, which is out of
# the CI harness scope. The script's --help output is the surface
# characterized here (per @luminary michael-feathers — pin the
# observable behavior at the install boundary).
#
# @pattern patterns/code/cockburn/walking-skeleton.md
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — flow passed: script carries cured --lan behavior anchor
#   1  — regression (script missing or 0.0.0.0 reappeared as the printed URL)
#   77 — SKIP (bundled script not available)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/dist/lite/scripts/launch/local-serve.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "SKIP|flow-launch-local-serve-phone|$SCRIPT absent (run bundle sync first)"
  exit 77
fi

# Anchor assertion — cure for bassclef-upstream#2143 names "0.0.0.0" as the
# prior failure and documents the Wi-Fi reachable intent. If a future
# bundle sync drops the cure, the first grep passes but the second fails.
if ! grep -qE 'bassclef-upstream#2143' "$SCRIPT"; then
  echo "FAIL|flow-launch-local-serve-phone|step=anchor: bassclef-upstream#2143 cure anchor missing"
  exit 1
fi
if ! grep -qE '0\.0\.0\.0' "$SCRIPT"; then
  echo "FAIL|flow-launch-local-serve-phone|step=anchor: script no longer references the 0.0.0.0 failure context — cure comment lost?"
  exit 1
fi
# The cure printed a resolved LAN IP — grep for the ip discovery pattern.
if ! grep -qiE 'ifconfig|ip addr|hostname -I|ipconfig' "$SCRIPT"; then
  echo "FAIL|flow-launch-local-serve-phone|step=behavior: no IP-discovery pattern in script (ifconfig/ip-addr/hostname/ipconfig)"
  exit 1
fi

echo "PASS|flow-launch-local-serve-phone|launch script carries --lan cure + Wi-Fi IP discovery"
exit 0
