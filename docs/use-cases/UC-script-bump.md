---
tier: standard
id: UC-script-bump
name: Bump the @thebassclef/core version before a release
level: user goal
primary_actor: Maintainer
scope: bassclef-cli — `scripts/bump-version.mjs` invoked via `npm run bump`
authored: 2026-08-08
authored_by: agent
cockburn_ceremony: brief
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
wu: 5
governs_source:
  - scripts/bump-version.mjs
  - package.json (version field)
  - CHANGELOG.md
references_standard: standards/npm-versioning-and-changelog.md
---

# UC-script-bump — Bump the `@thebassclef/core` version before a release

## Scope

The `bump-version.mjs` script shipped in WU-5. Wraps semver + Keep a Changelog discipline in one command. Runs on the maintainer's machine before `git tag`.

## Level

User goal — maintainer prepares a release.

## Primary actor

Maintainer. Just finished merging a PR that adds a feature or fixes a bug. Wants the next release to reflect that change. Working tree at the tip of `main`.

## Main success scenario

1. Maintainer decides bump size per `standards/npm-versioning-and-changelog.md`. Small bug fix → patch. New CLI flag → minor.
2. Maintainer runs `npm run bump patch` (or `minor` or `major`) from repo root.
3. Script reads `package.json` version.
4. Script computes new version.
5. Script reads `CHANGELOG.md`. Confirms `## [Unreleased]` has content.
6. Script rewrites `CHANGELOG.md`:
   - Renames `## [Unreleased]` heading to `## [X.Y.Z] - YYYY-MM-DD`.
   - Inserts a fresh empty `## [Unreleased]` block above.
   - Updates compare link at the bottom.
7. Script writes new version to `package.json` (atomic write via `.tmp` rename).
8. Script prints new version + a reminder line: `git add package.json CHANGELOG.md && git commit -m "chore: release vX.Y.Z" && git tag vX.Y.Z && git push origin main vX.Y.Z`.
9. Maintainer runs the reminded commands.
10. Publish workflow fires per ADR-004.

## Extensions (brief)

- **Bump arg missing or unknown**: script exits 3 with usage. Maintainer picks one of patch / minor / major.
- **`CHANGELOG.md` missing**: exit 1 with "run from repo root."
- **`## [Unreleased]` block empty**: exit 1 with "add changes before bumping." Maintainer edits CHANGELOG.md under `## [Unreleased]`, re-runs.
- **Dirty working tree (unrelated file modified)**: exit 1 with "commit or stash first, or pass `--allow-dirty`." Maintainer either cleans the tree or bypasses.
- **`--allow-dirty`**: skips the dirty check silently. No stderr log today; a follow-on may add one for auditability (see `bump-version.mjs` L108).
- **`--date YYYY-MM-DD`**: overrides today's UTC date. Useful for tests + backdated releases.
- **Pre-release stripping**: if current version is `0.1.0-rc.1`, any bump strips the pre-release suffix first per semver §11. Patch of `0.1.0-rc.1` → `0.1.0`.

## Preconditions (brief)

- `scripts/bump-version.mjs` exists (installed via `npm ci`).
- `CHANGELOG.md` exists at repo root with a `## [Unreleased]` block that has content.
- `package.json` exists with a `version` field.
- Working tree is clean (or `--allow-dirty` passed).

## Postconditions (brief)

- `package.json` `version` field carries the new version. Other fields untouched.
- `CHANGELOG.md` has a new `## [X.Y.Z] - YYYY-MM-DD` block with the prior `## [Unreleased]` content.
- Fresh `## [Unreleased]` block sits above the new version block, with empty subsections ready for the next release.
- Compare link at the bottom of `CHANGELOG.md` names the new version.
- Neither file is committed by the script — the maintainer runs `git commit` explicitly.
- No git tag created — the maintainer runs `git tag` explicitly.

## Special requirements

- Every message reads at grade 8 or lower.
- No bassclef-internal jargon in output.
- Refusal messages end with a specific command to run.
- Atomic writes for both `package.json` and `CHANGELOG.md` — write to `.tmp` sibling, then rename.

## Frequency

Every release. Roughly weekly during active development.

## Composes with

- `standards/npm-versioning-and-changelog.md` pins the policy this script applies.
- `docs/decompositions/wu-5-methodology.md` covers the code-shape decomposition.
- ADR-004 (publish pipeline) enforces the tag ↔ version match this script produces.
- ADR-005 (npm distribution architecture) covers the Road 1 semver contract.
- UC-script-publish — sibling UC; publish runs after bump + tag.
