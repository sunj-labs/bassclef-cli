#!/usr/bin/env bash
# tier: upstream
#
# smoke-assert-settings-hooks.sh — verify every hook path wired in
# .claude/settings.json exists on disk.
#
# Closes bassclef-cli#160 blind spot — sync installs hooks that fail
# ("8 could not be installed") and settings.json still wires them.
# Every bash tool call in the adopter session then errors with
# "No such file or directory" on those hooks.
#
# Flags:
#   --settings FILE   settings.json to check (default: .claude/settings.json)
#   --json OUT        write JSON summary to OUT
#   --help            print this help
#
# Exit codes:
#   0  all wired hooks exist on disk
#   1  usage or config error
#   3  one or more hooks wired in settings do not exist on disk

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
echo ">>> ${SCRIPT_NAME} starting" >&2
trap 'echo "<<< ${SCRIPT_NAME} done (exit $?)" >&2' EXIT

SETTINGS_FILE=".claude/settings.json"
JSON_OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --settings) SETTINGS_FILE="$2"; shift 2 ;;
    --json) JSON_OUT="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "${SCRIPT_NAME}: settings file not found: $SETTINGS_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "${SCRIPT_NAME}: jq required but not on PATH" >&2
  exit 1
fi

# Extract every hook command path (recursively under hooks tree).
# jq walks all events (PreToolUse, PostToolUse, SessionStart, Stop, etc.)
# and pulls every command field.
RAW_PATHS=()
while IFS= read -r _line; do
  RAW_PATHS+=("$_line")
done < <(jq -r '.hooks // {} | .. | objects | select(has("command")) | .command' "$SETTINGS_FILE" 2>/dev/null | sort -u)

if [ "${#RAW_PATHS[@]}" -eq 0 ]; then
  echo "${SCRIPT_NAME}: no hook command entries in $SETTINGS_FILE" >&2
  # emit empty JSON if requested
  if [ -n "$JSON_OUT" ]; then
    printf '{"check":"settings-hooks-present","total":0,"missing":[],"status":"PASS"}\n' > "$JSON_OUT"
  fi
  exit 0
fi

# Resolve each path against runtime env vars.
# $HOME → adopter's home
# $CLAUDE_PROJECT_DIR → project root (default to current dir if unset)
: "${CLAUDE_PROJECT_DIR:=$PWD}"

MISSING=()
TOTAL=0

for raw in "${RAW_PATHS[@]}"; do
  # Skip empty and pure-bash-command entries (rare — most hooks are script paths)
  [ -z "$raw" ] && continue
  TOTAL=$((TOTAL + 1))

  # Expand env vars
  resolved="${raw//\$HOME/$HOME}"
  resolved="${resolved//\$CLAUDE_PROJECT_DIR/$CLAUDE_PROJECT_DIR}"

  if [ ! -f "$resolved" ]; then
    MISSING+=("$raw → $resolved")
  fi
done

# Emit human summary
echo ""
echo "settings.json: $SETTINGS_FILE"
echo "hooks wired: $TOTAL"
echo "hooks missing on disk: ${#MISSING[@]}"

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo ""
  echo "MISSING HOOKS:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
fi

# Emit JSON summary if requested
if [ -n "$JSON_OUT" ]; then
  STATUS="PASS"
  [ "${#MISSING[@]}" -gt 0 ] && STATUS="FAIL"
  # Build missing[] JSON
  MISSING_JSON=$(printf '%s\n' "${MISSING[@]}" 2>/dev/null | jq -R . 2>/dev/null | jq -s . 2>/dev/null || printf '[]')
  jq -n \
    --arg check "settings-hooks-present" \
    --argjson total "$TOTAL" \
    --argjson missing "$MISSING_JSON" \
    --arg status "$STATUS" \
    '{check: $check, total: $total, missing: $missing, status: $status}' \
    > "$JSON_OUT"
fi

# Exit code
if [ "${#MISSING[@]}" -gt 0 ]; then
  exit 3
fi
exit 0
