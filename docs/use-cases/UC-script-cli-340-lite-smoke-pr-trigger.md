---
ticket: cli#340
ceremony: brief (Cockburn — adopter-facing script per `.claude/rules/oo-ad-entry-point.md`)
primary_luminary: linus-torvalds
supporting:
  - michael-nygard
  - hyrum-wright
---

# UC-script-cli-340 — lite-adopter-smoke self-exercises on PRs

## Primary actor

Author who edits `.github/workflows/lite-adopter-smoke.yml` or any `scripts/tests/smoke-drive-e2e-*.test.sh`.

## Goal

The author sees the smoke workflow run on their PR before merge. Today the workflow runs only on nightly schedule, tag push, and manual dispatch. A broken edit lands on main and the author learns from a nightly failure 12 hours later.

## Preconditions

- PR open against main.
- PR changes at least one file matching the workflow trigger paths.

## Main success scenario

1. Author pushes a PR touching the workflow file.
2. GitHub Actions reads the `pull_request` trigger and fires the workflow.
3. Hello-probe job runs. On pass, matrix job runs across ubuntu + macOS × 3 releases.
4. Workflow result shows on the PR Checks tab within ~10 minutes.
5. Author sees a RED signal before merge if the edit broke the matrix.

## Extensions

- 1a. PR touches only unrelated paths (e.g., `docs/`): workflow does not fire. `paths` filter keeps noise out.
- 2a. PR touches `scripts/tests/smoke-drive-e2e-*.test.sh`: workflow fires because driver edits are the other high-risk surface.
- 3a. Hello-probe fails: matrix skipped; author sees the auth/service degrade signal.

## Postconditions

- PR shows at least one `lite-adopter-smoke` check row.
- Nightly schedule unchanged. Tag push unchanged. Manual dispatch unchanged.

## Why this is brief ceremony

Per `.claude/rules/oo-ad-entry-point.md` matrix row "Adopter-facing script (new `scripts/*.sh`)" — brief use case plus Tier 0 tests. This is a workflow edit, not a new skill or hook. Fully-dressed would be ceremony drag. One file change, one Tier 0 test, no new interface.

## Pattern

No GoF pattern instantiated. The workflow is a config file.
