# Changelog

All notable changes to `@thebassclef/core` land here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The full versioning + changelog discipline lands in WU-5 per iteration
bet 2026-08-06b.

## [Unreleased]

### Added
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
