---
tier: lite
id: tier-a-driver-inventory-state
status: active
started: 2026-10-07
updated: 2026-10-07
parent_plan: docs/plans/tier-a-dynamic-driver-roadmap.md
goal: Validate low-friction UX for Sam / Louis / Jamie in first 5-10 minutes of adopter touch
cadence: update at every Session close that touches drivers, fixtures, or Tier A tickets
amendments:
  - 2026-10-07 — cli#361 moved Q4 → Q1 after peer coordination. The bassclef-sync DEGRADED banner fires on every adopter SessionStart; that IS the 5-10 min friction surface. Prior Q4 classification missed the per-session banner evidence.
  - 2026-10-07 — cli#327 promoted Q2 → Q1 for Session M scope. Peer flagged it in deferred Q1 set; pairs with cli#328 /build Phase 4-7 gaps on Jamie's happy path.
session_m_scope:
  waiting_on: bassclef-upstream v1.9.0 release URL + bassclef-version.json SHA from peer uds:/tmp/cc-socks/38138.sock
  scope_a: cli#361 + cli#314 + cli#327 (~80-150 turns)
  scope_b_follow_on: cli#361 + cli#314 + cli#327 + cli#328 pair (~200-350 turns; unlocks /build happy path capture)
---

# Tier A driver inventory + state

Living record of the Tier A dynamic driver suite. Reads what shipped, names what remains, scores remaining work per Eisenhower against the UX validation goal.

## Why this doc

The roadmap at `docs/plans/tier-a-dynamic-driver-roadmap.md` says WHAT to build. This doc says what SHIPPED, what's GREEN, and what's NEXT. Keep both. Roadmap is the plan; this is the state against the plan.

## The anchor goal

> Validate low-friction UX for Sam / Louis / Jamie in the first 5-10 minutes of adopter touch.

Every item scored below answers one question — does it move this goal forward? Items that only move substrate hygiene, dev-tool polish, or internal harness quality rank lower unless they block the goal.

## Inventory — Tier A persona driver state

6 call-to-action skills per roadmap §Tiering. All 6 covered.

| Skill | Persona | Driver | Fixture | Version | Shipped |
|---|---|---|---|---|---|
| /onboard-repo | Sam | `smoke-drive-e2e-onboard-repo-sam.test.sh` | REAL (4 cases) | 1.9.10 | Session J, PR #382 |
| /whereami | Louis | `smoke-drive-e2e-whereami-louis.test.sh` | REAL (3 cases) | 1.9.10 | Session J, PR #382 |
| /sprint | Louis | `smoke-drive-e2e-sprint-louis.test.sh` | REAL (3 cases) | 1.9.11 | Session L, PR #396 |
| /riff | Jamie | `smoke-drive-e2e-riff-jamie.test.sh` | REAL (3 cases) | 1.9.11 | Session L, PR #396 |
| /launch | Jamie | `smoke-drive-e2e-launch-jamie.test.sh` | REAL (3 cases) | 1.9.11 | Session L, PR #396 |
| /build | Jamie | `smoke-drive-e2e-build-jamie.test.sh` | REAL — refusal path only (3 cases) | 1.9.11 | Session L, PR #396 |

**Aggregate: 19/19 cases GREEN** at 2026-10-07.

## Known gaps (named + tracked)

| Gap | What's missing | Where tracked |
|---|---|---|
| /build happy path | Scratch-dir with fake plan + git init so /build actually ships code | `scripts/tests/fixtures/jamie-build/README.md` §Shape notes |
| /onboard-repo + /whereami on 1.9.11 | Captures pin v1.9.10; refresh when either skill changes shape | this doc |
| Tier A architect-review sweep | PR 7 of 7 per roadmap | cli#388 |
| /riff output over Jamie ceiling | 45 lines vs aspirational 40 | bassclef-upstream#2123 |

## Open tickets touching Tier A (persona UX in first 10 min)

Read at 2026-10-07 via `gh issue list --state open`:

