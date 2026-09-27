#!/usr/bin/env bash
# tier: standard
# fake_gh.sh — deterministic stand-in for the `gh` binary.
#
# Used by scripts/tests/smoke-drive-generic.test.sh to characterize
# the gh-inject-smoke-label shim without touching real GitHub.
#
# Behavior:
#   - Logs invocation as one-line JSON to $SMOKE_GH_LOG
#     (default: /tmp/fake_gh.log)
#   - For `gh issue create ...` — prints a fake ticket number to stdout
#     (extracted from $SMOKE_GH_FAKE_ISSUE_NUM or defaults to 99999)
#   - For `gh issue list ...` — prints a JSON array from $SMOKE_GH_FAKE_LIST
#     (or empty array [])
#   - For any other subcommand — exits 0 silently
#   - Never touches the network. Never hits real GitHub.

set -u

log="${SMOKE_GH_LOG:-/tmp/fake_gh.log}"
mkdir -p "$(dirname "$log")" 2>/dev/null || true

# Serialize args as JSON array (bash 3.2 portable)
args_json=""
for a in "$@"; do
  esc=$(printf '%s' "$a" | sed 's/\\/\\\\/g; s/"/\\"/g')
  if [ -z "$args_json" ]; then
    args_json="\"$esc\""
  else
    args_json="$args_json,\"$esc\""
  fi
done

printf '{"argv":[%s]}\n' "$args_json" >> "$log"

case "${1:-}" in
  issue)
    case "${2:-}" in
      create)
        num="${SMOKE_GH_FAKE_ISSUE_NUM:-99999}"
        printf 'https://github.com/example/repo/issues/%s\n' "$num"
        exit 0
        ;;
      list)
        printf '%s\n' "${SMOKE_GH_FAKE_LIST:-[]}"
        exit 0
        ;;
      close)
        exit 0
        ;;
    esac
    ;;
esac

exit 0
