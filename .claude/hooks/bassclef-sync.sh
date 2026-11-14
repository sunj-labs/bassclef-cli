#!/bin/bash
# tier: lite
# description: Retagged standard → lite per #1301 concentric rule (ADR-052 D1) —
# Retagged standard → lite per #1301 concentric rule (ADR-052 D1) —
# this dispatcher IS the sync entry point every adopter vendors into
# .claude/hooks/bassclef-sync.sh. Without ship at lite, lite adopters
# have no sync at all. Closes #1301 sister file.
# BASSCLEF_SYNC_VERSION=thin-pointer-2026-07-28a
# ^^ DO NOT REMOVE — used by bassclef's drift check + Layer 3 self-heal
#    detection (per ADR-032). Version string format: descriptor-YYYY-MM-DD.
#
# Thin-pointer bassclef-sync dispatcher.
#
# Source of truth for the dispatcher consumers vendor into their
# .claude/hooks/bassclef-sync.sh. See standards/bassclef-source-config.md
# for the .bassclef-source.json schema this dispatcher reads.
#
# Two paths, tried in order:
#
#   1. Sibling fast-path (local dev, desktop, multi-repo workspaces)
#      — if $CWD/../bassclef/presence/install/bassclef-sync.template.sh
#        exists, exec it directly. Always-current because the file is
#        read fresh on every fire.
#
#   2. Curl fallback (Cloud Env, mobile, fresh sandboxes, CI)
#      — read .bassclef-source.json for upstream URL + auth metadata,
#        fetch the tarball, extract, exec the included template.
#
# When neither path works, the dispatcher prints a plain-language
# explanation with three resolution paths (public adopter / local dev
# / private fork). Always exits 0 so SessionStart hooks don't crash;
# consumers that want CI fail-fast behavior should pre-check inside
# their workflow.
#
# Versioning: bump BASSCLEF_SYNC_VERSION when the dispatcher's
# semantics change. Format: YYYY-MM-DD or descriptor-YYYY-MM-DD.
#
#   thin-pointer-2026-07-09: pointer-file rename cure (bet 2026-07-09a).
#                            Adopters onboarded before 2026-06-20 rename carry
#                            .canonical-source.json. Dispatcher now reads new
#                            name first, falls back to old, and self-heals
#                            (writes new name from old content; removes old on
#                            second cycle per Hoare two-step atomic). Fires
#                            before auto_sync check + Path 2 curl fallback.
#                            Overrides: SKIP_SELF_HEAL_POINTER=1 skips write.
#                            Prior version: thin-pointer-2026-06-29c.
#   thin-pointer-2026-06-29c: fallback message names the cure (bet 29e WU-10).
#                              emit_error() now lists option 4 — the curl
#                              one-liner that runs migrate-adopter-references.sh
#                              for adopters whose tree carries leftover
#                              canonical-* references from the 2026-06-20 rename
#                              event. Discoverable cure inside the error itself;
#                              the adopter does not need to read the wiki.
#                              Prior version: thin-pointer-2026-06-29b.
#   thin-pointer-2026-06-29b: auto-invocation added (bet 29e WU-4). Detection
#                              step now runs the migrate script automatically
#                              via curl-pipe + continues to Path 1/Path 2.
#                              SKIP_AUTO_INVOKE=1 falls back to WU-2's BLOCKED
#                              behavior. Passes BASSCLEF_DISPATCHER_TEMPLATE
#                              to migrate when sibling template available.
#                              Prior version: thin-pointer-2026-06-29.
#   thin-pointer-2026-06-29: canonical-* reference detection step added
#                            (bet 29e WU-2). Scans adopter .claude/settings.json
#                            + vendored bassclef-sync.sh for refs surviving the
#                            2026-06-20 rename. Emits BLOCKED + exits 0. WU-4 will
#                            replace exit with auto-invocation of migrate-adopter-
#                            references.sh. Override: SKIP_CANONICAL_DETECTION=1.
#                            Prior version: thin-pointer-2026-06-22.
#   thin-pointer-2026-06-22: version-detection helper added per ADR-032
#                            (Layer 2 two-stage rocket). __bassclef_dispatcher_version
#                            function exposes BASSCLEF_SYNC_VERSION to external
#                            tooling (Layer 3 self-heal in WU-4). No protocol
#                            break; purely additive. Prior version: thin-pointer-2026-06-13.
#   thin-pointer-2026-06-13: auto_sync flag check — dispatcher short-
#                            circuits when .bassclef-source.json has
#                            auto_sync:false or the field absent. Per
#                            bassclef#939. Prior version: 2026-05-15.
#   thin-pointer-2026-05-15: friendly error messages with three
#                            resolution paths. Closes bassclef#715
#                            Layer A. Prior version: 2026-05-02.

# === Version-detection helper (per ADR-032) ===
# Layer 3 self-heal (WU-4 of bet 2026-06-22b) calls this to detect
# bootstrap version drift. External tooling can also grep
# BASSCLEF_SYNC_VERSION from line 3, but the function gives a stable
# programmatic interface that survives header-comment reformatting.
__bassclef_dispatcher_version() {
  echo "thin-pointer-2026-07-09"
}