- **cli#388** — Session L architect-review on full Tier A harness
- **cli#383** — docker-smoke multi-turn chaining for Tier A drivers
- **cli#330** — /build critiques caught 20 Builder defects (review quality)
- **cli#328** — First supervised /build run — 14 gaps in Phases 4-7
- **cli#327** — /build passes spec with zero steps + hides YAML parse errors
- **cli#325** — /launch mocks have no contrast check; failing color reached tokens
- **cli#320** — /personas builds default slug from git email; leaks account ID
- **cli#318** — /personas and /jtbd-tasks conflict on persona path; no create mode
- **cli#314** — /launch --local says "open on phone" but binds 127.0.0.1 only
- **cli#310** — /build capability probe flaky 2s timeout + wrong fallback message
- **cli#284** — /whereami auto-update signal misreads user-scope inheritance
- **cli#283** — Kunal cold adopter report — lite 1.9.7 in Docker (persona notes)
- **cli#241** — /riff cannot read .claude/luminaries/ in docker container
- **cli#235** — bassclef init reports '68 files refused (path collision)' on truly-fresh dir
- **cli#210** — smoke-drive-onboard-repo assertion mismatches /onboard-repo Phase 0 refuse-on-main
- **bassclef-upstream#2123** — /riff output 45 lines vs 40-line ceiling (my Session L filing)

## Eisenhower matrix

Scored 2026-10-07. Anchor goal — Sam / Louis / Jamie first 5-10 min UX validation.

### Q1 — DO NOW (urgent + important)

Blocks the current adopter happy path OR carries a security concern:

- **cli#361** — 8 hooks recur missing after bassclef-sync self-heal. The `bassclef-sync: DEGRADED` banner fires on every SessionStart — including this session's own at 2026-10-07 turn 1. Every adopter sees it on first touch. Session M scope (a) picks this up.
- **cli#320** — /personas leaks git email in default slug. Blocks any adopter running /personas. Security concern. Fix is small; ship next.
- **cli#235** — bassclef init reports '68 files refused' on fresh dir. Sam's first touch — this IS the 5-minute UX. If adopters see this on a clean install, the validation stops before it starts.
- **cli#241** — /riff cannot read .claude/luminaries/ in docker container sandbox. Jamie's /riff path breaks in the exact environment the harness tests. Blocks /riff validation.
- **cli#314** — /launch --local says "open on phone" but binds 127.0.0.1. Jamie reads the output as a lie. Trust-breaking on first touch. Session M scope (a) picks this up.
- **cli#327** — /build passes zero-step spec + hides YAML parse errors. Promoted from Q2 for Session M because peer flagged it in the deferred Q1 set and it pairs with /build Phase 4-7 gaps (#328). Session M scope (a) picks this up.

### Q2 — SCHEDULE (important, not urgent) — assign a time budget

Moves the goal; no 2-week deadline. Each needs a time budget:

- **cli#388** — architect-review on full Tier A harness. ~30 turns. Closes PR 7 of 7 from roadmap. Catches drift across the 6 drivers.
- **cli#328** — 14 gaps in /build Phases 4-7 from supervised run. Enables /build happy path capture (the current biggest gap). Big ticket — likely 100-200 turns on its own. Session M follow-on scope (b) picks this up alongside #327.
- **cli#325** — /launch mocks have no contrast check. 10-20 turns. Lifts Jamie's /launch quality bar.
- **cli#318** — /personas and /jtbd-tasks path conflict. 20-30 turns. Clears a persona-chain blocker that will surface the moment anyone chains the two.
- **cli#310** — /build capability probe flaky. 10-15 turns. Reduces first-touch noise on Jamie's /build attempts.
- **cli#284** — /whereami auto-update misreads user-scope inheritance. 15-20 turns. Louis defect; cosmetic but visible.
- **cli#330** — /build critiques — review caught 20 defects. Not a bug; a quality signal. 20-30 turns to turn it into checklist items.
- **/build happy path capture** (no ticket yet) — once #328 lands, capture /build shipping real code. 15-25 turns. File ticket when #328 moves.
- **Refresh /onboard-repo + /whereami to 1.9.11** — opportunistic. 10-15 turns. Only when either skill changes shape in a 1.9.x bump.
- **bassclef-upstream#2123** — /riff ceiling decision (upstream owns; cli waits).

### Q3 — DELEGATE / BATCH / AUTOMATE (urgent, not important for THIS goal)

Not on the 5-10 min persona path; still worth handling:

- **cli#383** — docker-smoke multi-turn chaining. Enables richer drivers but current single-turn captures validate the first 5-10 min already. Batch into a follow-on session when Tier B drivers surface.
- **cli#283** — Kunal cold adopter report notes. 10 findings. Already filed as individual tickets per the Kunal #2036 pattern. Close the parent once children clear.
- **cli#210** — smoke-drive-onboard-repo assertion vs Phase 0 refuse-on-main. Driver bug, not UX bug. Fix when touching the sam-onboard driver next.

### Q4 — CLOSE / defer indefinitely (not urgent + not important for THIS goal)

