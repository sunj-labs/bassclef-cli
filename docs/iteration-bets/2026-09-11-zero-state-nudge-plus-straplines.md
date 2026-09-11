---
tier: lite
goal: 2026-09-11-zero-state-nudge-plus-straplines
title: Ship #55 zero-state nudge + draft 4 tagline promotes for /riff /launch /build /howdoi
project: bassclef-cli
execution_repo: sunj-labs/bassclef-cli
status: proposed
authored: 2026-09-11
authored_by: agent
in_flight_goal: null
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
time_budget: 60-110 turns
time_budget_source: |
  Ticket #55 body estimates 5 tests + one dispatcher branch. Iteration i
  (install harness) shipped a similar shape at ~50 turns per whereami L169
  (7 commits + 11 tests). Range top covers pre-mortem interlude turns per
  goal 09-07 evidence. Strapline chain adds 20-40 turns for /extract-intent
  + /luminary + 4 issue body drafts (no code, docs only).
authoring_luminaries:
  primary: [alan-cooper]
  supporting: [jerome-saltzer-and-michael-schroeder, john-ousterhout]
lead_lens: alan-cooper
tickets: [55]
references:
  - {type: parent_bet, id: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md, anchor: parent goal — npm distribution for @thebassclef/lite}
  - {type: ticket, id: 55, anchor: cold-adopter zero-state nudge; the feature this ships}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-11-zero-state-nudge-plus-straplines.md, anchor: pre-mortem light — 3 lenses × 3 risks; strongest folded into Steps 2-3}
  - {type: session_log, id: docs/session-logs/2026-09-07-lite-rename-sync-publish-shipped.md, anchor: origin of the cold-adopter friend signal on 2026-09-07}
  - {type: memory, id: project_lite_is_free_tier_package, anchor: binary name stays `bassclef`; package is `@thebassclef/lite`}
adr_references:
  - ADR-002 (bassclef init safety contract) — manifest path this nudge reads
---

# Ship #55 zero-state nudge + draft 4 tagline promotes

## Problem

Cold adopter installs `@thebassclef/lite`, runs `bassclef --help`, sees three verbs (`init`, `sync`, `migrate`) with no cue which to run first. Session log 2026-09-07 L48-51 documents a friend hit this on fresh install; had to ask which verb sets up the project. Ticket #55 opened the same day. The verbs `sync` and `migrate` both assume the project is set up; running them first prints a confusing error instead of a friendly nudge.

## Value

Every cold adopter forever lands on the right first command. The nudge takes one line at stderr + exit 1. No substrate change, no new ADR. Adopter self-service beats every doc line.

Second scope element — draft four /promote issue bodies at bassclef-upstream for skill taglines. `/riff`, `/launch`, `/build`, `/howdoi`. Framed for a brownfield adopter (a repo like bassclef-cli that ships to npm and inherits substrate via sync). The operator will file the four promotes. Every adopter benefits.

Per @luminary alan-cooper — Sam's zero-state moment is the highest-leverage UX signal. The nudge closes it in one line.

Per @luminary jerome-saltzer-and-michael-schroeder — the preflight mediates every future verb dispatch. Absent-manifest is treated the same as read-error; no silent pass.