# === Pointer-file fallback + self-heal (bet 2026-07-09a) ===
#
# Every adopter onboarded before the 2026-06-20 canonical → bassclef
# rename carries .canonical-source.json. The dispatcher previously read
# .bassclef-source.json only; stale adopters saw substrate refuse to
# load. These two functions cure the class:
#
#   bassclef_sync_resolve_pointer_file(cwd)
#     Echoes the path of the pointer file to use. Prefers new name;
#     falls back to old name; echoes empty when neither exists.
#
#   bassclef_sync_self_heal_pointer(cwd)
#     Two-step atomic rename per Tony Hoare. First cycle: writes new
#     name from old content, keeps old file for safety. Second cycle:
#     removes old file when new already exists. Never deletes new.
#     Honors SKIP_SELF_HEAL_POINTER=1 for one-shot recovery scenarios.
#
# Composing luminaries:
#   @luminary linus-torvalds — we-dont-break-adopters (ADR-031)
#   @luminary jerome-saltzer-and-michael-schroeder — complete mediation
#   @luminary tony-hoare — pre/post conditions on two-step rename
#   @luminary michael-feathers — characterization tests using real Quorum
#
# Tests: .claude/hooks/tests/bassclef-sync-pointer-fallback.test.sh
# Refs: bassclef-upstream#679
bassclef_sync_resolve_pointer_file() {
  local cwd="${1:-$CWD}"
  local new="$cwd/.bassclef-source.json"
  local old="$cwd/.canonical-source.json"
  if [ -f "$new" ]; then
    echo "$new"
  elif [ -f "$old" ]; then
    echo "$old"
  else
    echo ""
  fi
}

# bassclef_sync_bundled_substrate_present <cwd>
#
# Returns 0 (yes) when .claude/hooks/, .claude/rules/, .claude/skills/ all
# exist AND contain at least one file (recursively). Returns 1 (no) when
# any of those conditions fails.
#
# Cures the npm-only cold adopter false-error class per
# bassclef-upstream#1849. The dispatcher was designed for peer-checkout
# OR source-config models. Neither works for anonymous adopters against
# private repos. But the npm bundle already unpacks substrate at install
# time. The fetch failure is not a real failure; this check catches the
# steady state and lets the dispatcher exit silently.
#
# Composes with:
#   @luminary alan-cooper — Sam persona; silent-on-success matches user model
#   @luminary donald-norman — signifier; false-positive banner erodes real signal
#   @luminary linus-torvalds — adopter contract; npm bundle IS the substrate
#   @luminary michael-feathers — characterization tests over 3 install shapes
#
# Tests: .claude/hooks/tests/bassclef-sync-bundled-substrate-check.test.sh
# Refs: bassclef-upstream#1849
bassclef_sync_bundled_substrate_present() {
  local cwd="${1:-}"
  if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
    return 1
  fi
  local _dir
  for _dir in .claude/hooks .claude/rules .claude/skills; do
    if [ ! -d "$cwd/$_dir" ]; then
      return 1
    fi
    # Nonempty check: at least one file anywhere under the dir.
    if [ -z "$(find "$cwd/$_dir" -mindepth 1 -maxdepth 4 -type f -print -quit 2>/dev/null)" ]; then
      return 1
    fi
  done
  return 0
}

bassclef_sync_self_heal_pointer() {
  local cwd="${1:-$CWD}"
  if [ "${SKIP_SELF_HEAL_POINTER:-0}" = "1" ]; then
    return 0
  fi
  local new="$cwd/.bassclef-source.json"
  local old="$cwd/.canonical-source.json"
  # Second cycle: both exist → remove old, keep new (Hoare postcondition)
  if [ -f "$new" ] && [ -f "$old" ]; then
    rm -f "$old"
    return 0
  fi
  # First cycle: only old exists → write new from old content, keep old for safety
  if [ ! -f "$new" ] && [ -f "$old" ]; then
    cp "$old" "$new" 2>/dev/null || return 0
    # Emit a one-line note so operator sees the self-heal firing
    echo "bassclef-sync: renamed .canonical-source.json → .bassclef-source.json (auto-heal; original kept for one session)" >&2
    return 0
  fi
  # Only new exists OR neither exists → no-op
  return 0
}

