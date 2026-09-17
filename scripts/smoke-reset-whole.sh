#!/usr/bin/env bash
# tier: upstream
#
# smoke-reset-whole.sh — reset the whole cold-adopter environment with
# snapshot + restore support.
#
# Composes with the existing scripts/smoke-reset.sh (which handles the
# core reset — global npm uninstall + ~/tmp/bassclef-smoke-test purge
# + optional ~/.claude/ backup). This script adds three things:
#
#   1. Snapshot target dirs to ~/tmp/bassclef-smoke-reset-backups/<ts>/
#      BEFORE the reset fires (RFC F6 fold — Cooper undo path).
#   2. --restore <ts> restores from a snapshot dir.
#   3. Auto-prune snapshot dirs older than 7 days (pre-mortem V3 fold —
#      Vogels self-prune so external cron is not load-bearing).
#
# Design refs (must-read):
#   docs/specs/smoke-evidence-capture.md § Interfaces § smoke-reset.sh --whole
#   docs/use-cases/UC-smoke-run.md § Main flow Step 1 + Extension 1a + 1b
#   docs/decompositions/smoke-evidence-capture.md § ResetController + Snapshot
#   docs/risk-ledgers/2026-09-18-smoke-evidence-capture-pre-mortem.md V3
#
# Flags:
#   --dry-run          print plan; write nothing; do not delegate
#   --restore <ts>     restore from ~/tmp/bassclef-smoke-reset-backups/<ts>/
#   --targets-file F   read snapshot targets from F (one path per line);
#                      default targets: ~/.claude/projects/<repo> +
#                      ~/tmp/bassclef-smoke-test
#                      (test uses this flag to point at fake dirs)
#   --backup-root DIR  where snapshots live (default: ~/tmp/bassclef-smoke-reset-backups)
#   --skip-delegate    do snapshot + prune only; skip the smoke-reset.sh --cold call
#                      (test uses this so the mock doesn't touch real home)
#   --help             print this help

set -euo pipefail

DRY_RUN=0
RESTORE_TS=""
TARGETS_FILE=""
BACKUP_ROOT="${HOME}/tmp/bassclef-smoke-reset-backups"
SKIP_DELEGATE=0
PRUNE_DAYS=7

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --restore) RESTORE_TS="$2"; shift 2 ;;
    --targets-file) TARGETS_FILE="$2"; shift 2 ;;
    --backup-root) BACKUP_ROOT="$2"; shift 2 ;;
    --skip-delegate) SKIP_DELEGATE=1; shift ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ---- default targets --------------------------------------------------------

resolve_targets() {
  if [ -n "$TARGETS_FILE" ]; then
    [ -f "$TARGETS_FILE" ] || { echo "smoke-reset-whole: targets file missing: $TARGETS_FILE" >&2; exit 1; }
    cat "$TARGETS_FILE"
  else
    printf '%s\n' \
      "${HOME}/.claude/projects/bassclef-cli" \
      "${HOME}/tmp/bassclef-smoke-test"
  fi
}

# ---- restore path -----------------------------------------------------------

if [ -n "$RESTORE_TS" ]; then
  SNAP_DIR="${BACKUP_ROOT}/${RESTORE_TS}"
  if [ ! -d "$SNAP_DIR" ]; then
    echo "smoke-reset-whole: snapshot dir not found: $SNAP_DIR" >&2
    exit 1
  fi

  echo "smoke-reset-whole: restoring from ${SNAP_DIR}" >&2
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    base=$(basename "$target")
    src="${SNAP_DIR}/${base}"
    if [ ! -e "$src" ]; then
      echo "  skip (no snapshot for ${base})" >&2
      continue
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  would restore ${src} -> ${target}" >&2
    else
      mkdir -p "$(dirname "$target")"
      rm -rf "$target"
      cp -R "$src" "$target"
      echo "  restored ${target}" >&2
    fi
  done < <(resolve_targets)
  exit 0
fi

# ---- snapshot path ----------------------------------------------------------

ISO_TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
SNAP_DIR="${BACKUP_ROOT}/${ISO_TS}"

echo "smoke-reset-whole: snapshotting to ${SNAP_DIR}" >&2

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$SNAP_DIR"
fi

snapshotted=0
while IFS= read -r target; do
  [ -z "$target" ] && continue
  base=$(basename "$target")
  if [ ! -e "$target" ]; then
    echo "  skip (target absent: ${target})" >&2
    continue
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  would snapshot ${target} -> ${SNAP_DIR}/${base}" >&2
  else
    cp -R "$target" "${SNAP_DIR}/${base}"
    echo "  snapshotted ${target}" >&2
    snapshotted=$((snapshotted + 1))
  fi
done < <(resolve_targets)

# ---- pre-mortem V3 fold — self-prune old snapshots --------------------------

if [ "$DRY_RUN" -eq 0 ] && [ -d "$BACKUP_ROOT" ]; then
  # find dirs older than N days; remove each. macOS + linux both support
  # -mtime +N on find.
  pruned=0
  while IFS= read -r old; do
    [ -z "$old" ] && continue
    [ "$old" = "$SNAP_DIR" ] && continue
    rm -rf "$old"
    pruned=$((pruned + 1))
  done < <(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -mtime +${PRUNE_DAYS} 2>/dev/null || echo "")
  [ "$pruned" -gt 0 ] && echo "smoke-reset-whole: pruned ${pruned} snapshot dir(s) older than ${PRUNE_DAYS} days" >&2
fi

# ---- delegate to existing smoke-reset.sh ------------------------------------

if [ "$SKIP_DELEGATE" -eq 1 ]; then
  echo "smoke-reset-whole: --skip-delegate — snapshotted ${snapshotted} target(s); skipped reset" >&2
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "smoke-reset-whole: would delegate to smoke-reset.sh --cold" >&2
  exit 0
fi

if [ -x "${SCRIPT_DIR}/smoke-reset.sh" ]; then
  echo "smoke-reset-whole: delegating to smoke-reset.sh --cold" >&2
  bash "${SCRIPT_DIR}/smoke-reset.sh" --cold
else
  echo "smoke-reset-whole: smoke-reset.sh not found at ${SCRIPT_DIR}/" >&2
  exit 1
fi
