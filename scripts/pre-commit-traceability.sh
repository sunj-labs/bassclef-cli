#!/bin/bash
# pre-commit-traceability.sh
#
# Fires before every commit that touches source, tests, vite.config.ts,
# or the requirements diagram. Runs the traceability test that lives
# at tests/requirements-traceability.test.ts. Blocks the commit when
# the test fails.
#
# Not a bassclef substrate hook. This is a git-side hook the adopter
# installs by hand via scripts/install-git-hooks.sh. The substrate
# hook equivalent (PreToolUse Edit/Write) is proposed as Phase 2 of
# the Traceability Subsystem promote at
# docs/promotes/2026-08-11-traceability-subsystem.md.
#
# Design:
# - Fast: runs one Vitest file, not the whole suite. ~200ms cold.
# - Path-filtered: exits 0 with no work when no relevant files staged.
# - Actionable: on failure, points at the requirements doc.
#
# Override: SKIP_TRACEABILITY_CHECK=1 git commit -m ... (logged to stderr).

set -euo pipefail

# Move to repo root so relative paths in the test still resolve.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "pre-commit-traceability: not in a git repo. Skipping."
  exit 0
fi
cd "$REPO_ROOT"

# Explicit operator override.
if [ "${SKIP_TRACEABILITY_CHECK:-0}" = "1" ]; then
  echo "pre-commit-traceability: SKIP_TRACEABILITY_CHECK=1 set; skipping." >&2
  exit 0
fi

# Only run when the commit touches files that could affect traceability.
STAGED="$(git diff --cached --name-only)"
RELEVANT_PATTERN='^(src/|scripts/|tests/|vite\.config\.ts|docs/requirements/)'
if ! echo "$STAGED" | grep -qE "$RELEVANT_PATTERN"; then
  # No traceability-relevant files staged. Nothing to check.
  exit 0
fi

# Refuse if vitest is not installed. Adopter needs to run `npm install`
# once before the hook can fire.
if [ ! -x "node_modules/.bin/vitest" ]; then
  echo "pre-commit-traceability: node_modules/.bin/vitest not found." >&2
  echo "Run 'npm install' first, then retry the commit." >&2
  echo "Or bypass this check with SKIP_TRACEABILITY_CHECK=1 git commit ..." >&2
  exit 1
fi

echo "pre-commit-traceability: running traceability check..."
if ! node_modules/.bin/vitest run tests/requirements-traceability.test.ts --reporter=default; then
  echo ""
  echo "pre-commit-traceability: check failed." >&2
  echo "See docs/requirements/2026-08-11-npm-distribution.md for the annotation shape." >&2
  echo "Fix the missing or orphaned annotation, then re-commit." >&2
  echo "Or bypass with SKIP_TRACEABILITY_CHECK=1 git commit ..." >&2
  exit 1
fi

exit 0
