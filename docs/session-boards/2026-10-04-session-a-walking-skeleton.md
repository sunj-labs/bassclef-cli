---
session: 2026-10-04 Session A — lite runtime + authoring-chain drivers
mode: /longrun agent-merges-within-scope + sequential
session_started: 2026-10-04T11:51Z
time_budget: 180-275 turns
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - linus-torvalds
    - kent-beck
---

# Session board — Session A walking skeleton

## Scope locked

Lite-only Docker runtime + 5-PR authoring-chain driver stack. Walking skeleton (Dockerfile + invariants lib + nightly workflow + /interpret-input driver + cli#305 Exhibit-A anchor + minimal /personas stub) ships as PR 1. Growth PRs 2-4 cover /personas, /jtbd-tasks, /launch --local drivers. PR 5 lands the full-chain path-contract driver (cli#317) that walks /interpret-input → /personas → /jtbd-tasks → /launch end to end.

## Merge mode

**Agent-merges-within-scope.** Agent merges PRs 2-5 when:

- All paths touched sit inside temperance marker in-scope list.
- No hard ceiling hit (auth, schema, security, prod-deploy, blast-radius-floor — none in scope).
- CI green on PR CI job (test + typecheck + docker-smoke).
- Loop discipline markers present (temperance + luminary + pre-mortem + loop + lead-lens-signoff).

**Operator pauses required at:**

- PR 1 merge — walking skeleton phase boundary. Review Dockerfile + invariants lib shape before 4 drivers ride on it.
- Scope step-out — any path outside Session A paths named in plan doc L68-79.
- Hard ceiling hit — none expected.
- Scope past 275 turns.

## /architect-review schedule

1. **After PR 1 merges** — walking skeleton sets the architectural shape. Review writes report at `docs/architecture/reviews/2026-10-04-session-a-walking-skeleton.md`. Operator reads before PRs 2-5 proceed.
2. **Closeout Step 7.5** — session-wide across all 5 PRs. Skip criteria don't apply (not docs-only, not single-file, ~5-7 PRs).

## PR stack

| PR | Branch | Closes | Content | Status |
|---|---|---|---|---|
| 1 | `feature/cli-319-stack-1-lite-runtime-interpret-input` | cli#319 anchor + cli#305 anchor | Dockerfile + invariants lib + nightly workflow matrix + /interpret-input driver + cli#305 Exhibit-A + minimal /personas stub (R-C2 fold) | ceremony-done, awaiting operator OK |
| 2 | `feature/cli-320-stack-2-personas-driver` | cli#320 + cli#318 (write side) | /personas driver (email-slug anchor + persona-path write anchor) | pending |
| 3 | `feature/cli-318-stack-3-jtbd-tasks-driver` | cli#318 (read side) | /jtbd-tasks driver (reads from /personas write path) | pending |
| 4 | `feature/cli-314-stack-4-launch-local-phase-gate` | cli#314 + critique 6 | /launch --local Phase 4 gate driver + 127.0.0.1 anchor | pending |
| 5 | `feature/cli-317-stack-5-full-chain-path-contract` | cli#317 | Full-chain driver walking /interpret-input → /personas → /jtbd-tasks → /launch; asserts each read-path matches prior write-path | pending |

## /loop discipline — fires per PR

Each PR runs the full 6-step loop before merge. Operator sees each stage via commit messages + PR body evidence section.

Per-PR sequence per `.claude/rules/loop-discipline.md`:

1. **Pre-mortem light** — ledger fold applied (shared ledger `docs/risk-ledgers/2026-10-04-session-a-walking-skeleton.md`; per-PR deltas inline in PR body).
2. **Luminary pin** — Cockburn lead stays across all 5 PRs; supporting lens flips per PR scope (Beck on RED-first, Torvalds on invariants).
3. **Beck RED-first** — fixture + assertion authored. Test runs RED. Commit `test(cli-NNN): RED fixture + assertion` lands first.
4. **Impl** — minimal code to flip GREEN. Commit `feat(cli-NNN): impl → GREEN` lands next.
5. **/verify** — Tier 0 tests GREEN + typecheck + container smoke. Marker at `state/markers/verify/<branch>.marker`.
6. **CodeReviewer dispatch** — reads diff against spec, flags red/amber findings, writes marker at `state/markers/reviewer/<branch>.marker`.
7. **Resolve red + amber** — iterations tracked. iteration_count recorded in loop marker.
8. **Lead-lens signoff (Cockburn)** — reads final diff, confirms walking skeleton shape, writes marker at `state/markers/lead-lens-signoff/<branch>.marker`.
9. **Loop marker** — written at `state/markers/loop/<branch>.marker` naming iteration_count + GREEN evidence.
10. **PR body `## /temperance + /luminary + /loop discipline` section** — three lines (temperance scope answer, luminary slugs, loop iteration count).
11. **Squash merge** — PR body carries evidence row; operator pauses only at PR 1 phase boundary.

## Agent-merges-within-scope — PR schedule

| PR | Merge path | Blocker check |
|---|---|---|
| 1 | **operator-reviewed** at phase boundary | /loop GREEN + /architect-review clean |
| 2 | **agent merges** when CI green + /loop GREEN + lead-lens signoff | paths inside temperance in-scope list |
| 3 | **agent merges** when CI green + /loop GREEN + lead-lens signoff | parallel-safe with PRs 2 + 4 |
| 4 | **agent merges** when CI green + /loop GREEN + lead-lens signoff | parallel-safe with PRs 2 + 3 |
| 5 | **agent merges** when CI green + /loop GREEN + lead-lens signoff | depends on PRs 1-4 behavior |

Operator pauses on any PR when: hard ceiling hit (none expected), path steps outside temperance in-scope list, iteration_count on a PR climbs past 3 (signal of design miss).

## Pre-code ceremony — complete

- [x] Risk ledger (3 lenses × 20 risks + 6 folds pre-code) at `docs/risk-ledgers/2026-10-04-session-a-walking-skeleton.md`
- [x] Temperance marker — scope decision + 4 drift triggers
- [x] Luminary marker — Cockburn lead + Torvalds + Beck supporting
- [x] Pre-mortem marker — cites ledger + fold summary
- [x] ADR-deviation marker — outcome=ADR-honored (ADR-005 + ADR-007)
- [x] Orientation-gate marker — whereami + plan doc + parent-chain walk
- [x] Session board (this file)
- [x] Stack manifest at `docs/branch-stacks/2026-10-04-session-a.md`
- [ ] /rfc adversarial — 3 outside lenses on walking skeleton shape (class c discipline per Step 0.86)
- [ ] Loop marker — fires at PR 1 close
- [ ] Lead-lens signoff marker — fires at PR 1 close

## Follow-ons parked

- cli#324 /launch MUST vs /ux-migration SKIP — Session A follow-on if time allows.
- cli#313 luminary-pick absolute-path leak — Session A follow-on if time allows.
- R-T7 trace-helper sibling scan — PR 1b if siblings surface.
- R-B7 GREEN-flip sibling check — ships with first upstream cure.
- R-T6 cold-adopter clone test runnability — CONTRIBUTING.md in PR 5.

## Checkpoint triggers armed

- Phase boundary — end of PR 1 (walking skeleton merge).
- Post-compaction — survival kit re-read.
- Turn counter — every ~25 steps.
- Context saturation — self-check for pressure before system compacts.
- Scope drift — any step > 1.5× its sub-budget.
- /promote audit — file substrate-defect candidates in-session.
