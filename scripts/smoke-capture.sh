#!/usr/bin/env bash
# tier: upstream
#
# smoke-capture.sh — capture per-hook SessionStart output for a cold-adopter
# smoke run of @thebassclef/lite.
#
# Runs from a directory where `bassclef init` has already fired. Reads
# `.claude/settings.json` to enumerate wired SessionStart hooks. Fires each
# hook with the harness's expected stdin shape, captures stdout + stderr
# per hook to `docs/smoke-captures/<ISO-date>/hooks/<hook-basename>.out`.
#
# Design refs (must-read):
#   docs/specs/smoke-evidence-capture.md          — script interface contract
#   docs/use-cases/UC-smoke-run.md                — main flow Step 8
#   docs/decompositions/smoke-evidence-capture.md — SmokeCapture entity
#
# Pre-mortem folds baked in:
#   V2 (Vogels) — df check before write; fail-fast if under 500MB free
#
# Exit codes:
#   0  capture complete for at least 1 hook
#   1  usage or config error
#   2  no wired SessionStart hooks found in .claude/settings.json
#   3  disk full (V2 fold)
#
# Flags:
#   --dry-run       print what would run; write nothing
#   --settings FILE point at a settings.json other than .claude/settings.json
#                   (used by the Tier 0 test)
#   --out DIR       write captures under DIR instead of docs/smoke-captures/<date>/
#                   (used by the Tier 0 test)
#   --help          print this help

set -euo pipefail

# --- defaults -----------------------------------------------------------------

SETTINGS_FILE=".claude/settings.json"
OUT_ROOT=""
DRY_RUN=0
MIN_FREE_MB=500

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# --- arg parse ----------------------------------------------------------------

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --settings) SETTINGS_FILE="$2"; shift 2 ;;
    --out) OUT_ROOT="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --- preconditions ------------------------------------------------------------

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "smoke-capture: settings file not found at $SETTINGS_FILE" >&2
  echo "hint: run bassclef init in this directory first" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "smoke-capture: jq is required" >&2; exit 1; }

# V2 fold — df check before write
free_mb=$(df -m . | awk 'NR==2 {print $4}')
if [ -n "$free_mb" ] && [ "$free_mb" -lt "$MIN_FREE_MB" ]; then
  echo "smoke-capture: less than ${MIN_FREE_MB}MB free on $(pwd); refusing to run" >&2
  echo "  available: ${free_mb}MB" >&2
  exit 3
fi

# --- compute output dir -------------------------------------------------------

ISO_DATE=$(date -u +"%Y-%m-%d")
if [ -z "$OUT_ROOT" ]; then
  OUT_ROOT="docs/smoke-captures/${ISO_DATE}/hooks"
fi

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$OUT_ROOT"
fi

# --- enumerate SessionStart hooks ---------------------------------------------

# Shape: hooks.SessionStart[].hooks[].command  (per Claude Code settings.json)
# Bash 3.2 compatible — no mapfile.
HOOK_CMDS_RAW=$(jq -r '.hooks.SessionStart[]?.hooks[]?.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

if [ -z "$HOOK_CMDS_RAW" ]; then
  echo "smoke-capture: no wired SessionStart hooks in $SETTINGS_FILE" >&2
  exit 2
fi

# Count hooks by line
HOOK_COUNT=$(printf '%s\n' "$HOOK_CMDS_RAW" | grep -c .)

echo "smoke-capture: found ${HOOK_COUNT} SessionStart hook(s)" >&2
echo "smoke-capture: writing captures under $OUT_ROOT" >&2

# --- fire each hook -----------------------------------------------------------

# The harness feeds hooks a JSON payload on stdin with cwd + other fields.
# Minimal payload for smoke: cwd only. Extend if a hook needs more.
STDIN_PAYLOAD=$(jq -n --arg cwd "$PWD" '{cwd: $cwd}')

fired=0
while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue

  # Basename the last path token in the command so multiple hooks don't collide.
  # e.g. "bash /path/to/session-reflection.sh" -> "session-reflection"
  last_token=$(printf '%s' "$cmd" | awk '{print $NF}')
  hook_slug=$(basename "$last_token" .sh)

  # Sanitize slug — replace / and space with -
  hook_slug=$(printf '%s' "$hook_slug" | tr ' /' '--')

  out_file="${OUT_ROOT}/${hook_slug}.out"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would run: $cmd" >&2
    echo "would write: $out_file" >&2
    continue
  fi

  # Fire the hook. Capture stdout + stderr merged into the .out file.
  # Also capture exit code so downstream assertions can distinguish CRASH.
  # set -e temporarily off around the eval so a non-zero exit does not
  # abort the script mid-capture.
  {
    echo "=== command: $cmd"
    echo "=== stdin: $STDIN_PAYLOAD"
    echo "=== output ==="
    set +e
    printf '%s' "$STDIN_PAYLOAD" | eval "$cmd" 2>&1
    exit_code=$?
    set -e
    echo "=== exit: $exit_code"
  } > "$out_file"

  fired=$((fired + 1))
done <<< "$HOOK_CMDS_RAW"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "smoke-capture: dry run complete for ${HOOK_COUNT} hook(s)" >&2
  exit 0
fi

echo "smoke-capture: captured $fired hook(s) to $OUT_ROOT" >&2
exit 0
