---
id: tier-a-dynamic-driver-roadmap
status: active
started: 2026-10-05
primary_lenses:
  - alistair-cockburn
  - alan-cooper
secondary_lenses:
  - kent-beck
  - michael-feathers
scope: multi-session (7 PRs across Session I + later sessions)
---

# Tier A dynamic driver roadmap

Durable plan — spans multiple sessions. Persist across session boundaries.

## Problem

bassclef lite ships 72 adopter-callable skills. Static characterization drivers (16 of them under `scripts/tests/smoke-drive-adopter-*.test.sh`) catch defect anchors in `dist/lite/` on every PR but do not catch friction a cold adopter sees mid-session. Known defect classes (Kunal #2036 — 10 findings, Session H — 6 reopens) are specific instances of the broader class: shipped skills chain in ways static grep cannot see.

## Goal

Build dynamic drivers under the docker-smoke harness for Tier A skills — the 6 call-to-action skills a cold adopter hits in the first 5 minutes. Each driver spawns `claude -p` inside the cold-adopter container running the **current published @thebassclef/lite** (via `CLI_VERSION=latest` → `npm install -g @thebassclef/lite@latest`). Each driver pins one persona slice doing one user-goal arc through one chain. Known defect anchors live inside those drivers as experience-goal assertions, not as separate drivers.

## Luminary map

- **Primary — @luminary alistair-cockburn.** Walking skeleton first; sea-level use cases per driver; hexagonal ports/adapters shape between driver → claude-p → captures-dir.
- **Primary — @luminary alan-cooper.** Persona slice named per driver; 3-level goals (end + experience + life) carried as per-level assertions; dancing-bear check catches "runs but adopter still bounces".
- **Supporting — @luminary kent-beck.** RED-first per driver (shipping bundle fails the chain → fix lands → driver flips GREEN). Simple design — one driver per CTA skill, each ≤100 assertion lines.
- **Supporting — @luminary michael-feathers.** Characterization — pin real behavior of shipped bundle before any upstream cure. Each driver pins what the adopter actually sees today.

/extract-intent returned confidence 0.92 (voyage-3-lite+haiku-4-5-1.0) on Cockburn + Cooper as the primary pair.

## Tiering

Per Cockburn Crystal — process weight matches stakes.

| Tier | Count | Driver weight |
|---|---|---|
| **A — call-to-action** (named in README/docs; adopter's first 5 min) | 6: /onboard-repo, /whereami, /sprint, /riff, /launch, /build | **Full chain driver per skill** |
| **B — chain composers** (compose multiple skills; adopter picks mid-session) | ~15: /decompose, /spec, /pre-mortem, /longrun, /architect-review, /temperance, /verify, /diagnose, /kiss, /promote, /retro, /session-end, /session-log, /journal, /release-notes | **Chain driver only when the exit skill of a Tier A chain** |
| **C — specialist** (adopter calls after they know bassclef) | ~51 | **Static driver only; defer dynamic until adopter demand surfaces** |

## Personas

Three slices from Kunal #2036 + current docs/personas:

- **Sam — cold install, first 5 min.** Fresh `npm install -g @thebassclef/lite`. No bassclef vocab. Follows README CTA.
- **Louis — context switcher.** Has bassclef installed. Picks up a project after days away. Runs `/sprint` or `/whereami` first.
- **Jamie — explorer.** Mid-session. Has an idea. Fires `/launch --local` with a paragraph.

Each driver names one slice. If a driver's input works for all three, split into 3 drivers.

## 3-level goals (Cooper) per driver

Each Tier A driver asserts across all three Cooper goal levels:

| Level | What the driver asserts |
|---|---|
| **End goal** (session-level) | Chain completes without unexpected BLOCKED banner; expected artifact lands on disk |
| **Experience goal** (how the interaction feels) | Output has no BLOCK terms from `standards/bassclef-internal-jargon.md`; grade-10 ceiling holds |
| **Life goal** (why adopter installed bassclef) | Artifact is scannable + actionable; persona can proceed to next step without reading SKILL body |

Dancing-bear check: for each assertion ask "does this catch painful-but-works?" If no, assertion is too narrow.

## 7 PRs — order of ship

1. **Walking skeleton** — `/onboard-repo` × Sam. 20-30 turns. Thinnest end-to-end. Proves the dynamic rig.
2. `/whereami` × Louis. Simplest Tier A. 15-20 turns.
3. `/sprint` × Louis. Chains /whereami. 15-20 turns.
4. `/riff` × Jamie. Visual variant from idea. 25-35 turns.
5. `/launch` × Jamie. Paragraph → mock gallery → spec. 30-40 turns.
6. `/build` × Jamie. Continues from /launch output. 30-40 turns.
7. **Architect review** — covers full suite. 20-30 turns.

Total: 7 PRs, ~155-215 turns, ~2-3 sessions.

## Known defect anchors — assertions per driver

Session H + Kunal defects assigned as experience-goal assertions:

| Defect | Lives inside driver |
|---|---|
| cli#311 (null-parent) | /launch × Jamie (fires /longrun prep) |
| cli#312 (verb_goal_pairs) | /launch + /build × Jamie chain |
| cli#322 (template jargon) | /launch × Jamie (Phase 14 output) |
| cli#323 (prototype auto-commit) | /riff × Jamie (session edits docs/prototypes/) |
| cli#324 (/ux-migration conflict) | /launch × Jamie (Phase 11) |
| cli#325 (contrast absent) | /launch × Jamie (token extraction) |
| cli#326 (slug mismatch) | /build × Jamie (adopter-mode detection) |
| cli#329 (adr unwired) | /build × Jamie (package.json rewrite) |
| Kunal #1 trace-log-privacy | /onboard-repo × Sam |
| Kunal #2 build-against-template | /build × Jamie |
| Kunal #3 onboard-free-tier | /onboard-repo × Sam |
| Kunal #8 install-written-paths | /onboard-repo × Sam |

## Validation contract — latest published lite

Each driver installs `@thebassclef/lite@latest` in the cold-adopter container via existing `harness/docker/Dockerfile.cold-adopter` + `.github/workflows/docker-smoke.yml` → `CLI_VERSION: ${{ github.event.inputs.cli_version || 'latest' }}`. The driver suite then validates the CURRENT ship — not a pinned snapshot. If an adopter installs today, drivers prove what the adopter sees.

Regression contract: when a new lite version publishes, docker-smoke runs the full driver matrix against it. Any chain regression blocks the next release.

## Walking skeleton PR shape

PR 1 — `/onboard-repo` × Sam:
- `scripts/tests/smoke-drive-e2e-onboard-repo-sam.test.sh` — spawns claude in cold-adopter container, runs `/onboard-repo`, asserts init.manifest.json lands + no BLOCKED banner in capture
- `harness/docker/entry.sh` — adds V2 Step 8 to orchestrate the new driver
- `docs/use-cases/UC-script-cli-onboard-repo-sam-driver.md` — brief
- 6 markers (temperance + pre-mortem + luminary + adr-deviation + loop + lead-lens-signoff)

Each subsequent PR follows this shape with its skill + persona.

## Ceremony per PR

Per `.claude/rules/loop-discipline.md`:

- /temperance (per-branch scope + drift trigger)
- /pre-mortem light (3 lenses × 5-8 risks; folds pre-code)
- /luminary primary alistair-cockburn + supporting cooper + beck
- Beck RED-first (driver fails first against known defect state, GREEN after assertion lands)
- /verify
- PR body carries /temperance + /luminary + /loop section per `.claude/rules/pr-body-shape.md`
- /loop CI until green
- /architect-review auto-dispatch per /longrun Step 7.5 at closeout

## Composes with

- `.claude/rules/loop-discipline.md`
- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD on new drivers
- `.claude/rules/cold-adopter-harness-discipline.md` — sibling smoke extension
- `.claude/skills/longrun/SKILL.md` — /longrun discipline each session
- `harness/docker/entry.sh` — V2 Step 8+ wiring
- `.github/workflows/docker-smoke.yml` — CI runs the drivers against latest lite

## Refs

- `docs/architecture/reviews/2026-10-05-session-h-driver-sweep.md` — architect review that led here
- Session H chronicle (pending at Session H closeout)
- Kunal cold-adopter report: bassclef-upstream#2036
- Session F precedent: PRs #355, #357, #358, #359, #360
- /extract-intent output at /tmp/session-h-chain-intent.json (confidence 0.92; Cockburn + Cooper picked)
