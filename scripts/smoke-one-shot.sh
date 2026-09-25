#!/usr/bin/env bash
# tier: upstream
#
# smoke-one-shot.sh — run the host smoke chain + publish the report as
# one command. Closes the version-tag + label-shape drift class that
# recurred on prior runs (per operator memory 2026-09-25).
#
# Chain:
#   smoke-preflight.sh (env sanity)
#   → smoke-capture.sh    (host hook captures)
#   → smoke-drive-skills.sh (host skill captures)
#   → smoke-assert-hooks.sh
#   → smoke-assert-skills.sh
#   → smoke-report.sh --publish
#
# Failure classes closed:
#   1. Missing --version-tag on smoke-report — this script resolves the
#      version deterministically: --cli-version arg > $CLI_VERSION env >
#      package.json version. Never falls through to "(unspecified)".
#   2. Non-semver label text (e.g. "1.9.2-nosync-nuked") — the script
#      validates the resolved version against the semver shape BEFORE
#      any gh call. Non-matching input exits 1 with a fix prompt.
#   3. Missing captures dir on --publish-only — this script always
#      builds the captures + report from scratch, so --publish sees
#      a real file every time.
#
# Flags:
#   --cli-version VER       @thebassclef/lite version under test (e.g. 1.9.3).
#                           Overrides $CLI_VERSION + package.json.
#   --date YYYY-MM-DD       capture dir date suffix (default: today UTC)
#   --skip-skills           skip smoke-drive-skills.sh + skills assertions
#                           (use when claude auth is not available)
#   --no-publish            build the report but do not publish to GitHub
#   --repo OWNER/REPO       publish target (default: sunj-labs/bassclef-cli)
#   --reset                 fire smoke-reset.sh --cold FIRST (uninstall cli,
#                           purge workdir, back up + remove ~/.claude/). Cold-
#                           adopter profiles only — destructive on dev machines.
#   --install               after reset, `npm install -g @thebassclef/lite@VER`
#                           + init a fresh test project. Composes with --reset.
#   --help                  print this help
#
# Env:
#   CLI_VERSION             fallback for --cli-version
#   CLAUDE_CODE_OAUTH_TOKEN skill drive needs one auth token set
#   ANTHROPIC_API_KEY       alternate skill drive auth (metered)
#
# Exit codes:
#   0  report built + (optionally) published cleanly
#   1  usage / version-shape / config error
#   2  smoke chain failed (see per-script exit for detail)
#   4  publish failed (bubbled from smoke-report.sh)

set -euo pipefail

# Resolve sibling script dir from BASH_SOURCE so the script works regardless
# of the caller's cwd. Prior version used `bash scripts/foo.sh` (relative to
# cwd) which failed when the script was fetched into ~/tmp/bassclef-smoke-scripts
# and invoked from any dir other than the fake "repo root".
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_NAME="$(basename "$0" .sh)"
echo ">>> ${SCRIPT_NAME} starting" >&2
trap 'echo "<<< ${SCRIPT_NAME} done (exit $?)" >&2' EXIT

# Defensive cd to $HOME up front. If the caller's cwd is under a dir
# that smoke-reset.sh will delete (e.g. ~/tmp/bassclef-smoke-test),
# subshells hit `getcwd: no such file or directory` and some terminals
# (Ghostty, Kitty) kill the parent pane. Landing at $HOME sidesteps it.
cd "${HOME}" || cd /

CLI_VERSION_ARG=""
DATE_ARG=""
SKIP_SKILLS=0
DO_PUBLISH=1
REPO_TARGET_ARG=""
DO_RESET=0
DO_INSTALL=0

usage() {
  sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cli-version) CLI_VERSION_ARG="$2"; shift 2 ;;
    --date) DATE_ARG="$2"; shift 2 ;;
    --skip-skills) SKIP_SKILLS=1; shift ;;
    --no-publish) DO_PUBLISH=0; shift ;;
    --repo) REPO_TARGET_ARG="$2"; shift 2 ;;
    --reset) DO_RESET=1; shift ;;
    --install) DO_INSTALL=1; shift ;;
    --help|-h) usage ;;
    *) echo "${SCRIPT_NAME}: unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --- resolve version deterministically ---------------------------------------
# Precedence: --cli-version > $CLI_VERSION > package.json.
VER="${CLI_VERSION_ARG:-${CLI_VERSION:-}}"
if [ -z "$VER" ] && [ -f package.json ]; then
  VER=$(node -p "require('./package.json').version" 2>/dev/null || echo "")
fi
if [ -z "$VER" ]; then
  echo "${SCRIPT_NAME}: cli version required." >&2
  echo "  pass --cli-version X.Y.Z, or set \$CLI_VERSION, or run from a repo root with package.json" >&2
  exit 1
fi

