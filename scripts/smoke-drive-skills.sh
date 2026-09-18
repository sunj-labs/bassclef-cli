#!/usr/bin/env bash
# tier: upstream
#
# smoke-drive-skills.sh — fire 5 skills through `claude -p` and capture
# each response to its own file.
#
# Design refs (must-read):
#   docs/specs/smoke-evidence-capture.md § Interfaces § smoke-drive-skills.sh
#   docs/use-cases/UC-smoke-run.md § Main flow Step 12 + Extensions 11a + 11b
#   docs/decompositions/smoke-evidence-capture.md § SkillDriver (Control)
#   docs/risk-ledgers/2026-09-18-smoke-evidence-capture-pre-mortem.md V1
#
# Pre-mortem folds baked in:
#   V1 (Vogels) — exit code captured separately so downstream assertion
#                 can write CRASH row on non-zero-non-timeout exit
#
# Flags:
#   --out DIR              write captures under DIR (default: docs/smoke-captures/<date>/skills)
#   --skill-list-file F    read skill list from F (one skill per line)
#                          default list: temperance, luminary don-norman, kiss words,
#                          state-a-problem brief, whats-the-plan
#   --claude BIN           use BIN instead of `claude` (used by tests with a mock)
#   --timeout N            per-skill timeout in seconds (default 30)
#   --dry-run              print the plan; write nothing
#   --help                 print this help
#
# Exit codes:
#   0  drive complete for all skills (regardless of individual exit codes)
#   1  usage or config error
#   2  claude binary not on PATH (or --claude points at a missing file)

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
echo ">>> ${SCRIPT_NAME} starting" >&2
trap 'echo "<<< ${SCRIPT_NAME} done (exit $?)" >&2' EXIT

OUT_ROOT=""
SKILL_LIST_FILE=""
CLAUDE_BIN="claude"
TIMEOUT_SEC=120
DRY_RUN=0

# Default skill list per spec § Acceptance item 4.
DEFAULT_SKILLS='/temperance
/luminary don-norman
/kiss words this is verbose corporate-sounding text
/state-a-problem brief a sample problem for the smoke run
/whats-the-plan'

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) OUT_ROOT="$2"; shift 2 ;;
    --skill-list-file) SKILL_LIST_FILE="$2"; shift 2 ;;
    --claude) CLAUDE_BIN="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# preconditions
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  echo "smoke-drive-skills: claude binary not found: $CLAUDE_BIN" >&2
  exit 2
fi

command -v perl >/dev/null 2>&1 || { echo "smoke-drive-skills: perl required for timeout wrapper" >&2; exit 1; }

# resolve skill list
if [ -n "$SKILL_LIST_FILE" ]; then
  [ -f "$SKILL_LIST_FILE" ] || { echo "smoke-drive-skills: skill list file not found: $SKILL_LIST_FILE" >&2; exit 1; }
  SKILLS=$(cat "$SKILL_LIST_FILE")
else
  SKILLS="$DEFAULT_SKILLS"
fi

# resolve output dir
ISO_DATE=$(date -u +"%Y-%m-%d")
[ -z "$OUT_ROOT" ] && OUT_ROOT="docs/smoke-captures/${ISO_DATE}/skills"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$OUT_ROOT"
fi

skill_count=$(printf '%s\n' "$SKILLS" | grep -c . || echo 0)
echo "smoke-drive-skills: driving ${skill_count} skill(s) via ${CLAUDE_BIN}" >&2

fired=0
while IFS= read -r skill; do
  [ -z "$skill" ] && continue

  # Slug from the first token (e.g. "/luminary don-norman" -> "luminary-don-norman")
  skill_slug=$(printf '%s' "$skill" | sed 's|^/||' | tr ' ' '-')
  out_file="${OUT_ROOT}/${skill_slug}.out"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would run: ${CLAUDE_BIN} -p \"${skill}\"" >&2
    echo "would write: ${out_file}" >&2
    continue
  fi

  # Perl alarm-based timeout wrapper.
  # Exit 142 (128+14, SIGALRM) when the alarm fires. Any other non-zero is
  # the skill's own exit; downstream assertion suite writes CRASH row.
  {
    echo "=== skill: ${skill}"
    echo "=== claude_bin: ${CLAUDE_BIN}"
    echo "=== timeout_sec: ${TIMEOUT_SEC}"
    echo "=== output ==="
    exit_code=0
    set +e
    perl -e '
      my ($t, @cmd) = @ARGV;
      $SIG{ALRM} = sub { exit 142 };
      alarm $t;
      exec @cmd or exit 127
    ' "$TIMEOUT_SEC" "$CLAUDE_BIN" -p "$skill" 2>&1
    exit_code=$?
    set -e
    echo "=== exit: ${exit_code}"
  } > "$out_file"

  fired=$((fired + 1))
done <<< "$SKILLS"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "smoke-drive-skills: dry run complete (${skill_count} skills)" >&2
  exit 0
fi

echo "smoke-drive-skills: captured ${fired} skill(s) to ${OUT_ROOT}" >&2
exit 0
