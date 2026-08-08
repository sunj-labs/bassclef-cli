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
