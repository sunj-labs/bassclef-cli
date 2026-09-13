#!/usr/bin/env bash
# tier: upstream
#
# smoke-preflight.sh — read-only inventory + guided reset for a cold-adopter
# smoke test of @thebassclef/lite.
#
# What this script does (in order):
#   1. Confirms your login and $HOME
#   2. Inventories ~/.claude/ (size, top-level shape)
#   3. Lists global npm packages the reset would remove
#   4. Lists ~/tmp/ contents
#   5. Looks for real Claude Code work worth saving (settings, projects, mcp)
#   6. Checks for any running Claude Code process
#   7. Lists prior backup dirs from earlier runs
#   8. Prints a per-signal risk verdict
#   9. Asks for explicit confirmation before running smoke-reset.sh
#
# Nothing in steps 1-8 changes state. Step 9 is the only destructive gate.
# Step 9 delegates to smoke-reset.sh — this script fetches it if missing.
#
# The script is idempotent — running it twice with no external changes
# produces the same inventory. The reset step itself only touches state
# if you confirm.
#
# Flags:
#   --auto-reset      Skip the interactive prompt; run reset with --clean-home if safe,
#                     otherwise abort. Use only in known-safe automation.
#   --no-fetch        Do not fetch smoke-reset.sh; require it at /tmp/smoke-reset.sh
#   -h, --help        Print this help and exit
#
# Usage from a cold-adopter profile:
#   curl -fsSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/smoke-preflight.sh \
#     -o /tmp/smoke-preflight.sh
#   bash /tmp/smoke-preflight.sh

set -euo pipefail

RESET_URL="https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/smoke-reset.sh"
RESET_PATH="/tmp/smoke-reset.sh"
AUTO_RESET=0
FETCH=1

# Verdict counters. Any RED means default answer is abort.
RED_COUNT=0
YELLOW_COUNT=0
GREEN_COUNT=0

# Findings buffer — printed at the end before the prompt.
FINDINGS=()

while (( "$#" )); do
  case "$1" in
    --auto-reset) AUTO_RESET=1; shift ;;
    --no-fetch) FETCH=0; shift ;;
    -h|--help) sed -n '1,42p' "$0" | sed 's|^#\{0,1\} \{0,1\}||'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

hdr() {
  echo ""
  echo "=== $* ==="
}

note() {
  echo "  $*"
}

flag_red() {
  RED_COUNT=$((RED_COUNT + 1))
  FINDINGS+=("RED: $*")
  echo "  RED: $*"
}

flag_yellow() {
  YELLOW_COUNT=$((YELLOW_COUNT + 1))
  FINDINGS+=("YELLOW: $*")
  echo "  YELLOW: $*"
}

flag_green() {
  GREEN_COUNT=$((GREEN_COUNT + 1))
  FINDINGS+=("GREEN: $*")
  echo "  GREEN: $*"
}

# --- 1. Profile identity ---------------------------------------------------

hdr "1. Profile identity"

WHO=$(whoami)
note "whoami:   ${WHO}"
note "HOME:     ${HOME}"
note "hostname: $(hostname -s 2>/dev/null || echo unknown)"

case "${HOME}" in
  */cold-adopter*|*/adopter-*|*/test-*|*/smoke-*)
    flag_green "HOME path looks like a test profile"
    ;;
  *)
    flag_yellow "HOME path does not look like a test profile — confirm you are on the cold-adopter login before proceeding"
    ;;
esac

# --- 2. ~/.claude/ inventory ------------------------------------------------

hdr "2. ~/.claude/ inventory"

if [ -d "${HOME}/.claude" ]; then
  SIZE=$(du -sh "${HOME}/.claude" 2>/dev/null | awk '{print $1}')
  note "size:  ${SIZE}"
  note "shape:"
  ls -la "${HOME}/.claude" 2>/dev/null | sed 's/^/    /'

  # Rough sanity: a fresh profile should be under ~10MB.
  SIZE_KB=$(du -sk "${HOME}/.claude" 2>/dev/null | awk '{print $1}')
  if [ "${SIZE_KB:-0}" -gt 102400 ]; then
    flag_yellow "~/.claude is over 100MB — probably real work, not test leftovers"
  else
    flag_green "~/.claude is under 100MB — probably test leftovers or fresh"
  fi
