---
tier: lite
date: 2026-10-03
goal: cli#294 Step 3
code-class: new adopter-facing script (brief UC per .claude/rules/oo-ad-entry-point.md matrix row 7)
---

# UC-script-cli-294-driver-5 — onboard-free-tier-403

## Primary actor

Smoke harness (CI docker-smoke OR local `bash scripts/tests/*.test.sh`).

## Goal

Assert that the `/onboard-repo` SKILL body carries three pre-API-call paths for free-tier GitHub adopters (make repo public, upgrade plan, skip + manage locally) AND a fallback marker-write block to `.claude/onboard-notes.md` when the adopter picks the local-only path.

## Main success scenario

1. Harness locates bundled `/onboard-repo` SKILL body
2. Harness greps for the HTTP 403 heads-up block ("HTTP 403" + "Upgrade to GitHub Pro")
3. Harness greps for three path labels — "Make the repo public" + "Upgrade the GitHub plan" + "skip" (local path 3)
4. Harness greps for fallback marker-write to `.claude/onboard-notes.md`
5. Exit 0

## Extensions

- 2a. 403 heads-up absent → exit 1 (regression: adopter runs API call without warning)
- 3a. Any of 3 paths absent → exit 1 (regression: adopter has fewer options than cure shipped)
- 4a. Marker-write block absent → exit 1 (regression: no record of operator-managed state)

## Preconditions

- Bundled SKILL reachable at `dist/lite/.claude/skills/onboard-repo/SKILL.md` OR sibling

## Postconditions

- Current main: driver exits 0 (SKILL carries the 3-path block + marker-write)
- Pre-cure commit (parent of upstream PR #2044): driver exits 1 (SKILL assumed `gh api` always succeeds; no 403 heads-up; no fallback)

## Pattern

Characterization test per @luminary michael-feathers. The driver pins the SKILL body shape — the 3-path block and fallback are the regression surface for Kunal's blocked flow.

## Covers

- Kunal #2036 finding #9 (free-tier GitHub branch-protection 403 — adopter stuck with no path forward)

Adopter was trying to: run `/onboard-repo` on their new free-tier private repo, hit HTTP 403 on branch-protection API, and have a clear fallback path that didn't require upgrading the plan.
