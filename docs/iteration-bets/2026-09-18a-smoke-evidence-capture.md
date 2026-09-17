---
tier: project
title: cold-adopter smoke evidence — capture, assert, report, publish
id: 2026-09-18a-smoke-evidence-capture
started_at: 2026-09-18T00:00:00Z
appetite: 90-140 turns (grounded — 2026-09-14 session shipped smoke-reset.sh rewrite plus new smoke-preflight.sh inside ~120 turns per whereami L112; this goal ships four new scripts plus a reset extension plus full OOAD ceremony)
mode: orchestrator-gated + sequential
authoring_luminaries:
  primary:
    - michael-feathers
    - jerome-saltzer-and-michael-schroeder
  supporting:
    - kent-beck
    - alistair-cockburn
    - donald-norman
    - john-ousterhout
    - gary-klein
    - michael-nygard        # added post intent audit — Fail-Fast + 3 UC extensions + cross-cutting
    - ivar-jacobson         # added post intent audit — anchors Step 0d BCE section
    - david-parnas          # added post intent audit — info hiding audit in cross-cutting + BCE split
    - frederick-brooks      # added post intent audit — conceptual integrity in "What NOT to build"
parent_goal_ids: []
references:
  - path: docs/next-session-plan-2026-09-17-cli-pickup.md
    role: pickup plan doc; Option e recommended
  - path: docs/whereami.md
    role: cli 1.1.1 shipped; cli#101 through #108 filed from tonight's smoke
  - path: docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md
    role: current smoke plan; Steps 5-7 are eyeball work
  - path: scripts/smoke-reset.sh
    role: existing reset script; extends to whole environment in Step 7
  - path: scripts/smoke-preflight.sh
    role: existing preflight script; sibling to the new scripts
  - ticket: sunj-labs/bassclef-cli#101
    role: fixture pin — /onboard-repo has no path for a repo where bassclef init already ran
  - ticket: sunj-labs/bassclef-cli#102
    role: fixture pin — orientation gate false-fires on fresh repo
  - ticket: sunj-labs/bassclef-cli#103
    role: fixture pin — whereami.md ships at wrong path
  - ticket: sunj-labs/bassclef-cli#104
    role: fixture pin — bassclef-configs.jsonc absent from bundle
  - ticket: sunj-labs/bassclef-cli#105
    role: fixture pin — BASSCLEF_DIR resolves to $HOME under operator install
  - ticket: sunj-labs/bassclef-cli#106
    role: fixture pin — sync failure message misdirects on auth-vs-visibility
  - ticket: sunj-labs/bassclef-cli#107
    role: fixture pin — textstat warning fires every turn with no once-per-session guard
  - ticket: sunj-labs/bassclef-cli#108
    role: fixture pin — ABRUPT STOP DETECTED false-fires on first session after init
  - ticket: sunj-labs/bassclef-upstream#1728
    role: coordination ticket routing all eight findings upstream
verification_status: draft
---

# Goal — smoke evidence capture

## Problem

The cold-adopter smoke is the real check. It found eight defects on 1.1.1
that no automated check here would have caught. Its evidence is manual
and ephemeral. Steps 5-7 of the smoke plan are eyeball work. Three tool
blocks collapsed and nearly lost cli#105 through #108. The next release
ships with the same gap unless we close it.

## Goal

After this goal, one command on the cold profile produces a test artifact.
Every check has a pass/fail row. Every RED row links to its raw capture.
The artifact posts as a GitHub issue on `sunj-labs/bassclef-cli` with the
`smoke-run` label. I read the issue on demand and run `/diagnose` on each
RED row.

Three layers stack. Layer 1 (this goal) covers wired SessionStart hooks
plus five skills that need no target app. Layer 2 (later) drives `/launch`
plus `/build` to produce a mock app. Layer 3 (later still) drives
`/verify`, `/architect-review`, `/decompose`, and `/pattern-review`
against that mock. Layer 1 ships the script shape and the reset extension
so Layers 2 and 3 extend by adding to a skill list, not by rewriting.

## Evidence

- Source `docs/next-session-plan-2026-09-17-cli-pickup.md` L48-131 —
  names the gap, sizes the work at 40-70 turns, pins risk at 🟢 low.
  Warrant: the plan doc walked five options and picked this one.
