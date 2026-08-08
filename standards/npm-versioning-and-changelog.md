---
tier: standard
title: npm versioning and changelog discipline for @thebassclef/core
authored: 2026-08-08
authored_by: agent
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
wu: 5
governs_source:
  - scripts/bump-version.mjs
  - CHANGELOG.md
governs_scope: every published version of @thebassclef/core (npm registry)
references_adr:
  - ADR-005-npm-distribution-architecture.md (Road 1 semver contract)
  - ADR-004-publish-pipeline-safety-contract.md (validate-tag.mjs enforces version match)
closes:
  - sunj-labs/bassclef-upstream#3 (packaging + versioning gap)
  - sunj-labs/bassclef-upstream#1110 (version bump policy)
---

# npm versioning and changelog discipline for `@thebassclef/core`

Every published version of `@thebassclef/core` follows this policy. The `scripts/bump-version.mjs` script writes the version + moves the changelog block. The publish pipeline (per ADR-004) refuses tags that do not string-equal the `package.json` version.

## Semver rules

The package follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) with the 0.x pre-stable relaxation described below.

**Below 1.0.0** (current phase):

- **patch** (`0.0.X` → `0.0.X+1`): backward-compatible bug fixes, doc-only changes, test-only changes, internal refactors that do not change any adopter-observable surface.
- **minor** (`0.X.0` → `0.X+1.0`): backward-compatible new features. New CLI flag with a safe default counts. Add a template file that init writes counts.
- **major** (`0.X.Y` → `1.0.0`): reserved for the 0.x → 1.0 stabilization cut. Do not run before the unscoped `bassclef` name transfer lands OR before adopter cohort reaches 25 (per `.claude/rules/we-dont-break-adopters.md`).

During 0.x, every backward-incompatible change bumps to the next **minor**, not to a new major. This is the pre-stable relaxation. Read Semver §4 for the underlying rule.

**At 1.0.0 and beyond** (future phase):

- **patch** (`X.Y.Z` → `X.Y.Z+1`): backward-compatible bug fixes.
- **minor** (`X.Y.Z` → `X.Y+1.0`): backward-compatible new features.
- **major** (`X.Y.Z` → `X+1.0.0`): any backward-incompatible change. Every major bump owes a compat shim + a 90-day deprecation window per `.claude/rules/we-dont-break-adopters.md`.

## What counts as backward-incompatible

Applies to `@thebassclef/core` as an adopter-observable surface.

| Change | Compatible? |
|---|---|
| Add a new CLI flag with a safe default | Yes — minor bump |
| Rename an existing CLI flag | No — major bump with compat alias |
| Remove a CLI flag | No — major bump with 90-day grace |
| Change the default value of an existing flag | No — major bump |
| Change the shape of a written template (add a field with a safe default) | Yes — minor bump |
| Change the shape of a written template (remove or rename a field) | No — major bump; needs sync fallback for prior manifests |
| Bump the Node engines floor (e.g., 20 → 22) | No — major bump; adopters on the old floor break |
| Change an exit code for the same failure class | No — major bump; scripted callers rely on codes |
| Change the SHA-256 content-hash normalization steps (per ADR-003) | No — major bump; sync detects false positives |
| Rename `.github/workflows/publish.yml` | No — coordinated release with npm trusted-publisher config change per ADR-004 K1 |
| Change a message string | Yes — patch |
| Add a Tier 0 test | Yes — patch |
| Update a doc | Yes — patch |
| Refactor internal code with no adopter-observable change | Yes — patch |

When in doubt, treat the change as backward-incompatible and bump minor (below 1.0) or major (at 1.0+).

## Pre-release tags

Pre-release versions use the semver pre-release suffix: `0.1.0-rc.1`, `0.2.0-beta.3`, `1.0.0-alpha.1`.

- Publish pipeline (per ADR-004) picks the npm dist-tag from the version string. Stable versions get `latest`. Pre-release versions get `next`.
- Adopters get pre-releases via `npm install -g @thebassclef/core@next`.
- Pre-release version format matches semver regex; anything else refuses at `scripts/validate-tag.mjs`.

## Changelog format

Follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) with these subsections:

