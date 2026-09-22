#!/usr/bin/env bash
# tier: upstream
#
# smoke-drive-skills.sh — fire 5 skills through `claude -p` and capture
# each response to its own file.
#
# Drive uses NATURAL-LANGUAGE prompts (cli #217 cure) — the prompt names
# the skill by /slashname inside a full-sentence request. `claude -p` in
# headless mode routes bare leading-slash strings to Claude Code's own
# CLI matcher (returns "Unknown command:"). Natural language routes to the
# LLM, which reads the skill body from disk and dispatches the Skill tool.
# Real adopters type /X interactively; this is the closest -p-mode proxy.
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
# Kept as leading-slash form for backward compat (RFC L1 fold — downstream
# consumers may hardcode this list). The invocation site wraps each entry
# in a natural-language prompt template (cli #217 cure).
DEFAULT_SKILLS='/temperance
/luminary don-norman
/kiss words this is verbose corporate-sounding text
/state-a-problem brief a sample problem for the smoke run
/whats-the-plan'

# Natural-language prompt template — the cli #217 cure.
#
# `claude -p "/slashname"` routes to Claude Code's CLI slash-command matcher
# and returns "Unknown command:" — never dispatches the Skill tool. Real
# adopters type /X interactively; the Skill tool then dispatches. In `-p`
# mode we approximate that path by sending a natural-language prompt that
# names the skill; Claude reads the skill body from disk and dispatches.
#
# Per-skill template map — concrete scenarios per docs/decompositions/
# 2026-09-22c-cli-217-drive-shape-cure.md § Prompt template.
# Pre-mortem C1 fold: each prompt fully specifies the input so the LLM
# cannot ask a clarifying question.
build_nl_prompt() {
  local slash_form="$1"
  case "$slash_form" in
    "/temperance")
      printf '%s' "run the /temperance skill for the scope decision 'add a login button to a test app'. show me the output."
      ;;
    "/luminary don-norman")
      printf '%s' "run the /luminary skill for don-norman and show me the lens summary."
      ;;
    "/kiss words"*)
      printf '%s' "use the /kiss skill in words mode to rewrite this verbose corporate text: \"It has come to our attention that stakeholders would benefit from more granular reporting cadence\". show me the output."
      ;;
    "/state-a-problem brief"*)
      printf '%s' "use the /state-a-problem skill in brief mode to draft a problem statement for: 'session-start hooks fire twice on cold-adopter installs'. show me the output."
      ;;
    "/whats-the-plan")
      printf '%s' "use the /whats-the-plan skill to declare a chain for shipping a login button to a test app. show me the output."
      ;;
    /*)
      # Generic fallback for any other slash-prefixed skill in a custom list.
      # RFC N2 fold: help text calls this out; adopters using interactive
      # /X still work — this drive is a proxy for smoke-time assertion.
      printf '%s' "run the ${slash_form} skill and show me the output."
      ;;
    *)
      # Not a slash-prefixed entry — pass through verbatim.
      printf '%s' "$slash_form"
      ;;
  esac
}

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

  # Natural-language prompt build (cli #217 cure) — see build_nl_prompt above.
  nl_prompt=$(build_nl_prompt "$skill")

  # Perl alarm-based timeout wrapper.
  # Exit 142 (128+14, SIGALRM) when the alarm fires. Any other non-zero is
  # the skill's own exit; downstream assertion suite writes CRASH row.
  #
  # Stdin cure (2026-09-20d): the outer while loop uses `<<< "$SKILLS"` as
  # a here-string. Without redirecting the child's stdin, `claude -p`
  # inherits and consumes it — the loop then reads EOF after 1 iteration
  # and only 1 skill fires. `< /dev/null` on the perl call closes the
  # child stdin so the here-string stays intact for the outer read.
  {
    echo "=== skill: ${skill}"
    echo "=== nl_prompt: ${nl_prompt}"
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
    ' "$TIMEOUT_SEC" "$CLAUDE_BIN" -p "$nl_prompt" < /dev/null 2>&1
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
