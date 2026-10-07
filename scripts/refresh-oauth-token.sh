#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# refresh-oauth-token.sh — one-command OAuth refresh for the docker-smoke harness.
#
# Parent ticket: sunj-labs/bassclef-cli#380
# Design chain: docs/use-cases/UC-script-cli-380-refresh-oauth-token.md
# Pre-mortem folds: docs/risk-ledgers/2026-10-06-cli-380-refresh-oauth-token.md
#
# Usage:
#   bash scripts/refresh-oauth-token.sh [--file PATH] [--dry-run] [--verify-only] [--no-backup]
#
# Default target: ~/.config/claude/oauth-token (per docker harness file-fallback at
#                 harness/docker/entry.sh L134 per cli#245)
#
# Preconditions:
#   - claude CLI on PATH
#   - operator subscription-authenticated on host (host claude works)
#   - target dir writable
#
# Postconditions (success):
#   - target file carries fresh OAuth token verified by probe
#   - old file backed up at <target>.bak-<ISO-timestamp> (unless --no-backup)
#   - file mode is 600
#
# Postconditions (failure):
#   - target file UNCHANGED (atomic contract — write only on probe PASS)
#   - stderr names the failure
#   - exit code per vocabulary below
#
# Exit codes:
#   0 — new token written + verified (or --verify-only PASS, or --dry-run PASS)
#   1 — setup-token failed OR token shape invalid (no match, bad length)
#   2 — probe against new/current token failed
#   3 — precondition fail OR flag conflict
#
# Luminaries:
#   lead: saltzer-schroeder (fail-safe defaults; chmod 600; backup; probe before write)
#   supporting: tony-hoare (pre/postcondition contracts), alan-cooper (one command, clear exit codes),
#               michael-feathers (Tier 0 strict TDD)

# R3 fold: umask 077 so new files land at mode 600 by default (defense in depth)
umask 077

# ---------- defaults ----------
DEFAULT_FILE="${HOME}/.config/claude/oauth-token"
TOKEN_MIN=90   # R10 fold: 90-120 byte window
TOKEN_MAX=120

# ---------- parse args ----------
target_file="$DEFAULT_FILE"
dry_run=0
verify_only=0
no_backup=0

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)         target_file="$2"; shift 2 ;;
    --dry-run)      dry_run=1; shift ;;
    --verify-only)  verify_only=1; shift ;;
    --no-backup)    no_backup=1; shift ;;
    --help|-h)      usage ;;
    *)              echo "ERROR: unknown flag: $1" >&2; exit 3 ;;
  esac
done

# R9 fold: --verify-only + --dry-run are mutually exclusive
if (( verify_only == 1 && dry_run == 1 )); then
  echo "ERROR: --verify-only and --dry-run are mutually exclusive." >&2
  echo "       --verify-only checks the current file; --dry-run shows the refresh plan." >&2
  echo "       Pick one. See --help for details." >&2
  exit 3
fi

# ---------- preconditions ----------
# R6 fold: command -v claude FIRST
if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude binary not on PATH." >&2
  echo "       Install Claude Code first (https://claude.com/claude-code), then retry." >&2
  exit 3
fi

target_dir=$(dirname "$target_file")
if [[ ! -d "$target_dir" ]]; then
  if ! mkdir -p "$target_dir" 2>/dev/null; then
    echo "ERROR: target dir does not exist and is not writable: $target_dir" >&2
    exit 3
  fi
fi

if [[ ! -w "$target_dir" ]]; then
  echo "ERROR: target dir is not writable: $target_dir" >&2
  echo "       Check permissions and retry." >&2
  exit 3
fi

# ---------- probe helper (R5 fold: isolated HOME) ----------
# Probes a token value in an isolated env so host Keychain cannot leak into the result.
# Returns 0 if probe passes ("hello" or similar), non-zero otherwise.
# NOTE: fake-claude in Tier 0 tests honors a sentinel in HOME to decide pass/fail,
# so we do NOT fully isolate HOME when the sentinel path matters. Real claude ignores
# HOME for OAuth validation (it checks the token against the auth server).
probe_token() {
  local token="$1"
  local probe_home; probe_home=$(mktemp -d)
  # Note: we keep PATH as-is (so claude resolves). We clear ANTHROPIC_API_KEY to force
  # OAuth path only. HOME points at a fresh dir so host Keychain is NOT reachable.
  # BUT: in tests, fake-claude lives on the fixture PATH; its behavior is set at build
  # time (mode baked into the script) + ignores HOME. So this works for both real and
  # fake claude.
  env PATH="$PATH" \
      HOME="$probe_home" \
      CLAUDE_CODE_OAUTH_TOKEN="$token" \
      ANTHROPIC_API_KEY="" \
      claude -p "say hello" >/dev/null 2>&1
  local rc=$?
  rm -rf "$probe_home" 2>/dev/null || true
  return $rc
}

