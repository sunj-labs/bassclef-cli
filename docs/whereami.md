---
tier: lite
---

# Whereami — bassclef-cli

Current project-state snapshot. Schema: `standards/whereami-schema.md`.
Read at session-start, updated at session-end.

## Project-level phase

phase: Inception
note: Execution home for Goal A — build + launch `@thebassclef/core` on npm. Bassclef substrate is inherited via user-scope `~/.claude/hooks/bassclef-sync.sh`; this repo carries only the config layer + build artifacts.

## Active iteration

iteration_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
iteration_started: 2026-08-06
iteration_phase: WU-1 (TypeScript + Vite scaffold — pending)
previous_bet: —
next_bet: —

## Active agents

- orchestrator-gated-sequential (bootstrap + WU-1 handoff)

## Subsystem phases

| Subsystem | Phase | Last iteration | Notes |
|-----------|-------|---------------|-------|
| npm package (`@thebassclef/core`) | Inception | 2026-08-06 | scaffold pending |
| CLI dispatcher | Inception | 2026-08-06 | shape TBD in WU-1 |

## Gate progress (project-level)

### Inception — IN PROGRESS
- [x] Vision doc (Goal A bet at docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md)
- [ ] Risk register populated
- [x] Appetite set (8 WUs per bet)
- [x] Viability hypothesis written (bet doc)
- [x] Build/buy/defer decision (build — npm distribution)

### Elaboration — PENDING
- [ ] Architecture decisions (ADRs)
- [ ] Standards defined
- [ ] Design principles established
- [ ] Object model documented

### Construction — PENDING
- [ ] TypeScript + Vite scaffold (WU-1)
- [ ] package.json with `bin` + files array whitelist + Apache-2.0 LICENSE (WU-1)
- [ ] Sync command (WU-2/3)
- [ ] npm publish workflow (WU-4)

### Transition — PENDING
- [ ] Production deploy gate configured (npm trusted publishing)
- [ ] Smoke tests green
- [ ] Release notes published
- [ ] Chronicle closeout

## Risk register

none yet — file when first risk materializes

## Last updated

2026-08-06T00:00:00+0000 — session-start (bootstrap via /onboard-repo)
session: 2026-08-06-onboard-repo

## Configuration

See substrate.config.md for external resource references.