- Source `docs/whereami.md` L45-46 — three tool blocks collapsed during
  the 1.1.1 smoke and nearly lost cli#105 through #108. Warrant: the
  evidence loss sits on the record, not hypothetical.
- Source `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` — nine
  manual steps; Steps 5-7 have no automation. Warrant: the current plan
  is the gap.
- Source `git log -1 -- scripts/smoke-*.sh` returns `fe7fcee` — only
  `smoke-reset.sh` and `smoke-preflight.sh` ship today; no capture
  script. Warrant: Option e's scripts are net-new work.

## Out of scope

- **The mock app itself.** Layer 2 next session drives `/launch` plus
  `/build` and produces the app as a byproduct. Not tonight.
- **Skills that read the app.** `/verify`, `/architect-review`,
  `/decompose`, `/pattern-review`, `/visual-review`, `/synthetic-user`
  — Layer 3.
- **CI wiring for the smoke.** The value sits on a real profile with a
  real global npm install. CI runs in a container and cannot verify
  what an adopter Mac sees. Plan doc L129 confirms.
- **Fix any of cli#101 through #108.** Those are fixtures for the
  checks. Cures are upstream work per bassclef-upstream#1728.
- **Fix cli#100 harness.** Different scope; Option a of the plan doc.
- **`bassclef list <family>` (cli#92).** Option b of the plan doc; a
  feature, not a test.

## Steps

| Step | Produces | Consumes (from prior step) | How this step builds on the prior | Turns | Risk |
|---|---|---|---|---|---|
| **0** prep | this goal doc + temperance + luminary + thread-walk markers | plan doc L48-131 | baseline | 5-8 | 🟢 |
| **0a** spec | `docs/specs/smoke-evidence-capture.md` | Step 0 markers | names entities, actors, acceptance | 5-8 | 🟢 |
| **0b** use case | `docs/use-cases/UC-smoke-run.md` fully-dressed | Step 0a spec | Cockburn shape: preconditions, main flow, extensions | 4-6 | 🟢 |
| **0c** decompose | `docs/decompositions/smoke-evidence-capture.md` | Steps 0a and 0b | GRASP roles, patterns, shared concerns | 5-8 | 🟢 |
| **0d** objectory | Jacobson BCE section in the decomposition | Step 0c | Boundary / Control / Entity classification | 3-5 | 🟢 |
| **1** capture | `scripts/smoke-capture.sh` — SessionStart hooks | Step 0d BCE | Boundary object writes one file per hook under `docs/smoke-captures/<date>/` | 10-15 | 🟢 |
| **2** assert hooks | `scripts/smoke-assert-hooks.sh` — four checks | Step 1 capture | reads the capture; four assertions per hook | 10-15 | 🟢 |
| **3** pin fixtures | fixtures for cli#101 through #108 | Step 2 assertions | proves the checks catch real defects | 8-12 | 🟡 |
| **4** drive skills | `scripts/smoke-drive-skills.sh` — five skills via `claude -p` | Step 3 fixtures | extends the capture pattern to skill output | 10-15 | 🟢 |
| **5** assert skills | `scripts/smoke-assert-skills.sh` — same four checks per skill | Step 4 drive | reads the skill transcripts; same shape as Step 2 | 8-12 | 🟡 |
| **6** report | `scripts/smoke-report.sh` — pass/fail matrix, exit code, posts issue | Steps 2 and 5 assertions | one artifact for a reader | 8-12 | 🟢 |
| **7** reset extension | `scripts/smoke-reset.sh --whole` — env reset | Step 6 report | idempotent extension of the existing script | 5-10 | 🟢 |
| **8** fold into plan | `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` calls the scripts | Step 7 | manual plan shrinks | 5-8 | 🟢 |
| **9** closeout | session log + whereami + retro | union of prior steps | records what held | 5-8 | 🟢 |

## Per-step compounding

| Step | Where the payoff shows up | How often it fires | What must be true first | Does this teach a shape later work reuses | What breaks if we ship this half-done |
|---|---|---|---|---|---|
| 0 prep | per-branch | continuous | plan doc | no (baseline) | 🟢 low — no scope anchor |
| 0a spec | per-goal | continuous | goal doc | yes — spec shape for Layer 2 + 3 goals | 🟢 low — decompose has no anchor |
| 0b use case | per-goal | continuous | spec | yes — UC-smoke-run extends per layer | 🟢 low — actors + flows implicit |
| 0c decompose | per-goal | continuous | UC | yes — entity model | 🟢 low — patterns hidden |
| 0d objectory | per-goal | continuous | decomposition | yes — BCE classification | 🟢 low — boundary blurs |
| 1 capture | per-smoke | per-release | prep + design | yes — capture before assert | 🟢 low — evidence stays ephemeral |
| 2 assert hooks | per-smoke | per-release | capture | yes — assert over an artifact | 🟢 low — capture nobody checks |
| 3 pin fixtures | per-smoke | per-release | assertions | yes — real defects as fixtures | 🟡 med — checks that pass on everything |
| 4 drive skills | per-smoke | per-release | Layer 1 skill list | yes — Layers 2 + 3 extend | 🟢 low — hooks-only coverage |
| 5 assert skills | per-smoke | per-release | drive | yes — same check shape | 🟡 med — skill checks loose |
| 6 report | per-smoke | per-release | assertions | yes — issue-per-run pattern | 🟢 low — findings stay buried |
| 7 reset extension | per-smoke | per-release | report | yes — reset covers whole env | 🟢 low — state leaks across runs |
| 8 fold in | per-smoke | per-release | report readable | yes — plan calls the tool | 🟢 low — plan drifts from tooling |
| 9 closeout | per-session | per-session | all prior | no | 🟢 low — next session re-derives |

## Acceptance

- `bash scripts/smoke-capture.sh` on a fresh cold profile writes one
  file per wired SessionStart hook under `docs/smoke-captures/<date>/`
- `bash scripts/smoke-assert-hooks.sh` reads the capture, returns
  pass/fail per hook, exits non-zero when any check fails
- Fixtures for cli#101 through #108 each cause exactly one assertion to
  fail; without the defect present each fixture passes
- `bash scripts/smoke-drive-skills.sh` runs five skills through
  `claude -p` and captures each response to its own file
- `bash scripts/smoke-assert-skills.sh` returns pass/fail per skill
  call
- `bash scripts/smoke-report.sh` writes one markdown summary, exits
  with the union exit code, and posts a GitHub issue on
  `sunj-labs/bassclef-cli` with the `smoke-run` label when `--publish`
  is set
- `bash scripts/smoke-reset.sh --whole` resets npm global cache plus
  `~/.claude/projects/<repo>/` plus `~/tmp/bassclef-smoke-test`;
  idempotent; dry-run flag preserved
- `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` Steps 5-7
  call the new scripts by name

## Sources read

- `docs/next-session-plan-2026-09-17-cli-pickup.md` — full read
  (revision 2)
- `docs/whereami.md` — full read; anchor is L41-49 pickup pointer plus
  L60-77 full smoke findings block plus L45-46 tool-block collapse note
- `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` — full read
  of current manual plan
- `.claude/rules/oo-ad-entry-point.md` — ceremony matrix; scaling up
  from brief use case to fully-dressed given coherent system scope
- `.claude/rules/we-dont-break-adopters.md` — ADR-031; grace window on
  old vocabulary preserved in Refs section
- `.claude/rules/loop-discipline.md` — pre-mortem light fires at Step
  2a before code lands at Step 1
- `.claude/skills/longrun/SKILL.md` Step 0.85 — converged preset picker
  fired against this plan doc
- `git log -1 -- scripts/smoke-*.sh` — shipped-state check per Step 0.75

## Refs

- Pickup plan: `docs/next-session-plan-2026-09-17-cli-pickup.md`
- Coordination ticket: sunj-labs/bassclef-upstream#1728
- Fixture pins: sunj-labs/bassclef-cli#101, #102, #103, #104, #105,
  #106, #107, #108
- Related but out of scope: cli#100 (harness), cli#92 (list verb),
  cli#96 (walker tagging expansion — blocked on upstream v1.7.0)