# bassclef_sync_self_heal_pointer_content(cwd)
#   Rewrites drift in .bassclef-source.json content on adopters onboarded
#   before the 2026-06-20 canonical → bassclef rename.
#     - source_url: sunj-labs/canonical -> sunj-labs/bassclef
#     - token_env:  CANONICAL_TOKEN     -> BASSCLEF_TOKEN
#   Preserves auth_method (Bearer during beta), auto_sync flag, and every
#   other field. Idempotent — no-op when content already uses new names.
#   Honors SKIP_SELF_HEAL_POINTER_CONTENT=1 for one-shot recovery cases.
#   Per bet 2026-07-09c WU-2 (bassclef-upstream#680). Sister to
#   bassclef_sync_self_heal_pointer (filename cure from bet 09a).
bassclef_sync_self_heal_pointer_content() {
  local cwd="${1:-$CWD}"
  if [ "${SKIP_SELF_HEAL_POINTER_CONTENT:-0}" = "1" ]; then
    return 0
  fi
  local pointer="$cwd/.bassclef-source.json"
  if [ ! -f "$pointer" ]; then
    return 0
  fi
  # Detect drift — cheap grep before invoking jq
  local drift=0
  if grep -q "sunj-labs/canonical" "$pointer" 2>/dev/null; then
    drift=1
  fi
  if grep -q "CANONICAL_TOKEN" "$pointer" 2>/dev/null; then
    drift=1
  fi
  if [ "$drift" = "0" ]; then
    return 0
  fi
  # Rewrite via jq — preserves JSON structure and untouched fields
  local new_json
  new_json=$(jq '
    (if (.source_url // "" | contains("sunj-labs/canonical"))
      then .source_url = (.source_url | sub("sunj-labs/canonical"; "sunj-labs/bassclef"))
      else . end)
    | (if (.token_env // "") == "CANONICAL_TOKEN"
      then .token_env = "BASSCLEF_TOKEN"
      else . end)
    | (if (.comment // "" | contains("sunj-labs/canonical"))
      then .comment = (.comment | gsub("sunj-labs/canonical"; "sunj-labs/bassclef"))
      else . end)
  ' "$pointer" 2>/dev/null)
  if [ -n "$new_json" ]; then
    echo "$new_json" > "$pointer.tmp" 2>/dev/null && mv "$pointer.tmp" "$pointer" 2>/dev/null
    echo "bassclef-sync: cured .bassclef-source.json content drift (source_url + token_env → bassclef names)" >&2
  fi
  return 0
}

# bassclef_sync_self_heal_claude_md_content(cwd)
#   Inserts @.claude/bassclef-orientation.md after the first heading in
#   adopter CLAUDE.md when missing. Rewrites stale sunj-labs/canonical
#   URL references + ../canonical path references. Preserves adopter-
#   authored sections. Backs up to CLAUDE.md.bak.<ts> before edit.
#   Idempotent — no-op on cured content.
#   Honors SKIP_SELF_HEAL_CLAUDE_MD_CONTENT=1 for adopters who want to
#   own their CLAUDE.md fully.
#   Per bet 2026-07-09c WU-3 (bassclef-upstream#687 Path 2). Sister to
#   bassclef_sync_self_heal_pointer_content (WU-2 pointer content cure).
bassclef_sync_self_heal_claude_md_content() {
  local cwd="${1:-$CWD}"
  if [ "${SKIP_SELF_HEAL_CLAUDE_MD_CONTENT:-0}" = "1" ]; then
    return 0
  fi
  local file="$cwd/CLAUDE.md"
  if [ ! -f "$file" ]; then
    return 0
  fi
  local drift_import=0
  local drift_url=0
  local drift_path=0
  if ! grep -q "@.claude/bassclef-orientation.md" "$file" 2>/dev/null; then
    drift_import=1
  fi
  if grep -q "sunj-labs/canonical" "$file" 2>/dev/null; then
    drift_url=1
  fi
  if grep -q "\\.\\./canonical" "$file" 2>/dev/null; then
    drift_path=1
  fi
  if [ "$drift_import" = "0" ] && [ "$drift_url" = "0" ] && [ "$drift_path" = "0" ]; then
    return 0
  fi
  local backup_ts
  backup_ts=$(date +%s)
  cp "$file" "${file}.bak.${backup_ts}" 2>/dev/null
  if [ "$drift_import" = "1" ]; then
    awk 'BEGIN{added=0} /^# / && added==0 {print; print ""; print "@.claude/bassclef-orientation.md"; added=1; next} {print}' \
      "$file" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" 2>/dev/null
  fi
  sed 's|sunj-labs/canonical|sunj-labs/bassclef|g; s|\.\./canonical|../bassclef|g' \
    "$file" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" 2>/dev/null
  echo "bassclef-sync: cured CLAUDE.md content drift (@import + canonical references → bassclef; backup at ${file}.bak.${backup_ts})" >&2
  return 0
}

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
cd "$CWD"

# Opt-out sentinel (bassclef#119): repos that must NOT inherit substrate.
if [ -f "$CWD/.no-bassclef-sync" ]; then
  echo "Bassclef substrate sync: skipped (.no-bassclef-sync sentinel present)."
  exit 0
fi

# === SELF_MODE detection (#929 — closes dispatcher-level bypass of #915) ===
# Sister to Section 0a in .claude/hooks/bassclef-sync.sh (which shipped in
# #915 PR #920 and guards the sync flow). This guard sits earlier in the
# call chain — at the dispatcher — so canonical-* auto-invoke + auto_sync
# fetch + Path 1 / Path 2 branches ALL skip when the current repo is the
# substrate source (bassclef or bassclef-upstream).
#
# Rationale: session 26g SessionStart re-symlinked ~63 hooks in
# bassclef-upstream despite #915. The project hook's SELF_MODE fired but
# only AFTER the dispatcher had already invoked the migrate script + fired
# other paths that touched the tree. Guard early = complete mediation.
#
# Env override SKIP_SELF_MODE_DETECTION=1 forces SELF_MODE=0 regardless
# of remote — for adopter forks of bassclef-upstream that legitimately
# want the sync flow.
#
# Non-breaking for adopters per ADR-031: SELF_MODE returns 0 for any repo
# whose git remote is NOT sunj-labs/bassclef or sunj-labs/bassclef-upstream.
# All 5 existing adopters keep their normal recovery + sync paths.
__bassclef_dispatcher_detect_self_mode() {
  local cwd="${1:-.}"

  # Env override wins
  if [ "${SKIP_SELF_MODE_DETECTION:-0}" = "1" ]; then
    echo "0"
    return 0
  fi

  # No git → not substrate source
  command -v git >/dev/null 2>&1 || { echo "0"; return 0; }

  # Get remote origin URL
  local remote_url
  remote_url=$(git -C "$cwd" config --get remote.origin.url 2>/dev/null)
  if [ -z "$remote_url" ]; then
    echo "0"
    return 0
  fi

  # Match sunj-labs/(bassclef|bassclef-upstream) with optional .git suffix
  # HTTPS: https://github.com/sunj-labs/bassclef.git
  # SSH:   git@github.com:sunj-labs/bassclef-upstream.git
  if echo "$remote_url" | grep -qE 'sunj-labs/(bassclef|bassclef-upstream)(\.git)?$'; then
    echo "1"
    return 0
  fi

  echo "0"
  return 0
}

__DISPATCHER_SELF_MODE=$(__bassclef_dispatcher_detect_self_mode "$CWD")
if [ "$__DISPATCHER_SELF_MODE" = "1" ]; then
  # #895: park user-scope orphans that shadow project scope before exit.
  # Without this, pre-existing symlinks planted by sibling syncs (POA,
  # twoDo, utilities) shadow bassclef-upstream's project scope in the
  # Claude Code menu — 92 skills appear twice. The parking helper leaves
  # real user-scope dirs (operator-authored content) untouched per its
  # v3 contract. Adopters never hit this path (SELF_MODE=0 for their
  # remotes per __bassclef_dispatcher_detect_self_mode).
  #
  # Override: SKIP_SELF_MODE_PARKING=1 for one-shot recovery scenarios.
  if [ "${SKIP_SELF_MODE_PARKING:-0}" != "1" ]; then
    __parking_helper="$CWD/scripts/bassclef-orphan-parking.sh"
    if [ -x "$__parking_helper" ]; then
      for __surface in skills agents hooks; do
        __user_surface="$HOME/.claude/$__surface"
        __project_surface="$CWD/.claude/$__surface"
        if [ -d "$__user_surface" ] && [ -d "$__project_surface" ]; then
          # v4 (bassclef-upstream#1077): pass BOTH user + project settings.json
          # as variadic 5th+ args. Parking helper unions the $HOME wirings
          # across both files. Any hook wired at $HOME by either settings
          # scope is preserved. Missing paths silently skip (helper v4 contract).
          bash "$__parking_helper" "$__user_surface" "$__project_surface" "$HOME/.claude" "$__surface" "$HOME/.claude/settings.json" "$CWD/.claude/settings.json" 2>/dev/null || true
        fi
      done
    fi
  fi
  echo "Bassclef dispatcher SELF_MODE — skipping sync in substrate source repo." >&2
  echo "  (Override with SKIP_SELF_MODE_DETECTION=1 for adopter forks;" >&2
  echo "   SKIP_SELF_MODE_PARKING=1 to skip user-scope orphan parking.)" >&2
  exit 0
fi

# === auto_sync flag check (bassclef#939) ===
#
# Per bassclef#939, fresh consumers default to OFF — the dispatcher
# only fetches when the consumer explicitly opts in via auto_sync: true
# in .bassclef-source.json. Cold adopters get a one-line note + the
# opt-in path instead of opaque auto-fetch.
#
# Default behavior on absence (file or field): OFF.
#
# Self-heal first (bet 2026-07-09a): stale adopters carrying
# .canonical-source.json get the file renamed to .bassclef-source.json
# so this pre-check sees the correct file. Second cycle drops the old.
bassclef_sync_self_heal_pointer "$CWD"
# Content-drift cure runs AFTER filename cure so the file we rewrite exists at the new name.
bassclef_sync_self_heal_pointer_content "$CWD"
# CLAUDE.md content cure runs at same lifecycle point — before Path 1 / Path 2 pick.
bassclef_sync_self_heal_claude_md_content "$CWD"
SOURCE_FILE_PRECHECK=$(bassclef_sync_resolve_pointer_file "$CWD")
if [ -n "$SOURCE_FILE_PRECHECK" ] && [ -f "$SOURCE_FILE_PRECHECK" ]; then
  AUTO_SYNC=$(jq -r '.auto_sync // false' "$SOURCE_FILE_PRECHECK" 2>/dev/null)
  if [ "$AUTO_SYNC" != "true" ]; then
    cat <<NOTE
### bassclef-sync — auto-update is OFF

Bassclef can keep your skills, rules, and agents current at every
session start by pulling its latest substrate. It's off by default
for fresh repos so nothing fetches without your say-so.

Turn on anytime by saying "enable auto-sync" or by setting:

    "auto_sync": true

in .bassclef-source.json. Run a manual sync once with:

    bash .claude/hooks/bassclef-sync.sh

More: https://github.com/sunj-labs/bassclef/blob/main/standards/bassclef-source-config.md

NOTE
    exit 0
  fi
fi

# === Plain-language error printer ===
#
# Args: $1 = short heading, $2 = context paragraph (one or more sentences).
# Always exits 0 to keep SessionStart hooks non-blocking.
emit_error() {
  local heading="$1"
  local context="$2"
  cat <<HEADER

### bassclef-sync — $heading

$context

Three ways to fix this:

  1) PUBLIC adopters (most common)
     Edit .bassclef-source.json to point at the public release tarball:

       {
         "source_url":  "https://github.com/sunj-labs/bassclef/releases/latest/download/substrate.tar.gz",
         "auth_method": "none",
         "token_env":   "",
         "comment":     "Public bassclef substrate. No auth needed."
       }

     Pre-launch note: while bassclef is still private, the public
     release URL above may not yet exist. Until it does, use option 3.

  2) LOCAL DEV — clone bassclef alongside this repo

       cd ../ && git clone https://github.com/sunj-labs/bassclef.git

     Re-run your session. The dispatcher uses the local checkout via
     the sibling fast-path; no auth needed.

  3) PRIVATE / pre-launch — create a fine-grained GitHub PAT

       a) GitHub -> Settings -> Developer settings -> Personal access tokens
          -> Fine-grained -> Generate new token
       b) Resource owner: sunj-labs
       c) Repository access: select sunj-labs/bassclef only
       d) Permissions -> Repository -> Contents -> Read
       e) Set the token as BASSCLEF_TOKEN in your environment:
            CI:         gh secret set BASSCLEF_TOKEN -R <your-org/your-repo>
            Local:      export BASSCLEF_TOKEN=<paste>
            Cloud Code: set BASSCLEF_TOKEN in your environment config

  4) STALE REFERENCES — your repo installed bassclef before 2026-06-29

       If your tree carries leftover canonical-* references from the
       2026-06-20 rename event, refresh them in place by running the
       migrate script directly:

         curl -sL https://raw.githubusercontent.com/sunj-labs/bassclef/main/scripts/migrate-adopter-references.sh \\
           | bash -s -- --apply "\$CWD"

       Open a fresh Claude Code session afterward. The fresh dispatcher
       carries detection that runs the cure automatically when needed.

  More: https://github.com/sunj-labs/bassclef/blob/main/standards/bassclef-source-config.md
        https://github.com/sunj-labs/bassclef/wiki/Troubleshooting#substrate-fails-to-load-and-you-do-not-see-the-self-heal-banner

