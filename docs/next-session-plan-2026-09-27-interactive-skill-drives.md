---
plan_id: 2026-09-27-interactive-skill-drives
tier: standard
authored_by: bassclef-cli aa @ 2026-09-26T14:40Z
handoff_from: /longrun 2026-09-26c closeout
---

# Next session — interactive skill drives for /onboard-repo + /riff + /launch

## Context

/longrun 2026-09-26c shipped cli v1.9.4 (bassclef v1.6.1 substrate cascade) plus a triage sweep. Docker smoke on v1.9.4 ran 41/2 exit-3 — the 2 fails traced to smoke assertion drift, not adopter regressions.

At closeout, operator surfaced the gap that current skill drives fire `claude -p` (headless one-shot). Multi-phase skills like /onboard-repo, /riff, /launch never reach later phases. Docker smoke can't tell whether they work end-to-end for cold adopters.

Filed as **cli#254**. Fully-dressed OOAD scope: 150-250 turns.

## Recommended session sequence

### Option a — /longrun 2026-09-27a (full ceremony)

Fully-dressed OOAD chain per operator's standard pattern:

1. `/temperance` — scope + drift-trigger stated
2. `/pre-mortem light` — 3 lenses (Feathers + Beck + Cockburn) × 5-8 risks each
3. **Design chain:** brief use case (per Cockburn matrix — new script + expect layer) → `/decompose` (GRASP + BCE) → interfaces + patterns (Strategy pattern for driver-per-skill; Template Method for expect-driven flow)
4. **RFC council** — 4-5 outside luminaries (candidates: Nygard for expect brittleness; Vernon for driver-per-skill boundary; Norman for assertion feedback loops; Linus for adopter contract)
5. **Beck TDD RED-first** — 3 characterization tests per drive (happy path + Phase 0 refuse + timeout)
6. Cure — 3 drive scripts + Dockerfile updates + entry.sh wire + assertions
7. Beck TDD GREEN — full smoke passes at 46/0 (43 baseline + 3 new drives with 1 assertion each; may grow)
8. `/architect-review` READY
9. PR + merge (agent-merges-within-scope if operator confirms)

**Estimated turns:** 200 (grounded per whereami 2026-09-22c actuals — 130 turns for similar scope; extension for 3 drives vs 1 pushes to 200).

### Option b — surgical split (smaller scope)

Ship /onboard-repo drive first as a proof; land /riff + /launch as follow-ons.

