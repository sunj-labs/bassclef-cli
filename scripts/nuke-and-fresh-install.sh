#!/usr/bin/env bash
# nuke-and-fresh-install.sh — one-command fresh install of @thebassclef/lite.
#
# For cold adopters who want a truly cold install with zero cruft from
# prior state. Paste-mangling risk removed by design: script fetches
# via curl and runs from disk, never as a multi-line paste.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-and-fresh-install.sh | bash
#   curl -sSL <url> | bash -s -- --version 1.9.8
#   bash nuke-and-fresh-install.sh --dry-run
#
# Contract per docs/use-cases/UC-script-nuke-and-fresh-install.md.
# Anchors: @luminary alan-cooper (CLI shape), @luminary michael-feathers (characterization tests).

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh 2>/dev/null || echo "nuke-and-fresh-install")"

usage() {
  cat <<'EOF'
Usage: nuke-and-fresh-install.sh [FLAGS]

Cold-adopter fresh install of @thebassclef/lite. Backs up ~/.claude,
uninstalls any prior global cli, installs the requested version, and
runs `bassclef init` in a fresh workdir.

Flags:
  --version VER             npm version to install (default: latest)
  --workdir PATH            target workdir (default: ~/tmp/bassclef-smoke-test)
  --keep-claude             do not back up ~/.claude (default: back up + remove)
  --delete-github           also delete GitHub test repos matching *bassclef-smoke-test*
                            under the authenticated gh user. Prompts per hit by default.
  --yes                     auto-confirm --delete-github prompts (scripted use only)
  --purge-adopter           one-flag full reset — implies --delete-github --yes.
                            Deletes every matching GitHub test repo (no prompts) plus
                            the standard workdir purge. For cold-adopter smoke sessions
                            that collide with repos from a prior run.
  --install-upstream-pat    install the upstream bug-reporting PAT on this profile.
                            Reads from env var BASSCLEF_UPSTREAM_PAT. Use `read -s`
                            to pass it without the value hitting shell history:
                              read -s "PAT: " BASSCLEF_UPSTREAM_PAT
                              export BASSCLEF_UPSTREAM_PAT
                              curl -sSL ... | bash -s -- --install-upstream-pat
                            Writes ~/.config/bassclef/upstream-pat (chmod 600) and
                            appends an idempotent export line to ~/.zshrc or
                            ~/.bashrc. Future shells on this profile pick up the
                            PAT automatically.
  --dry-run                 print planned steps and exit; no state changes
  --help, -h                print this help

Examples:
  # fresh install of latest
  curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-and-fresh-install.sh | bash

  # pin a specific version
  curl -sSL <url> | bash -s -- --version 1.9.8

  # preview without touching state
  bash nuke-and-fresh-install.sh --dry-run

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
DELETE_GITHUB=0
AUTO_YES=0
GH_PATTERN="bassclef-smoke-test"
INSTALL_UPSTREAM_PAT=0
PAT_PATH="${HOME}/.config/bassclef/upstream-pat"
PAT_EXPORT_MARKER="# bassclef upstream PAT — auto-added by nuke-and-fresh-install.sh"

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
    --delete-github)
      DELETE_GITHUB=1
      shift
      ;;
    --yes)
      AUTO_YES=1
      shift
      ;;
    --purge-adopter)
      # One-flag convenience: implies --delete-github --yes.
      # Cold-adopter smoke sessions typically want a full reset including
      # every matching GitHub test repo from prior runs, no prompts.
      DELETE_GITHUB=1
      AUTO_YES=1
      shift
      ;;
    --install-upstream-pat)
      INSTALL_UPSTREAM_PAT=1
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
  if [ "$INSTALL_UPSTREAM_PAT" -eq 1 ]; then
    if [ -n "${BASSCLEF_UPSTREAM_PAT:-}" ]; then
      echo "  1b. install upstream PAT → ${PAT_PATH} + idempotent shell rc hook"
    else
      echo "  1b. --install-upstream-pat set but BASSCLEF_UPSTREAM_PAT env var missing; would exit 1"
    fi
  fi
  if [ "$KEEP_CLAUDE" -eq 0 ]; then
    echo "  2. if ~/.claude exists: mv ~/.claude ${BACKUP_PATH}"
  else
    echo "  2. --keep-claude set: leave ~/.claude in place"
  fi
  echo "  3. npm uninstall -g @thebassclef/lite (silent if absent)"
  echo "  4. npm install -g @thebassclef/lite@${VERSION}"
  if [ "$DELETE_GITHUB" -eq 1 ]; then
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      if [ "$AUTO_YES" -eq 1 ]; then
        echo "  5. list GitHub repos matching '*${GH_PATTERN}*' + auto-delete each (--yes)"
      else
        echo "  5. list GitHub repos matching '*${GH_PATTERN}*' + prompt-confirm delete each"
      fi
    else
      echo "  5. --delete-github set but gh not authenticated; would skip"
    fi
    echo "  6. rm -rf ${WORKDIR}"
    echo "  7. mkdir -p ${WORKDIR} && cd ${WORKDIR}"
    echo "  8. git init -q + empty fixture commit"
    echo "  9. bassclef init"
  else
    echo "  5. rm -rf ${WORKDIR}"
    echo "  6. mkdir -p ${WORKDIR} && cd ${WORKDIR}"
    echo "  7. git init -q + empty fixture commit"
    echo "  8. bassclef init"
  fi
  echo
  echo "No state changed. Remove --dry-run to execute."
  exit 0
