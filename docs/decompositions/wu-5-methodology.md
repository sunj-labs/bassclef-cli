---
tier: standard
name: WU-5 — semver + changelog methodology decomposition
slug: wu-5-methodology
authored: 2026-08-08
authored_by: agent
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
wu: 5
luminaries:
  primary: john-ousterhout
  supporting: [saltzer-schroeder, alan-cooper]
  rotation_reason: WU-5 ships a bump script that writes to package.json and CHANGELOG.md. Ousterhout for deep-module framing (bump policy hidden behind a single verb). Saltzer for the audited write posture. Cooper for the operator-facing output shape.
---

# WU-5 — semver + changelog methodology decomposition

WU-5 ships the versioning policy plus the mechanism the operator uses to apply it. Small scope. One doc + one script + tests + a CHANGELOG amendment.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` L124 (WU-5 scope) + L136 (discipline touchpoints — WU-5 not explicitly named, so applying `.claude/rules/oo-ad-entry-point.md` tier for scripts)
- `standards/npm-versioning-and-changelog.md` (this WU's standards doc — authored in the same PR)
- `docs/adrs/ADR-005-npm-distribution-architecture.md` (Road 1 semver contract; lives in PR #8)
- `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` (validate-tag.mjs enforces version match)
- `CHANGELOG.md` (current shape uses Keep a Changelog 1.1.0 with Added/Changed/Notes subsections)
- `package.json` (version 0.0.1, no bump script in scripts block)
- `.claude/rules/oo-ad-entry-point.md` L21 tiering — scripts fall under "adopter-facing script" tier (brief use case + Tier 0 tests)

## Boundary objects — what the operator touches

| Boundary | Shape |
|---|---|
| `npm run bump patch\|minor\|major` | The operator's trigger. Standard npm script. |
| `package.json` after bump | version field updated. Nothing else changed. |
| `CHANGELOG.md` after bump | `## [Unreleased]` renamed to `## [X.Y.Z] - YYYY-MM-DD`. Fresh empty `## [Unreleased]` block inserted above. Compare link at bottom updated. |
| Terminal output | New version + reminder to git add + commit + tag + push. |
| Refusal output | Names what failed + what to run to fix. |

## Entity objects — state the script reads or writes

| Entity | Owner | Read or written? |
|---|---|---|
| `package.json` version field | package.json | Read (current) + written (new) |
| `CHANGELOG.md` `[Unreleased]` block | CHANGELOG.md | Read (content) + rewritten (renamed to versioned block) |
| `CHANGELOG.md` compare link | CHANGELOG.md footer | Read + written (adds a new link) |
| Today's UTC date | `Date` | Read at run time; overridable via `--date YYYY-MM-DD` for testing |
| Working tree state | `git status` | Read (dirty check) |
| Bump arg | `argv[2]` | Read (one of patch/minor/major) |

## Control objects — the code

| Control | Responsibility | Shape |
|---|---|---|
| `main()` in `scripts/bump-version.mjs` | Parse arg, refuse if dirty or arg bad, compute new version, rewrite CHANGELOG, write package.json, print next-step guidance | ≤ 100 lines. One entry point. |
| `parseArgs(argv)` | Return `{bumpType, allowDirty, dateOverride}` or throw ArgvError | ≤ 20 lines. Pure. |
| `computeNewVersion(current, bumpType)` | Return new semver string per bump rules | ≤ 15 lines. Pure. Handles pre-release strip on any bump (drops `-rc.1` etc.). |
| `refuseIfDirty(allowDirty)` | Check `git status --porcelain -uno` — refuse if any file other than package.json / CHANGELOG.md is modified. `--allow-dirty` bypasses. | ≤ 15 lines. |
| `renameUnreleasedBlock(changelogText, newVersion, date)` | Rename `## [Unreleased]` heading. Insert fresh empty `## [Unreleased]` block above. Update compare links at bottom. Refuse if `## [Unreleased]` empty or missing. | ≤ 40 lines. Pure string transform. |
| `writePackageJsonVersion(packagePath, newVersion)` | Write only the version field. Preserve every other field's ordering + indentation. | ≤ 15 lines. |

## Test list first (Beck)

Tier 0 — MUST pass before merge (per `.claude/rules/testing-tier-config.md` global floor for `scripts/*.mjs`):

