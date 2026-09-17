---
tier: project
title: Next-session pickup — cli work after 1.1.1
date: 2026-09-17
status: prep complete, scope recommended not confirmed
repo: sunj-labs/bassclef-cli
revision: 2 — rewritten after the operator challenged the option-a framing
---

# Next-session pickup — 2026-09-17

Written at the end of the cli 1.1.1 session so the next one opens with a
picture instead of an archaeology task.

## Correction in revision 2

Revision 1 recommended fixing the install harness and called it "the
check that stands between a broken tarball and npm." **That was wrong,
and the operator caught it.**

- `publish.yml` runs two jobs: `checks` (L54) and `publish` (L201) with
  `needs: checks` (L204).
- The `checks` job contains **"Assert dist/lite/ present in tarball"**
  (L177) — the exact failure that broke cli 1.0.0.
- That class is therefore already blocked before publishing. It passed
  on tonight's release.
- The harness fires on `release: published`. It runs *after* the publish
  and could never have blocked anything.

The harness is not a gate. Fixing it is cleanup, not safety. The option
survives below at a much smaller size, and the recommendation moved.

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

**Option e — make the cold-adopter smoke produce evidence.**

Not confirmed with the operator. Four alternatives follow with the same
evidence.

### Why this one

The profile test is the real check. It found eight defects tonight that
no automated check in this repo would have caught — a wrong root
directory, a silent skip, a misleading sync message, a false crash
report. None of those show up in a `bassclef init` exit code.

It is also entirely manual, and its evidence is ephemeral. That is the
gap worth closing.

What exists today:

- `scripts/smoke-reset.sh` — resets the profile. Four steps. Worked
  cleanly tonight.
- `scripts/smoke-preflight.sh` — read-only inventory of the environment.
- `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` — nine manual
  steps, Step 0 through Step 8.

What does not exist: anything that captures or checks the session
output. Steps 5 through 7 of the plan — "Verify the cure — no source
errors", "Open Claude Code", "Quick sanity checks" — are eyeball work.

Tonight showed the cost. The eight findings surfaced only because the
operator asked an agent to re-read the transcript afterwards, and three
tool blocks were collapsed, which nearly lost the evidence. Separately I
reproduced the same root-cause error here in three commands. That
sequence wants to be a script.

### What the work is

Not automating the profile test. The real Mac and the real session are
the value and cannot move. The gap is that the evidence disappears.

A script that runs the wired SessionStart hooks in the freshly-initialised
repo, captures stdout and stderr per hook to a file, and asserts over the
capture:

- zero `not found` and `No such file or directory`
- zero `skip —` lines, which is how a fragment reports doing nothing
- no unexpected `BLOCKED` block
- every path a hook names actually exists

Then one report the operator or an agent reads in a single place,
instead of scrolling a transcript hoping nothing collapsed.

### Steps

| Step | Produces | Consumes (from prior step) | How this step builds on the prior | Turns | Risk |
|---|---|---|---|---|---|
| **0** prep | goal doc + markers | this plan doc | baseline | 5-8 | 🟢 |
| **1** capture | script running the wired hooks, output to file | Step 0 markers | turns ephemeral output into an artifact | 10-15 | 🟢 |
| **2** assertions | checks over the capture | the capture file from Step 1 | an artifact you can test is worth having | 10-15 | 🟢 |
| **3** pin tonight's eight | fixtures from the 1.1.1 findings | assertions from Step 2 | proves the checks catch real defects | 8-12 | 🟢 |
| **4** report | one readable summary | the passing checks from Step 3 | the operator reads one file | 5-10 | 🟢 |
| **5** fold into the plan | test-plan steps 5-7 call the script | the report from Step 4 | the manual steps shrink | 5-8 | 🟢 |
| **6** closeout | session log + whereami | union of prior steps | records what held | 5-8 | 🟢 |

### Per-step compounding

| Step | Where the payoff shows up | How often it fires | What must be true first | Does this teach a shape later work reuses | What breaks if we ship this half-done |
|---|---|---|---|---|---|
| 0 prep | per-branch | continuous | this plan doc | no (baseline) | 🟢 low — no scope anchor |
| 1 capture | per-smoke | per-release | prep markers | yes — capture before assert | 🟢 low — evidence stays ephemeral |
| 2 assertions | per-smoke | per-release | capture exists | yes — assert over an artifact | 🟢 low — capture nobody checks |
| 3 pin the eight | per-smoke | per-release | assertions exist | yes — real defects as fixtures | 🟡 med — checks that pass on everything |
| 4 report | per-smoke | per-release | checks pass | no | 🟢 low — findings stay buried |
| 5 fold in | per-smoke | per-release | report readable | yes — plan calls the tool | 🟢 low — plan drifts from tooling |
| 6 closeout | per-session | per-session | all prior | no | 🟢 low — next session re-derives |

**Turns: 40-70.** Grounded on the 2026-09-14 session, which shipped the
`smoke-reset.sh` rewrite plus a new `smoke-preflight.sh` inside a larger
~120 turn session. This is comparable script work plus assertions and
fixtures, standing alone.

**Risk: 🟢 low.** New scripts. Nothing existing changes. The one real
risk is writing checks loose enough to pass on everything, which Step 3
guards by pinning them against tonight's actual findings.

## The other four

**Option a — fix or delete the harness (cli#100).** Reduced from
revision 1. The honest case is cleanup: five consecutive red runs plus a
green test fetching `@thebassclef/core@0.0.2` — a package npm reports as
renamed — train everyone to ignore the signal. A permanently broken
check has negative value. **Deleting it is also a legitimate answer**,
since `publish.yml` guards the tarball and the profile test covers real
behaviour. 15-25 turns to fix, fewer to remove. Risk 🟡 only because it
touches the release workflow.

**Option b — `bassclef list <family>` (cli#92), version 1.2.0.** A new
subcommand for shell-only catalog discovery. Turns 70-130, grounded on
`bassclef migrate` (a comparable new subcommand) and cli 1.1.0 at 65-120
for five substantive changes. Risk 🟢 — additive. Real adopter value,
and the only option here that ships a feature.

**Option c — wait for upstream#1728, then pin bump and re-smoke.** Turns
25-45. Blocked today: nothing to pin until upstream ships the eight
fixes. Becomes the obvious pick once #1728 lands, and it pairs with
upstream#1706. Option e makes this one cheaper when it arrives.

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

## One note for whoever picks this up

Revision 1 of this doc recommended option a on a premise that did not
survive one question from the operator. The evidence was in
`publish.yml` the whole time and I had read that file earlier the same
session. Worth checking the premise of a recommendation against the
source before writing the plan around it, not after.
