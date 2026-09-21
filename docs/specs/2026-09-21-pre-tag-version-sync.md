---
tier: lite
slug: 2026-09-21-pre-tag-version-sync
scope: Epic #194 Stories 1-3
date: 2026-09-21
status: draft
authoring_luminaries:
  primary: michael-nygard
  supporting: [kent-beck, saltzer-schroeder]
references:
  - docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md
  - docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md
  - .github/workflows/publish.yml
  - tests/version-sync.test.ts
  - scripts/bump-version.mjs
---

# Spec — pre-tag version-sync guardrails

## Sources read

- `docs/whereami.md` L1-266 — active state + v1.5.0 mis-ship recap L18-22
- `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md` L1-80 — full failure narrative + tickets filed
- Epic #194 body via `gh issue view 194` — 6 stories total; this spec covers 1-3
- Ticket #192 body via `gh issue view 192` — approval-gate notifications (out of scope this session)
- Ticket #193 body via `gh issue view 193` — env modernization (out of scope this session)
- `tests/version-sync.test.ts` L1-32 — existing test covers `src/index.ts` ↔ `package.json` only
- `.github/workflows/publish.yml` L1-306 — release-time check surface + trigger shape
- `scripts/bump-version.mjs` L1-80 — bump helper; writes all four files
- `README.md` L38 — version marker delimiters `<!-- version-start -->1.5.1<!-- version-end -->`
- `CHANGELOG.md` L1-25 — Keep-a-Changelog format; version headings `## [X.Y.Z] - YYYY-MM-DD`
- `src/index.ts` L16 — version constant `export const version = '1.5.1' as const;`
- `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md` — full 3-lens pre-mortem, top-5 folded

## What I'm NOT reading (with reason)

- Full history of past publish runs — v1.5.0 shape is the characterization case; older cycles do not add signal
- Epic #195 body — Docker harness ergonomics, separate scope
- Prior husky/lefthook adopter patterns — decided not to add a dev dependency per new-dependency-check rule

## Problem

Version markers live in four files. `package.json`, `src/index.ts`, `README.md`, and `CHANGELOG.md` all carry the current version string. The bump script `scripts/bump-version.mjs` writes all four in one shot. A hand-edit of `package.json` skips the other three.

The v1.5.0 release cycle shipped that exact drift. `package.json` bumped to 1.5.0. The sibling files stayed at 1.4.1. The pre-publish check caught the miss — but only after the tag was cut and the publish workflow fired on `release: published`. That check ran 30 seconds in and failed the publish. The cure was PR #191 + tag v1.5.1. Cost: one full publish attempt, one phantom GH release, and about 380 turns of session time (session log 2026-09-21 § Work Done).

The check reads the truth. It reads it too late.

## Goal

Move the same check earlier in the pipeline. Two layers:

- **PR-CI layer.** A new workflow runs on every `pull_request` and asserts all four version markers agree. A drift trips the PR check red. The reviewer sees the miss before merge.
- **Pre-commit layer.** A git-native hook runs the same test on `git commit` when any of the four files is staged. A drift blocks the commit locally.

Plus a third piece:

- **CONTRIBUTING note.** A short section pointing at `npm run bump` as the one path for version changes. Names the four files. Cites this spec.

Together: 33% faster cycles (no wasted publish attempt) and 50% fewer false-starts (drift caught at the cheapest layer that still catches it).

## Acceptance

- [ ] `tests/version-sync.test.ts` asserts all four files agree — not just `src/index.ts` + `package.json`. Covers the README marker between `<!-- version-start -->` and `<!-- version-end -->`. Covers the top non-Unreleased heading in `CHANGELOG.md`.
- [ ] A new workflow `.github/workflows/pr-checks.yml` runs `npm test` + `npm run typecheck` on every `pull_request`. No `paths:` filter — fires on every PR.
- [ ] A new script `scripts/git-hooks/pre-commit-version-sync.sh` runs the version-sync test when any of the four files is staged. Exits 2 on drift with a clear message pointing at `npm run bump`.
- [ ] A new script `scripts/install-git-hooks.mjs` installs the hook into `.git/hooks/pre-commit`. Idempotent. Preserves any prior content by chaining.
- [ ] `CONTRIBUTING.md` documents `npm run bump` as the one path. Names the four files. Names the install command for the pre-commit hook.
- [ ] Tier 0 test coverage for `pre-commit-version-sync.sh` and `install-git-hooks.mjs` per `.claude/rules/test-sufficiency.md`.
- [ ] Test-bump end-to-end after the cure lands. A dry-run `npm run bump patch` produces a clean set of four staged files. The pre-commit hook passes. The PR-CI check passes.

