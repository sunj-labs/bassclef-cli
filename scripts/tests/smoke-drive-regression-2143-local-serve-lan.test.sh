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

set -uo pipefail

# test-list:
# [x] Case 1 — dist/lite/scripts/launch/local-serve.sh exists in the bundle
# [x] Case 2 — script carries the bassclef-upstream#2143 cure anchor
# [x] Case 3 — script body documents the Wi-Fi-reachable intent
# [x] Case 4 — spawn local-serve.sh --lan against a scratch gallery; curl the
#              bound port; assert HTTP 2xx; kill the server via state-file PID.
#              Catches the "binds + responds" regression class the earlier
#              grep-only shape could not. python3 absent → SKIP via exit 77.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/dist/lite/scripts/launch/local-serve.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "SKIP|driver-2143|$SCRIPT absent (run bundle sync first)"
  exit 77
fi

# ---- Case 1-3: anchor greps (static) ------------------------------------
missing=()
grep -qE 'bassclef-upstream#2143' "$SCRIPT" || missing+=("bassclef-upstream#2143 cure anchor")
grep -qiE 'wi-?fi|lan' "$SCRIPT" || missing+=("Wi-Fi/LAN reachable intent")

if (( ${#missing[@]} > 0 )); then
  echo "FAIL|driver-2143|regression: cure anchors missing: ${missing[*]}"
  exit 1
fi

# ---- Case 4: real bind + curl (dynamic) ---------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP|driver-2143|python3 not on PATH; static anchors passed; dynamic bind+curl skipped"
  exit 77
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP|driver-2143|curl not on PATH; static anchors passed; dynamic bind+curl skipped"
  exit 77
fi

TMPDIR=$(mktemp -d)
cleanup() {
  # Kill any serve process we spawned via state-file PID.
  if [[ -n "${STATE_FILE:-}" ]] && [[ -f "$STATE_FILE" ]]; then
    local pid
    pid=$(awk -F= '/^pid=/{print $2}' "$STATE_FILE" 2>/dev/null || true)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 0.5
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

GALLERY_DIR="$TMPDIR/gallery"
mkdir -p "$GALLERY_DIR"
cat > "$GALLERY_DIR/index.html" <<'HTML'
<!doctype html><title>reachability probe</title><body>driver-2143 ok</body>
HTML

# REPO_ROOT is read by local-serve.sh to place the state file.
PORT_HINT=$((8800 + RANDOM % 100))
STATE_DIR="$TMPDIR/state/markers/local-serve"
STATE_FILE="$STATE_DIR/gallery.state"

URL_OUTPUT=$(REPO_ROOT="$TMPDIR" bash "$SCRIPT" --lan "$GALLERY_DIR" "$PORT_HINT" 2>/dev/null | head -1 || true)

if [[ -z "$URL_OUTPUT" ]]; then
  echo "FAIL|driver-2143|Case 4: local-serve.sh printed no URL on stdout"
  exit 1
fi

# Extract port from the printed URL. --lan prints an IP that may be LAN or
# 127.0.0.1 fallback — in CI without a Wi-Fi interface the detect falls
# back cleanly. We curl 127.0.0.1:$PORT regardless because the server binds
# to 0.0.0.0 (all interfaces) when --lan is set.
PORT=$(echo "$URL_OUTPUT" | sed -nE 's#.*:([0-9]+).*#\1#p')
if [[ -z "$PORT" ]]; then
  echo "FAIL|driver-2143|Case 4: could not parse port from URL '$URL_OUTPUT'"
  exit 1
fi

# Give the server a moment to accept connections.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sfI "http://127.0.0.1:${PORT}/" -m 1 >/dev/null 2>&1; then
    HTTP_OK=1
    break
  fi
  sleep 0.3
done

if [[ "${HTTP_OK:-0}" != "1" ]]; then
  echo "FAIL|driver-2143|Case 4: curl http://127.0.0.1:${PORT}/ did not return 2xx; server bound but unreachable"
  exit 1
fi

# Verify the index.html we wrote is actually served.
BODY=$(curl -sf "http://127.0.0.1:${PORT}/" -m 2 2>/dev/null || true)
if ! grep -q 'driver-2143 ok' <<< "$BODY"; then
  echo "FAIL|driver-2143|Case 4: served content does not match written index.html"
  exit 1
fi

echo "PASS|driver-2143|GREEN-CONFIRMED: anchors + real bind+curl (port=$PORT) via local-serve --lan"
exit 0
