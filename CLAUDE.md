# bassclef-cli

@.claude/bassclef-orientation.md

## What this repo is

Execution home for Goal A — build + launch `@thebassclef/core` on npm.
The npm package replaces the tarball distribution path
(`.bassclef-source.json` + sync-hook fetch) with a standard installer:
`npm install -g @thebassclef/core && bassclef init`.

## Substrate

Substrate is inherited from `~/src/sunj-labs/bassclef` via user-scope
`~/.claude/hooks/bassclef-sync.sh` — it symlinks `.claude/skills/`,
`.claude/rules/`, `.claude/luminaries/`, `.claude/agents/`, and
`.claude/hooks/` at every SessionStart. The `@import` above loads the
orientation into every session.

**No per-repo tarball wiring.** No `.bassclef-source.json`, no
`bassclef-sync.sh` under `.claude/hooks/`, no tarball URL refresh
matrix. Handoff at `HANDOFF.md:49-51` names this explicitly.

## Stack

TypeScript on Node.js ≥ 20, built with Vite, published to npm as
`@thebassclef/core`. Package layout carries `bin/` for the CLI
dispatcher. See `.claude/bassclef-configs.jsonc` `tech_stack` for the
full declaration.

## Current state

Phase: Construction. Iteration: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`.
WU-1 (scaffold + package.json + LICENSE) shipped as PR #3, merged. WU-2
(`bassclef init` command) is on `feat/wu-2-init`. Next: WU-3 (sync).
Read `docs/whereami.md` at session-start for the live snapshot.

## Shipped commands

- `bassclef --version` / `--help` — prints info; exits 0.
- `bassclef init [--force] [--dry-run] [--dir <path>] [--allow-root] [--allow-any-dir] [--verbose]` — writes `.claude/settings.json` + `substrate.config.md` + `.bassclef/init.manifest.json` into a project directory. Safety contract: `docs/adrs/ADR-002-bassclef-init-safety-contract.md`.
- `bassclef sync` — stub; sync workunit lands the real implementation.

## Architecture decisions

- `docs/adrs/ADR-001-npm-package-build-toolchain.md` — Vite (library mode) + TypeScript + Vitest pinned.
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` — init command's fail-safe defaults, atomic writes, path scoping, escape-hatch matrix. Semver-locked from 0.0.2.

## Primary luminary triad (per iteration bet)

- **Alan Cooper** — command shape + operator experience of the CLI
- **John Ousterhout** — deep modules for the sync + init surfaces
- **Saltzer & Schroeder** — 7 defensive disciplines on the npm
  security surface (files array whitelist, `--ignore-scripts`,
  no `prepublishOnly` auto-build, trusted publishing, provenance)

Any code change on those surfaces MUST cite its dominant lens.

## What NOT to do

- Do NOT create `.bassclef-source.json` — tarball has zero adopters;
  the bet's whole point is going straight to npm. Memory:
  `project-tarball-distribution-deprecated`.
- Do NOT add `bassclef-sync.sh` to `.claude/hooks/` — user-scope sync
  already fires. Per-repo dispatcher would double-fire.
- Do NOT `npm publish` in autonomous sessions — publishing is a manual
  operator step gated on trusted-publishing config + review.
