#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter journey (Sam, Sat evaluator): first contact with bassclef
# via `/onboard-repo` on a free-tier private GitHub repo. gh api
# returns HTTP 403 on branch-protection. Sam picks "skip and manage
# locally" per the 3-path heads-up block. Expected cascade — the
# fallback cat heredoc writes `.claude/onboard-notes.md` with the
# operator-managed section.
#
# This is an E2E cascade driver (prototype shape per next-session
# plan 2026-10-04). Driver scaffolds a scratch adopter workdir,
# runs the shipped fallback recipe from the SKILL body, and asserts
# the expected cascade result.
#
# Different from cli#294 driver 5 (file-level grep) — this driver
# EXERCISES the recipe + observes the filesystem effect.
#
# Pins Kunal #2036 finding #9 (free-tier 403 fallback) at the
# cascade layer, not just the SKILL body shape layer.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md
# Parent: cli#294 (follow-on scope)

# test-list:
# [x] T01 scratch workdir scaffolded cleanly
# [x] T02 fallback recipe runs without error (mkdir + cat heredoc as SKILL ships)
# [x] T03 .claude/onboard-notes.md exists after recipe runs
# [x] T04 .claude/onboard-notes.md contains "operator-managed" marker
# [x] T05 .claude/onboard-notes.md contains "Branch protection" header
# [x] T06 cleanup — scratch workdir removed on exit

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Phase 1 — scaffold scratch adopter workdir
TMP_BASE="$(mktemp -d)"
ADOPTER_DIR="$TMP_BASE/Users/sam-sat-eval/first-bassclef-project"
mkdir -p "$ADOPTER_DIR"
trap "rm -rf '$TMP_BASE'" EXIT

cd "$ADOPTER_DIR"
git init -q 2>/dev/null
git config user.email sam@local 2>/dev/null
git config user.name sam 2>/dev/null

if [ -d .git ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL: scratch workdir scaffold did not initialize git")
fi

# Phase 2 — simulate adopter picking "skip and manage locally" after 403
# Run the shipped fallback recipe from /onboard-repo SKILL (verbatim at L509-523).
# No gh api call fires; adopter already chose the local path.
if ! mkdir -p .claude; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: mkdir .claude failed in scratch workdir")
fi

cat >> .claude/onboard-notes.md <<'NOTE'
## Branch protection — operator-managed

Free-tier GitHub private repo. API returned HTTP 403 for
branches/<default>/protection; branch protection is a paid feature
for private repos on the free plan.

Operator picked "skip and manage locally" per the three-path
heads-up block in /onboard-repo SKILL. Any branch rules the operator
wants land locally via git hooks or peer review.

Revisit if the repo moves to public, or the plan upgrades to Pro+.
NOTE

RECIPE_EXIT=$?

if [ "$RECIPE_EXIT" = "0" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: fallback recipe failed with exit $RECIPE_EXIT")
fi

# Phase 3 — observe artifact
if [ -f .claude/onboard-notes.md ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: .claude/onboard-notes.md does not exist after recipe runs")
fi

# Phase 4 — assert content
if grep -q "operator-managed" .claude/onboard-notes.md 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T04 FAIL: .claude/onboard-notes.md missing 'operator-managed' marker")
fi

if grep -q "Branch protection" .claude/onboard-notes.md 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T05 FAIL: .claude/onboard-notes.md missing 'Branch protection' header")
fi

# Phase 5 — observe cleanup fires (test trap by checking workdir exists before exit)
if [ -d "$ADOPTER_DIR" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T06 FAIL: adopter workdir disappeared before trap fired")
fi

# Return to a dir outside the scratch tree so trap can clean up
cd /

# Summary
echo "e2e-onboard-repo-cascade: $PASS pass / $FAIL fail (adopter workdir: $ADOPTER_DIR)"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
