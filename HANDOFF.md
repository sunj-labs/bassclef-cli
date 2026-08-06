# Handoff — first session bootstrap

This repo was created by a bassclef-upstream session on 2026-08-06 as the execution home for Goal A (build + launch `@thebassclef/core` on npm).

## What already happened when Claude Code first launched here

Nothing you need to do — `~/.claude/hooks/bassclef-sync.sh` (user scope, installed on your machine) fires at every SessionStart. It populated `.claude/` here on your first session: symlinks to skills + rules + luminaries (pointing at `~/src/sunj-labs/bassclef`), hooks directory, and a settings.json. This is the current-state install path.

**Known first-session friction:** two SessionStart hook errors appear before bassclef-sync completes population — `session-reflection.sh` and `session-start-recap-inject.sh` at `$CLAUDE_PROJECT_DIR/.claude/hooks/` don't exist yet at that point. Race condition. Filed as sunj-labs/bassclef-upstream#1145. Not fatal — the session continues, and the hooks exist for the next SessionStart.

## Do NOT run /onboard-repo

The substrate is already installed via user-scope bassclef-sync. `/onboard-repo` would layer additional settings.json edits on top. That whole per-repo settings.json pattern is being replaced by `managed-settings.d/bassclef.json` (design in `design/discoveries/2026-08-04-managed-settings-d-as-bassclef-wiring-channel.md`). Adapter exists; rollout to this machine pending. Filed under sunj-labs/bassclef-upstream#1145 for Goal B.

## Turn 1 — /longrun prep

```
/longrun prep
```

Reads `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` as the pickup contract. WU-0 is already done on the bassclef-upstream side. Next is WU-1 — bootstrap the TypeScript + Vite scaffold per the bet's step map.

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
- Do NOT add tarball-related settings.json entries — same reason.

Good luck. The bet doc is your compass.