HEADER
  exit 0
}

# === Recovery script resolver + checksum verifier ===
#
# Per goal 2026-08-27 step 7 PR #1 — cures external security review HIGH
# finding on the self-heal curl|bash fallback (source audit tracked in
# operator-only artifact; not shipped to public bassclef).
#
# Two functions cover Adam's Options A (bundle local) + B (checksum on curl).
#
# @pattern strategy (RecoveryScriptResolver picks one of three sources)
# @pattern guard-clause (verify_checksum fails loud on mismatch)

# resolve_recovery_script — prints one of:
#   LOCAL:<path>        env override set + file exists
#   SIBLING:<path>      sibling checkout has the script
#   CURL:<url>|<sha>    neither available; use curl with checksum
#
# Priority chain per docs/decompositions/2026-08-27-step-7-pr-1-dispatcher-cure-responsibilities.md
resolve_recovery_script() {
  # Priority 1 — env override
  if [ -n "${BASSCLEF_RECOVERY_SCRIPT_PATH:-}" ] && [ -f "$BASSCLEF_RECOVERY_SCRIPT_PATH" ]; then
    printf 'LOCAL:%s\n' "$BASSCLEF_RECOVERY_SCRIPT_PATH"
    return 0
  fi

  # Priority 2 — sibling checkout (matches SIBLING_TEMPLATE pattern at L594)
  local sibling_script="${CWD:-$(pwd)}/../bassclef/scripts/migrate-adopter-references.sh"
  if [ -f "$sibling_script" ]; then
    printf 'SIBLING:%s\n' "$sibling_script"
    return 0
  fi

  # Priority 3 — curl fallback with checksum sidecar
  local recovery_url="https://raw.githubusercontent.com/sunj-labs/bassclef/main/scripts/migrate-adopter-references.sh"
  local sha_url="${recovery_url}.sha256"
  printf 'CURL:%s|%s\n' "$recovery_url" "$sha_url"
  return 0
}