- Session 1: /onboard-repo interactive drive + expect setup in container (~100 turns)
- Session 2: /riff interactive drive + Playwright MCP setup (~100 turns, blocked on cli#241)
- Session 3: /launch drive (~80 turns)

Total: same effort, split across 3 sessions. Better if operator wants to verify /onboard-repo works before scaling to the other two.

## Key decisions for prep

1. **Ceremony depth:** full-dressed OOAD (option a) OR surgical (option b)?
2. **Playwright MCP blocker (cli#241):** do we cure it in this scope OR skip /riff until #241 lands?
3. **Interactive tech pick:** `expect` (Tcl-based; classic; ships in Debian) OR node `pty` wrapper (more control; needs Node bootstrap in container)?
4. **Assertion granularity:** per-artifact (settings.json exists) OR per-phase (Phase 0 completed → Phase 1 completed → ...) OR both?

## Prereqs to read at prep

- `scripts/smoke-drive-skills.sh` — current headless driver shape
- `scripts/smoke-drive-onboard-repo.sh` — existing /onboard-repo headless drive (asserts .claude/settings.json lands)
- `scripts/smoke-drive-riff.sh` — existing /riff headless drive
- `scripts/lib/smoke-assert.sh` — assertion library
- `harness/docker/Dockerfile.cold-adopter` — where expect installs
- `harness/docker/entry.sh` — where new drives wire
- cli#241 (/riff MCP sandbox) — blocking dependency
- bassclef-upstream#1922, #1923 — talkative-refuse contracts these drives depend on

## Related open work

- **cli#253** — smoke assertion drift on v1.6.1 log-on-skip stderr (medium; small scope; can pick as a warm-up before #254)
- **cli#241** — /riff Playwright MCP sandbox gap (dep for /riff drive)
- **bassclef-upstream#1955** — bassclef doctor tool (peer's next work; unrelated to this)

## Prior actuals reference

- 2026-09-22c — cli#217 drive-shape cure (V2 headless drives with positive-artifact assertions) — 130 turns
- 2026-09-21c — Epic #199 Story 1 /riff drive — ~85 turns
- 2026-09-21b — Epic #194 pre-tag version-sync — ~180 turns

Extrapolating: this scope shipped in ~200 turns as a single session (option a) or 3 × 90 turns split (option b).

## Recommendation

**Option a (full ceremony /longrun 2026-09-27a).** Rationale: the 3 skills share the expect infrastructure + Dockerfile changes + assertion library extensions. Splitting them across sessions duplicates that infra work. Fully-dressed chain also matches operator's standard pattern for new construction (per recaps 2026-09-22b, 2026-09-22c, 2026-09-21b, 2026-09-21c).

**Order the drives:**
1. /onboard-repo (simplest — no MCP needed; refuses on main-branch guard which is easy to bypass with fresh git init)
2. /launch (medium — asserts multiple output artifacts; no MCP)
3. /riff last (dep on cli#241 MCP cure)

If cli#241 blocks, ship the first two + defer /riff to a follow-on.

---

## Sub-step progress (overnight 2026-09-26)

| Sub-step | Scope | Status | PR |
|---|---|---|---|
| 0 | Walking skeleton (5-verb interface + 3 drive stubs + registry) | shipped 2026-09-26 | #255 |
| 1 | Real smoke-expect.sh bodies + fake_claude fixture + 35 Tier 0 tests | shipped 2026-09-26 | #256 |
| 2 | Real /onboard-repo drive body | shipped 2026-09-26 | #257 |
| 3 | Real /launch drive body | shipped 2026-09-26 | #258 |
| 4 | Real /riff drive body (SKIP_RIFF_INTERACTIVE preserved for cli#241) | shipped 2026-09-26 | #259 |
| 5 | Dockerfile installs expect + real-claude integration test | pending next session | — |
| 6 | entry.sh Step 8 wire + smoke-report interactive-class rows | pending | — |

## Batch extension (per operator directive)

| Batch | Skills | Status | PR |
|---|---|---|---|
| A | dev-flow: sprint / whereami / temperance / diagnose / verify / kiss / luminary | shipped 2026-09-26 | #260 |
| B | SDLC-chain: shape / spec / decompose / build / architect-review / longrun-prep / session-end | shipped 2026-09-26 | #261 |
| C | authoring: state-a-problem / value-prop / whats-the-plan / roadmap-reconcile / promote / interpret-input / use-case | shipped 2026-09-26 | #262 |

Total: 21 skills interactive-drive-capable via generic driver + catalog. Excluded: /release, /release-notes, /deploy (production side effects; deferred to per-skill design).

## Pickup for next session (sub-step 2)

**Scope:** real `scripts/smoke-drive-interactive-onboard-repo.sh` body.

**Reads:**
- `scripts/lib/smoke-expect.sh` (merged 2d33dbd) — the 5-verb interface + fake_claude fixture
- `scripts/smoke-drive-onboard-repo.sh` — existing headless /onboard-repo drive (assertion shape reference)
- `.claude/skills/onboard-repo/SKILL.md` — Phase sequence + prompts the drive needs to send/expect

**Approach:**
- Read the SKILL body to enumerate Phase 0 → N prompts + expected responses
- Wire drive_start + sequence of drive_send/drive_expect per phase
- Assert filesystem artifacts (`settings.json`, `substrate.config.md`, `docs/whereami.md`)
- Test against fake_claude fixture with a scripted response map (extend fixture if needed)
- Real-claude integration deferred to sub-step 5 wire

**Estimated turns:** 60-100 (bounded by SKILL body complexity + assertion set size).

**Ceremony:** Class (b) script extension per `.claude/rules/oo-ad-entry-point.md`. Brief use case + /decompose entry-point check. Lighter than sub-step 1's Class (c) since the interface is already pinned.

