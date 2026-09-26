#!/usr/bin/env bash
# tier: standard
#
# smoke-drives-registry.sh — DriveConfig entity per cli#254 decompose doc.
#
# Registry of interactive skill drives. Function-based lookup for bash 3.2
# portability (macOS default; Debian bash 5 in CI both work).
#
# Consumers: harness/docker/entry.sh Step 8 iterates the registry to fire drives.

set -euo pipefail

if [[ -n "${_SMOKE_DRIVES_REGISTRY_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SMOKE_DRIVES_REGISTRY_LOADED=1

readonly SMOKE_DRIVES_REGISTRY_SCHEMA_VERSION="1"

# smoke_drives_list — emit registered drive slugs, one per line, sorted.
smoke_drives_list() {
  printf '%s\n' "launch" "onboard-repo" "riff"
}

# smoke_drives_lookup SLUG FIELD — emit the requested field for the slug.
# Fields: script | timeout | artifacts
# Returns:
#   0 on match; 1 on unknown slug or field.
smoke_drives_lookup() {
  local slug="${1:?SLUG required}"
  local field="${2:?FIELD required}"
  local entry

  case "$slug" in
    onboard-repo) entry="scripts/smoke-drive-interactive-onboard-repo.sh:180:.claude/settings.json,substrate.config.md" ;;
    riff)         entry="scripts/smoke-drive-interactive-riff.sh:300:docs/prototypes/*/index.html" ;;
    launch)       entry="scripts/smoke-drive-launch.sh:240:docs/prototypes/*/index.html,docs/specs/*.md" ;;
    *) return 1 ;;
  esac

  case "$field" in
    script)    echo "$entry" | cut -d: -f1 ;;
    timeout)   echo "$entry" | cut -d: -f2 ;;
    artifacts) echo "$entry" | cut -d: -f3 ;;
    *) return 1 ;;
  esac
}

# Convenience wrappers per field for callers that prefer per-field verbs.
smoke_drives_get_script()    { smoke_drives_lookup "$1" script; }
smoke_drives_get_timeout()   { smoke_drives_lookup "$1" timeout; }
smoke_drives_get_artifacts() { smoke_drives_lookup "$1" artifacts; }
