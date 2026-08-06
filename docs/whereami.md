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
iteration_phase: WU-1 + WU-2 + WU-3 merged; WU-4 (publish pipeline) on feat/wu-4-publish awaiting PR
previous_bet: —
next_bet: —

## Shipped

- PR #1 — chore/bassclef-bootstrap MERGED (substrate config layer)
- PR #3 — feat/wu-1-scaffold MERGED (scaffold shell + package.json + LICENSE + WU-1 tests)
- PR #4 — feat/wu-2-init MERGED (bassclef init command with ADR-002 safety contract)
- PR #5 — feat/wu-3-sync MERGED (bassclef sync command with ADR-003 safety contract)
- PR #6 — chore/decomp-diagrams-backfill MERGED (WU-2 + WU-3 state + sequence diagrams)

## In flight

- feat/wu-4-publish (publish pipeline with ADR-004 safety contract) — 110 tests green, ready to open PR

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
- [x] TypeScript + Vite scaffold — merged (PR #3)
- [x] package.json with `bin` + files array whitelist + Apache-2.0 LICENSE — merged (PR #3)
- [x] Init command with safety contract (ADR-002) — merged (PR #4)
- [x] Sync command with safety contract (ADR-003) — merged (PR #5)
- [x] npm publish workflow with safety contract (ADR-004) — on feat/wu-4-publish awaiting PR

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
