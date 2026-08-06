# Handoff — first session bootstrap

This repo was created by a bassclef-upstream session on 2026-08-06 as the execution home for Goal A (build + launch `@thebassclef/core` on npm). Bassclef substrate is NOT vendored here. Access it at launch via `--add-dir`.

## Turn 1 — launch Claude Code with substrate access

```bash
cd ~/src/sunj-labs/bassclef-cli
claude --add-dir ~/src/sunj-labs/bassclef-upstream
```

The `--add-dir` gives this session read access to bassclef-upstream's `.claude/skills/`, `.claude/rules/`, `.claude/hooks/`, `.claude/luminaries/`. Skills like `/longrun` + `/decompose` + `/verify` + `/kiss` + `/luminary` resolve from that directory. No tarball fetch, no dispatcher install, no `.bassclef-source.json`.

## Turn 2 — /longrun prep

```
/longrun prep
```

Reads `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` as the pickup contract. WU-0 (bet doc + markers) is already done on the bassclef-upstream side. Next is WU-1 — bootstrap the TypeScript + Vite scaffold per the bet's step map.

## Context you should have

The Goal A bet doc `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` carries:

- 8 substantive WUs (bootstrap → init → sync → publish → semver → cold-adopter → security → Sam demo)
- Primary luminaries: alan-cooper + john-ousterhout + saltzer-schroeder
- npm best practices — files array whitelist, trusted publishing, provenance, `--ignore-scripts`, no `prepublishOnly` auto-build
- Handoff notes at the bottom

## Sibling execution

Goal B (polish — vocab + legibility for Louis) is executing in parallel in the `~/src/sunj-labs/bassclef-upstream` pane. The two goals do not overlap. Token pressure stays local per repo.

## First WU to ship

WU-1 per the bet doc — bootstrap TypeScript + Vite build + package.json with `bin` field + files array whitelist + Apache-2.0 LICENSE. `/decompose` the repo shape before writing code per operator direction (bake in `/decompose` + `/pattern-review` + `/architect-review` touchpoints).

## What NOT to do

- Do NOT run `/onboard-repo`. That skill installs the tarball distribution path this bet is replacing.
- Do NOT create `.bassclef-source.json`. Same reason.
- Do NOT vendor bassclef skills or rules into this repo. `--add-dir` at launch is the pattern.

Good luck. The bet doc is your compass.
