---
tier: lite
spec: lite-rename-sync-publish
title: Spec — rename @thebassclef/core → @thebassclef/lite, sync substrate to v1.5.0, publish 0.1.0
authored: 2026-09-07
goal: 2026-09-07-lite-rename-sync-publish
uc: docs/use-cases/UC-lite-rename-sync.md
decomposition: docs/decompositions/lite-rename-sync-publish.md
references:
  - {type: goal, id: docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md}
  - {type: uc, id: docs/use-cases/UC-lite-rename-sync.md}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-07-lite-rename-sync.md}
---

# Spec — lite-rename-sync-publish

## Sources read

- `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md` — parent goal; 7-step chain + acceptance
- `docs/use-cases/UC-lite-rename-sync.md` — main success scenario + extensions covering top-3 pre-mortem risks
- `docs/risk-ledgers/2026-09-07-lite-rename-sync.md` — 3-lens risk ledger; drove new Step 2.5, extended Step 3, new Step 3.5
- `.claude/rules/pr-strategy.md` — stacked atomic default; bundle exception documented per allow-list
- `.claude/rules/test-list-discipline.md` — Beck test-list block for new test file in Step 4
- `package.json` — current name @thebassclef/core@0.1.1, files array, prepublishOnly, bin
- `substrate/.bassclef/lite-manifest.json` — current manifest_version 1.2.19 (sync target v1.5.0)

## What I'm NOT reading (with reason)

- `docs/ia-models/` — no UI surface; operator direction skips UX artifacts
- `docs/interaction-designs/` — same; no UI flows here
- prototype files — CLI-only scope; no mock gallery

## Overview

Ship `@thebassclef/lite@0.1.0` to npm as the go-forward package name. Bundle the current v1.5.0 substrate. Deprecate `@thebassclef/core`. Close coord ticket #51 Q1. Seven implementation PRs stacked in dependency order.

## Branch strategy

Stacked atomic per `.claude/rules/pr-strategy.md`. One branch per step (2 through 8). Each branch cuts from `main` after its predecessor merges. Reviewer merges upstream branches before dependents cut.

- `feat/step-2-sync-substrate-v1.5.0` (cuts from main after Step 1 merged; DONE)
- `feat/step-3-extended-validate-copy-substrate` (cuts from main after Step 2 merged)
- `feat/step-4-tarball-audit-tier-0` (cuts from main after Step 3 merged)
- `feat/step-5-trusted-publisher-verify` (cuts from main after Step 4 merged)
- `feat/step-6-rename-package-publish-lite-0.1.0` (cuts from main after Step 5 merged)
- `feat/step-7-deprecate-core` (cuts from main after Step 6 merged AND publish live)
- `feat/step-8-coord-51-comment` (cuts from main after Step 7 merged)

Bundle exception per pr-strategy allow list — Steps 4 (tarball audit) + Step 5 (trusted-publisher verify) MAY bundle if audit reveals a config gap that changes the tarball surface. Default is stacked.

## Acceptance criteria per step

