# Changelog

All notable changes to `@thebassclef/core` land here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The full versioning + changelog discipline lands in WU-5 per iteration
bet 2026-08-06b.

## [Unreleased]

### Added
- `bassclef init` — writes `.claude/settings.json` + `substrate.config.md` + `.bassclef/init.manifest.json` into a project directory. Safety contract in ADR-002 (fail-safe overwrite, atomic writes, path scoping, symlink refusal unconditional).
- Six flags: `--force`, `--dry-run`, `--dir <path>`, `--allow-root`, `--allow-any-dir`, `--verbose`.
- Init manifest carries template versions and per-file outcomes so the sync command can upgrade cleanly.
- ADR-002 — bassclef init safety contract. Semver-locks defaults, files, escape-hatch matrix, exit codes.

### Notes
- Settings template ships MINIMAL — no `../bassclef` sibling assumption. Sync will populate substrate references when it lands.
- `bassclef sync` remains a stub. Real implementation lands in the sync workunit.

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
