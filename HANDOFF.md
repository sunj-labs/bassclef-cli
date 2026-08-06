# Handoff — first session bootstrap

This repo was created by a bassclef-upstream session on 2026-08-06 as the execution home for Goal A (build + launch `@thebassclef/core` on npm).

## Turn 1 — /onboard-repo

```
/onboard-repo
```

Pick Path A. Answer Phase 2.x `tech_stack` prompts:

- `frontend`: `none`
- `backend`: `none`
- `runtime`: `node` (min version 20)
- `lang`: `typescript`
- `pkg_manager`: `npm`
- `orm`: `none`

**Known tech debt (do NOT block on it):** /onboard-repo writes per-repo `.claude/settings.json` today. That editing pattern is being replaced by `managed-settings.d/bassclef.json` per `design/discoveries/2026-08-04-managed-settings-d-as-bassclef-wiring-channel.md`. Tracked at sunj-labs/bassclef-upstream#1145 + folded into Goal B WU-1. Run /onboard-repo anyway — the settings.json layered on top is safe, just duplicated with the user-scope bassclef-sync that already populated `.claude/` here on first SessionStart.

**Also known — first-session hook errors:** Two SessionStart hooks (`session-reflection.sh` + `session-start-recap-inject.sh`) fire not-found errors before bassclef-sync completes the first `.claude/hooks/` population. Race condition. Not fatal. Also tracked in #1145.

## Turn 2 — /longrun prep

```
/longrun prep
```

Reads `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` as the pickup contract. WU-0 done on bassclef-upstream side. Next is WU-1 — bootstrap the TypeScript + Vite scaffold per the bet's step map.

## Context you should have

The Goal A bet doc `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` carries:

- 8 substantive WUs (bootstrap → init → sync → publish → semver → cold-adopter → security → Sam demo)
- Primary luminaries: alan-cooper + john-ousterhout + saltzer-schroeder
- npm best practices — files array whitelist, trusted publishing, provenance, `--ignore-scripts`, no `prepublishOnly` auto-build
- Handoff notes at the bottom

## Sibling execution

Goal B (polish — vocab + legibility for Louis) is executing in parallel from `~/src/sunj-labs/bassclef-upstream`. Two goals do not overlap. Token pressure stays local per repo.

## First WU to ship

WU-1 per the bet doc — bootstrap TypeScript + Vite build + package.json with `bin` field + files array whitelist + Apache-2.0 LICENSE. `/decompose` the repo shape before writing code per operator direction (bake in `/decompose` + `/pattern-review` + `/architect-review` touchpoints).

## What NOT to install

- Do NOT create `.bassclef-source.json` pointing at the tarball path — tarball has zero adopters; going straight to npm. Memory: `project-tarball-distribution-deprecated`.

Good luck. The bet doc is your compass.