# verify_checksum <file> <expected_sha256>
# Returns 0 on match; non-zero + loud stderr on mismatch or missing tool.
# @luminary saltzer-schroeder — complete mediation; no silent pass.
verify_checksum() {
  local file="$1"
  local expected="$2"
  local computed=""

  if command -v shasum >/dev/null 2>&1; then
    computed=$(shasum -a 256 "$file" 2>/dev/null | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    computed=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
  else
    echo "verify_checksum: neither shasum nor sha256sum found in PATH" >&2
    echo "verify_checksum: install one before continuing" >&2
    return 2
  fi

  if [ -z "$computed" ]; then
    echo "verify_checksum: could not compute SHA-256 of $file" >&2
    return 3
  fi

  if [ "$computed" = "$expected" ]; then
    return 0
  fi

  echo "verify_checksum: SHA-256 mismatch on $file" >&2
  echo "verify_checksum: expected: $expected" >&2
  echo "verify_checksum: computed: $computed" >&2
  return 1
}

# === Canonical-* reference detection (per bet 29e WU-2) ===
#
# Self-heal for adopters carrying canonical-* references from the
# 2026-06-20 rename. Scans the adopter .claude/ tree at session-start
# BEFORE Path 1 / Path 2. When canonical-* refs are found, emits a
# BLOCKED block naming the recovery command (curl one-liner shipped
# in WU-3 of bet 29e) and exits 0 so SessionStart stays non-blocking.
#
# WU-2 emits BLOCKED + exits. WU-4 will rewrite this block to auto-
# invoke the recovery and continue the dispatcher chain.
#
# Override: SKIP_CANONICAL_DETECTION=1 bypasses the scan. Reserved for
# migration scripts; not for routine adopter use.
#
# Primary lens: @luminary michael-nygard — self-healing integration
# point per Release It! Stability Patterns. Composing lenses:
# @luminary jerome-saltzer-and-michael-schroeder (complete mediation —
# every session-start sees the scan), @luminary tony-hoare (when no
# canonical refs found, scan is silent; postcondition holds), @luminary
# john-ousterhout (deep dispatcher hides migration complexity).
if [ "${SKIP_CANONICAL_DETECTION:-0}" != "1" ]; then
  CANONICAL_FINDINGS=()

  # Surface 2: settings.json additionalDirectories contains "canonical"
  SETTINGS_PATH="$CWD/.claude/settings.json"
  if [ -f "$SETTINGS_PATH" ]; then
    STALE_DIRS=$(jq -r '.permissions.additionalDirectories // [] | .[] | select(test("canonical"))' "$SETTINGS_PATH" 2>/dev/null || true)
    if [ -n "$STALE_DIRS" ]; then
      CANONICAL_FINDINGS+=(".claude/settings.json additionalDirectories contains canonical")
    fi
  fi

  # Surface 3: vendored dispatcher BASSCLEF_SYNC_VERSION drift
  # (per ADR-032 Layer 3 self-heal; mirrors migrate-adopter-references.sh Surface 3)
  # Read the current version from the helper to avoid drift between the
  # comment header, the function, and this constant.
  CURRENT_VERSION=$(__bassclef_dispatcher_version)
  for CANDIDATE in "$CWD/.claude/hooks/bassclef-sync.sh" "$CWD/.claude/hooks/canonical-sync.sh"; do
    if [ -f "$CANDIDATE" ] && [ ! -L "$CANDIDATE" ]; then
      VENDORED_VERSION=$(grep -m1 'BASSCLEF_SYNC_VERSION=' "$CANDIDATE" 2>/dev/null | sed 's/.*BASSCLEF_SYNC_VERSION=\([^ ]*\).*/\1/' | head -1)
      if [ -z "$VENDORED_VERSION" ] || [[ "$VENDORED_VERSION" < "$CURRENT_VERSION" ]]; then
        BASENAME=$(basename "$CANDIDATE")
        DISPLAY_VERSION="${VENDORED_VERSION:-<missing>}"
        CANONICAL_FINDINGS+=(".claude/hooks/$BASENAME stale (BASSCLEF_SYNC_VERSION=$DISPLAY_VERSION; current=$CURRENT_VERSION)")
      fi
      break
    fi
  done

  if [ "${#CANONICAL_FINDINGS[@]}" -gt 0 ]; then
    RECOVERY_URL="https://raw.githubusercontent.com/sunj-labs/bassclef/main/scripts/migrate-adopter-references.sh"
    SIBLING_DISPATCHER_TEMPLATE="$CWD/../bassclef/presence/install/bassclef-sync.dispatcher.template.sh"
    # Per bet 30a WU-5 (F7 cure): the migrate script reads three env vars
    # for path overrides. Local layout sibling files for each.
    SIBLING_RENAME_MAP="$CWD/../bassclef/standards/file-renames.json"
    SIBLING_STATUSLINE_TEMPLATE="$CWD/../bassclef/presence/cli/bassclef-statusline.dispatcher.sh"

    # Decide auto-invoke vs BLOCKED-only path (per bet 29e WU-4)
    AUTO_INVOKE_READY=0
    if [ "${SKIP_AUTO_INVOKE:-0}" != "1" ]; then
      if [ -n "${BASSCLEF_RECOVERY_SCRIPT_PATH:-}" ] && [ -f "$BASSCLEF_RECOVERY_SCRIPT_PATH" ]; then
        AUTO_INVOKE_READY=1
      elif command -v curl >/dev/null 2>&1; then
        AUTO_INVOKE_READY=1
      fi
    fi

    if [ "$AUTO_INVOKE_READY" = "1" ]; then
      # === Leg 3 of self-healing — auto-invocation (WU-4) ===
      # Detection found canonical-* refs; run the migrate script
      # automatically; continue the dispatcher chain afterward so the
      # adopter sees one clean session-start (no second paste needed).
      echo ""
      echo "🩹 bassclef self-heal — canonical-* references detected; running recovery automatically"
      for finding in "${CANONICAL_FINDINGS[@]}"; do
        echo "  - $finding"
      done

      # Source the migrate script (env-var override for tests, curl in prod).
      # Per bet 30a WU-5 (F7 cure): pass all three env vars the migrate
      # script reads — DISPATCHER_TEMPLATE + RENAME_MAP + STATUSLINE_TEMPLATE
      # — when their sibling files exist. Without these, the script's
      # fallback expansion `$(cd "$(dirname "$0")/..")` resolves wrong
      # under curl-pipe ($0 = bash), and Surfaces 5 + 6 silently no-op.
      # POA was broken for 8+ days because only the dispatcher template
      # env var was passed.
      ENV_ARGS=()
      [ -f "$SIBLING_DISPATCHER_TEMPLATE" ] && ENV_ARGS+=("BASSCLEF_DISPATCHER_TEMPLATE=$SIBLING_DISPATCHER_TEMPLATE")
      [ -f "$SIBLING_RENAME_MAP" ] && ENV_ARGS+=("BASSCLEF_RENAME_MAP=$SIBLING_RENAME_MAP")
      [ -f "$SIBLING_STATUSLINE_TEMPLATE" ] && ENV_ARGS+=("BASSCLEF_STATUSLINE_TEMPLATE=$SIBLING_STATUSLINE_TEMPLATE")

      # Per bet 2026-08-27 step 7 PR #1 — resolver picks source with priority
      # env override → sibling → curl+checksum. Verifier gates curl path.
      RESOLVED=$(resolve_recovery_script)
      RESOLVED_KIND="${RESOLVED%%:*}"
      RESOLVED_REST="${RESOLVED#*:}"

      case "$RESOLVED_KIND" in
        LOCAL|SIBLING)
          echo "🩹 recovery source: $RESOLVED_KIND ($RESOLVED_REST)" >&2
          if [ "${#ENV_ARGS[@]}" -gt 0 ]; then
            cat "$RESOLVED_REST" | env "${ENV_ARGS[@]}" bash -s -- --apply "$CWD" || true
          else
            cat "$RESOLVED_REST" | bash -s -- --apply "$CWD" || true
          fi
          ;;
        CURL)
          RECOVERY_URL_RESOLVED="${RESOLVED_REST%|*}"
          SHA_URL="${RESOLVED_REST#*|}"
          echo "🩹 recovery source: CURL ($RECOVERY_URL_RESOLVED)" >&2
          TMP_SCRIPT=$(mktemp -t bassclef-recovery.XXXXXX.sh) || {
            echo "⚠ bassclef self-heal: mktemp failed; skipping recovery" >&2
            true
          }
          TMP_SHA=$(mktemp -t bassclef-recovery.XXXXXX.sha) || {
            rm -f "$TMP_SCRIPT" 2>/dev/null
            echo "⚠ bassclef self-heal: mktemp failed; skipping recovery" >&2
            true
          }
          # Fetch both files; abort verify path if either fetch fails
          if curl -sL --fail "$RECOVERY_URL_RESOLVED" -o "$TMP_SCRIPT" 2>/dev/null \
             && curl -sL --fail "$SHA_URL" -o "$TMP_SHA" 2>/dev/null; then
            EXPECTED_SHA=$(awk '{print $1}' "$TMP_SHA")
            if verify_checksum "$TMP_SCRIPT" "$EXPECTED_SHA"; then
              echo "🩹 recovery: checksum verified; executing" >&2
              if [ "${#ENV_ARGS[@]}" -gt 0 ]; then
                cat "$TMP_SCRIPT" | env "${ENV_ARGS[@]}" bash -s -- --apply "$CWD" || true
              else
                cat "$TMP_SCRIPT" | bash -s -- --apply "$CWD" || true
              fi
            else
              echo "🛑 recovery: SHA-256 mismatch; refusing to execute" >&2
              echo "   URL: $RECOVERY_URL_RESOLVED" >&2
              echo "   To retry manually after investigating:" >&2
              echo "   SKIP_CANONICAL_DETECTION=1 <re-run session>" >&2
            fi
          else
            echo "⚠ bassclef self-heal: fetch failed for recovery or checksum" >&2
            echo "   Falls back to manual recovery via BLOCKED path below" >&2
          fi
          rm -f "$TMP_SCRIPT" "$TMP_SHA" 2>/dev/null
          ;;
        *)
          echo "⚠ bassclef self-heal: resolver returned unknown kind ($RESOLVED_KIND); skipping" >&2
          ;;
      esac

      echo "🩹 bassclef self-heal: recovery applied; continuing"
      echo ""
      # Fall through to Path 1 / Path 2 — substrate now loadable
    else
      # === Fall back: BLOCKED + exit (WU-2 behavior) ===
      # SKIP_AUTO_INVOKE=1 set, OR neither curl nor BASSCLEF_RECOVERY_SCRIPT_PATH
      # available. Surface the recovery shape and stop here.
      cat <<DETECT