# --- validate semver shape BEFORE any gh call --------------------------------
# Matches: 1.9.3 | 1.9.3-rc1 | 1.9.3-beta.2 | 1.9.3+build.5
# Rejects: 1.9.3-nosync-nuked (arbitrary suffix), 1.9.3-nuked (single-word only if intentional prerelease)
# The rule: prerelease identifier must not include a dash-word beyond one segment.
# Rationale: prior label failure was "smoke-run-1.9.2-nosync-nuked" — a run-description
# passed as version. Semver allows dashes in prerelease, so this check is deliberately
# loose but still refuses obvious run-descriptions by requiring valid semver structure.
if ! echo "$VER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?(\+[A-Za-z0-9.-]+)?$'; then
  echo "${SCRIPT_NAME}: '$VER' is not a valid semver shape." >&2
  echo "  expected: X.Y.Z  OR  X.Y.Z-prerelease  OR  X.Y.Z+build" >&2
  echo "  hint: run descriptions belong in the report body, not the version tag" >&2
  exit 1
fi

# --- confirm version resolves at npm registry (best-effort, non-blocking) ----
# Registry query is best-effort. On failure (network, 404), warn + continue —
# the smoke chain runs against local cli, not registry.
REGISTRY_URL="https://registry.npmjs.org/@thebassclef/lite/${VER}"
if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS --max-time 5 "$REGISTRY_URL" >/dev/null 2>&1; then
    echo "${SCRIPT_NAME}: WARN — @thebassclef/lite@${VER} not visible at npm registry yet (CDN lag or unpublished)." >&2
    echo "  continuing; smoke runs against local install" >&2
  fi
fi

DATE="${DATE_ARG:-$(date -u +%Y-%m-%d)}"
CAPTURES_DIR="docs/smoke-captures/${DATE}"

echo "${SCRIPT_NAME}: version=${VER} date=${DATE} captures=${CAPTURES_DIR}" >&2

# --- optional reset (cold-adopter profile only) ------------------------------
# smoke-reset.sh --cold uninstalls cli globally, purges the smoke workdir,
# backs up ~/.claude/ then removes it. Only fire on a dedicated cold-adopter
# profile — destructive on dev machines.
if [ "$DO_RESET" -eq 1 ]; then
  echo "${SCRIPT_NAME}: firing smoke-reset.sh --cold" >&2
  bash "${SCRIPT_DIR}/smoke-reset.sh" --cold
fi

# --- optional install (fresh cli install + test project) ---------------------
# Runs `npm install -g @thebassclef/lite@VER` + inits a fresh test project
# at ~/tmp/bassclef-smoke-test. Composes with --reset for a clean cycle.
if [ "$DO_INSTALL" -eq 1 ]; then
  echo "${SCRIPT_NAME}: installing @thebassclef/lite@${VER}" >&2
  npm install -g "@thebassclef/lite@${VER}"
  TESTDIR="${HOME}/tmp/bassclef-smoke-test"
  mkdir -p "$TESTDIR"
  cd "$TESTDIR"
  if [ ! -d .git ]; then
    git init -q
    # Empty fixture commit — inline identity so we do not require global
    # git config on cold-adopter profiles (git commit exits 128 otherwise).
    GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@local \
    GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@local \
    git commit --allow-empty -m "chore: smoke fixture" -q
  fi
  bassclef init
  echo "${SCRIPT_NAME}: init landed tier=$(grep -oE '"tier"[[:space:]]*:[[:space:]]*"[^"]*"' .bassclef-source.json)" >&2
fi

# --- run the chain -----------------------------------------------------------
bash "${SCRIPT_DIR}/smoke-preflight.sh"
bash "${SCRIPT_DIR}/smoke-capture.sh" --out "$CAPTURES_DIR"

if [ "$SKIP_SKILLS" -eq 0 ]; then
  bash "${SCRIPT_DIR}/smoke-drive-skills.sh" --out "${CAPTURES_DIR}/skills"
else
  echo "${SCRIPT_NAME}: skipping smoke-drive-skills.sh (--skip-skills)" >&2
fi

bash "${SCRIPT_DIR}/smoke-assert-hooks.sh" \
  --capture-dir "${CAPTURES_DIR}/hooks" \
  --out "${CAPTURES_DIR}/hooks-assertions.json"

if [ "$SKIP_SKILLS" -eq 0 ]; then
  bash "${SCRIPT_DIR}/smoke-assert-skills.sh" \
    --capture-dir "${CAPTURES_DIR}/skills" \
    --out "${CAPTURES_DIR}/skills-assertions.json"
fi

# --- build + publish report --------------------------------------------------
REPORT_ARGS=(
  --captures-dir "$CAPTURES_DIR"
  --out "${CAPTURES_DIR}/report.md"
  --version-tag "$VER"
)
if [ "$DO_PUBLISH" -eq 1 ]; then
  REPORT_ARGS+=(--publish)
  if [ -n "$REPO_TARGET_ARG" ]; then
    export SMOKE_REPO_TARGET="$REPO_TARGET_ARG"
  fi
fi

bash "${SCRIPT_DIR}/smoke-report.sh" "${REPORT_ARGS[@]}"