fi

echo ">>> ${SCRIPT_NAME} starting (version=${VERSION} workdir=${WORKDIR})" >&2

# Step 0: optional upstream PAT install.
# Fires before the destructive steps so the operator sees the result up front.
# Reads from env var BASSCLEF_UPSTREAM_PAT (set before the curl pipe so the
# value never lands in shell history). Writes the PAT file + appends an
# idempotent export line to the operator's shell rc. Future shells on this
# profile export BASSCLEF_UPSTREAM_PAT automatically; cold-adopter smoke
# sessions can then run `GH_TOKEN=$BASSCLEF_UPSTREAM_PAT gh ...` for
# upstream bug filing.
if [ "$INSTALL_UPSTREAM_PAT" -eq 1 ]; then
  pat_value="${BASSCLEF_UPSTREAM_PAT:-}"
  if [ -z "$pat_value" ]; then
    echo "${SCRIPT_NAME}: --install-upstream-pat requires env var BASSCLEF_UPSTREAM_PAT" >&2
    echo "  recipe:  BASSCLEF_UPSTREAM_PAT=xxx curl -sSL ... | bash -s -- --install-upstream-pat ..." >&2
    exit 1
  fi
  # Write the PAT file. mkdir -p covers the config dir; chmod narrows access.
  mkdir -p "$(dirname "$PAT_PATH")"
  printf '%s\n' "$pat_value" > "$PAT_PATH"
  chmod 600 "$PAT_PATH"
  echo "${SCRIPT_NAME}: wrote ${PAT_PATH} (chmod 600)" >&2

  # Append idempotent export line to the operator's primary shell rc.
  # zsh is default on current macOS; bash fallback for older profiles.
  rc_file=""
  case "${SHELL:-/bin/zsh}" in
    *zsh) rc_file="${HOME}/.zshrc" ;;
    *bash) rc_file="${HOME}/.bashrc" ;;
    *) rc_file="${HOME}/.profile" ;;
  esac
  if [ ! -f "$rc_file" ]; then
    touch "$rc_file"
  fi
  if ! grep -qF "$PAT_EXPORT_MARKER" "$rc_file" 2>/dev/null; then
    {
      printf '\n%s\n' "$PAT_EXPORT_MARKER"
      printf '[ -f %s ] && export BASSCLEF_UPSTREAM_PAT="$(cat %s)"\n' "$PAT_PATH" "$PAT_PATH"
    } >> "$rc_file"
    echo "${SCRIPT_NAME}: appended export line to ${rc_file}" >&2
    echo "${SCRIPT_NAME}: open a new shell OR run: source ${rc_file}" >&2
  else
    echo "${SCRIPT_NAME}: ${rc_file} already has the export line (idempotent)" >&2
  fi
fi

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

# Step 3b: optional GitHub test-repo cleanup.
# Fires only on --delete-github. Lists repos under the authenticated gh
# user matching *${GH_PATTERN}* (default: bassclef-smoke-test), prompts
# per hit, and deletes on y. Silent + fail-soft on anything else:
# gh missing, not authenticated, no hits, operator declines → carry on.
if [ "$DELETE_GITHUB" -eq 1 ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "${SCRIPT_NAME}: --delete-github requested but gh not installed; skipping" >&2
  elif ! gh auth status >/dev/null 2>&1; then
    echo "${SCRIPT_NAME}: --delete-github requested but gh not authenticated; skipping" >&2
  else
    gh_user="$(gh api user --jq '.login' 2>/dev/null || echo unknown)"
    echo "${SCRIPT_NAME}: listing test repos under gh user '${gh_user}' matching '*${GH_PATTERN}*'" >&2
    hits="$(gh repo list "$gh_user" --limit 100 --json nameWithOwner \
            --jq ".[] | select(.nameWithOwner | test(\"${GH_PATTERN}\")) | .nameWithOwner" \
            2>/dev/null || true)"
    if [ -z "$hits" ]; then
      echo "${SCRIPT_NAME}: no matching GitHub repos" >&2
    else
      while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        if [ "$AUTO_YES" -eq 1 ]; then
          answer="y"
        else
          printf "${SCRIPT_NAME}: delete GitHub repo '%s'? [y/N] " "$repo" >&2
          read -r answer </dev/tty || answer="n"
        fi
        case "${answer:-n}" in
          y|Y|yes|YES)
            if gh repo delete "$repo" --yes >/dev/null 2>&1; then
              echo "${SCRIPT_NAME}:   deleted ${repo}" >&2
            else
              echo "${SCRIPT_NAME}:   delete failed for ${repo} (missing scope? requires 'delete_repo' PAT scope)" >&2
            fi
            ;;
          *)
            echo "${SCRIPT_NAME}:   skipped ${repo}" >&2
            ;;
        esac
      done <<< "$hits"
    fi
  fi
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
  git commit --allow-empty -m "chore: nuke-and-fresh-install fixture" -q
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