- **Added** — new features
- **Changed** — changes to existing features
- **Deprecated** — features scheduled for removal
- **Removed** — features that were removed
- **Fixed** — bug fixes
- **Security** — security fixes
- **Notes** — anything the operator wants adopters to see that does not fit the above

Every version block reads left to right: `## [X.Y.Z] - YYYY-MM-DD`. ISO 8601 date. Square brackets around the version.

The `[Unreleased]` block sits at the top. Content lands there during development. `scripts/bump-version.mjs` moves the `[Unreleased]` content into a new `[X.Y.Z]` block and adds a fresh empty `[Unreleased]` block on top.

Compare links at the bottom follow the git tag pattern: `[X.Y.Z]: https://github.com/sunj-labs/bassclef-cli/compare/vW.W.W...vX.Y.Z`. The script updates these on each bump.

## The bump script — `scripts/bump-version.mjs`

Invocation:

```
npm run bump patch
npm run bump minor
npm run bump major
```

Behavior:

1. Reads `package.json` current version.
2. Computes the new version per the arg (patch / minor / major).
3. Reads `CHANGELOG.md`. Refuses if `## [Unreleased]` block is empty or missing.
4. Renames `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` (today's UTC date).
5. Inserts a fresh empty `## [Unreleased]` block above the new version.
6. Updates the compare link at the bottom.
7. Writes new version to `package.json`.
8. Prints new version + next-step reminder (`git add package.json CHANGELOG.md && git commit && git tag vX.Y.Z && git push origin vX.Y.Z`).

Refusals:

- Missing or invalid bump arg → exit 3 with usage.
- Missing `CHANGELOG.md` → exit 1 with "run this from repo root."
- Empty `## [Unreleased]` block → exit 1 with "add changes before bumping."
- Dirty working tree with unrelated changes → exit 1 with "commit or stash first, or pass `--allow-dirty`."
- Package.json missing version field → exit 1.

Escape hatch:

- `--allow-dirty` — bypasses the working tree check. Logged to stderr.
- `--date YYYY-MM-DD` — override today's UTC date (useful for testing + backdated releases).

The script does NOT tag or push. Operator retains explicit control over those steps per ADR-004's separation-of-privilege posture.

## Release-notes shape (for `gh release create`)

The GitHub Release body for each version reuses the changelog's `## [X.Y.Z]` block. Copy-paste from `CHANGELOG.md` after `npm run bump` runs.

Include at minimum:

- The bumped subsections (Added / Changed / etc.)
- A link to the compare view (`https://github.com/sunj-labs/bassclef-cli/compare/vW.W.W...vX.Y.Z`)

No custom formatting. Reader gets the same content on npmjs.com, GitHub Release page, and CHANGELOG.md.

## Deprecation grace period

Per `.claude/rules/we-dont-break-adopters.md`:

- **Below 25 adopters** (current state; 5 adopters per bassclef-source-consumers.json): substrate renames ship immediate. Old vocabulary reads through the translation table. No compat-shim skill stubs per rename. Adopter changelog entry names the rename.
- **At 25 or more adopters** (future state): rename ships with compat alias + fixture + migration manifest + 90-day grace on prose + adopter changelog entry.

Behavior changes stay under full discipline regardless of adopter count. API contract changes, schema shape changes, and hook filename changes always ship with compat shims — the translation table cannot help there.

## What this discipline does NOT cover

- Substrate content versioning — Road 2 per ADR-005 has its own release rhythm on the bassclef repo.
- Node engines bumps as pure-patch — never. Node floor changes are always major per the table above.
- Rolling back a bad publish — `npm deprecate` after the fact, not `npm unpublish` (npm forbids unpublish past 72 hours). Live rollback is a separate incident procedure.

## Refs

- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- ADR-005 — the arc-level architecture this policy governs
- ADR-004 — publish pipeline enforces the tag ↔ version match
- ADR-003 — content-hash normalization is semver-locked per this policy
- `.claude/rules/we-dont-break-adopters.md` — adopter compatibility discipline
- `scripts/bump-version.mjs` — the script this policy pins
- `CHANGELOG.md` — the file the script writes
- Sister: `docs/publish-setup.md` — one-time maintainer setup that runs before the first publish
- Sister: `docs/use-cases/UC-script-bump.md` — brief use case for the bump script
