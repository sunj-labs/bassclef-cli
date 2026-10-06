---
tier: lite
author: kingofrock
created: 2026-10-07
parent_goal: cli#375
---

# Session K — Full Tier A real-capture drivers (PRs 4-7)

**Problem (≤500 chars):** The Tier A dynamic driver suite shipped 3 of 8 PRs — walking skeletons for /onboard-repo (Sam) + /whereami (Louis) + Session J integration bridge. PRs 4-7 (/sprint × Louis, /riff × Jamie, /launch × Jamie, /build × Jamie) still ride mocks or do not exist yet. Harness cannot catch upstream cures to these 4 skills until real captures ship. Session K closes the gap.

---

## Goal

Ship all 4 remaining Tier A persona drivers with real `claude -p` captures from `@thebassclef/lite@1.9.10` cold-adopter docker container. Add `scripts/lib/claude-chain.sh` as the shared `claude -c` multi-turn helper (per cli#383). Harness becomes production-ready for upstream cure regression against 7 of 7 Tier A skills.

## Evidence

- Source: `docs/plans/tier-a-dynamic-driver-roadmap.md` L155-162 (8-PR revised roadmap; PRs 4-7 open).
- Source: PR #382 landed real captures for Sam + Louis per the integration bridge pattern.
- Source: cli#383 scopes the multi-turn chain helper + names scaffold path `scripts/lib/claude-chain.sh`.
- Warrant: Each PR follows the pattern Session J proved — one-shot container capture → scrub → fixture replace → driver assertions → CI → merge.

## Recommended session sequence

Four PRs plus one closing PR. Each rides the Session J shape with the multi-turn chain helper landing in PR 4.

### Scan table

| Option | Scope | Turns | Compounds | Risk | Why not (non-rec.) |
|---|---|---|---|---|---|
| **a (recommended)** | PRs 4-7 full Tier A | 120-200 | per-session; proves pattern once + reuses 3× | 🟡 med | — |

Only one option — the operator picked full Tier A at scope-selection time (session 2026-10-07 prep).

### Compounding value — recommended only

#### Option a — Full Tier A (PRs 4-7)

- **Deliverable** — `scripts/lib/claude-chain.sh` + 4 real-capture fixtures + 4 driver files + 4 PR merges + architect-review follow-on ticket.
- **Problem** — Harness today covers 3 of 7 Tier A skills with real captures. 4 skills (/sprint, /riff, /launch, /build) stay uncovered. Upstream cures to these skills ship without regression anchors.
- **Value prop** — Multi-turn chain helper proven once in PR 4. PRs 5-7 reuse the helper. Harness regression-ready for every Tier A skill.
- **Turns** — 120-200 (grounded in PR #382 actuals: ~60 turns per PR including 1-2 RED iterations; 4 PRs × 30-50 turns each).
- **Risk** — 🟡 med — chain helper is new scaffold; interactive menus may need expect-wrapper fallback; 4 CI loops multiply format-drift risk. Caught by local test loop before push.
- **Shipping priority** — P1

### Step sequencing

| Step | PR | Produces | Consumes (from prior step) |
|---|---|---|---|
| **0** prep | — | goal doc + markers + session board | — (session-start) |
| **1** PR 4 | `/sprint × Louis` + chain helper | `scripts/lib/claude-chain.sh` + real-capture fixture + driver | goal doc (step 0) |
| **2** PR 5 | `/riff × Jamie` | real-capture fixture + driver reusing chain helper | chain helper (step 1) |
| **3** PR 6 | `/launch × Jamie` | real-capture fixture + driver | chain helper + /riff fixture (steps 1-2) |
| **4** PR 7 | `/build × Jamie` | real-capture fixture + driver | chain helper + /launch fixture (steps 1-3) |
| **5** architect review ticket | — | follow-on ticket for PR 8 architect review | union of steps 1-4 PRs |
| **6** closeout | — | session log + whereami flip + chronicle | union of all steps |

### Per-step compounding

Each step reuses the fixture-replace + driver-assertion pattern from Session J. Steps 2-4 reuse the chain helper scaffolded in step 1. Each PR passes local Tier 0 + CI matrix before merge.

## Pre-mortem light — 3 lenses × 5-7 risks

### Lens 1 — @luminary alistair-cockburn (walking skeleton)

- R1 — Chain helper abstraction leaks implementation to one driver and breaks on reuse. Fold: write 1 driver first, let it work, THEN extract shared helper (not before).
- R2 — Multi-turn menus (/sprint "pick N", /riff "pick variant") capture asynchronously and race against claude's stdout flush. Fold: use `sleep 2` between `-c` calls or capture via `--background` + wait.
- R3 — Container state between turns differs from local shell session; `claude -c` may fail across container boundary. Fold: run entire chain in one container exec per driver.
- R4 — Fixture format drift across 4 drivers compounds. Fold: scrub pass per fixture before stage; verify no `/home/adopter` paths leak.
- R5 — Session J's `--dangerously-skip-permissions` default may not fit every skill (e.g., `/riff` reads but mostly doesn't write). Fold: driver passes `CLAUDE_PERMISSIONS=strict` where read-only is sufficient.

### Lens 2 — @luminary michael-feathers (characterization)

- R6 — Driver assertions pin aspirational behavior rather than what the skill actually does today. Fold: write assertion AFTER capture lands; let real output define contract.
- R7 — Interactive menus print after `-p` returns, not before. Fold: capture multi-turn output in order, parse per-turn, assert on turn-N output not aggregate.
- R8 — Real captures carry latent jargon the persona-assert lib doesn't flag. Fold: use experience-goal assertion exactly as shipped; if jargon appears, file upstream not fix in driver.

### Lens 3 — @luminary kent-beck (RED-first)

- R9 — Writing driver before capture lands produces a hollow test. Fold: fire the container; capture; then write driver referencing the capture.
- R10 — 4 PRs × 2 RED iterations each = 8 CI loops may blow the time budget. Fold: pause after PR 4 lands GREEN; re-estimate; cut scope to PR 4+5 only if 60+ turns consumed.
- R11 — Format-drift fixes (e.g., `**Phase**:` vs `Phase:`) ripple across siblings. Fold: fix driver's assertion-glob, not the bad fixtures.
- R12 — Chain helper's env-var contract gets copy-pasted into drivers rather than sourced. Fold: `source scripts/lib/claude-chain.sh` + call `claude_chain_capture` wrapper.

## Out of scope

- PR 8 architect review (deferred to Session L; filed as follow-on ticket at step 5).
- Multi-turn walking skeleton proving via `expect`-style interactive wrapper (cli#254 pattern) — only `claude -c` chaining this session; expect falls out if any skill fully blocks on tty.
- Session J closeout markers (operator may fire separately; not blocking).
- PR #381 CI re-run (cli#380 OAuth refresh) — operator fires at their next desktop session.

## Luminary map

**Primary:** @luminary alistair-cockburn — walking skeleton walks end-to-end at every PR.

**Supporting:**
- @luminary michael-feathers — characterization pins real output
- @luminary alan-cooper — persona assertions frame pass/fail
- @luminary kent-beck — RED-first; chain helper lands with its own Tier 0 test before any driver sources it

## References

- `docs/plans/tier-a-dynamic-driver-roadmap.md` — parent roadmap (cli#375)
- cli#383 — multi-turn chain-driving ticket (defines scaffold path)
- PR #382 — Session J real-capture precedent (merged 2026-10-06)
- `scripts/tests/smoke-drive-e2e-onboard-repo-sam.test.sh` — pattern reference
- `scripts/lib/persona-assert.sh` — Cooper 3-level assertion lib
- `.claude/rules/loop-discipline.md` — per-PR cycle (6 steps + 3 substeps)
- `.claude/rules/compounding-sequence-fresh-analysis.md` — this doc's shape contract
- `.claude/rules/longrun-prep-plan-doc-compression.md` — triggers converged preset in next session

## Operator notes

Operator exited the setup session 2026-10-07 after merging PR #382. Overnight Session K reads this plan doc at `/longrun prep`, fires the converged preset, and runs through the 7 steps above. If PR 4 lands GREEN inside 60 turns, continue through PRs 5-7. If it blows past 60 turns, pause after PR 4 merges and leave PRs 5-7 for the next session.

Hard ceilings:
- No `auth`, `schema`, `security`, `prod-deploy` touches.
- No pushes to main without PR.
- Operator-gated merge mode (default per `.claude/bassclef-configs.jsonc`).
