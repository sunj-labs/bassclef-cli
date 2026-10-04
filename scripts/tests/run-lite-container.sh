#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/run-lite-container.sh — operator-dispatched local runner
# for the lite-adopter smoke container.
#
# Session A walking skeleton. Builds Dockerfile.lite-adopter and runs
# every scripts/tests/smoke-drive-e2e-*.test.sh inside the container.
#
# RFC F-JC-1 fold: Dockerfile is operator-local convenience; CI uses
# GHA OS matrix for fidelity.
# R-T3 fold: --platform linux/amd64 so M-series Macs run through Rosetta
# cleanly instead of booting arm64 node image.
#
# Usage:
#   bash scripts/tests/run-lite-container.sh                # run all drivers
#   bash scripts/tests/run-lite-container.sh --live         # SMOKE_LIVE=1

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="bassclef-cli-lite-adopter:local"
SMOKE_LIVE="${SMOKE_LIVE:-0}"

for arg in "$@"; do
  case "$arg" in
    --live) SMOKE_LIVE=1 ;;
    *) echo "unknown arg: $arg"; exit 2 ;;
  esac
done

echo "==> building ${IMAGE_TAG} from $REPO_ROOT/Dockerfile.lite-adopter"
docker build \
  --platform linux/amd64 \
  -t "$IMAGE_TAG" \
  -f "$REPO_ROOT/Dockerfile.lite-adopter" \
  "$REPO_ROOT"

echo "==> running drivers (SMOKE_LIVE=$SMOKE_LIVE)"
docker run --rm \
  --platform linux/amd64 \
  -v "$REPO_ROOT:/opt/bassclef-cli:ro" \
  -e "SMOKE_LIVE=$SMOKE_LIVE" \
  "$IMAGE_TAG" \
  /bin/bash -c '
    set -euo pipefail
    cd /opt/bassclef-cli
    pass=0
    fail=0
    for drv in scripts/tests/smoke-drive-e2e-*.test.sh; do
      if [[ -f "$drv" ]]; then
        echo "--- running $drv ---"
        if bash "$drv"; then
          pass=$((pass+1))
        else
          fail=$((fail+1))
        fi
      fi
    done
    echo ""
    echo "==> drivers: $pass pass / $fail fail"
    [[ "$fail" -eq 0 ]] || exit 3
  '
