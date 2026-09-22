#!/usr/bin/env bash
# Mock claude — reproduces the cli #217 failure class.
# When -p receives a leading-slash string, echoes "Unknown command: X"
# and exits 0 — matching the observed behavior in cold-adopter smoke.
set -eu

PROMPT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p) PROMPT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$PROMPT" in
  /*)
    echo "Unknown command: $PROMPT"
    exit 0
    ;;
  *)
    # Natural-language prompt — pretend to work
    echo "mock claude — natural-language prompt received, but this mock always no-ops"
    exit 0
    ;;
esac
