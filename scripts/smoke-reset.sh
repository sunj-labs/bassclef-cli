#!/usr/bin/env bash
# tier: upstream
#
# smoke-reset.sh — reset the local environment for a cold-adopter smoke
# test of @thebassclef/lite.
#
# What this script does:
#   1. Uninstalls global @thebassclef/lite AND @thebassclef/core (older name)
#   2. Removes the smoke test work dir (~/tmp/bassclef-smoke-test)
#   3. With --clean-home: backs up ~/.claude/ to ~/.claude.bak.<ts>/ then removes it
#   4. Verifies the reset (bassclef not on PATH; work dir gone; home clean if asked)
#
# The --clean-home step is destructive on machines that use Claude Code
# for real work. Only pass it on a dedicated cold-adopter profile OR when
# you have another backup path. The script backs up ~/.claude/ to a
# timestamped sibling before removal, so recovery is a single mv.
#
# Flags:
#   --dry-run       Print what would happen; change nothing
#   --yes           Skip the confirmation prompt
#   --clean-home    Also back up + remove ~/.claude/ (cold-profile only)
#   -h, --help      Print this help and exit
#
# Usage on a cold-adopter profile:
#   bash scripts/smoke-reset.sh --clean-home --yes
#
# Usage on any machine (safe subset — no home touch):
#   bash scripts/smoke-reset.sh
#   bash scripts/smoke-reset.sh --dry-run

set -euo pipefail

WORK_DIR="${HOME}/tmp/bassclef-smoke-test"
PRIMARY_PKG="@thebassclef/lite"
LEGACY_PKG="@thebassclef/core"
DRY_RUN=0
ASSUME_YES=0
CLEAN_HOME=0

print_usage() {
  sed -n '1,32p' "$0" | sed 's|^#\{0,1\} \{0,1\}||'
}

while (( "$#" )); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --clean-home) CLEAN_HOME=1; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; print_usage; exit 2 ;;
  esac
done

log() {
  echo "smoke-reset: $*"
}

do_or_dry() {
  if (( DRY_RUN )); then
    log "would run: $*"
  else
    log "running: $*"
    "$@"
  fi
}

confirm_or_exit() {
  local prompt="$1"
  if (( ASSUME_YES )) || (( DRY_RUN )); then
    return 0
  fi
  read -r -p "smoke-reset: ${prompt} [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) log "aborted by user"; exit 1 ;;
  esac
}

# --- Step 1 — global npm uninstall ----------------------------------------

uninstall_global() {
  local pkg="$1"
  if npm ls -g "${pkg}" --depth=0 >/dev/null 2>&1; then
    local version
    version=$(npm ls -g "${pkg}" --depth=0 --json 2>/dev/null \
      | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>{try{const j=JSON.parse(d); const v=(j.dependencies||{})['${pkg}']?.version||'unknown'; process.stdout.write(v);}catch{process.stdout.write('unknown');}})" \
      2>/dev/null || echo "unknown")
    log "found ${pkg}@${version} globally"
    do_or_dry npm uninstall -g "${pkg}"
  else
    log "no global install of ${pkg} — nothing to uninstall"
  fi
}

if command -v npm >/dev/null 2>&1; then
  uninstall_global "${PRIMARY_PKG}"
  uninstall_global "${LEGACY_PKG}"
else
  log "npm not on PATH — skipping uninstall step"
fi

# --- Step 2 — remove the smoke test work dir ------------------------------

if [ -d "${WORK_DIR}" ]; then
  log "removing work dir ${WORK_DIR}"
  do_or_dry rm -rf "${WORK_DIR}"
else
  log "work dir ${WORK_DIR} does not exist — nothing to remove"
fi

# --- Step 3 — clean home (opt-in) -----------------------------------------

if (( CLEAN_HOME )); then
  if [ -d "${HOME}/.claude" ]; then
    TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
    BACKUP_DIR="${HOME}/.claude.bak.${TS}"
    log "will back up ${HOME}/.claude to ${BACKUP_DIR} then remove ${HOME}/.claude"
    log "recovery command if needed later: mv ${BACKUP_DIR} ${HOME}/.claude"
    confirm_or_exit "back up and remove ${HOME}/.claude ?"
    do_or_dry mv "${HOME}/.claude" "${BACKUP_DIR}"
  else
    log "${HOME}/.claude does not exist — nothing to clean"
  fi
else
  log "skipping ~/.claude/ cleanup (pass --clean-home for cold-profile reset)"
fi

# --- Step 4 — verify ------------------------------------------------------

if (( DRY_RUN )); then
  log "dry-run complete. Re-run without --dry-run to apply."
  exit 0
fi

log "verifying reset"

VERIFY_FAIL=0

if command -v bassclef >/dev/null 2>&1; then
  log "FAIL: 'bassclef' still on PATH at $(command -v bassclef)"
  VERIFY_FAIL=1
else
  log "OK: 'bassclef' not on PATH"
fi

if [ -d "${WORK_DIR}" ]; then
  log "FAIL: work dir ${WORK_DIR} still exists"
  VERIFY_FAIL=1
else
  log "OK: work dir ${WORK_DIR} gone"
fi

if (( CLEAN_HOME )); then
  if [ -d "${HOME}/.claude" ]; then
    log "FAIL: ${HOME}/.claude still exists after --clean-home"
    VERIFY_FAIL=1
  else
    log "OK: ${HOME}/.claude gone"
  fi
fi

if (( VERIFY_FAIL )); then
  log "reset incomplete — investigate the FAIL lines above"
  exit 1
fi

log "reset complete. Ready for cold-adopter smoke test."
log "next: npm install -g ${PRIMARY_PKG}@1.0.1"
exit 0
