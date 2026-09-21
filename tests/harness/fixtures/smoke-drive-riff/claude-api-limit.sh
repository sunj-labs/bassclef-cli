#!/usr/bin/env bash
# Mock claude — API usage cap hit (real signature from 2026-09-21 verification).
# Tests F3 expanded env-miss detection for API-budget class.
set -euo pipefail
echo "API Error: 400 You have reached your specified API usage limits. You will regain access on 2026-10-01 at 00:00 UTC." >&2
exit 1
