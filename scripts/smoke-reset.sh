#!/usr/bin/env bash
# tier: upstream
#
# smoke-reset.sh — reset the local environment for a cold-adopter smoke
# test of @thebassclef/core.
#
# Companion to docs/test-plans/2026-08-31-cold-adopter-smoke-0.1.1.md.
#
# What this script does:
#   1. Uninstalls the global @thebassclef/core if present
#   2. Removes the smoke test working directory (~/tmp/bassclef-smoke-test)
#   3. Verifies the reset (which bassclef → nothing; work dir gone)
#
# What this script does NOT touch:
#   - ~/.claude/ (may hold real Claude Code state)
#   - ~/.npm/ cache (harmless; leaving it in place keeps normal npm fast)
#   - Any repo directory
#   - Any global npm package other than @thebassclef/core
#
# Flags:
#   --dry-run     Print what would be removed; do not remove anything
#   -h, --help    Print this help and exit
#
# Usage:
#   bash scripts/smoke-reset.sh
#   bash scripts/smoke-reset.sh --dry-run

set -euo pipefail

WORK_DIR="${HOME}/tmp/bassclef-smoke-test"
PKG_NAME="@thebassclef/core"
DRY_RUN=0

print_usage() {
  sed -n '1,30p' "$0" | sed 's|^#\{0,1\} \{0,1\}||'
}

while (( "$#" )); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
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

# --- Step 1 — global npm uninstall ----------------------------------------

log "checking for global install of ${PKG_NAME}"

GLOBAL_INSTALLED=0
if command -v npm >/dev/null 2>&1; then
  if npm ls -g "${PKG_NAME}" --depth=0 >/dev/null 2>&1; then
    GLOBAL_INSTALLED=1
    INSTALLED_VERSION=$(npm ls -g "${PKG_NAME}" --depth=0 --json 2>/dev/null \
      | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>{try{const j=JSON.parse(d); const v=(j.dependencies||{})['${PKG_NAME}']?.version||'unknown'; process.stdout.write(v);}catch{process.stdout.write('unknown');}})" \
      2>/dev/null || echo "unknown")
    log "found ${PKG_NAME}@${INSTALLED_VERSION} globally"
    do_or_dry npm uninstall -g "${PKG_NAME}"
  else
    log "no global install found — nothing to uninstall"
  fi
else
  log "npm not on PATH — skipping uninstall step"
fi

# --- Step 2 — remove the smoke test working directory ---------------------

if [ -d "${WORK_DIR}" ]; then
  log "removing work dir ${WORK_DIR}"
  do_or_dry rm -rf "${WORK_DIR}"
else
  log "work dir ${WORK_DIR} does not exist — nothing to remove"
fi

# --- Step 3 — verify --------------------------------------------------------

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

if (( VERIFY_FAIL )); then
  log "reset incomplete — investigate the FAIL lines above"
  exit 1
fi

log "reset complete. Environment ready for cold-adopter smoke test."
log "next: run 'npm install -g ${PKG_NAME}' per docs/test-plans/2026-08-31-cold-adopter-smoke-0.1.1.md"
exit 0
