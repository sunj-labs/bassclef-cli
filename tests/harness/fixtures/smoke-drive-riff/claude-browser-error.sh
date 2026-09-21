#!/usr/bin/env bash
# Mock claude — browser-launch failure (browser token per F3 expanded set).
# Tests F-AR-1 cure — `browser` alone matches without `playwright` present.
set -euo pipefail
echo "/riff: could not launch browser process — visual-review step blocked" >&2
exit 3
