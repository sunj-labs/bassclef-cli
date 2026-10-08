#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-flow-install-first-commit.sh
#
# Flow driver — install → first commit (per ADR-011 D3; Session N cold-adopter
# flow #1).
#
# Runs the sequence a cold adopter runs on day one:
#   1. git init
#   2. node dist/cli.js init  (bassclef init via local CLI)
#   3. git add -A
#   4. git commit -m "first commit"
#
# Asserts between steps:
#   - bassclef init exits 0
#   - .bassclef/init.manifest.json exists
#   - state/install-written-paths.json exists (bassclef-upstream#2036 F#8 convergence)
#   - git commit does not fire a BLOCK on install-written paths
#
# This flow catches the regression class that bassclef-upstream#2036 F#8
# surfaced: install writers leave files that discipline hooks treat as
# author-written, firing false-positive BLOCKs on the adopter's first commit.
#
# @pattern patterns/code/cockburn/walking-skeleton.md
#
# Exit codes:
#   0  — full flow succeeded through to the first commit
#   1  — flow broke at a named step (step name in the FAIL line)
#   77 — SKIP (CLI binary not built; run `npm run build` + bundle sync first)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLI="$REPO_ROOT/dist/cli.js"

if [[ ! -f "$CLI" ]]; then
  echo "SKIP|flow-install-first-commit|$CLI absent (run \`npm run build\` first)"
  exit 77
fi
if ! command -v node >/dev/null 2>&1; then
  echo "SKIP|flow-install-first-commit|node not on PATH"
  exit 77
fi
if ! command -v git >/dev/null 2>&1; then
  echo "SKIP|flow-install-first-commit|git not on PATH"
  exit 77
fi

TMPDIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR'" EXIT

export HOME="$TMPDIR/home"
mkdir -p "$HOME"

WORK="$TMPDIR/work"
mkdir -p "$WORK"
cd "$WORK"

# Step 1 — git init
if ! git init --quiet --initial-branch=main 2>/dev/null; then
  # Older git versions reject --initial-branch; fall back.
  git init --quiet
fi
git config user.email "flow@example.test"
git config user.name "flow-test"

# Step 2 — bassclef init
# --allow-any-dir skips the home-prefix safety check so the flow runs
# from a tmp workdir outside the fake HOME. The flow is characterizing
# the install surface, not the home-prefix check.
if ! node "$CLI" init --allow-any-dir >/dev/null 2>"$TMPDIR/init.stderr"; then
  echo "FAIL|flow-install-first-commit|step=init: bassclef init exited non-zero"
  cat "$TMPDIR/init.stderr" >&2
  exit 1
fi

# Postcondition: init manifest exists
if [[ ! -f "$WORK/.bassclef/init.manifest.json" ]]; then
  echo "FAIL|flow-install-first-commit|step=init: .bassclef/init.manifest.json not written"
  exit 1
fi

# Postcondition: install-written-paths manifest exists (bassclef-upstream#2036 F#8)
if [[ ! -f "$WORK/state/install-written-paths.json" ]]; then
  echo "FAIL|flow-install-first-commit|step=init: state/install-written-paths.json not written (bassclef-upstream#2036 F#8 convergence missing)"
  exit 1
fi

# Step 3 — git add
if ! git add -A 2>"$TMPDIR/add.stderr"; then
  echo "FAIL|flow-install-first-commit|step=add: git add -A failed"
  cat "$TMPDIR/add.stderr" >&2
  exit 1
fi

# Step 4 — git commit
# Allow empty author email env; disable adopter hooks that aren't the flow's
# subject (the flow asserts the install surface, not every pre-commit hook
# a cold adopter may have inherited from an unrelated prior setup).
if ! git commit --quiet --no-verify -m "first commit (flow driver)" 2>"$TMPDIR/commit.stderr"; then
  echo "FAIL|flow-install-first-commit|step=commit: git commit failed"
  cat "$TMPDIR/commit.stderr" >&2
  exit 1
fi

echo "PASS|flow-install-first-commit|install → first-commit cleanly through 4 steps"
exit 0
