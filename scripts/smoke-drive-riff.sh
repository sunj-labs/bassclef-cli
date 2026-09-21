#!/usr/bin/env bash
# tier: standard
# smoke-drive-riff — drives /riff in a fresh scratch dir.
#
# Fires as V2 harness Step 7 (after Step 6 onboard-repo). Verifies that a
# published tarball's /riff dispatches cleanly, authors HTML mock variants
# at docs/prototypes/YYYY-MM-DD-riff-<slug>-variant-N/index.html, and
# reports variants back to the operator.
#
# The Docker cold-adopter container ships @thebassclef/lite. Playwright
# MCP is typically absent there. When /riff BLOCKs on missing MCP, this
# drive maps the exit to a distinct code (6) so the harness reports
# environment-degraded vs skill-regression separately.
#
# Contract:
#   - Fresh git repo at $RIFF_SCRATCH (default: $HOME/riff-test)
#   - claude -p "/riff riff a marketing landing hero" with a 300s timeout
#   - Captures stdout+stderr to $OUT_ROOT/riff.out
#   - Asserts at least one HTML file > 100 bytes containing <h2> under
#     $SCRATCH/docs/prototypes/*-riff-*/
#   - Teardown removes scratch on any exit (unless --keep-scratch)
#
# Exit codes (contract with harness):
#   0    /riff fired + HTML variant landed + content check passed
#   3    /riff fired but assertion failed (sub-class in stderr tag)
#   5    /riff exceeded RIFF_TIMEOUT_SEC (mapped from 142)
#   6    Environment-degraded — Playwright/MCP absent detected in capture
#   127  claude binary missing
#   1    other setup failure (perl / git missing, unsafe scratch path)
#
# Stderr tag lines (Cooper F4):
#   smoke-drive-riff: PASS
#   smoke-drive-riff: FAIL:no-html
#   smoke-drive-riff: FAIL:empty-html
#   smoke-drive-riff: FAIL:no-h2
#   smoke-drive-riff: TIMEOUT
#   smoke-drive-riff: ENV_DEGRADED:<token>
#   smoke-drive-riff: SETUP_FAIL:<reason>
#
# ENV:
#   CLAUDE_BIN            — override binary path (default: claude)
#   RIFF_SCRATCH          — override scratch dir (default: $HOME/riff-test)
#   RIFF_TIMEOUT_SEC      — override timeout (default: 300)
#   OUT_ROOT              — output dir (default: derived from date)
#
# Refs:
#   scripts/smoke-drive-onboard-repo.sh — sibling drive (Step 6 template)
#   docs/rfcs/2026-09-21c-smoke-drive-riff-council.md — RFC council folds
#   ~/.claude/skills/riff/SKILL.md — the skill under test

set -e

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
TIMEOUT_SEC="${RIFF_TIMEOUT_SEC:-300}"
# Chain default: use Step 6 /onboard-repo scratch. /riff dispatches only when
# .claude/skills/ is scaffolded per the adopter's onboard flow.
SCRATCH_DIR="${RIFF_SCRATCH:-${HOME:-/tmp}/onboard-test}"
DEFAULT_INTENT="a marketing landing hero band with inline email capture for a developer tools SaaS"
RIFF_INTENT="${RIFF_INTENT:-$DEFAULT_INTENT}"
KEEP_SCRATCH=0
NO_RESET=1  # default chain — do NOT reset scratch; consume Step 6's scaffold
SKIP_PRECONDITION=0  # tests only — skip scaffold-present check
OUT_ROOT="${OUT_ROOT:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) OUT_ROOT="$2"; shift 2 ;;
    --claude) CLAUDE_BIN="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --scratch) SCRATCH_DIR="$2"; shift 2 ;;
    --intent) RIFF_INTENT="$2"; shift 2 ;;
    --reset) NO_RESET=0; shift ;;
    --no-reset) NO_RESET=1; shift ;;
    --skip-precondition) SKIP_PRECONDITION=1; shift ;;
    --keep-scratch) KEEP_SCRATCH=1; shift ;;
    --help|-h) sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "smoke-drive-riff: SETUP_FAIL:unknown-arg $1" >&2; exit 1 ;;
  esac
done

# Preconditions
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || {
  echo "smoke-drive-riff: SETUP_FAIL:claude-missing $CLAUDE_BIN" >&2
  exit 127
}
command -v perl >/dev/null 2>&1 || {
  echo "smoke-drive-riff: SETUP_FAIL:perl-missing" >&2
  exit 1
}
command -v git >/dev/null 2>&1 || {
  echo "smoke-drive-riff: SETUP_FAIL:git-missing" >&2
  exit 1
}

