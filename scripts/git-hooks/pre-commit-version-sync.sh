#!/usr/bin/env bash
# scripts/git-hooks/pre-commit-version-sync.sh
#
# Pre-commit git hook. Fires when any of the four version-bearing files
# is staged. Runs scripts/check-version-set.mjs. Exits 2 on drift.
#
# @requirement R-NPM-007 (extension per Epic #194 Stories 1-3)
#
# Install path — this file gets installed at .git/hooks/pre-commit via
# `scripts/install-git-hooks.mjs`. See CONTRIBUTING.md § Version bumps.
#
# The hook is deliberately narrow — it fires only when a version file
# is staged. Other commits pass through without cost.
#
# Local bypass: `git commit --no-verify`. The PR-CI workflow catches
# any bypass at the merge gate — pre-commit is belt-and-suspenders with
# a server-side safety net per pre-mortem R5.
#
# See docs/decompositions/2026-09-21-pre-tag-version-sync.md § Interface 4.

set -euo pipefail

# Discover repo root — the hook fires from `.git/hooks/`, so cd up to it.
REPO_ROOT="$(git rev-parse --show-toplevel)"
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "pre-commit-version-sync: could not resolve repo root" >&2
  exit 2
fi

# Guard: is any version-bearing file staged?
STAGED="$(git diff --cached --name-only)"
CHECK=0
for path in "package.json" "src/index.ts" "README.md" "CHANGELOG.md"; do
  if echo "$STAGED" | grep -qxF "$path"; then
    CHECK=1
    break
  fi
done

if [ "$CHECK" -eq 0 ]; then
  # No version file staged. Pass.
  exit 0
fi

# Guard: node present?
if ! command -v node >/dev/null 2>&1; then
  echo "pre-commit-version-sync: node is not on PATH — cannot run the check" >&2
  echo "Install Node.js 20+ or bypass this commit with --no-verify (PR-CI will still catch drift)." >&2
  exit 2
fi

# Run the check.
CHECK_SCRIPT="$REPO_ROOT/scripts/check-version-set.mjs"
if [ ! -f "$CHECK_SCRIPT" ]; then
  echo "pre-commit-version-sync: check script missing at $CHECK_SCRIPT" >&2
  exit 2
fi

exec node "$CHECK_SCRIPT" "$REPO_ROOT"
