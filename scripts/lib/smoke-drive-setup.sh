#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/template-method.md
# @pattern patterns/code/vernon/anticorruption-layer.md
#
# smoke-drive-setup.sh — per-skill setup + teardown helpers.
#
# Sub-step 4.5 of cli#254. Each helper is one shell function callable
# by name from the catalog's _catalog_setup / _catalog_teardown accessors.
#
# Contract:
#   - Each helper takes $1 = SCRATCH_DIR
#   - Each helper returns 0 on success, non-zero on failure
#   - Setup helpers write to SCRATCH_DIR only (or export env vars)
#   - Teardown helpers may call real network binaries (gh, git)
#   - Neither helper edits files outside SCRATCH_DIR unless declared
#     (like teardown_close_smoke_tickets touching real GitHub)
#
# Adopter env vars:
#   GH_SMOKE_REPO       — optional; if set, gh-inject-smoke-label routes
#                         `gh issue *` calls to this repo (dummy-repo mode)
#   SMOKE_GH_LOG        — log path for shim gh invocations
#                         (default: $SCRATCH_DIR/.gh-invocations.log)
#   SMOKE_GH_BIN        — path to real gh binary (default: `which gh`)

set -u

# =====================================================================
# Setup helpers
# =====================================================================

# setup_git_init_clean SCRATCH_DIR
# Initializes a fresh empty git repo in SCRATCH_DIR with a bassclef-safe
# identity. Used by /onboard-repo Path B and any skill that reads git state.
setup_git_init_clean() {
  local dir="${1:?SCRATCH_DIR required}"
  [ -d "$dir" ] || return 13
  (
    cd "$dir" || return 13
    git init -q 2>/dev/null || return 1
    git config user.email "smoke-drive@example.com"
    git config user.name "smoke-drive"
    # Create an initial commit so branch state is well-formed
    printf 'smoke\n' > .smoke-init
    git add .smoke-init 2>/dev/null
    git commit -q -m "smoke init" 2>/dev/null || true
  )
}

# setup_chronicle_dir_writable SCRATCH_DIR
# Creates docs/chronicle inside SCRATCH_DIR so /session-end has a
# target for its writes.
setup_chronicle_dir_writable() {
  local dir="${1:?SCRATCH_DIR required}"
  mkdir -p "$dir/docs/chronicle" 2>/dev/null || return 1
  return 0
}

# setup_iteration_goals_dir_writable SCRATCH_DIR
# Creates docs/iteration-bets inside SCRATCH_DIR so /longrun prep can
# write its goal doc.
setup_iteration_goals_dir_writable() {
  local dir="${1:?SCRATCH_DIR required}"
  mkdir -p "$dir/docs/iteration-bets" 2>/dev/null || return 1
  return 0
}

