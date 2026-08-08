---
tier: lite
---

# Whereami — bassclef-cli

Current project-state snapshot. Schema: `standards/whereami-schema.md`.
Read at session-start, updated at session-end.

## Project-level phase

phase: Construction
note: Execution home for Goal A — build + launch `@thebassclef/core` on npm. Bassclef substrate is inherited via user-scope `~/.claude/hooks/bassclef-sync.sh`; this repo carries only the config layer + build artifacts.

## Active iteration

iteration_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
iteration_started: 2026-08-06
iteration_phase: WU-1 + WU-2 + WU-3 + WU-4 + WU-5 merged. Setup-docs, WU-6, WU-7, WU-8, WU-9 owed.

## Operator recap

Session 2026-08-08 shipped WU-5 (semver + changelog methodology + bump script + 27 Tier 0 tests) and closed the OOAD discipline gap the operator caught mid-session — 4 ADRs flipped from proposed to accepted, ADR-005 authored for the two-road architecture, interaction-design doc + 4 Cockburn use cases backfilled. Five bassclef-upstream promote tickets filed (#1167-1171) naming the substrate-level gap where OOAD skills produce artifacts nothing consumes at engineering time. PRs #8 and #9 merged; WU-6 (upstream), WU-7 (Adam PRs deferred), WU-8 (needs live 0.0.2), and WU-9 (tag + publish) remain.
previous_bet: —
next_bet: —

## Shipped

- PR #1 — chore/bassclef-bootstrap MERGED (substrate config layer)
- PR #3 — feat/wu-1-scaffold MERGED (scaffold shell + package.json + LICENSE + WU-1 tests)
- PR #4 — feat/wu-2-init MERGED (bassclef init command with ADR-002 safety contract)
- PR #5 — feat/wu-3-sync MERGED (bassclef sync command with ADR-003 safety contract)
- PR #6 — chore/decomp-diagrams-backfill MERGED (WU-2 + WU-3 state + sequence diagrams)
- PR #7 — feat/wu-4-publish MERGED (publish pipeline with trusted publisher + ADR-004)
- PR #8 — docs(wu-5): backfill ADRs + interaction-design + use cases MERGED
- PR #9 — feat(wu-5): semver + changelog methodology + bump script MERGED

## In flight

- Session-close PR (this artifact) on chore/session-close-2026-08-08

## Active agents

- operator-gated-sequential (checkpointed at every scope decision)

## Subsystem phases

| Subsystem | Phase | Last iteration | Notes |
|-----------|-------|---------------|-------|
| npm package (`@thebassclef/core`) | Construction | 2026-08-08 | WU-1..5 shipped; setup-docs + WU-9 owed before first tagged 0.0.2 |
| CLI dispatcher | Construction | 2026-08-08 | Shell + init + sync + publish pipeline all merged |
| Publish pipeline | Construction | 2026-08-08 | Workflow + scan scripts + trusted-publisher config merged; ready to run on first tag |
| Bump discipline | Construction | 2026-08-08 | scripts/bump-version.mjs + standards doc + 27 Tier 0 tests merged |

## Gate progress (project-level)

### Inception — COMPLETE
- [x] Vision doc (Goal A bet at docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md)
- [ ] Risk register populated
- [x] Appetite set (8 WUs per bet)
- [x] Viability hypothesis written (bet doc)
- [x] Build/buy/defer decision (build — npm distribution)

### Elaboration — IN PROGRESS
- [x] Architecture decisions (ADR-001, ADR-002, ADR-003, ADR-004, ADR-005 all accepted)
- [x] Standards defined (standards/npm-versioning-and-changelog.md)
- [ ] Design principles established
- [x] Object model documented (docs/interaction-design/2026-08-08-npm-distribution.md + docs/use-cases/UC-*.md)

### Construction — IN PROGRESS
- [x] TypeScript + Vite scaffold — merged (PR #3)
- [x] package.json with `bin` + files array whitelist + Apache-2.0 LICENSE — merged (PR #3)
- [x] Init command with safety contract (ADR-002) — merged (PR #4)
- [x] Sync command with safety contract (ADR-003) — merged (PR #5)
- [x] npm publish workflow with safety contract (ADR-004) — merged (PR #7)
- [x] Semver + changelog methodology (ADR-005 + standards + bump script) — merged (PR #9)
- [ ] Setup-docs fill-in (docs/publish-setup.md)
- [ ] Cold-adopter harness against npm path (WU-6 — bassclef-upstream side)
- [ ] Adam Sharpe security PRs (WU-7 — deferred per bet L128)

### Transition — PENDING
- [ ] One-time trusted-publisher setup on npmjs.com
- [ ] GitHub Environment `npm-publish` with operator as required reviewer
- [ ] First tagged 0.0.2 release (WU-9)
- [ ] Sam demo (WU-8; needs live 0.0.2)
- [ ] /architect-review at bet close
- [ ] Chronicle closeout

## Open promote tickets (bassclef-upstream)

- #1167 — wire OOAD dispatch into /longrun
- #1168 — wire OOAD dispatch into /build
- #1169 — mechanize oo-ad-entry-point.md as a PreToolUse hook
- #1170 — adr-discipline-check.sh warn on proposed ADRs after PRs merge
- #1171 — umbrella: OOAD artifacts as first-class inputs to /build /longrun /sprint

## Risk register

- WU-7 (Adam Sharpe security PRs) deferred per bet L128 — must land before 0.1.0 or 0.0.3.
- Setup-docs owed before WU-9 — the workflow refuses to publish without trusted-publisher + Environment configured.

## Last updated

2026-08-08T18:55:13Z — session-end (WU-5 + OOAD backfill + 5 upstream promote tickets)
session: docs/session-logs/2026-08-08-wu-5-plus-ooad-backfill.md

## Configuration

See substrate.config.md for external resource references.