- [ ] patch bump: 0.0.1 → 0.0.2 (package.json + CHANGELOG both updated)
- [ ] minor bump: 0.1.0 → 0.2.0
- [ ] major bump: 0.1.0 → 1.0.0
- [ ] pre-release strip: 0.1.0-rc.1 → 0.1.0 on any bump type (per semver §11)
- [ ] missing arg: exits 3 with usage
- [ ] invalid arg (`bump abc`): exits 3 with usage + valid options
- [ ] missing CHANGELOG.md: exits 1 with "run from repo root"
- [ ] empty `## [Unreleased]` block: exits 1 with "add changes before bumping"
- [ ] missing `## [Unreleased]` block: exits 1
- [ ] non-empty `## [Unreleased]` block: renames to `## [X.Y.Z] - YYYY-MM-DD`, adds fresh `## [Unreleased]` above
- [ ] compare link at bottom updated with new version
- [ ] fresh empty Unreleased block carries the standard subsections (Added / Changed / Fixed / Notes empty)
- [ ] dirty working tree (unrelated file modified): exits 1 with "commit or stash first, or pass --allow-dirty"
- [ ] `--allow-dirty` bypasses the dirty check
- [ ] `--date 2026-01-15` uses the override date, not today
- [ ] on success: prints new version + reminder command line
- [ ] package.json field order + indentation preserved after write

Tier 1 — SHOULD pass (deferred to follow-on if scope pressure hits):

- [ ] Idempotency: running bump twice in a row is not the same as running it once — the second run has no `[Unreleased]` content to move (refuses per empty-block rule)

## Pre-mortem light — 2 lenses × 2 risks

### Ousterhout lens

1. **RISK: The bump script grows one flag at a time (`--allow-dirty`, `--date`, then `--tag-format`, `--skip-changelog`) and becomes a 200-line matrix.**
   - Owner: script authorship
   - Mitigation: pin 2 flags in ADR-006 or embed in `standards/npm-versioning-and-changelog.md`. Every new flag needs justification. Prefer separate scripts for genuinely separate concerns.

2. **RISK: The CHANGELOG parser hand-rolled here diverges from real CHANGELOG.md over time.**
   - Owner: `renameUnreleasedBlock` parser
   - Mitigation: Tier 0 test uses the actual CHANGELOG.md as fixture. Any change to CHANGELOG shape breaks the test at fixture-update time, not at production-run time.

### Saltzer-Schroeder lens

3. **RISK: The script writes to a git-tracked file with no atomic write. A crash mid-write leaves package.json corrupt.**
   - Owner: `writePackageJsonVersion`
   - Mitigation: write to `.tmp` sibling, then rename atomically via `fs.renameSync`. Same pattern the init/sync commands use (per `src/lib/write-safely.ts`).

4. **RISK: The dirty-tree check misses staged-but-not-committed files.**
   - Owner: `refuseIfDirty`
   - Mitigation: use `git status --porcelain` (not `--porcelain -uno`) to catch both staged and unstaged. Test the case explicitly.

## Interface shape

```
Usage:
  npm run bump patch          Bump patch (0.0.X → 0.0.X+1)
  npm run bump minor          Bump minor (0.X.Y → 0.X+1.0)
  npm run bump major          Bump major (0.Y.Z → 1.0.0 during 0.x; X+1.0.0 at 1.0+)

Flags:
  --allow-dirty               Allow bump with unrelated file changes
  --date YYYY-MM-DD           Override today's UTC date (for testing)

Exit codes:
  0  Success — version bumped, CHANGELOG rewritten
  1  Refused — CHANGELOG missing, Unreleased empty, dirty tree
  3  Invalid args — missing or unknown bump type
```

## What WU-5 must produce

- [ ] `standards/npm-versioning-and-changelog.md` — the policy doc (authored)
- [ ] `docs/decompositions/wu-5-methodology.md` — this file (authored)
- [ ] `docs/use-cases/UC-script-bump.md` — brief use case (Cockburn script tier)
- [ ] `scripts/bump-version.mjs` — the bump script
- [ ] `tests/bump-version.test.ts` — Tier 0 tests (17+ tests per list above)
- [ ] `package.json` — add `bump` script entry (`"bump": "node scripts/bump-version.mjs"`)
- [ ] `CHANGELOG.md` — amend `## [Unreleased]` block to add Added / Changed / Fixed / Notes subsections empty, ready for WU-5 content

## What WU-5 does NOT ship

- Auto-tagging or auto-pushing — operator retains explicit control per ADR-004 separation-of-privilege.
- Auto-generating the release notes body from CHANGELOG (operator copy-pastes for now).
- Publishing to npm — that lives in the publish workflow (ADR-004).
- Setup docs update — separate branch.
- First tagged 0.0.2 release — separate branch (WU-9).

## Open questions

- None. Every design decision the script makes is pinned in `standards/npm-versioning-and-changelog.md`.