# setup_gh_inject_smoke_label SCRATCH_DIR
# Puts a `gh` shim on PATH that adds `--label smoke-drive` +
# `--label automated-run` to every `gh issue create` invocation.
# Optional GH_SMOKE_REPO env routes all `gh issue *` calls to that
# repo. Falls back to real `gh` for other subcommands.
#
# The shim also logs every invocation as one-line JSON to
# $SMOKE_GH_LOG (default: $SCRATCH_DIR/.gh-invocations.log).
setup_gh_inject_smoke_label() {
  local dir="${1:?SCRATCH_DIR required}"
  local shim_dir="$dir/.smoke-bin"
  mkdir -p "$shim_dir" 2>/dev/null || return 1

  # Resolve the real gh binary. Shim needs to call it (unless
  # SMOKE_GH_BIN points at a fake for tests).
  local real_gh="${SMOKE_GH_BIN:-$(command -v gh 2>/dev/null || echo /usr/bin/gh)}"
  local gh_log="${SMOKE_GH_LOG:-$dir/.gh-invocations.log}"

  # Write the shim script
  cat > "$shim_dir/gh" <<EOF
#!/usr/bin/env bash
# gh shim — injects smoke labels + logs invocations
set -u
log="${gh_log}"
mkdir -p "\$(dirname "\$log")" 2>/dev/null || true

# Log invocation as one-line JSON
args_json=""
for a in "\$@"; do
  esc=\$(printf '%s' "\$a" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
  if [ -z "\$args_json" ]; then args_json="\"\$esc\""
  else args_json="\$args_json,\"\$esc\""; fi
done
printf '{"argv":[%s]}\n' "\$args_json" >> "\$log"

# Inject labels on \`gh issue create\`
if [ "\${1:-}" = "issue" ] && [ "\${2:-}" = "create" ]; then
  shift 2
  extra_args=""
  if [ -n "\${GH_SMOKE_REPO:-}" ]; then
    extra_args="--repo \${GH_SMOKE_REPO}"
  fi
  # shellcheck disable=SC2086
  exec "${real_gh}" issue create --label smoke-drive --label automated-run \$extra_args "\$@"
fi

# Pass through everything else
exec "${real_gh}" "\$@"
EOF
  chmod +x "$shim_dir/gh"

  # Prepend shim dir to PATH; export so drive_send sees it
  export PATH="$shim_dir:$PATH"
  export SMOKE_GH_LOG="$gh_log"
  return 0
}

# setup_git_remote_scratch SCRATCH_DIR
# Sets git origin to a local bare repo under SCRATCH_DIR. `git push`
# succeeds locally without reaching any remote. Used by /build.
setup_git_remote_scratch() {
  local dir="${1:?SCRATCH_DIR required}"
  local bare="$dir/.smoke-remote.git"
  mkdir -p "$bare" 2>/dev/null || return 1
  (
    cd "$bare" && git init -q --bare 2>/dev/null || return 1
  )
  (
    cd "$dir" || return 1
    # Requires git repo initialized (setup_git_init_clean should run first)
    if [ -d "$dir/.git" ]; then
      git remote remove origin 2>/dev/null || true
      git remote add origin "file://$bare" 2>/dev/null
    fi
  )
  return 0
}

# =====================================================================
# Teardown helpers
# =====================================================================

# teardown_close_smoke_tickets SCRATCH_DIR
# Closes every open GitHub ticket labeled `smoke-drive` in the repo
# named by GH_SMOKE_REPO (or the current repo if unset). Emits stderr
# banner on any close failure. Never touches unlabeled tickets.
teardown_close_smoke_tickets() {
  local dir="${1:?SCRATCH_DIR required}"
  local real_gh="${SMOKE_GH_BIN:-$(command -v gh 2>/dev/null || echo /usr/bin/gh)}"
  local repo_arg=""
  if [ -n "${GH_SMOKE_REPO:-}" ]; then
    repo_arg="--repo ${GH_SMOKE_REPO}"
  fi

  # Fetch open tickets with smoke-drive label as JSON
  local list_json
  # shellcheck disable=SC2086
  list_json=$("$real_gh" issue list --label smoke-drive --state open --json number $repo_arg 2>/dev/null || echo "[]")

  local nums
  if command -v jq >/dev/null 2>&1; then
    nums=$(printf '%s' "$list_json" | jq -r '.[].number' 2>/dev/null || true)
  else
    # bash 3.2 fallback: crude parse
    nums=$(printf '%s' "$list_json" | grep -oE '"number":[0-9]+' | grep -oE '[0-9]+' || true)
  fi

  local failures=0
  local n
  for n in $nums; do
    # shellcheck disable=SC2086
    if ! "$real_gh" issue close "$n" --comment "auto-closed after smoke run" $repo_arg >/dev/null 2>&1; then
      failures=$((failures + 1))
      echo "teardown_close_smoke_tickets: failed to close ticket #$n" >&2
    fi
  done

  [ "$failures" -eq 0 ]
}

# teardown_delete_created_branch SCRATCH_DIR
# Parses the gh log for any `pr create` branch reference and deletes
# the branch locally + on origin (if a remote exists). Best-effort;
# non-zero return is a warning, not a hard error.
teardown_delete_created_branch() {
  local dir="${1:?SCRATCH_DIR required}"
  local log="${SMOKE_GH_LOG:-$dir/.gh-invocations.log}"
  [ -f "$log" ] || return 0

  # Look for --head <branch> in `pr create` invocations
  local branches
  branches=$(grep -oE '"pr","create"[^}]*"--head","[^"]+"' "$log" 2>/dev/null | \
             grep -oE '"--head","[^"]+"' | \
             sed 's/"--head","//; s/"//' || true)

  local b
  for b in $branches; do
    (
      cd "$dir" && \
      git branch -D "$b" 2>/dev/null || true
      git push origin --delete "$b" 2>/dev/null || true
    )
  done
  return 0
}