else
  note "~/.claude does not exist"
  flag_green "no home dir to back up"
fi

# --- 3. Global npm packages the reset would remove -------------------------

hdr "3. Global npm packages"

if command -v npm >/dev/null 2>&1; then
  for pkg in "@thebassclef/lite" "@thebassclef/core"; do
    if npm ls -g "${pkg}" --depth=0 >/dev/null 2>&1; then
      VER=$(npm ls -g "${pkg}" --depth=0 --json 2>/dev/null \
        | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);const v=(j.dependencies||{})['${pkg}']?.version||'unknown';process.stdout.write(v);}catch{process.stdout.write('unknown');}})" \
        2>/dev/null || echo "unknown")
      note "installed: ${pkg}@${VER}"
      flag_yellow "${pkg}@${VER} will be uninstalled"
    else
      note "not installed: ${pkg}"
    fi
  done
else
  flag_red "npm not on PATH — reset cannot run"
fi

# --- 4. ~/tmp/ contents ----------------------------------------------------

hdr "4. ~/tmp/ contents"

if [ -d "${HOME}/tmp" ]; then
  ls -la "${HOME}/tmp" 2>/dev/null | sed 's/^/    /'

  # Reset script's declared work dir.
  if [ -d "${HOME}/tmp/bassclef-smoke-test" ]; then
    flag_yellow "~/tmp/bassclef-smoke-test will be removed"
  fi

  # Leftovers the reset script does NOT touch.
  LEFTOVERS=$(ls -1 "${HOME}/tmp" 2>/dev/null | grep -vE '^bassclef-smoke-test$' | grep -E '^adopter-|^cold-adopter-|^smoke-' || true)
  if [ -n "${LEFTOVERS}" ]; then
    note "leftovers the reset will NOT touch:"
    echo "${LEFTOVERS}" | sed 's/^/    /'
    flag_yellow "prior adopter test dirs present under ~/tmp/ — delete by hand for a fully clean slate"
  fi
else
  note "~/tmp does not exist"
fi

# --- 5. Real Claude Code work check ----------------------------------------

hdr "5. Real Claude Code work check"

WORK_SIGNALS=0

if [ -f "${HOME}/.claude/settings.json" ]; then
  SETTINGS_SIZE=$(wc -c < "${HOME}/.claude/settings.json" 2>/dev/null || echo 0)
  note "~/.claude/settings.json: ${SETTINGS_SIZE} bytes"
  if [ "${SETTINGS_SIZE:-0}" -gt 200 ]; then
    WORK_SIGNALS=$((WORK_SIGNALS + 1))
    flag_yellow "settings.json is non-trivial — may hold custom config you want back"
  fi
else
  note "no settings.json"
fi

if [ -d "${HOME}/.claude/projects" ]; then
  PROJECT_COUNT=$(ls -1 "${HOME}/.claude/projects" 2>/dev/null | wc -l | tr -d ' ')
  note "~/.claude/projects/: ${PROJECT_COUNT} project(s) with chat history"
  if [ "${PROJECT_COUNT:-0}" -gt 0 ]; then
    WORK_SIGNALS=$((WORK_SIGNALS + 1))
    flag_yellow "projects dir has ${PROJECT_COUNT} entries — chat history will be in the backup"
  fi
else
  note "no ~/.claude/projects/"
fi

if [ -d "${HOME}/.claude/mcp" ] || [ -f "${HOME}/.claude.json" ]; then
  WORK_SIGNALS=$((WORK_SIGNALS + 1))
  note "MCP configs present"
  flag_yellow "MCP configs present — will be in the backup"
fi

if [ "${WORK_SIGNALS}" -eq 0 ]; then
  flag_green "no real Claude Code work detected"
fi

# --- 6. Running Claude Code sessions ---------------------------------------