Per @luminary john-ousterhout — the detector lives as a small `requireInit(verb)` helper. One extension point for future verbs; deep interface stays clean.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` — parent_bet; npm distribution parent goal; inherits authoring_luminaries + roadmap anchor; walked this turn per state/markers/thread-walk marker
- `docs/whereami.md` L23-31 — open threads; #55 flagged from cold-adopter signal
- `docs/session-logs/2026-09-07-lite-rename-sync-publish-shipped.md` L48-51 — Cooper #1 pre-mortem gap origin
- `docs/risk-ledgers/2026-09-11-zero-state-nudge-plus-straplines.md` — 3 lenses × 3 risks; strongest folded into Steps 2-3
- Ticket #55 body — 5-test contract + goal statement + evidence bullets
- `src/cli.ts` L1-80 — current dispatcher shape; `--help` check runs before `runSync`/`runMigrate`
- `package.json` — name `@thebassclef/lite@0.1.0`; bin `bassclef` → `dist/cli.js`
- ADR-002 (bassclef init safety contract) — `.bassclef/init.manifest.json` is the manifest path

## Steps

| Step | Problem + value | Produces | Consumes (from prior) | How builds on prior | Risk |
|---|---|---|---|---|---|
| **0** housekeeping | Session start; scope confirmed; markers absent | Goal doc + ledger + temperance/pre-mortem/luminary/thread-walk markers | session-start | baseline | 🟢 |
| **1** brief use case | Adopter src/ extension needs Cockburn brief tier per oo-ad-entry-point matrix | `docs/use-cases/UC-cold-adopter-init-nudge.md` at brief tier | Step 0 goal doc | UC pins acceptance the tests check | 🟢 |
| **2** Beck RED Tier 0 tests | Cannot ship src/ change without failing tests first | 4 Tier 0 tests in `tests/cli-init-nudge.test.ts` (sync no-manifest → nudge exit 1; migrate no-manifest → nudge exit 1; init no-manifest → works; sync --dry-run init'd → works) | Step 1 UC | Tests pin UC acceptance | 🟢 |
| **3** source cure GREEN | Tests RED; need dispatcher preflight | `requireInit(verb)` helper in a small module; wire into sync + migrate dispatch in `src/cli.ts` after `--help` check; nudge string constant | Step 2 RED tests | Smallest cure that turns tests GREEN | 🟢 |
| **4** full suite verify + PR | Cannot ship without full suite green | 222+ tests GREEN via vitest; PR body per pr-body-shape rule; auto-merge or hold-for-review per orchestrator merge mode | Step 3 GREEN | Full suite check + operator merge | 🟢 |
| **5** strapline promote bodies | Second scope element; needs adopter-context grounding | 4 /promote issue body drafts at bassclef-upstream for /riff, /launch, /build, /howdoi via /extract-intent + /luminary chain | Step 4 PR merged (or approved) | brownfield input is this repo | 🟢 |
| **6** closeout | Session end; whereami stale (4 days) | Session log; whereami frontmatter fix + recap update; /retro one-liner; markers cleaned | Union of Steps 0-5 | Chronicle discipline | 🟢 |

## Compounding value per step

Every step is 🟢 low risk. Rate: per-adopter for the src/ change; per-adopter-forever for the substrate-side tagline changes. Prereq: none beyond session-start. Teaches: `requireInit(verb)` preflight helper as extension point for future verbs; adopter-brownfield lens for skill positioning. Half-done risk: low; adopter code is a small dispatcher branch, tagline promotes are drafts the operator files at their pace.

## Acceptance

- 4 Tier 0 tests written before src/ change; suite GREEN after cure
- Nudge string pinned in a constant + tested by literal match
- `requireInit(verb)` helper documents extension point for future verbs
- Ticket #55 out-of-scope section carries R3 (exit 1 breaks shell wrappers) note
- 4 /promote issue body drafts at bassclef-upstream ready for operator to file
- Session log written; whereami frontmatter compliant with schema; recap updated

## Out of scope

- Bin-name confusion — user installs `@thebassclef/lite` but binary is `bassclef` (documented in ticket #55 out-of-scope)
- Nudge on bare `bassclef` invocation without a verb — help text already covers first-run
- Docs/README update for flow ordering — separate ticket if needed
- Cooper #1 silent-install deprecation hook — belongs upstream, not here

## Refs

- Ticket #55 (open — cold-adopter zero-state nudge)
- Session log 2026-09-07 (@thebassclef/lite@0.1.0 ship; source of the cold-adopter friend signal)
- ADR-002 (init safety contract)
- Memory `project_lite_is_free_tier_package.md` (binary name stays `bassclef`)
- `.claude/rules/oo-ad-entry-point.md` (Cockburn ceremony matrix; brief tier fits)
- `.claude/rules/loop-discipline.md` (per-PR loop discipline)
- `.claude/rules/turn-estimate-grounding.md` (time budget grounding cited above)