# ---------- --verify-only ----------
if (( verify_only == 1 )); then
  if [[ ! -f "$target_file" ]]; then
    echo "ERROR: target file not present: $target_file" >&2
    exit 2
  fi
  current_token=$(tr -d '\n\r ' < "$target_file")
  if probe_token "$current_token"; then
    echo "PASS: token at $target_file passes probe."
    exit 0
  else
    echo "FAIL: token at $target_file failed probe (likely expired or revoked)." >&2
    echo "       Rerun without --verify-only to refresh." >&2
    exit 2
  fi
fi

# ---------- plan ----------
echo "Refresh plan:"
echo "  target file: $target_file"
echo "  backup:      $( ((no_backup==0)) && echo "yes (.bak-<timestamp>)" || echo "no (--no-backup set)" )"
echo "  current:     $( [[ -f "$target_file" ]] && echo "present ($(wc -c < "$target_file" | tr -d ' ') bytes, mode $(stat -f '%A' "$target_file" 2>/dev/null || stat -c '%a' "$target_file"))" || echo "absent" )"
echo "  procedure:   claude setup-token → extract → length check (${TOKEN_MIN}-${TOKEN_MAX}) → probe → atomic write"

if (( dry_run == 1 )); then
  echo "DRY-RUN: no changes made."
  exit 0
fi

# ---------- fire setup-token ----------
echo ""
echo "A browser will open for OAuth. Follow the prompts; return here when done."
echo ""

# R13 fold: trap to clean up tempfiles
tmp_capture=$(mktemp)
tmp_new=$(mktemp)
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
  rm -f "$tmp_capture" "$tmp_new" 2>/dev/null || true
}
trap cleanup EXIT

if ! claude setup-token > "$tmp_capture" 2>&1; then
  echo "ERROR: claude setup-token failed. Output:" >&2
  cat "$tmp_capture" >&2
  exit 1
fi

# ---------- extract token (R4 fold: regex anchor + length check backstop) ----------
new_token=$(grep -oE 'sk-ant-oat01-[A-Za-z0-9_-]+' "$tmp_capture" | tail -1)
if [[ -z "$new_token" ]]; then
  echo "ERROR: could not extract OAuth token from setup-token output." >&2
  echo "       Captured output above. Expected a sk-ant-oat01-... pattern." >&2
  exit 1
fi

token_len=${#new_token}
if (( token_len < TOKEN_MIN || token_len > TOKEN_MAX )); then
  echo "ERROR: extracted token length $token_len bytes outside expected window ${TOKEN_MIN}-${TOKEN_MAX}." >&2
  echo "       Token shape may have changed. Confirm manually and update script if needed." >&2
  exit 1
fi

# ---------- probe new token ----------
echo "Probing new token..."
if ! probe_token "$new_token"; then
  echo "ERROR: new token failed probe. File unchanged." >&2
  echo "       Check your subscription state and retry." >&2
  exit 2
fi
echo "Probe PASS."

# ---------- backup current file (R2 fold: timestamped, no overwrite) ----------
if [[ -f "$target_file" ]] && (( no_backup == 0 )); then
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  backup_path="${target_file}.bak-${ts}"
  # Loop in case same-second collision
  i=0
  while [[ -e "$backup_path" ]]; do
    i=$((i+1))
    backup_path="${target_file}.bak-${ts}-${i}"
  done
  cp -p "$target_file" "$backup_path"
  echo "Backup: $backup_path"
fi

# ---------- atomic write (R1 fold: write to tmp on same filesystem + mv) ----------
# Write new token to a tempfile in the same dir, then rename to target.
printf '%s' "$new_token" > "$tmp_new"
chmod 600 "$tmp_new"

tmp_sibling="${target_file}.new.$$"
mv "$tmp_new" "$tmp_sibling"
mv "$tmp_sibling" "$target_file"

# R3 fold: belt-and-suspenders chmod 600
chmod 600 "$target_file"

echo "PASS: refreshed $target_file (${token_len} bytes)."
exit 0
