#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter was trying to: run /onboard-repo on their new free-tier
# private repo, hit HTTP 403 on branch-protection API, and have a
# clear fallback path that did not require upgrading the plan.
#
# Pins Kunal #2036 finding #9 (free-tier GitHub branch-protection
# docs). Pre-cure defect: SKILL assumed `gh api` always succeeds;
# adopter saw "Upgrade to GitHub Pro or make this repository public"
# with no path forward.
#
# Upstream cure: bassclef-upstream PR #2044 (part of release-2026-10-03-89ceaa15, tag v1.7.0).
# Cure shape — SKILL now documents 3 paths BEFORE the API call
# (public / upgrade / skip-local) + marker-write fallback to
# .claude/onboard-notes.md when adopter picks local-only.
#
# UC: docs/use-cases/UC-script-cli-294-driver-5-onboard-free-tier-403.md
# Risk ledger: docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md
# Parent: cli#294 Step 3

# test-list:
# [x] T01 SKILL body carries 403 heads-up ("HTTP 403" + "Upgrade to GitHub Pro")
# [x] T02 SKILL body names "Make the repo public" path
# [x] T03 SKILL body names "Upgrade the GitHub plan" path
# [x] T04 SKILL body names skip-and-local path
# [x] T05 SKILL body carries fallback marker-write to .claude/onboard-notes.md
# [x] T06 SKIP cleanly if SKILL unreachable

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Locate SKILL body
SKILL=""
if [ -f "$REPO_ROOT/dist/lite/.claude/skills/onboard-repo/SKILL.md" ]; then
  SKILL="$REPO_ROOT/dist/lite/.claude/skills/onboard-repo/SKILL.md"
elif [ -n "${BASSCLEF_SIBLING_ROOT:-}" ] && [ -f "$BASSCLEF_SIBLING_ROOT/.claude/skills/onboard-repo/SKILL.md" ]; then
  SKILL="$BASSCLEF_SIBLING_ROOT/.claude/skills/onboard-repo/SKILL.md"
elif [ -f "$HOME/src/sunj-labs/bassclef/.claude/skills/onboard-repo/SKILL.md" ]; then
  SKILL="$HOME/src/sunj-labs/bassclef/.claude/skills/onboard-repo/SKILL.md"
else
  echo "SKIP (T06): no onboard-repo SKILL.md reachable at dist/lite/, sibling, or ~/src/sunj-labs/bassclef/" >&2
  exit 77
fi

# T01 — 403 heads-up block
if grep -q "HTTP 403" "$SKILL" && grep -q "Upgrade to GitHub Pro" "$SKILL"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL: SKILL ($SKILL) missing HTTP 403 heads-up block ('HTTP 403' + 'Upgrade to GitHub Pro')")
fi

# T02 — public path
if grep -q "Make the repo public" "$SKILL"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: SKILL missing public path label 'Make the repo public'")
fi

# T03 — upgrade path
if grep -q "Upgrade the GitHub plan" "$SKILL"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: SKILL missing upgrade path label 'Upgrade the GitHub plan'")
fi

# T04 — skip-and-local path (search for the operator-managed fallback language)
if grep -qE "skip and manage locally|skip.*local|local-only|manage locally" "$SKILL"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T04 FAIL: SKILL missing skip-and-local path (grep 'skip and manage locally' or 'local-only' or 'manage locally')")
fi

# T05 — fallback marker-write to .claude/onboard-notes.md
if grep -q ".claude/onboard-notes.md" "$SKILL"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T05 FAIL: SKILL missing fallback marker-write block to .claude/onboard-notes.md")
fi

# Summary
echo "driver-5 onboard-free-tier-403: $PASS pass / $FAIL fail (source: $SKILL)"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