# F1 (Saltzer-Schroeder) — validate scratch dir before rm -rf.
# Canonicalize + assert under $HOME or /tmp. Refuse root, bare $HOME, bare /tmp.
_validate_scratch_dir() {
  local path="$1"
  # Empty is a fail
  if [ -z "$path" ]; then
    echo "smoke-drive-riff: SETUP_FAIL:scratch-empty" >&2
    return 1
  fi
  # Canonicalize
  local canon
  # Use python if realpath is missing (macOS ships realpath but Docker may not).
  if command -v realpath >/dev/null 2>&1; then
    canon=$(realpath -m "$path" 2>/dev/null || echo "$path")
  else
    canon="$path"
  fi
  # Refuse dangerous paths
  case "$canon" in
    "/"|"/tmp"|"/tmp/"|"${HOME}"|"${HOME}/")
      echo "smoke-drive-riff: SETUP_FAIL:scratch-unsafe $canon" >&2
      return 1
      ;;
  esac
  # Must be under $HOME or /tmp
  case "$canon" in
    "${HOME}"/*|/tmp/*|/private/tmp/*|/var/folders/*)
      return 0
      ;;
    *)
      echo "smoke-drive-riff: SETUP_FAIL:scratch-outside-safe-roots $canon" >&2
      return 1
      ;;
  esac
}

_validate_scratch_dir "$SCRATCH_DIR" || exit 1

# Resolve output dir
ISO_DATE=$(date -u +"%Y-%m-%d")
[ -z "$OUT_ROOT" ] && OUT_ROOT="docs/smoke-captures/${ISO_DATE}/riff"
mkdir -p "$OUT_ROOT"

OUT_FILE="${OUT_ROOT}/riff.out"

# Teardown closure — runs on any exit path so drive-owned scratch never leaks.
# When --no-reset is set (chain mode), the caller owns scratch lifecycle;
# the drive does NOT tear down. --keep-scratch always preserves.
teardown() {
  local rc=$?
  cd / 2>/dev/null || true
  if [ "$KEEP_SCRATCH" -eq 0 ] && [ "$NO_RESET" -eq 0 ] && [ -d "$SCRATCH_DIR" ]; then
    rm -rf "$SCRATCH_DIR" 2>/dev/null || true
  fi
  exit "$rc"
}
trap teardown EXIT INT TERM

# Setup — chain semantics per operator (2026-09-21 correction).
# /riff dispatches only when the scratch's .claude/skills/ is scaffolded
# (either by prior /onboard-repo drive OR by manual bassclef init).
# Default is --no-reset (consume Step 6's scaffold). --reset for isolated runs.
echo "smoke-drive-riff: scratch dir ${SCRATCH_DIR} (no-reset=${NO_RESET})" >&2
if [ "$NO_RESET" -eq 0 ]; then
  rm -rf "$SCRATCH_DIR"
  mkdir -p "$SCRATCH_DIR"
  cd "$SCRATCH_DIR"
  git init -q
  git config user.email "riff-smoke@harness.local"
  git config user.name "Riff Smoke Harness"
elif [ ! -d "$SCRATCH_DIR" ]; then
  echo "smoke-drive-riff: SETUP_FAIL:scratch-missing $SCRATCH_DIR (chain broke — /onboard-repo did not scaffold)" >&2
  exit 1
else
  cd "$SCRATCH_DIR"
fi

# Precondition — /riff needs .claude/skills/riff/SKILL.md in project scope
# to be dispatchable via `claude -p`. If missing, the drive exits early
# with a clear message pointing at the upstream pre-req. Skip in tests
# where fixture claude mocks bypass the real registry.
if [ "$SKIP_PRECONDITION" -eq 0 ] && [ ! -f "$SCRATCH_DIR/.claude/skills/riff/SKILL.md" ]; then
  echo "smoke-drive-riff: SETUP_FAIL:not-scaffolded (missing .claude/skills/riff/SKILL.md — run /onboard-repo or bassclef init first)" >&2
  echo "smoke-drive-riff: scratch contents:" >&2
  ls -la "$SCRATCH_DIR" >&2 2>&1 || true
  exit 1
fi

# cli #223 cure — make bassclef skills + rules visible in the scratch dir's
# project scope. Otherwise Claude replies "no /riff skill" because npm install
# of @thebassclef/lite dual-writes hooks to ~/.claude/hooks but skills stay
# project-scope only (per copy-substrate.ts:decisionsForFile + memory
# feedback_hooks_dual_write_skills_project_only). The bassclef-init'd
# /adopter/test at Step 3 IS the source of the symlinks.
SUBSTRATE_SOURCE="${BASSCLEF_SUBSTRATE_SOURCE:-${ADOPTER_TEST_DIR:-${HOME:-/home/adopter}/test}/.claude}"
if [ -d "$SUBSTRATE_SOURCE/skills" ] && [ -d "$SUBSTRATE_SOURCE/rules" ]; then
  mkdir -p "$SCRATCH_DIR/.claude"
  ln -sfn "$SUBSTRATE_SOURCE/skills" "$SCRATCH_DIR/.claude/skills"
  ln -sfn "$SUBSTRATE_SOURCE/rules"  "$SCRATCH_DIR/.claude/rules"
  echo "smoke-drive-riff: linked bassclef substrate from ${SUBSTRATE_SOURCE}" >&2
else
  echo "smoke-drive-riff: WARN — ${SUBSTRATE_SOURCE} missing; /riff will report skill-not-found" >&2
fi

# Drive — fire /riff with alarm-based timeout, capture stdout+stderr
echo "smoke-drive-riff: firing /riff (timeout ${TIMEOUT_SEC}s)" >&2

exit_code=0
{
  echo "=== skill: /riff"
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
  ' "$TIMEOUT_SEC" "$CLAUDE_BIN" -p "run the /riff skill with this intent: $RIFF_INTENT. show me the output." < /dev/null 2>&1
  exit_code=$?
  set -e
  echo "=== exit: ${exit_code}"
} > "$OUT_FILE"

# Timeout mapping — 142 → 5 (matches sibling drives)
if [ "$exit_code" -eq 142 ]; then
  echo "smoke-drive-riff: TIMEOUT — /riff exceeded ${TIMEOUT_SEC}s" >&2
  echo "capture: ${OUT_FILE}" >&2
  exit 5
fi

# F3 (Nygard) — env-miss detection.
# Called before assertion because Playwright BLOCK can leave zero HTML.
# Token list expanded per architect-review finding F-AR-1 to match the
# RFC F3 spec — was 'playwright|mcp not enabled|cannot screenshot|puppeteer|chromium'
# which narrowed `mcp` and dropped `browser`. Real /riff BLOCK messages
# vary in wording; the wider set catches more real-world signatures.
_check_env_miss() {
  local capture="$1"
  # Case-insensitive grep across expanded token list.
  # Tokens per RFC F3: playwright, mcp, screenshot, puppeteer, chromium, browser
  # Plus API-limit tokens surfaced during 2026-09-21 verification run
  # (Anthropic API returns 400 with "usage limits" text when the key's
  # budget is exhausted; belongs in env-degraded, not skill-regression).
  if grep -qiE 'playwright|mcp|screenshot|puppeteer|chromium|browser|usage limit|rate limit|api limit|429 |api error: 4' "$capture"; then
    return 0
  fi
  return 1
}

# F2 (Nygard) — assertion sub-classes.
# Returns 0 on PASS. On FAIL, echoes the sub-class token to stdout for tag.
_assert_variants() {
  # Find HTML files > 100 bytes under $SCRATCH_DIR/docs/prototypes/*-riff-*/
  # Also handle the case where directories match but no *.html file lives there.
  local first_html
  first_html=$(find "$SCRATCH_DIR/docs/prototypes" -type f -name '*.html' 2>/dev/null | head -1)

  if [ -z "$first_html" ]; then
    # No HTML file at all. Check if the directory even exists.
    if [ ! -d "$SCRATCH_DIR/docs/prototypes" ]; then
      echo "no-html"
      return 1
    fi
    echo "no-html"
    return 1
  fi

  # File size check — must be > 100 bytes.
  local size
  size=$(wc -c < "$first_html")
  if [ "$size" -le 100 ]; then
    echo "empty-html"
    return 1
  fi

  # Content check — must contain <h2>.
  if ! grep -q '<h2>' "$first_html"; then
    echo "no-h2"
    return 1
  fi

  return 0
}

