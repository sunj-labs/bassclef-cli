---
tier: project
title: Next-session pickup — make the cli release gate real
date: 2026-09-17
status: prep complete, scope recommended not confirmed
repo: sunj-labs/bassclef-cli
---

# Next-session pickup — 2026-09-17

Written at the end of the cli 1.1.1 session so the next one opens with a
picture instead of an archaeology task.

## Where things stand

`@thebassclef/lite@1.1.1` shipped tonight and is verified working from
the registry — all three verbs, 379 files, install record matching the
report. cli#93, #94, #95 closed. 1.0.0 and 1.0.1 deprecated on npm.

A cold-adopter smoke on a fresh macOS profile passed: 24 of 24 hooks
armed, Claude Code booted, zero hook-not-found errors. It also found
eight upstream defects, now routed as **bassclef-upstream#1728**. None of
them belong to this repo.

Nothing here is blocked on a decision. The repo is clean, main is
pushed, 345 tests green.

## Recommended scope

**Option a — make the release gate real (cli#100, and cli#80 falls out of it).**

Not confirmed with the operator. If they pick differently, the other
three options are below with the same evidence.

### Why this one

The install harness is the check that stands between a broken tarball
and npm. It has failed on every release since v0.1.3 — five runs — and
the one test that reaches the live registry passes by fetching
`@thebassclef/core@0.0.2`, a package npm reports as renamed. So neither
half has ever tested a released version of the current package.

Tonight showed what that costs. cli 1.0.0 reached npm with an init
walker and no hook binaries, and broke every cold adopter. cli#80 asks
how that survived to publish. A permanently red check is a large part of
the answer, and fixing it answers the retro rather than just filing one.

### What the work is

Small and well-scoped. `harness.yml` L94 runs `npm run build`, which
empties `dist/`, and nothing then builds `dist/lite/`. Two steps are
missing between L94 and L117, and `publish.yml` already has both:

- Checkout `sunj-labs/bassclef` at the pinned tag — `publish.yml` L97-127,
  using the existing `BASSCLEF_SOURCE_TOKEN` secret
- Run `node scripts/prepublish-bundle-substrate.mjs`

Then `harness/npm-install.test.ts` L112-113 un-pins from
`@thebassclef/core` / `0.0.2` and reads the package name and version
from `package.json` at the resolved tag. `harness.yml` already computes
that version for its registry-wait step.

Then an assertion that `dist/lite/standards/bassclef-wiring-manifest.json`
exists before packing, so a regression fails on a clear message rather
than on an init exit code.

### Steps

| Step | Produces | Consumes (from prior step) | How this step builds on the prior | Turns | Risk |
|---|---|---|---|---|---|
| **0** prep | goal doc + markers | this plan doc | baseline | 5-8 | 🟢 |
| **1** characterize | a test pinning today's harness failure | Step 0 markers | proves the failure before touching it, per Feathers | 5-10 | 🟢 |
| **2** bundle steps | `harness.yml` with sibling checkout + bundle | the red test from Step 1 | turns the failing test green | 10-15 | 🟡 |
| **3** un-pin published test | test reads name + version from package.json | working local pack from Step 2 | the second half of the same gate | 8-12 | 🟢 |
| **4** floor assertion | explicit check before pack | both halves passing from Steps 2-3 | future regressions fail loudly | 5-8 | 🟢 |
| **5** verify live | green `workflow_dispatch` against v1.1.1 | the full harness from Steps 2-4 | proves it on the real runner, not locally | 8-15 | 🟡 |
| **6** close #80 | retro naming the cause and the cure | green harness from Step 5 | the fix is the answer to the retro | 5-10 | 🟢 |
| **7** closeout | session log + whereami | union of prior steps | records what held | 5-8 | 🟢 |

### Per-step compounding

| Step | Where the payoff shows up | How often it fires | What must be true first | Does this teach a shape later work reuses | What breaks if we ship this half-done |
|---|---|---|---|---|---|
| 0 prep | per-branch | continuous | this plan doc | no (baseline) | 🟢 low — no scope anchor |
| 1 characterize | per-change | per-goal | prep markers | yes — pin before fix | 🟢 low — fix unproven |
| 2 bundle steps | per-release | per-release | red test exists | yes — reuse the publish.yml pattern | 🟡 med — a wrong edit breaks publishing |
| 3 un-pin | per-release | per-release | local pack works | yes — read config, don't hardcode | 🟡 med — tests a stale package again |
| 4 assertion | per-release | per-release | both halves pass | yes — fail on the check, not the symptom | 🟢 low — regressions stay quiet |
| 5 verify live | per-release | per-release | harness complete | no | 🟡 med — green locally, red on the runner |
| 6 close #80 | per-retro | once | harness green | yes — a fix can answer a retro | 🟢 low — retro stays open |
| 7 closeout | per-session | per-session | all prior | no | 🟢 low — next session re-derives |

**Turns: 45-75.** Grounded on the 2026-09-12b session, which shipped two
workflow edits plus one Tier 0 test in about 30 turns. This adds a
sibling checkout, a bundle step, an un-pinned test, a new assertion, and
a live `workflow_dispatch` round trip, which costs wall-clock waiting.

**Risk: 🟡 medium.** It touches the release workflow. A wrong edit could
break publishing. Test with `workflow_dispatch` against the existing
v1.1.1 tag before merging — that path is already wired.

## The other three

**Option b — `bassclef list <family>` (cli#92), version 1.2.0.** A new
subcommand for shell-only catalog discovery. Turns 70-130, grounded on
`bassclef migrate` (a comparable new subcommand) and cli 1.1.0 at 65-120
for five substantive changes. Risk 🟢 — additive, nothing existing
changes. Worth doing; it is a feature rather than a hole, so it waits.

**Option c — wait for upstream#1728, then pin bump and re-smoke.** Turns
25-45. Blocked today: nothing to pin until upstream ships the eight
fixes. This becomes the obvious pick once #1728 lands, and it pairs with
upstream#1706.

**Option d — tidy the backlog.** Rewrite cli#42 against the current
workflow step, answer cli#44 (the contact addresses now ship at three
sites), reconcile cli#71, build cli#67. Turns 30-60, risk 🟢. Real work,
low compounding, no deadline.

## Open, not blocking

- **upstream#1728** — eight defects routed. Nothing for this repo to do
  until they ship.
- **cli#96** — blocked on upstream lite-manifest v1.7.0. Verified: tag
  v0.42.0 carries manifest_version 1.6.1 with zero top-level
  `.claude/*.md` entries, and v0.42.0 is the newest release.
- **cli#103 and cli#104** may close under cli#96's tagging expansion.
  Check the v1.7.0 tag set before writing any fix for either.

## First commands for the next session

```
/longrun prep
```

The picker should land on converged, since this doc carries a
`## Recommended scope` section and is less than 48 hours old. If it
fires the full ceremony instead, that is worth noticing — this doc is
the test case.

Then read `docs/whereami.md` for the state, and this doc for the pick.
