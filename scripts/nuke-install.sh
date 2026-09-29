#!/usr/bin/env bash
# nuke-install.sh — one-command fresh install of @thebassclef/lite.
#
# For cold adopters who want a truly cold install with zero cruft from
# prior state. Paste-mangling risk removed by design: script fetches
# via curl and runs from disk, never as a multi-line paste.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-install.sh | bash
#   curl -sSL <url> | bash -s -- --version 1.9.8
#   bash nuke-install.sh --dry-run
#
# Contract per docs/use-cases/UC-script-nuke-install.md.
# Anchors: @luminary alan-cooper (CLI shape), @luminary michael-feathers (characterization tests).

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh 2>/dev/null || echo "nuke-install")"

usage() {
  cat <<'EOF'
Usage: nuke-install.sh [FLAGS]

Cold-adopter fresh install of @thebassclef/lite. Backs up ~/.claude,
uninstalls any prior global cli, installs the requested version, and
runs `bassclef init` in a fresh workdir.

Flags:
  --version VER       npm version to install (default: latest)
  --workdir PATH      target workdir (default: ~/tmp/bassclef-smoke-test)
  --keep-claude       do not back up ~/.claude (default: back up + remove)
  --dry-run           print planned steps and exit; no state changes
  --help, -h          print this help

Examples:
  # fresh install of latest
  curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-install.sh | bash

  # pin a specific version
  curl -sSL <url> | bash -s -- --version 1.9.8

  # preview without touching state
  bash nuke-install.sh --dry-run

Exit codes:
  0  success (or dry-run)
  1  usage error
  2  npm install failed
  3  bassclef init failed
EOF
}

# Defensive cd to $HOME up front. Cold-adopter shells may start in a
# cwd that gets deleted below (~/tmp/bassclef-smoke-test purge). Landing
# at $HOME sidesteps process.cwd() uv_cwd errors from npm + git.
cd "${HOME}" 2>/dev/null || cd /

VERSION="latest"
WORKDIR="${HOME}/tmp/bassclef-smoke-test"
KEEP_CLAUDE=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      if [ $# -lt 2 ] || [ -z "${2:-}" ] || [ "${2:0:1}" = "-" ]; then
        echo "${SCRIPT_NAME}: --version requires an argument" >&2
        exit 1
      fi
      VERSION="$2"
      shift 2
      ;;
    --workdir)
      if [ $# -lt 2 ] || [ -z "${2:-}" ] || [ "${2:0:1}" = "-" ]; then
        echo "${SCRIPT_NAME}: --workdir requires an argument" >&2
        exit 1
      fi
      WORKDIR="$2"
      shift 2
      ;;
    --keep-claude)
      KEEP_CLAUDE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "${SCRIPT_NAME}: unknown flag: $1" >&2
      echo "  run '${SCRIPT_NAME} --help' for usage" >&2
      exit 1
      ;;
  esac
done

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_PATH="${HOME}/.claude.bak.${TIMESTAMP}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY-RUN — planned steps:"
  echo "  1. cd ${HOME}"
  if [ "$KEEP_CLAUDE" -eq 0 ]; then
    echo "  2. if ~/.claude exists: mv ~/.claude ${BACKUP_PATH}"
  else
    echo "  2. --keep-claude set: leave ~/.claude in place"
  fi
  echo "  3. npm uninstall -g @thebassclef/lite (silent if absent)"
  echo "  4. npm install -g @thebassclef/lite@${VERSION}"
  echo "  5. rm -rf ${WORKDIR}"
  echo "  6. mkdir -p ${WORKDIR} && cd ${WORKDIR}"
  echo "  7. git init -q + empty fixture commit"
  echo "  8. bassclef init"
  echo
  echo "No state changed. Remove --dry-run to execute."
  exit 0
fi

echo ">>> ${SCRIPT_NAME} starting (version=${VERSION} workdir=${WORKDIR})" >&2

# Step 1: back up ~/.claude if requested + present.
if [ "$KEEP_CLAUDE" -eq 0 ]; then
  if [ -e "${HOME}/.claude" ] || [ -L "${HOME}/.claude" ]; then
    echo "${SCRIPT_NAME}: moving ~/.claude → ${BACKUP_PATH}" >&2
    mv "${HOME}/.claude" "${BACKUP_PATH}"
  else
    echo "${SCRIPT_NAME}: no ~/.claude to back up" >&2
  fi
fi

# Step 2: uninstall any prior global cli. Silent on absent.
echo "${SCRIPT_NAME}: uninstalling any prior @thebassclef/lite" >&2
npm uninstall -g @thebassclef/lite >/dev/null 2>&1 || true

# Step 3: fresh install.
echo "${SCRIPT_NAME}: installing @thebassclef/lite@${VERSION}" >&2
if ! npm install -g "@thebassclef/lite@${VERSION}"; then
  echo "${SCRIPT_NAME}: npm install failed" >&2
  exit 2
fi

# Step 4: fresh workdir.
echo "${SCRIPT_NAME}: preparing workdir ${WORKDIR}" >&2
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Step 5: git init with inline identity (cold profiles may lack global config).
if [ ! -d .git ]; then
  git init -q
  GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@local \
  GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@local \
  git commit --allow-empty -m "chore: nuke-install fixture" -q
fi

# Step 6: bassclef init.
echo "${SCRIPT_NAME}: running bassclef init" >&2
if ! bassclef init; then
  echo "${SCRIPT_NAME}: bassclef init failed" >&2
  exit 3
fi

# Summary.
INSTALLED_VERSION="$(bassclef --version 2>/dev/null || echo unknown)"
echo >&2
echo "<<< ${SCRIPT_NAME} done" >&2
echo "  installed: @thebassclef/lite@${INSTALLED_VERSION}" >&2
echo "  workdir:   ${WORKDIR}" >&2
if [ "$KEEP_CLAUDE" -eq 0 ] && [ -e "${BACKUP_PATH}" ]; then
  echo "  backup:    ${BACKUP_PATH}" >&2
  echo "  restore:   mv ${BACKUP_PATH} ~/.claude" >&2
else
  echo "  backup:    none (no prior ~/.claude or --keep-claude)" >&2
fi