Off-goal for persona UX validation. These serve substrate hygiene or dev tooling, not Sam/Louis/Jamie first-touch. Close with a note or leave off the queue:

- cli#361 — 8 hooks missing after bassclef-sync self-heal (substrate; internal)
- cli#373 — bump-version.mjs dist/ staleness (dev tool)
- cli#356 — finish or remove smoke-drive-generic.sh (dev tool)
- cli#329 — adr-discipline-check.sh wired-but-not-wired (substrate hygiene)
- cli#305 — identifier-leak check blocks own files + skips commit author (hygiene)
- cli#294 — adopter-regression smoke drivers for Kunal cures (hygiene)
- cli#291 — statusline dispatcher hardcoded filename (polish)
- cli#290 — bassclef v1.6.5 tag ships v1.6.4 (likely historical; verify first)
- cli#276 — V2i drives need pre-seeded credentials (dev harness)
- cli#273 — migrate CI secrets to 1Password (ops)
- cli#267, cli#266 — CODEOWNERS + GitHub App migration (security/ops; both > 90 days old)
- cli#246 — probe channel between operator + cold-adopter (dev harness)
- cli#243 — auto_sync=true variant for docker-smoke (dev harness)
- cli#236 — smoke-report auto-create labels (dev tool)
- cli#232 — harness workflow race timeout (dev harness)
- cli#215 — plain-English exit codes in entry.sh (polish)
- cli#214 — bash gotcha lint (dev tool)
- cli#213 — bassclef init npm pack wiring manifest (dev harness)
- cli#209, #208, #207, #206 — bassclef-evolution items (hygiene; 90+ days old)
- cli#202, #201 — F-AR epic follow-ons (dev workflow)
- cli#2095 (bassclef-upstream) — bassclef-sync CLAUDE_PROJECT_DIR unset in SessionStart (upstream owns)

Not literally "close now" — leave off the sprint queue. Close only when the operator says so.

## Q3 pattern — automation candidate

4 items under "dev harness polish" (#276, #246, #243, #232, #214, #213). Shape — operator-facing harness quality that compounds across every future driver. Could batch into a single `/promote` ticket for a harness-polish mini-goal in a future session. Not now; not important for the 5-10 min goal.

## How to keep this doc fresh

Update at every session close that touches:

- A Tier A driver file (`scripts/tests/smoke-drive-e2e-*-{sam,louis,jamie}.test.sh`)
- A Tier A fixture (`scripts/tests/fixtures/{sam-,louis-,jamie-}*/`)
- A ticket in the open-items list above
- The parent roadmap

The update discipline — read current fixture state via `ls` + `git log`, re-run `gh issue list` for the ticket cut, re-score any shifted item against the anchor goal above. If the anchor goal shifts, re-run `/eisenhower` from scratch — the matrix collapses without a current anchor.

## References

- `docs/plans/tier-a-dynamic-driver-roadmap.md` — parent plan
- `docs/next-session-plan-2026-10-08-session-l-exercise-v1.9.11.md` — Session L plan (closed by PR #396)
- `docs/session-logs/2026-10-07-session-k-tier-a-full.md` — Session K log
- `docs/session-logs/2026-10-08-session-l-tier-a-real-captures.md` — Session L log
- PR #382 (Session J real captures), PR #384-#387 (Session K scaffolds), PR #396 (Session L real captures)
- cli#375 — parent Tier A roadmap ticket (closed Session K)
- cli#389 — Session L follow-on (closed PR #396)
- cli#388 — architect-review follow-on (open)
- bassclef-upstream#2123 — /riff ceiling decision (open)
- `.claude/skills/eisenhower/SKILL.md` — the scoring method used here

## Session M outcome (2026-10-07 close)

Scope (a) collapsed to upstream routings — all 3 "cli Q1 cures" turned out to be bassclef-source defects:

- cli#361 CLOSED → bassclef-upstream#2130 (sync template postcondition misreads install-class)
- cli#314 CLOSED → bassclef-upstream#2131 (/launch --local bind + handoff text lie)
- cli#327 CLOSED → bassclef-upstream#2132 (/build zero-step specs + YAML errors)

Scope (b) pivot to genuine cli-side harness work:

- PR #397 — jamie-build twin fixture + T04 case. `golden-capture-env-partial.txt` pins /build's env-check refusal on plan+spec+git-init+no-gh container. 20/20 Tier A aggregate GREEN.

Methodology miss recorded in session log — `/eisenhower` prep should pre-flight defect code location (md5sum against bassclef source) before accepting peer scope framing. Filed as `/promote bassclef-evolution` candidate; follow-on next session.
