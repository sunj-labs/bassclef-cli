#!/usr/bin/env bash
# tier: upstream
#
# smoke-bootstrap.sh — fetch all smoke-* scripts + shared libs from
# bassclef-cli via curl. One command; no git clone needed.
#
# Fetches ten files from raw.githubusercontent.com into a target dir,
# preserving the scripts/ + scripts/lib/ layout so the scripts source
# each other correctly.
#
# Design refs:
#   docs/runbooks/smoke.md — where this script slots into the runbook
#   docs/specs/smoke-evidence-capture.md § Interfaces
#
# Files fetched:
#   scripts/smoke-capture.sh
#   scripts/smoke-assert-hooks.sh
#   scripts/smoke-assert-skills.sh
#   scripts/smoke-drive-skills.sh
#   scripts/smoke-report.sh
#   scripts/smoke-reset.sh
#   scripts/smoke-reset-whole.sh
#   scripts/smoke-preflight.sh
#   scripts/lib/smoke-assert.sh
#   scripts/lib/smoke-schema.sh
#
# Flags:
#   --target DIR    where to land the files (default: ~/tmp/bassclef-smoke)
#   --ref REF       branch or tag to fetch from (default: main)
#   --dry-run       print the plan; fetch nothing
#   --help          print this help
#
# Exit codes:
#   0  all files fetched
#   1  usage or config error
#   2  one or more curl failures

set -euo pipefail

TARGET_DIR="${HOME}/tmp/bassclef-smoke"
REF="main"
DRY_RUN=0
REPO="sunj-labs/bassclef-cli"

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v curl >/dev/null 2>&1 || { echo "smoke-bootstrap: curl required" >&2; exit 1; }

BASE_URL="https://raw.githubusercontent.com/${REPO}/${REF}"

# The ten files. Space-separated relative paths under repo root.
FILES="scripts/smoke-capture.sh
scripts/smoke-assert-hooks.sh
scripts/smoke-assert-skills.sh
scripts/smoke-drive-skills.sh
scripts/smoke-report.sh
scripts/smoke-reset.sh
scripts/smoke-reset-whole.sh
scripts/smoke-preflight.sh
scripts/lib/smoke-assert.sh
scripts/lib/smoke-schema.sh"

echo "smoke-bootstrap: target ${TARGET_DIR}" >&2
echo "smoke-bootstrap: ref ${REF} on ${REPO}" >&2

fetched=0
failed=0
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  url="${BASE_URL}/${rel}"
  dest="${TARGET_DIR}/${rel}"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would fetch ${url}" >&2
    echo "        -> ${dest}" >&2
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  if curl -sfL "$url" -o "$dest"; then
    chmod +x "$dest"
    echo "  fetched ${rel}" >&2
    fetched=$((fetched + 1))
  else
    echo "  FAIL   ${rel} (${url})" >&2
    failed=$((failed + 1))
  fi
done <<< "$FILES"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "smoke-bootstrap: dry run complete (would fetch 10 files)" >&2
  exit 0
fi

echo "" >&2
echo "smoke-bootstrap: fetched ${fetched} file(s); ${failed} failure(s)" >&2

if [ "$failed" -gt 0 ]; then
  echo "" >&2
  echo "Some files failed. Retry after a moment (raw.githubusercontent.com" >&2
  echo "caches; a just-merged PR may take 30 seconds to propagate)." >&2
  exit 2
fi

echo "" >&2
echo "Next: set BCLI and run the smoke per docs/runbooks/smoke.md" >&2
echo "  export BCLI=${TARGET_DIR}" >&2
exit 0
