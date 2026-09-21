---
tier: lite
slug: UC-version-sync-guardrails
ceremony: brief
date: 2026-09-21
actors: [maintainer]
scope: Epic #194 Stories 1-3
references:
  - docs/specs/2026-09-21-pre-tag-version-sync.md
  - docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md
---

# UC — version-sync guardrails (brief tier)

## Sources read

- `docs/specs/2026-09-21-pre-tag-version-sync.md` — full spec authored this session
- `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md` — 3-lens pre-mortem, top-5 folded
- `scripts/bump-version.mjs` — existing bump helper this UC reinforces
- `state/markers/adr-deviation/feat-194-pre-tag-version-sync-guardrails.marker` — outcome ADR-honored

**Actor.** Maintainer (the operator, or any future contributor with commit rights).

**Scope.** Pre-commit hook + PR-CI check + CONTRIBUTING note that stop v1.5.0-class mis-ships.

**Level.** Subfunction (task-level, not user-goal).

**Primary actor goal.** Never ship a tag whose four version markers disagree.

## Primary scenario — bump via script (happy path)

1. Maintainer runs `npm run bump patch`.
2. Script writes `package.json`, `src/index.ts`, `README.md`, `CHANGELOG.md` — all four to the new version.
3. Maintainer runs `git add -A && git commit -m "chore: bump v1.5.2"`.
4. Pre-commit hook fires. Reads all four files. Confirms they agree. Exits 0.
5. Commit lands.
6. Maintainer opens a PR.
7. PR-CI runs `npm test` + `npm run typecheck`. Version-sync test passes.
8. PR merges. Tag cut. Publish workflow fires. All checks pass. Package lands on npm.

## Alternative — hand-edit drift caught locally

1. Maintainer opens `package.json`. Edits `"version": "1.5.2"`. Saves.
2. Maintainer runs `git add package.json && git commit -m "bump version"`.
3. Pre-commit hook fires. Reads all four files. `package.json` says 1.5.2. Sibling files still say 1.5.1.
4. Hook exits 2 with a message: "Version drift: package.json=1.5.2, src/index.ts=1.5.1, README.md=1.5.1, CHANGELOG.md=1.5.1. Run `npm run bump patch` instead."
5. Commit is blocked. Maintainer runs `npm run bump patch`. Continues from Primary Scenario Step 3.

## Alternative — local hook bypassed via `--no-verify`

1. Maintainer runs `git commit --no-verify`. Local hook does not fire.
2. Maintainer pushes + opens PR.
3. PR-CI workflow fires. `npm test` runs the extended version-sync test. Fails.
4. GitHub blocks the PR merge. Maintainer sees the red check.
5. Maintainer runs `npm run bump patch` locally. Amends commit. Force-pushes.
6. PR-CI re-runs. Passes. PR merges.

## Alternative — cold-adopter machine without the hook installed

1. Contributor clones the repo. Runs `npm install`.
2. Contributor makes a version change. Commits.
3. Pre-commit hook is absent (never installed). Commit lands with drift.
4. Contributor pushes + opens PR.
5. PR-CI catches the drift. Red check. Same recovery as prior alternative.
6. CONTRIBUTING doc points at `npm run install-hooks` for the local layer.

## Preconditions

- Repo cloned.
- `npm install` ran successfully.
- Optional: `npm run install-hooks` ran (installs the pre-commit hook into `.git/hooks/pre-commit`).

## Postconditions (success)

- Every commit that changes a version marker leaves all four files in agreement.
- Every PR that reaches merge has passed the version-sync check.
- No tag can be cut with drift.

## Postconditions (failure paths)

- Local drift: commit blocked with clear message. Maintainer runs `npm run bump`.
- CI drift: PR blocked with red check. Same recovery.
- Bypass: local `--no-verify` still gets caught at PR-CI. No path reaches merge silently.

## Refs

- Spec: `docs/specs/2026-09-21-pre-tag-version-sync.md`
- Risk ledger: `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md`
- Bump helper: `scripts/bump-version.mjs`
- Existing test: `tests/version-sync.test.ts`
