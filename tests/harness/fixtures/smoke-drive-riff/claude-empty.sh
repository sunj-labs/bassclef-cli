#!/usr/bin/env bash
# Mock claude — assertion-fail path.
# Exits 0 but writes no HTML. Simulates a /riff regression that dispatches
# cleanly but fails to author variants (e.g., interpret-input hangs).
set -euo pipefail
echo "/riff mock: dispatched but wrote nothing"
exit 0
