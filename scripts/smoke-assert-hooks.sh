#!/usr/bin/env bash
# tier: upstream
#
# smoke-assert-hooks.sh — run 4 checks per hook capture and emit
# hooks-assertions.json.
#
# Design refs (must-read):
#   docs/specs/smoke-evidence-capture.md § Interfaces § smoke-assert-hooks.sh
#   docs/use-cases/UC-smoke-run.md § Main flow Step 10 + Extension 9a + 9b
#   docs/decompositions/smoke-evidence-capture.md § AssertionSuite (Control)
#
# Pre-mortem folds baked in:
#   F4 (Fowler) — shared assertion contract in lib/smoke-assert.sh
#   F6 (Fowler) — shared schema in lib/smoke-schema.sh
#
# Flags:
#   --capture-dir DIR       read captures from DIR (default: docs/smoke-captures/<date>/hooks)
#   --out FILE              write JSON to FILE (default: docs/smoke-captures/<date>/hooks-assertions.json)
#   --only CHECK            run only that check (RFC F2 fold — Operator-Diagnose)
#                           CHECK is one of: no-not-found, no-silent-skip,
#                           no-unexpected-blocked, paths-exist
#   --allowlist-dir DIR     per-check allowlist files at DIR/<check>.txt
#   --help                  print this help
#
# Exit codes:
#   0  all checks pass
#   1  usage or config error
#   2  no capture files in --capture-dir
#   3  one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/smoke-schema.sh
source "${SCRIPT_DIR}/../lib/smoke-schema.sh"
# shellcheck source=../lib/smoke-assert.sh
source "${SCRIPT_DIR}/../lib/smoke-assert.sh"

CAPTURE_DIR=""
OUT_FILE=""
ONLY_CHECK=""
ALLOWLIST_DIR=""

usage() {
  sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --capture-dir) CAPTURE_DIR="$2"; shift 2 ;;
    --out) OUT_FILE="$2"; shift 2 ;;
    --only) ONLY_CHECK="$2"; shift 2 ;;
    --allowlist-dir) ALLOWLIST_DIR="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

ISO_DATE=$(date -u +"%Y-%m-%d")
[ -z "$CAPTURE_DIR" ] && CAPTURE_DIR="docs/smoke-captures/${ISO_DATE}/hooks"
[ -z "$OUT_FILE" ] && OUT_FILE="$(dirname "$CAPTURE_DIR")/hooks-assertions.json"

# --only validation
if [ -n "$ONLY_CHECK" ]; then
  case "$ONLY_CHECK" in
    no-not-found|no-silent-skip|no-unexpected-blocked|paths-exist) ;;
    *) echo "smoke-assert-hooks: unknown check '$ONLY_CHECK'" >&2; exit 1 ;;
  esac
  OUT_FILE="$(dirname "$OUT_FILE")/hooks-assertions-${ONLY_CHECK}.json"
fi

# preconditions
if [ ! -d "$CAPTURE_DIR" ]; then
  echo "smoke-assert-hooks: capture dir not found at $CAPTURE_DIR" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "smoke-assert-hooks: jq is required" >&2; exit 1; }

# enumerate capture files
CAPTURE_FILES=$(find "$CAPTURE_DIR" -maxdepth 1 -type f -name '*.out' 2>/dev/null | sort || echo "")

if [ -z "$CAPTURE_FILES" ]; then
  echo "smoke-assert-hooks: no capture files in $CAPTURE_DIR" >&2
  exit 2
fi

# checks list
if [ -n "$ONLY_CHECK" ]; then
  CHECKS="$ONLY_CHECK"
else
  CHECKS="no-not-found
no-silent-skip
no-unexpected-blocked
paths-exist"
fi

# accumulate
mkdir -p "$(dirname "$OUT_FILE")"
: > "${OUT_FILE}.tmp"

any_fail=0
while IFS= read -r cap; do
  [ -z "$cap" ] && continue
  hook_name=$(basename "$cap" .out)
  while IFS= read -r check; do
    [ -z "$check" ] && continue
    allowlist_file=""
    if [ -n "$ALLOWLIST_DIR" ] && [ -f "${ALLOWLIST_DIR}/${check}.txt" ]; then
      allowlist_file="${ALLOWLIST_DIR}/${check}.txt"
    fi
    fn="check_${check//-/_}"
    set +e
    result=$("$fn" "$cap" "$allowlist_file")
    rc=$?
    set -e
    status_field=$(printf '%s' "$result" | awk -F'|' '{print $1}')
    msg_field=$(printf '%s' "$result" | awk -F'|' '{print $3}')
    assertion_result_json "$hook_name" "$check" "$status_field" "$msg_field" "$cap" >> "${OUT_FILE}.tmp"
    if [ "$rc" -ne 0 ]; then
      any_fail=1
    fi
  done <<< "$CHECKS"
done <<< "$CAPTURE_FILES"

# wrap into JSON array
jq -s '.' "${OUT_FILE}.tmp" > "$OUT_FILE"
rm -f "${OUT_FILE}.tmp"

echo "smoke-assert-hooks: wrote $OUT_FILE" >&2
if [ "$any_fail" -eq 1 ]; then
  exit 3
fi
exit 0
