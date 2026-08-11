# Changelog

All notable changes to `@thebassclef/core` land here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The full versioning + changelog discipline lands in WU-5 per iteration
bet 2026-08-06b.

## [Unreleased]

### Added — semver + changelog methodology (WU-5)
- `standards/npm-versioning-and-changelog.md` — semver rules for 0.x and 1.0+ phases, changelog format per Keep a Changelog 1.1.0, deprecation grace window rules per adopter cohort size.
- `scripts/bump-version.mjs` — one command per bump size (`npm run bump patch|minor|major`). Rewrites `CHANGELOG.md` — renames `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`, inserts fresh empty `[Unreleased]` block, updates compare links. Atomic writes for both `package.json` and `CHANGELOG.md`. Refuses on dirty working tree (except package.json + CHANGELOG.md), missing CHANGELOG, empty Unreleased block, invalid bump arg.
- `--allow-dirty` flag to bypass dirty-tree check. `--date YYYY-MM-DD` flag to override today's UTC date.
- Pre-release strip per semver §11 — any bump from `0.1.0-rc.1` lands on `0.1.0`.
- 27 Tier 0 tests covering parseArgs, computeNewVersion, renameUnreleasedBlock, refuseIfDirty.
- `docs/use-cases/UC-script-bump.md` — brief use case per Cockburn tiering.
- `docs/decompositions/wu-5-methodology.md` — WU-5 decomposition with pre-mortem light + test list.
- `npm run bump` script wired in `package.json`.

### Added — publish pipeline
- `.github/workflows/publish.yml` — one-job GitHub Actions workflow at a semver-locked path. Triggers on `release: [published]` and `workflow_dispatch`. Publishes to npm via trusted publisher with `--provenance --ignore-scripts`.
- `scripts/validate-tag.mjs` — refuses tags that do not string-equal `package.json` version, tags outside the semver format, and tags not reachable from `origin/main`. Also picks the dist-tag (`latest` for stable, `next` for pre-release).
- `scripts/andon-scan.mjs` — scans every file `npm pack` would ship for operator-private terms (absolute home paths, `docs/operator-private/` references, emails outside LICENSE + package.json author). Per-file `# andon-allow: <regex>` header supported. Exit 2 on any hit.
- `scripts/tier-filter.mjs` — refuses any shipped Markdown file whose YAML frontmatter has `tier: upstream`. Handles LF, CRLF, UTF-8 BOM, leading blank lines, and quoted values (single + double). Exit 3 on any hit.
- `docs/publish-setup.md` — one-time operator playbook covering npm 2FA, package name reservation, trusted publisher config, GitHub Environment, per-release flow, and a post-publish audit habit.
- ADR-004 — publish pipeline safety contract. Semver-locks workflow path, triggers, permissions, ordered checks, dist-tag rule, exit codes, tag-format regex, refusal message shape, and tier-filter YAML normalization.

### Added — sync command
- `bassclef init` — writes `.claude/settings.json` + `substrate.config.md` + `.bassclef/init.manifest.json` into a project directory. Safety contract in ADR-002 (fail-safe overwrite, atomic writes, path scoping, symlink refusal unconditional).
- Init flags: `--force`, `--dry-run`, `--dir <path>`, `--allow-root`, `--allow-any-dir`, `--verbose`.
- Init manifest carries template versions + content hashes + per-file outcomes so sync can upgrade cleanly.
- ADR-002 — bassclef init safety contract. Semver-locks defaults, files, escape-hatch matrix, exit codes.
- `bassclef sync` — reads the init manifest, detects change per file (four cases: Current / NeedsUpdate / Edited / Deleted), applies updates under `--force` (versions) + `--replace-edits` (adopter edits). Content-hash detection catches adopter edits via SHA-256 with BOM strip + CRLF normalization.
- Sync flags: `--force`, `--replace-edits`, `--dry-run`, `--diff`, `--dir`, `--allow-root`, `--allow-any-dir`, `--verbose`.
- Exit code 4 added for "manifest schema is newer than this package understands."
- ADR-003 — bassclef sync safety contract. Semver-locks two-force-flag design, content-hash normalization steps, single-writer assumption, exit codes.

### Changed
- Init refuses to re-baseline an existing manifest without `--force`. `bassclef sync` is the path for updates; init is greenfield-only.
- Init manifest schema bumped to 0.0.2 (adds `content_hash_sha256`, `updated_at`; renamed `template_version` → `manifest_schema_version` at the `$bassclef` block).
- **CLI unknown-command exit (iteration b).** `bassclef <unknown>` now exits 3 (invalid args per ADR-002 §Exit codes) instead of 1. Aligns with the "Unknown → exit 3" boundary contract in the interaction design doc. Scripted callers that keyed on `!= 0` still pass; callers that keyed specifically on `== 1` need to update. Semver-locked from 0.0.2.

