#!/usr/bin/env bash
# tier: upstream
#
# smoke-assert-skills.sh — run 4 checks per skill capture and emit
# skills-assertions.json.
#
# Design refs (must-read):
#   docs/specs/smoke-evidence-capture.md § Interfaces § smoke-assert-skills.sh
#   docs/use-cases/UC-smoke-run.md § Main flow Step 14 + Extension 13b
#   docs/decompositions/smoke-evidence-capture.md § AssertionSuite (Control)
#
# Pre-mortem folds baked in:
#   F4 (Fowler) — shared assertion contract in lib/smoke-assert.sh
#   F6 (Fowler) — shared schema in lib/smoke-schema.sh
#
# Flags:
#   --capture-dir DIR       read captures from DIR (default: docs/smoke-captures/<date>/skills)
#   --out FILE              write JSON to FILE (default: docs/smoke-captures/<date>/skills-assertions.json)
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

SCRIPT_NAME="$(basename "$0" .sh)"
echo ">>> ${SCRIPT_NAME} starting" >&2
trap 'echo "<<< ${SCRIPT_NAME} done (exit $?)" >&2' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/smoke-schema.sh
source "${SCRIPT_DIR}/lib/smoke-schema.sh"
# shellcheck source=lib/smoke-assert.sh
source "${SCRIPT_DIR}/lib/smoke-assert.sh"

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
[ -z "$CAPTURE_DIR" ] && CAPTURE_DIR="docs/smoke-captures/${ISO_DATE}/skills"
[ -z "$OUT_FILE" ] && OUT_FILE="$(dirname "$CAPTURE_DIR")/skills-assertions.json"

# --only validation
if [ -n "$ONLY_CHECK" ]; then
  case "$ONLY_CHECK" in
    no-not-found|no-silent-skip|no-unexpected-blocked|paths-exist|no-timeout|no-crash|no-unknown-command) ;;
    *) echo "smoke-assert-skills: unknown check '$ONLY_CHECK'" >&2; exit 1 ;;
  esac
  OUT_FILE="$(dirname "$OUT_FILE")/skills-assertions-${ONLY_CHECK}.json"
fi

# preconditions
if [ ! -d "$CAPTURE_DIR" ]; then
  echo "smoke-assert-skills: capture dir not found at $CAPTURE_DIR" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "smoke-assert-skills: jq is required" >&2; exit 1; }

# enumerate capture files
CAPTURE_FILES=$(find "$CAPTURE_DIR" -maxdepth 1 -type f -name '*.out' 2>/dev/null | sort || echo "")

if [ -z "$CAPTURE_FILES" ]; then
  echo "smoke-assert-skills: no capture files in $CAPTURE_DIR" >&2
  exit 2
fi

# checks list
# no-unknown-command added per cli #217 — catches `claude -p "/slashname"`
# regression to CLI slash-command dispatch (returns "Unknown command:" and
# exit 0; falls through every existing negative check).
if [ -n "$ONLY_CHECK" ]; then
  CHECKS="$ONLY_CHECK"
else
  CHECKS="no-not-found
no-silent-skip
no-unexpected-blocked
paths-exist
no-timeout
no-crash
no-unknown-command"
fi

# Per-skill positive-artifact checks — cli #217 cure. Keyed on the
# capture filename (basename minus .out); each key maps to a check
# function that fires ONLY on the matching capture.
#
# The generic checks above catch failures orthogonally (crash, timeout,
# unknown command). These per-skill checks confirm the skill actually
# produced its declared side-effect — a marker file or a phrase in output.
per_skill_check_fn() {
  local hook_name="$1"
  case "$hook_name" in
    temperance)               echo "check_temperance_marker" ;;
    luminary-don-norman)      echo "check_luminary_norman_artifact" ;;
    kiss-words-this-is-verbose-corporate-sounding-text) echo "check_kiss_words_artifact" ;;
    state-a-problem-brief-a-sample-problem-for-the-smoke-run) echo "check_state_a_problem_artifact" ;;
    whats-the-plan)           echo "check_whats_the_plan_artifact" ;;
    *) echo "" ;;
  esac
}

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

  # Per-skill positive-artifact check (cli #217 cure). Fires only when:
  #  - SMOKE_PER_SKILL_CHECKS=1 in env (opt-in; keeps existing tests green)
  #  - --only was not passed
  #  - the capture filename matches a known skill in the per-skill map
  # Workdir for filesystem-based asserts is the parent of $CAPTURE_DIR —
  # captures live at $workdir/docs/smoke-captures/<date>/skills/*.out and
  # markers land at $workdir/state/markers/temperance/*.marker.
  skill_fn=""
  if [ "${SMOKE_PER_SKILL_CHECKS:-0}" = "1" ]; then
    skill_fn=$(per_skill_check_fn "$hook_name")
  fi
  if [ -n "$skill_fn" ] && [ -z "$ONLY_CHECK" ]; then
    workdir=$(cd "$CAPTURE_DIR/../../.." 2>/dev/null && pwd || echo ".")
    set +e
    result=$("$skill_fn" "$cap" "$workdir")
    rc=$?
    set -e
    check_name=$(printf '%s' "$result" | awk -F'|' '{print $2}')
    status_field=$(printf '%s' "$result" | awk -F'|' '{print $1}')
    msg_field=$(printf '%s' "$result" | awk -F'|' '{print $3}')
    assertion_result_json "$hook_name" "$check_name" "$status_field" "$msg_field" "$cap" >> "${OUT_FILE}.tmp"
    if [ "$rc" -ne 0 ]; then
      any_fail=1
    fi
  fi
done <<< "$CAPTURE_FILES"

# wrap into JSON array
jq -s '.' "${OUT_FILE}.tmp" > "$OUT_FILE"
rm -f "${OUT_FILE}.tmp"

echo "smoke-assert-skills: wrote $OUT_FILE" >&2
if [ "$any_fail" -eq 1 ]; then
  exit 3
fi
exit 0