🛑 BLOCKED: bassclef substrate — canonical-* references detected

Your adopter tree carries references from before the 2026-06-20
canonical→bassclef rename. Bassclef cannot load substrate cleanly
until these are repaired.

Found:
DETECT
      for finding in "${CANONICAL_FINDINGS[@]}"; do
        echo "  - $finding"
      done
      cat <<RECOVERY

Recovery — one paste, no extra setup:

  curl -sL $RECOVERY_URL | bash -s -- --apply "$CWD"

After it runs, open a fresh Claude Code session in this repo.

To skip this check once (override):  SKIP_CANONICAL_DETECTION=1
To skip auto-invocation (manual recovery): SKIP_AUTO_INVOKE=1

Refs: scripts/migrate-adopter-references.sh, .claude/rules/we-dont-break-adopters.md

RECOVERY
      exit 0
    fi
  fi
fi

# === Path 1. Sibling fast-path ===
SIBLING_TEMPLATE="$CWD/../bassclef/presence/install/bassclef-sync.template.sh"
if [ -f "$SIBLING_TEMPLATE" ]; then
  echo "$INPUT" | bash "$SIBLING_TEMPLATE"
  exit $?
fi

# === Path 1.5. Bundled-substrate recognition (per #1849) ===
# npm-only cold adopters carry substrate in the package bundle. The
# dispatcher was designed for peer-checkout OR source-config models; both
# fail for anonymous adopters against private repos. Before firing the
# fetch-strategies path, check whether the substrate is already loaded at
# CWD. If yes, exit silently — no news is good news (Cooper).
#
# Override: BASSCLEF_DISPATCHER_STRICT=1 forces the Path 2 fetch even when
# bundled substrate is present (operator debugging).
if [ "${BASSCLEF_DISPATCHER_STRICT:-0}" != "1" ]; then
  if bassclef_sync_bundled_substrate_present "$CWD"; then
    exit 0
  fi