### Fixed — iteration b drift pass
- **ADR Status body drift (D-1.1 + D-2.4 + D-3.3 + D-4.2).** ADRs 001-004 had Status bodies that read "proposed" while their frontmatter said "accepted". Bodies now match the frontmatter. Reason: the ADRs were authored 2026-08-06 in a proposed state then flipped to accepted 2026-08-08 without updating the body prose. ADR-005 was authored fresh at 2026-08-08 without a Status body and stays that way.
- **ADR-001 shebang banner invariant (D-1.2).** Named the semver-locked contract that Vite `rollupOptions.output.banner` MUST inject `#!/usr/bin/env node` on `dist/cli.js`. The invariant lived in `vite.config.ts` L54-55 but not in the ADR — a silent-failure class if removed.
- **ADR-002 files count (D-2.1).** Context section said `bassclef init` writes two files; Invariants section said three. Both now say three (`.claude/settings.json`, `substrate.config.md`, `.bassclef/init.manifest.json`).
- **ADR-002 complete-mediation extension (D-2.2).** Named `mkdirSafely` alongside `writeSafely` under §Complete-mediation. Init's parent-directory creation runs through the same audited surface as writes.
- **ADR-003 case table extension (D-3.1).** Named `NoMarker` and `UnknownHash` as first-class sync cases. Both were shipped in `sync.ts` and UC-sync but not listed in the ADR's case table.
- **UC-sync unified-diff wording (D-3.4).** UC-sync claimed `--diff` produces a unified diff per file. Actual code shows a template-version summary; full unified diff is later work. UC now reflects the real shape and cites the code comment.
- **UC-script-bump `--allow-dirty` logging claim (D-8.2).** UC said the flag logs to stderr; code silently returns. UC now reflects the real shape and marks the stderr log as a possible follow-on.
- **Interaction-design git-tag data source (D-8.3).** Boundary contract said the workflow reads the tag via `${{ github.ref }}`. Actual workflow reads via `github.event.release.tag_name` or `inputs.tag`. Doc now matches.
- **CLI unknown-command exit-code drift (D-5.2).** See Changed above.
- **Whereami D-9.1 skipped.** The stale setup-docs line lives on the unmerged session-close PR #10, not on main. Handled separately when that PR resolves.

### Security
- **Source-map exclusion (iteration a).** `package.json` `files` field is now an explicit whitelist (`dist/*.js`, `dist/*.cjs`, `dist/*.d.ts`) instead of the bulk `dist` entry. `vite.config.ts` `sourcemap` flipped from `true` to `'hidden'` — build still emits map files for local debugging but strips the `//# sourceMappingURL=` reference from shipped `.js`. Together the two layers block the shipping pattern that produced the Anthropic v2.1.88 leak in March 2026 (59.8 MB source map exposed ~513K lines of TypeScript per InfoQ + Layer5 write-ups). Semver-locked from 0.0.2 per ADR-001 §Invariants.
- `tests/pack-no-source-maps.test.ts` — 6 Tier 0 tests verify both layers of the source-map exclusion. Runs on every `npm test`.

### Notes
- Settings template ships MINIMAL — no `../bassclef` sibling assumption. Sync populates references when templates ship real content.
- Content-hash algorithm is semver-locked from 0.0.2. Any change to the normalization steps is a MAJOR bump.
- No file lock — two concurrent bassclef processes on the same target dir race. Single-writer discipline is the operator's responsibility.

## [0.0.1] — 2026-08-06

Initial scaffold. Shell only — real command behavior lands in WU-2 and
later.

### Added
- CLI shell — `bassclef --version`, `bassclef --help`, `bassclef init` (stub), `bassclef sync` (stub).
- Programmatic API — `version: string` export from `@thebassclef/core`.
- Package shape — `bin` field, `files` whitelist, `exports` map, dual module (ESM + CJS), `types` (.d.ts).
- Build stack — Vite 5 (library mode) + TypeScript 5.5 + Vitest 2.
- Node 20 minimum via `engines.node: ">=20"`.
- Apache-2.0 LICENSE.
- README.md — Cooper first-touch pass.
- ADR-001 — build toolchain pin.

### Notes
- Zero runtime dependencies. Dev dependencies only.
- No `postinstall` / `preinstall` / `prepublishOnly` scripts.
- `bassclef init` and `bassclef sync` exit non-zero with a "WU-2/3 will land this" message. Intentional — the scaffold ships before the behavior so publish + install can be tested end-to-end.

[Unreleased]: https://github.com/sunj-labs/bassclef-cli/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/sunj-labs/bassclef-cli/releases/tag/v0.0.1
