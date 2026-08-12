#!/bin/bash
# install-git-hooks.sh
#
# One-time helper. Installs the traceability pre-commit hook into
# .git/hooks/pre-commit. Run once per fresh clone.
#
# Usage:
#   bash scripts/install-git-hooks.sh
#
# Idempotent: re-running the same command copies the current source
# again. If .git/hooks/pre-commit already exists AND was not put there
# by this script, the operator sees a warning and picks --force or
# --skip.
#
# Override: --force overwrites an existing hook without asking.
#           --dry-run prints what would happen; writes nothing.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "install-git-hooks: not in a git repo." >&2
  exit 1
fi

FORCE=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: $0 [--force] [--dry-run]"
      exit 0
      ;;
    *)
      echo "install-git-hooks: unknown arg: $arg" >&2
      echo "Usage: $0 [--force] [--dry-run]" >&2
      exit 3
      ;;
  esac
done

HOOK_SRC="$REPO_ROOT/scripts/pre-commit-traceability.sh"
HOOK_DST="$REPO_ROOT/.git/hooks/pre-commit"
HOOK_MARKER="# pre-commit-traceability.sh"

if [ ! -f "$HOOK_SRC" ]; then
  echo "install-git-hooks: source hook missing at $HOOK_SRC" >&2
  exit 1
fi

# Only worry about overwrite when an existing hook is present AND is
# not our own script. Our script carries a marker line so we recognize
# it on re-install.
if [ -f "$HOOK_DST" ]; then
  if grep -q "$HOOK_MARKER" "$HOOK_DST"; then
    action="reinstall"
  elif [ "$FORCE" = "1" ]; then
    action="overwrite (--force)"
  else
    echo "install-git-hooks: .git/hooks/pre-commit already exists and is not our hook." >&2
    echo "Re-run with --force to overwrite, or move the existing hook aside first." >&2
    exit 1
  fi
else
  action="install"
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "install-git-hooks: --dry-run set; would $action pre-commit hook at $HOOK_DST"
  exit 0
fi

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "install-git-hooks: $action complete."
echo "Hook location: $HOOK_DST"
echo "Fires on every commit that touches src/, scripts/, tests/, vite.config.ts, or docs/requirements/."
