---
id: 2026-09-12b-node-bump
title: Node 20 → 22 bump in GitHub Actions workflows
status: in_flight
started: 2026-09-12
appetite: 10-20 turns
parent_drivers:
  - GHA emits Node 20 deprecation warning on `@thebassclef/lite@0.1.3` publish run (2026-09-12); observed on run that shipped v0.1.3
  - Node 20 EOL date is 2026-04; the deprecation clock is on
authoring_luminaries:
  primary: linus-torvalds
  supporting: [michael-feathers, michael-nygard]
references:
  - .github/workflows/harness.yml
  - .github/workflows/publish.yml
  - package.json (engines field — informational; already `>=20`)
  - docs/whereami.md L26 (open thread — Node 22 bump)
  - GitHub issue #66
  - docs/risk-ledgers/2026-09-12b-node-bump.md
tier: lite
---

# Node 20 → 22 bump in GitHub Actions workflows

## Sources read

- `docs/whereami.md` L26 — open thread lists Node 20 → 22 bump as small mechanical follow-on, ~10-15 turns
- `docs/whereami.md` L37 — session recap notes deprecation warning surfaced on v0.1.3 publish run
- `.github/workflows/harness.yml:81` — one `node-version: '20'` pin under `actions/setup-node@v4`
- `.github/workflows/publish.yml:83` — one `node-version: '20'` pin under `actions/setup-node@v4`
- `.github/workflows/publish.yml:205` — second `node-version: '20'` pin under `actions/setup-node@v4`
- `package.json` engines field — `"node": ">=20"`; Node 22 already allowed; no bump needed here
- GitHub issue #66 — filed 2026-09-12; frames the scope
- `.claude/rules/oo-ad-entry-point.md` — ceremony matrix; workflow edit sits in "existing code extension" tier

## What I'm NOT reading (with reason)

- Full body of upstream #1608 — Node bump is unrelated to the hook wiring boundary; that thread waits on upstream 12e
- ADR-004 body — this bump does not amend the publish pipeline contract; only the runner Node version
- `docs/use-cases/` — brief-tier use case sits in the commit body per Cockburn tiering; standalone UC not needed for a 3-line workflow edit

## Problem (≤500 chars)

GitHub Actions emits a Node 20 deprecation warning on every publish run. Node 20 EOLs 2026-04. Waiting past EOL means a forced bump under time pressure; bumping now lets the change land unhurried. The change is 3 pins in 2 workflow files, each `actions/setup-node@v4` with `node-version: '20'` → `'22'`.

## Goal

Bump the 3 `node-version: '20'` pins in `.github/workflows/harness.yml` + `.github/workflows/publish.yml` to `'22'`. Verify the harness workflow still passes on Node 22. Ship one PR. Close issue #66.

## Scope

**In scope:**

- `.github/workflows/harness.yml:81` — `node-version: '20'` → `'22'`
- `.github/workflows/publish.yml:83` — `node-version: '20'` → `'22'`
- `.github/workflows/publish.yml:205` — `node-version: '20'` → `'22'`
- One Tier 0 grep test that fails if any workflow file pins Node < 22

**Out of scope:**

- `package.json` engines bump. Current pin is `>=20`; Node 22 already allowed.
- Local dev Node version. No `.nvmrc` in repo; not needed for this goal.
- Actions runner OS bump. Separate concern.

## Steps

| Step | Produces | Consumes (from prior step) |
|---|---|---|
| **0** prep | this goal doc + temperance marker + pre-mortem marker + risk ledger | — (session-start) |
| **1** grep + edit | Node 20 pins bumped to 22 in 2 files; Tier 0 grep test added | Step 0 goal doc |
| **2** local verify | `npm test` green (229/229 expected); grep test asserts no `node-version: .20.` remains | Step 1 edits |
| **3** PR + review | PR body per `/pr-body`; operator merge; deprecation warning gone on next publish | Step 2 verify |
| **4** close | session log + whereami update + issue #66 closed | union of Steps 0-3 |

## Compounding value per step

**Step 0** — Where the payoff shows up: per-session (this session's anchor). How often: once. Prereq: none. Teaches later work: no. Breaks if half-done: low.

**Step 1** — Where the payoff shows up: per-release (deprecation warning stops). How often: every publish run. Prereq: Step 0. Teaches later work: yes — grep-test pattern for version pins works for other pin bumps. Breaks if half-done: low.

**Step 2** — Where the payoff shows up: this session. How often: once. Prereq: Step 1. Teaches later work: no. Breaks if half-done: low.

**Step 3** — Where the payoff shows up: per-release. How often: once (merge event). Prereq: Step 2. Teaches later work: no. Breaks if half-done: low.

**Step 4** — baseline (closeout). Prereq: Step 3 merge. Breaks if half-done: low.

## Acceptance

- [ ] `grep -rn "node-version: '20'" .github/workflows/` returns zero hits
- [ ] `grep -rn "node-version: '22'" .github/workflows/` returns 3 hits
- [ ] Tier 0 grep test asserts the invariant
- [ ] `npm test` green
- [ ] PR opened, reviewed, merged
- [ ] Issue #66 closed via PR body `Closes #66`
- [ ] Next publish run (post-merge) does not emit Node 20 deprecation warning
- [ ] Session log written; whereami updated

## Out of scope

- Engines field bump in `package.json`. Already `>=20`; no change.
- Ubuntu runner version bump. Separate concern.
- Actions dependency version bumps (e.g., `actions/checkout@v4`). Separate concern.
- Local `.nvmrc`. Not present; not needed for this goal.

## Risk register

See `docs/risk-ledgers/2026-09-12b-node-bump.md`. Three-lens pre-mortem — Torvalds (adopter contract), Feathers (characterization), Nygard (stability). Strongest risk: F1 (Feathers) — no characterization test exists that would catch a Node 22 behavior drift in publish output. The Tier 0 grep test does not cover this; only re-running the full suite on Node 22 does. Step 2 covers this.
