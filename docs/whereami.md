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
iteration_phase: WU-1 shipped as PR #2 (awaiting operator review); WU-2 (init command) next
previous_bet: —
next_bet: —

## Active PRs (awaiting review)

- PR #1 — chore/bassclef-bootstrap (substrate config layer): https://github.com/sunj-labs/bassclef-cli/pull/1
- PR #2 — feat/wu-1-scaffold (scaffold shell, stacked on PR #1): https://github.com/sunj-labs/bassclef-cli/pull/2

## Active agents

- orchestrator-gated-sequential (autonomous overnight — bootstrap + WU-1 shipped)

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

### Construction — IN PROGRESS
- [x] TypeScript + Vite scaffold — shipped as PR #2 (feat/wu-1-scaffold)
- [x] package.json with `bin` + files array whitelist + Apache-2.0 LICENSE — shipped as PR #2
- [ ] Init command — init workunit next
- [ ] Sync command — sync workunit
- [ ] npm publish workflow — publish workunit

### Transition — PENDING
- [ ] Production deploy gate configured (npm trusted publishing)
- [ ] Smoke tests green
- [ ] Release notes published
- [ ] Chronicle closeout

## Risk register

none yet — file when first risk materializes

## Last updated

2026-08-06T02:55:00+0000 — session-end (bootstrap + WU-1 shipped as PRs #1 and #2)
session: docs/session-logs/2026-08-06-onboard-plus-wu-1.md

## Configuration

See substrate.config.md for external resource references.