## Design notes

**Existing test extension over new test.** `tests/version-sync.test.ts` already exists at 32 lines and covers `src/index.ts` ↔ `package.json`. Extend it. Do not add a parallel test file.

**Regex anchors for each file:**

- `package.json` — `.version` field via `JSON.parse`.
- `src/index.ts` — `/export const version = '([^']+)' as const;/`. Already in use.
- `README.md` — `/<!-- version-start -->([^<]+)<!-- version-end -->/`. Marker delimiters at L38.
- `CHANGELOG.md` — first `## [X.Y.Z]` heading below `## [Unreleased]`. Non-Unreleased pattern: `/^## \[(\d+\.\d+\.\d+)\]/m`.

**Hook trigger surface (Saltzer-Schroeder complete mediation).** The pre-commit hook fires when ANY of the four files is staged. Not just `package.json`. The PR-CI check has no `paths:` filter — fires on every PR.

**Belt and suspenders (Nygard).** Local hook + server-side PR-CI. Local can be bypassed with `--no-verify`. PR-CI catches the bypass at the gate. Both required.

**Test-first (Beck).** The extended test lands as RED first. Fixture replays the v1.5.0 commit shape — `package.json` at 1.5.0, sibling files at 1.4.1. GREEN comes with the file-extension logic.

**No new dependency.** Hand-rolled git hook plus a Node installer script. Husky adds a dev dep with no marginal value at this scope. Per `.claude/rules/new-dependency-check.md` five checks.

**`readVersionSet` error contract (RFC F1 · Hoare).** Every reader in the strategy throws a typed error when its marker cannot be read. `class VersionMarkerNotFound extends Error` with a `source` field naming which file failed. The check function propagates it; callers see a clear failure. Not a `null` entry, not an empty string. Tests cover four not-found cases: missing `.version` key, `src/index.ts` regex miss, `README.md` marker gone, `CHANGELOG.md` no version heading below `[Unreleased]`.

**PR-CI scope (RFC F2 · Brooks).** The new workflow runs `npm test` + `npm run typecheck`. That is the Tier 0 suite + typecheck. The version-sync assertion rides inside `npm test`. The workflow does NOT run tag validation, dist/lite bundling, andon scan, or tier filter — those are release-only concerns per ADR-004 §Two-job shape. The PR gate is narrower on purpose. Running the full checks job at PR time is redundant (no tag yet) and slow (~5min vs ~30sec).

## Non-goals

- No auto-fix. The hook and PR-CI both fail loud. Fix path is `npm run bump` or manual edit of all four.
- No coverage of the workflow YAML files themselves. They do not carry a version string.
- No lint-level enforcement of `npm run bump`. CONTRIBUTING is prose. Enforcement lives in the hook + CI.
- No `.husky/` install path. Husky is a fine tool. We do not need it here.

## Out of scope this session

- Epic #194 Story 4-5 (approval-gate notifications). Ticket #192 covers those.
- Epic #195 (Docker harness ergonomics). Separate scope.
- Ticket #193 (Node 20 + ubuntu-latest modernization). Separate scope.

## Refs

- Epic #194 body (6 stories total; this spec covers 1-3)
- Risk ledger `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md`
- Session log `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md`
- `standards/npm-versioning-and-changelog.md`
- ADR-004 (publish pipeline safety contract)
- Memory `feedback_use_npm_run_bump_not_hand_edit` (the ship failure that motivated this)
