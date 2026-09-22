#!/usr/bin/env bash
# tier: standard
# smoke-drive-onboard-repo — drives /onboard-repo in a fresh scratch dir.
#
# Runs AFTER the 5-skill V2 drive per operator ask (2026-09-20 wrap).
# /onboard-repo has side effects (writes .claude/settings.json + docs/whereami.md +
# CLAUDE.md + .bassclef-source.json). Cannot ride the shared /adopter/test dir the
# 5-skill drive uses. Owns its own setup + drive + assert + teardown.
#
# Contract:
#   - Fresh git repo at $ADOPTER_HOME/onboard-test (default) or $ONBOARD_SCRATCH
#   - claude -p "/onboard-repo" with a 180s timeout (longer than the 120s per skill
#     in smoke-drive-skills — /onboard-repo runs more sub-actions)
#   - Captures stdout+stderr to $OUT_ROOT/onboard-repo.out
#   - Asserts .claude/settings.json exists after the run
#   - Teardown removes the scratch dir on success OR on failure
#     (pass --keep-scratch to preserve for debugging)
#
# Exit codes:
#   0 — skill fired + .claude/settings.json landed
#   3 — skill fired but expected artifact missing (assertion fail)
#   5 — skill exceeded 180s timeout (SIGALRM 142 → mapped to 5)
#   127 — claude binary not found
#   1 — other setup failure
#
# ENV:
#   CLAUDE_BIN              — override binary path (default: claude)
#   ONBOARD_SCRATCH         — override scratch dir (default: $HOME/onboard-test)
#   ONBOARD_TIMEOUT_SEC     — override timeout (default: 180)
#   OUT_ROOT                — output dir (default: derived from date)
#
# Refs:
#   - scripts/smoke-drive-skills.sh — sibling drive script (5-skill V2)
#   - harness/docker/entry.sh — wires this script as V2 step 6

set -e

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
TIMEOUT_SEC="${ONBOARD_TIMEOUT_SEC:-180}"
SCRATCH_DIR="${ONBOARD_SCRATCH:-${HOME:-/tmp}/onboard-test}"
KEEP_SCRATCH=0
OUT_ROOT="${OUT_ROOT:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) OUT_ROOT="$2"; shift 2 ;;
    --claude) CLAUDE_BIN="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --scratch) SCRATCH_DIR="$2"; shift 2 ;;
    --keep-scratch) KEEP_SCRATCH=1; shift ;;
    --help|-h) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Preconditions
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || {
  echo "smoke-drive-onboard-repo: claude binary not found: $CLAUDE_BIN" >&2
  exit 127
}
command -v perl >/dev/null 2>&1 || {
  echo "smoke-drive-onboard-repo: perl required for timeout wrapper" >&2
  exit 1
}
command -v git >/dev/null 2>&1 || {
  echo "smoke-drive-onboard-repo: git required for scratch repo init" >&2
  exit 1
}

# Resolve output dir
ISO_DATE=$(date -u +"%Y-%m-%d")
[ -z "$OUT_ROOT" ] && OUT_ROOT="docs/smoke-captures/${ISO_DATE}/onboard"
mkdir -p "$OUT_ROOT"

OUT_FILE="${OUT_ROOT}/onboard-repo.out"

# Teardown closure — runs on any exit path so scratch never leaks
teardown() {
  local rc=$?
  cd / 2>/dev/null || true
  if [ "$KEEP_SCRATCH" -eq 0 ] && [ -d "$SCRATCH_DIR" ]; then
    rm -rf "$SCRATCH_DIR" 2>/dev/null || true
  fi
  exit "$rc"
}
trap teardown EXIT INT TERM

# Setup — fresh scratch dir, fresh git repo
echo "smoke-drive-onboard-repo: scratch dir ${SCRATCH_DIR}" >&2
rm -rf "$SCRATCH_DIR"
mkdir -p "$SCRATCH_DIR"
cd "$SCRATCH_DIR"
git init -q
git config user.email "onboard-smoke@harness.local"
git config user.name "Onboard Smoke Harness"

# Drive — fire /onboard-repo with alarm-based timeout, capture stdout+stderr
echo "smoke-drive-onboard-repo: firing /onboard-repo (timeout ${TIMEOUT_SEC}s)" >&2

exit_code=0
{
  echo "=== skill: /onboard-repo"
  echo "=== claude_bin: ${CLAUDE_BIN}"
  echo "=== timeout_sec: ${TIMEOUT_SEC}"
  echo "=== scratch_dir: ${SCRATCH_DIR}"
  echo "=== output ==="
  set +e
  perl -e '
    my ($t, @cmd) = @ARGV;
    $SIG{ALRM} = sub { exit 142 };
    alarm $t;
    exec @cmd or exit 127
  ' "$TIMEOUT_SEC" "$CLAUDE_BIN" -p "run the /onboard-repo skill on this repo. show me the output." < /dev/null 2>&1
  exit_code=$?
  set -e
  echo "=== exit: ${exit_code}"
} > "$OUT_FILE"

# Map timeout to a distinct exit code (per exit-codes.sh EXIT_SKILL_TIMEOUT=5)
if [ "$exit_code" -eq 142 ]; then
  echo "smoke-drive-onboard-repo: TIMEOUT — /onboard-repo exceeded ${TIMEOUT_SEC}s" >&2
  echo "capture: ${OUT_FILE}" >&2
  exit 5
fi

if [ "$exit_code" -ne 0 ]; then
  echo "smoke-drive-onboard-repo: skill exited ${exit_code}; see ${OUT_FILE}" >&2
  exit "$exit_code"
fi

# Assert — /onboard-repo's stated behavior includes scaffolding config
if [ ! -f "$SCRATCH_DIR/.claude/settings.json" ]; then
  echo "smoke-drive-onboard-repo: ASSERTION FAIL — .claude/settings.json missing after /onboard-repo" >&2
  echo "capture: ${OUT_FILE}" >&2
  echo "scratch contents:" >&2
  ls -la "$SCRATCH_DIR" >&2 2>&1 || true
  exit 3
fi

echo "smoke-drive-onboard-repo: PASS — /onboard-repo fired + .claude/settings.json landed" >&2
echo "capture: ${OUT_FILE}" >&2
exit 0