fi

# === Path 2. Curl fallback ===
# Uses the same resolver as auto_sync pre-check so old-name adopters
# still get here (self-heal already fired above, but resolve for safety
# in case self-heal was skipped via SKIP_SELF_HEAL_POINTER).
SOURCE_FILE=$(bassclef_sync_resolve_pointer_file "$CWD")
if [ -z "$SOURCE_FILE" ] || [ ! -f "$SOURCE_FILE" ]; then
  emit_error "couldn't find bassclef substrate" \
"This repo doesn't have a sibling bassclef checkout at ../bassclef AND
doesn't have a .bassclef-source.json file to fetch from a remote source.

The dispatcher needs ONE of those to load bassclef's substrate (skills,
rules, hooks, luminaries) into your session."
fi

SOURCE_URL=$(jq -r '.source_url // empty' "$SOURCE_FILE")
AUTH_METHOD=$(jq -r '.auth_method // "none"' "$SOURCE_FILE")
TOKEN_ENV=$(jq -r '.token_env // "BASSCLEF_TOKEN"' "$SOURCE_FILE")

if [ -z "$SOURCE_URL" ]; then
  emit_error ".bassclef-source.json is missing source_url" \
"Your .bassclef-source.json file exists but doesn't specify where to fetch
bassclef from. The 'source_url' field is required.