hdr "6. Running Claude Code sessions"

RUNNING=$(pgrep -fl claude 2>/dev/null | grep -v -- 'pgrep' | grep -v -- 'smoke-preflight' || true)
if [ -n "${RUNNING}" ]; then
  note "found running processes:"
  echo "${RUNNING}" | sed 's/^/    /'
  flag_red "quit running claude sessions before proceeding — mv of ~/.claude mid-session will corrupt state"
else
  note "no running claude processes"
  flag_green "no running claude sessions"
fi

# --- 7. Prior backups from earlier runs ------------------------------------

hdr "7. Prior smoke-reset backups"

PRIOR_BACKUPS=$(ls -1d "${HOME}"/.claude.bak.* 2>/dev/null || true)
if [ -n "${PRIOR_BACKUPS}" ]; then
  note "existing backup dirs:"
  echo "${PRIOR_BACKUPS}" | sed 's/^/    /'
  BAK_COUNT=$(echo "${PRIOR_BACKUPS}" | wc -l | tr -d ' ')
  if [ "${BAK_COUNT}" -gt 3 ]; then
    flag_yellow "${BAK_COUNT} prior backup dirs — consider deleting old ones to reclaim disk"
  else
    flag_green "prior backup dirs present but count is manageable"
  fi
else
  note "no prior backups"
fi

# --- 8. Verdict summary ----------------------------------------------------

hdr "8. Verdict"

echo "  RED signals:    ${RED_COUNT}"
echo "  YELLOW signals: ${YELLOW_COUNT}"
echo "  GREEN signals:  ${GREEN_COUNT}"
echo ""

if [ "${RED_COUNT}" -gt 0 ]; then
  echo "  Recommendation: ABORT. Resolve RED findings before running the reset."
  DEFAULT_ACTION="abort"
elif [ "${YELLOW_COUNT}" -gt 3 ]; then
  echo "  Recommendation: PAUSE. Review the YELLOW findings — several suggest real work is present."
  DEFAULT_ACTION="pause"
else
  echo "  Recommendation: PROCEED with reset --clean-home. Backup will be created before removal."
  DEFAULT_ACTION="proceed"
fi

# --- 9. Fetch reset script if needed ---------------------------------------

hdr "9. Reset script availability"

if [ ! -f "${RESET_PATH}" ]; then
  if (( FETCH )); then
    note "fetching smoke-reset.sh to ${RESET_PATH}"
    if curl -fsSL "${RESET_URL}" -o "${RESET_PATH}"; then
      note "fetched OK"
    else
      flag_red "failed to fetch reset script from ${RESET_URL}"
    fi
  else
    flag_red "reset script not found at ${RESET_PATH} and --no-fetch set"
  fi
else
  note "reset script already present at ${RESET_PATH}"
fi

# --- 10. Confirmation prompt ----------------------------------------------

hdr "10. Confirmation"

if [ "${RED_COUNT}" -gt 0 ]; then
  echo "  Aborting due to RED findings. Re-run after resolving them."
  exit 1
fi

if (( AUTO_RESET )); then
  if [ "${DEFAULT_ACTION}" = "proceed" ]; then
    echo "  --auto-reset set and recommendation is PROCEED. Running reset now."
    exec bash "${RESET_PATH}" --clean-home --yes
  else
    echo "  --auto-reset set but recommendation is ${DEFAULT_ACTION}. Aborting."
    exit 1
  fi
fi

echo "  Options:"
echo "    1) Reset with --clean-home  (backs up ~/.claude and removes it)"
echo "    2) Reset without --clean-home  (leaves ~/.claude alone)"
echo "    3) Abort (no changes)"
echo ""
read -r -p "  Pick 1, 2, or 3: " CHOICE

case "${CHOICE}" in
  1) exec bash "${RESET_PATH}" --clean-home --yes ;;
  2) exec bash "${RESET_PATH}" --yes ;;
  3) echo "  Aborted. No changes made."; exit 0 ;;
  *) echo "  Unknown choice. Aborted. No changes made."; exit 2 ;;
esac
