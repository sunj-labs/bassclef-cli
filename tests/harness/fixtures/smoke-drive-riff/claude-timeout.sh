#!/usr/bin/env bash
# Mock claude — timeout path.
# Sleeps past the drive's default 300s timeout. The perl-alarm wrapper
# should fire SIGALRM at the timeout boundary.
set -euo pipefail
sleep 999