See standards/bassclef-source-config.md for the schema and provider
examples (GitHub public release, GitHub private repo, Azure DevOps, GitLab)."
fi

# Resolve auth header from env-stored token.
TOKEN_VALUE=""
AUTH_HEADER=""
if [ "$AUTH_METHOD" != "none" ]; then
  TOKEN_VALUE=$(printenv "$TOKEN_ENV" 2>/dev/null || true)
  if [ -z "$TOKEN_VALUE" ]; then
    emit_error "auth token not set in environment" \
"Your .bassclef-source.json uses auth_method '$AUTH_METHOD' and expects the
'$TOKEN_ENV' environment variable to hold the token. That variable isn't set
in this environment.

If you're in CI:        the secret needs to be configured on the repo
                        (gh secret set $TOKEN_ENV -R <repo>).
If you're on a laptop:  export $TOKEN_ENV=<token> in your shell.
If you're in Cloud Code: set $TOKEN_ENV in your environment config.

If you don't have a token yet, follow option 3 below to create one."
  fi
  case "$AUTH_METHOD" in
    Bearer) AUTH_HEADER="Authorization: Bearer $TOKEN_VALUE" ;;
    Basic)  AUTH_HEADER="Authorization: Basic $(printf ':%s' "$TOKEN_VALUE" | base64)" ;;
    *)      AUTH_HEADER="Authorization: $AUTH_METHOD $TOKEN_VALUE" ;;
  esac
fi

# Fetch tarball
TARBALL="/tmp/bassclef-thin-pointer-$$.tar.gz"
if [ -n "$AUTH_HEADER" ]; then
  HTTP_CODE=$(curl -sS -L -H "$AUTH_HEADER" -w "%{http_code}" -o "$TARBALL" "$SOURCE_URL" 2>/dev/null || echo "000")
else
  HTTP_CODE=$(curl -sS -L -w "%{http_code}" -o "$TARBALL" "$SOURCE_URL" 2>/dev/null || echo "000")
fi

if [ "$HTTP_CODE" != "200" ]; then
  rm -f "$TARBALL" 2>/dev/null
  emit_error "fetch returned HTTP $HTTP_CODE" \
"The dispatcher tried to download bassclef from:

    $SOURCE_URL

The server returned HTTP $HTTP_CODE instead of 200. Common causes:

  HTTP 401: token is invalid or expired. Regenerate it.
  HTTP 403: token is valid but doesn't have the required permission
            (needs Contents:read on the bassclef repo).
  HTTP 404: source_url is wrong, OR the bassclef repo / release
            doesn't exist at that URL.
  HTTP 000: network couldn't reach the host. Check DNS / firewall /
            whether you're offline."
fi

# Extract to a stable per-user location.
BASSCLEF_FRESH="$HOME/bassclef-fresh"
rm -rf "$BASSCLEF_FRESH" 2>/dev/null
mkdir -p "$BASSCLEF_FRESH"
if ! tar -xzf "$TARBALL" -C "$BASSCLEF_FRESH" --strip-components=1 2>/dev/null; then
  rm -f "$TARBALL"
  emit_error "couldn't extract the downloaded tarball" \
"The dispatcher downloaded the file from $SOURCE_URL but tar -xzf failed.

This usually means the response wasn't a real tarball. Check:

  - Is source_url correct? It should return a gzipped tarball, not HTML.
  - Is a network proxy / SSO portal injecting a login page instead?
  - To inspect what the server is actually sending, run:

      curl -sSL -H \"Authorization: ...\" \"$SOURCE_URL\" | file -

    If the output says 'HTML document' instead of 'gzip compressed data',
    you're being intercepted."
fi
rm -f "$TARBALL"

# Exec the big template.
#
# Export the extracted tarball root so §3c-hooks (dynamic-derive hook connect,
# per bassclef-upstream#625) can read bassclef's own .claude/settings.json.
# The template sources presence/install/bassclef-hook-connect.sh and calls
# bassclef_hook_connect_apply "$CWD" — the function reads
# $BASSCLEF_SOURCE_ROOT/.claude/settings.json to learn the current hook list
# across every event type, then merges every entry additively into the
# adopter's settings.json.
export BASSCLEF_SOURCE_ROOT="$BASSCLEF_FRESH"

FALLBACK_TEMPLATE="$BASSCLEF_FRESH/presence/install/bassclef-sync.template.sh"
if [ ! -f "$FALLBACK_TEMPLATE" ]; then
  emit_error "tarball is missing bassclef-sync.template.sh" \
"The dispatcher downloaded and extracted the tarball, but it doesn't
contain presence/install/bassclef-sync.template.sh — bassclef's
main sync logic.

This usually means source_url points at a tarball that isn't bassclef
(e.g., a different repo, or a branch / tag that's missing the template
file). Verify the URL in .bassclef-source.json points at bassclef's
main branch or a release that includes strategy/templates/."
fi

echo "$INPUT" | bash "$FALLBACK_TEMPLATE"
exit $?
