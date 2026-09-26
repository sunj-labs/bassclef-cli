#!/usr/bin/env bash
# tier: standard
# fake_claude.sh — deterministic stand-in for interactive `claude` process.
#
# Used by scripts/tests/smoke-expect.test.sh to characterize
# scripts/lib/smoke-expect.sh without requiring the real claude binary
# or claude auth. `expect` cannot tell this fixture from a real REPL.
#
# Behavior:
#   - Emits "READY>" on startup (drive_expect can wait for this).
#   - Reads stdin one line at a time.
#   - Emits "RESP: <text>" for each input line.
#   - Emits "DONE>" when stdin closes (EOF).
#
# Env-var knobs (per pre-mortem F8 + S5 folds):
#   SMOKE_FAKE_LATENCY_SEC=N     — sleep N seconds before each response
#   SMOKE_FAKE_EXIT_ON=<phrase>  — exit 0 immediately when input matches
#   SMOKE_FAKE_STARTUP_DELAY=N   — sleep N seconds before READY> prompt

set -u
# Note: no `set -e` — read on EOF returns 1; that's the exit signal.

startup_delay="${SMOKE_FAKE_STARTUP_DELAY:-0}"
latency="${SMOKE_FAKE_LATENCY_SEC:-0}"
exit_on="${SMOKE_FAKE_EXIT_ON:-}"

if [ "$startup_delay" -gt 0 ] 2>/dev/null; then
  sleep "$startup_delay"
fi

printf 'READY>\n'

while IFS= read -r line; do
  if [ -n "$exit_on" ] && [ "$line" = "$exit_on" ]; then
    printf 'BYE>\n'
    exit 0
  fi
  if [ "$latency" -gt 0 ] 2>/dev/null; then
    sleep "$latency"
  fi
  printf 'RESP: %s\n' "$line"
done

printf 'DONE>\n'
exit 0