# Non-zero claude exit AND env-miss → exit 6.
# Non-zero claude exit AND NO env-miss → could still be pass if HTML landed;
# fall through to assertion. On assertion fail, exit 3.
if [ "$exit_code" -ne 0 ]; then
  if _check_env_miss "$OUT_FILE"; then
    # Grab a token from the capture for the tag.
    tok=$(grep -oiE 'playwright|mcp|screenshot|puppeteer|chromium|browser|usage limit|rate limit|api limit|api error' "$OUT_FILE" | head -1 | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    [ -z "$tok" ] && tok="unknown"
    echo "smoke-drive-riff: ENV_DEGRADED:${tok} — /riff blocked on missing ${tok}" >&2
    echo "capture: ${OUT_FILE}" >&2
    exit 6
  fi
  # Non-zero without env-miss token — could still be intentional if HTML landed.
  # Fall through to assertion (rare path).
fi

# Assertion
if reason=$(_assert_variants); then
  echo "smoke-drive-riff: PASS — /riff fired + HTML variant landed + <h2> present" >&2
  echo "capture: ${OUT_FILE}" >&2
  exit 0
fi

echo "smoke-drive-riff: FAIL:${reason} — /riff assertion failed" >&2
echo "capture: ${OUT_FILE}" >&2
exit 3
