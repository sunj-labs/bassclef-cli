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

Phase: Inception. Iteration: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`.
Next WU: WU-1 (TypeScript + Vite scaffold + package.json + LICENSE).
Read `docs/whereami.md` at session-start for the live snapshot.

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
