---
date: 2026-10-04
goal: Session B — session-shape drivers
mode: /longrun orchestrator-gated + agent-merges-within-scope
time_budget: 100-150 turns
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - michael-feathers
    - linus-torvalds
---

# Session B — board

## 3 PRs — all independent, no cascade

| PR | Scope | Anchor | /loop iteration estimate |
|---|---|---|---|
| 1 | `/sprint` driver — orientation output clean of PyYAML | cli#308 (characterization) | 1 (RED → GREEN first pass) |
| 2 | `/longrun prep` driver — 6-axis compounding frame | compounding-sequence-fresh-analysis.md | 1 |
| 3 | `/temperance` driver — marker format fits `/build` flow | cli#328 finding 6 | 1-2 (gitignore fixture is new shape) |

Each PR runs the full /loop (pre-mortem light + luminary + Tier 0 TDD + review + resolve + signoff + merge).

## /architect-review schedule

- After PR 3 merges — session-wide static-comprehension pass per `standards/architect-review-discipline.md`. Inline doc at `docs/architecture/reviews/2026-10-04-session-b-session-shape.md`. Session A pattern verified the inline fallback works when subagent prompt-too-long fires.

## Agent-merges-within-scope schedule

- Each PR merges autonomously once CI green AND review clean. No operator pause between PRs.
- Operator paused only at: session kickoff (done), /architect-review commit, session closeout.

## Deferred to follow-on

- Live-mode runs for all 3 drivers under nightly (SMOKE_LIVE=1). Session A nightly workflow already dispatches; Session B drivers inherit when nightly fires.
- cli#308 PyYAML cure — upstream work, not this session.
- cli#328 full 14-gap sweep — this session covers finding 6 only.
