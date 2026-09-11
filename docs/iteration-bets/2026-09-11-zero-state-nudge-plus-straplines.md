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

## Scope reconciled 2026-09-11 (Step 1 finding)

Reading the source at Step 1 discovered ticket #55 conflicts with ADR-008 Decision 2 (migrate no-manifest → Path B full init, not nudge). Reconciled scope: polish `bassclef --help` to mark `init` as first-run + add characterization tests pinning current sync + migrate behavior. No behavior change on sync or migrate. No ADR amendment. See `docs/use-cases/UC-cold-adopter-init-nudge.md` § Reconciliation.

## Steps

| Step | Problem + value | Produces | Consumes (from prior) | How builds on prior | Risk |
|---|---|---|---|---|---|
| **0** housekeeping ✅ | Session start; scope confirmed; markers absent | Goal doc + ledger + temperance/pre-mortem/luminary/thread-walk markers | session-start | baseline | 🟢 |
| **1** brief use case ✅ | Adopter surface change needs Cockburn brief tier | `docs/use-cases/UC-cold-adopter-init-nudge.md` at brief tier; scope reconciled per source reading | Step 0 goal doc | UC pins reconciled acceptance | 🟢 |
| **2** Beck RED Tier 0 tests | Cannot ship src/ change without failing tests first | 4 Tier 0 tests in `tests/cli-init-nudge.test.ts`: (a) `--help` first-run hint present; (b) sync no-manifest nudge stays intact (characterization); (c) migrate no-manifest Path B opener stays intact (characterization); (d) init works today (regression pin) | Step 1 UC | Tests pin UC acceptance | 🟢 |
| **3** source cure GREEN | Tests RED; need `--help` first-run hint | One-line addition to `USAGE` in `src/cli.ts` — `Start here: \`bassclef init\`` before the verb list | Step 2 RED tests | Smallest cure that turns tests GREEN; no behavior change to sync or migrate | 🟢 |
| **4** full suite verify + PR | Cannot ship without full suite green | 222+ tests GREEN via vitest; PR body per pr-body-shape rule; ticket #55 comment explaining scope reconciliation | Step 3 GREEN | Full suite check + operator merge | 🟢 |
| **5** strapline promote bodies | Second scope element; needs adopter-context grounding | 4 /promote issue body drafts at bassclef-upstream for /riff, /launch, /build, /howdoi via /extract-intent + /luminary chain | Step 4 PR merged (or approved) | brownfield input is this repo | 🟢 |
| **6** closeout | Session end; whereami stale (4 days) | Session log; whereami frontmatter fix + recap update; /retro one-liner; markers cleaned | Union of Steps 0-5 | Chronicle discipline | 🟢 |

## Compounding value per step

Every step is 🟢 low risk. Rate: per-adopter for the `--help` polish; per-adopter-forever for the substrate-side tagline changes. Prereq: none beyond session-start. Teaches: characterization-test-first when reconciling ticket spec against ADR reality. Half-done risk: low; help text change is one line, characterization tests pin current behavior.

## Acceptance

- 4 Tier 0 tests written before source change; suite GREEN after cure
- `bassclef --help` output contains `Start here: bassclef init` line
- Sync no-manifest characterization test pins current nudge string
- Migrate no-manifest characterization test pins Path B opener
- Ticket #55 comment posted explaining scope reconciliation (migrate no-manifest out of scope per ADR-008 D2)
- 4 /promote issue body drafts at bassclef-upstream ready for operator to file
- Session log written; whereami frontmatter compliant with schema; recap updated

## Out of scope

- Behavior change on migrate no-manifest — Path B stays per ADR-008 D2
- Interactive Path B prompt for cold adopters — sister proposal for a future ticket
- Bin-name confusion (user installs `@thebassclef/lite`, binary is `bassclef`) — documented in #55 out-of-scope
- Cooper #1 silent-install deprecation hook — belongs upstream, not here

## Refs

- Ticket #55 (open — cold-adopter zero-state nudge)
- Session log 2026-09-07 (@thebassclef/lite@0.1.0 ship; source of the cold-adopter friend signal)
- ADR-002 (init safety contract)
- Memory `project_lite_is_free_tier_package.md` (binary name stays `bassclef`)
- `.claude/rules/oo-ad-entry-point.md` (Cockburn ceremony matrix; brief tier fits)
- `.claude/rules/loop-discipline.md` (per-PR loop discipline)
- `.claude/rules/turn-estimate-grounding.md` (time budget grounding cited above)