### Step 2 — sync substrate v1.2.19 → v1.5.0
- `substrate/**` refreshed from upstream v1.5.0 git tag SHA (SHA pinned in PR body per Saltzer #2)
- `substrate/.bassclef/lite-manifest.json` regenerated; `manifest_version: "1.5.0"`; no `upstream_commit` field; `problem` + `value` per entry
- CHANGELOG entry names: /build promoted to lite, 4 skills retagged, 14 luminaries flipped to lite
- All 11 existing tests still GREEN
- PR body cites: upstream #1508, #1480, #1462, #1478, #1459

### Step 3 — extended validate
- `copy-substrate --dry-run` runs on fresh clone (bundle only, no adopter state)
- Result: `copied.length === manifest.entries.length` AND `refused.length === 0` AND `errored.length === 0`
- Smoke output written to `state/markers/smoke/lite-v1.5.0-validate.md`
- If any `entry.path` fails to resolve, halt and diagnose per pre-mortem Ousterhout #1

### Step 4 — pre-publish tarball audit + Tier 0 test
- `npm publish --dry-run` generates tarball listing
- Grep tarball for these paths — count must be 0 for each:
  - `operator-private/`
  - `chronicle/`
  - `journals/`
  - `state/markers/`
  - `docs/session-logs/`
- New Tier 0 test at `tests/harness/tarball-cleanliness.test.ts` asserts tarball has no operator-private paths
- Test file opens with test-list block per `.claude/rules/test-list-discipline.md`

### Step 5 — trusted-publisher config verification
- Log in to npm; view trusted-publisher settings for `@thebassclef/lite`
- Confirm entry exists for `sunj-labs/bassclef-cli` repo + publish workflow
- If missing: operator adds via npm UI (out of scope for automation; document steps)
- Marker at `state/markers/npm-config/lite-trusted-publisher.md` with confirmation date + screenshot path
- If missing: goal halts; ticket filed to add config; operator resumes on config confirmation

### Step 6 — rename package.json name + publish
- `package.json` `name` field flipped from `@thebassclef/core` to `@thebassclef/lite`
- `package.json` `version` bumped from `0.1.1` to `0.1.0`
- Git tag `v0.1.0-lite` pushed to origin
- GitHub release created; publish workflow fires on release published
- npm 2FA Touch ID at operator keyboard (operator confirms availability before dispatch)
- `@thebassclef/lite@0.1.0` visible on npm within 5 minutes of tag push
- Provenance attestation URL logged in release notes

### Step 7 — deprecate @thebassclef/core
- Run `npm deprecate @thebassclef/core "use @thebassclef/lite"` (all versions)
- Verify deprecation notice on `npm view @thebassclef/core`
- Screenshot committed to `docs/npm-screenshots/2026-09-07-core-deprecated.png`
- Cooper risk #1 note added to session log — silent-install adopters may not see the notice

### Step 8 — coord ticket #51 comment
- `gh issue comment 51 --body <text>` — comment names:
  - Q1 status closed
  - PR chain (Steps 2-7 PR numbers)
  - `@thebassclef/lite@0.1.0` live URL
  - Recommended Q2 pickup (#25 dist/lite/, #49 auto-trigger)
- Session log written per `.claude/rules/session-artifacts.md`
- Whereami flip: iteration_phase reflects the ship

## Test plan

- [ ] `npx vitest run` returns all Tier 0 tests GREEN after each step (11 today + 1 new in Step 4 = 12+)
- [ ] Step 2: `git log substrate/ -1 --format=%H` matches upstream v1.5.0 tag SHA
- [ ] Step 3: fresh-clone `copy-substrate --dry-run` output committed to state/markers/smoke/
- [ ] Step 4: tarball listing has zero operator-private paths; new test file has test-list block
- [ ] Step 5: npm trusted-publisher settings screenshot committed
- [ ] Step 6: `npm view @thebassclef/lite version` returns `0.1.0`
- [ ] Step 7: `npm view @thebassclef/core deprecated` returns the migration message
- [ ] Step 8: `gh issue view 51 --comments` shows the comment

## Out of scope

- Q2 slice (#25 dist/lite/, #49 auto-trigger) — separate goal
- Unpublish `@thebassclef/core` versions — later session
- Standard-tier or ultra-tier package publish — placeholder reservations only today
- UX / mock-gallery / prototype / interaction-design — this is CLI infrastructure

## Refs

- Goal: `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md`
- UC: `docs/use-cases/UC-lite-rename-sync.md`
- Decomposition: `docs/decompositions/lite-rename-sync-publish.md`
- Migration plan: `docs/migration/lite-rename.md`
- Risk ledger: `docs/risk-ledgers/2026-09-07-lite-rename-sync.md`
- Coord ticket: bassclef-cli#51
- ADR-002, ADR-003, ADR-005, ADR-031
