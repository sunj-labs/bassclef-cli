---
tier: upstream
session: 2026-10-05 Session E
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - linus-torvalds
    - david-ogilvy
---

# Session E — backlog triage (36 open tickets)

**Problem (≤500 chars):** 36 open tickets have piled up since 2026-09-24. Many are Kunal-rerun class with cli-side driver anchors shipped but wait on upstream Slot 9 cadence. Several ship-and-closed PRs never got the ticket close-keyword in the body. A few are clearly stale smoke markers. Operator reading `gh issue list` cannot tell what is actually open vs waiting vs shipped-but-not-closed. Triage derives per-ticket action using upstream RCA shape.

---

## Goal

Classify each of 36 open tickets. Close provably-shipped with cross-ref evidence. Status-comment on BLOCKED tickets citing the cli anchor + upstream dependency. Leave operator-task tickets alone with a one-line note. Next `/sprint` reads a clean backlog.

## Attribution

Operator ask Session E 2026-10-05: triage backlog using upstream's RCA format (ticket shape from `bassclef-upstream#2036` + `#2039`). Run `/kiss` + `/ogilvy-writing-audit` on every proposed edit.

## Evidence

- Source: `gh issue list --state open --limit 50` (36 tickets returned 2026-10-05T01:40Z).
- Source: `docs/whereami.md` L17-21 (Session A-D closeouts naming driver PRs #333-#353).
- Source: `docs/session-logs/2026-09-25-*` through `2026-10-04-*` (actual shipping history per session).
- Source: `gh issue view 305` comment 2026-10-04 (upstream PR #2062 merged; cli waits for bundle sync).
- Source: `gh issue view 290` comment 2026-09-29 (bassclef-upstream#2024 mirrored; cli waits for v1.6.6 tag).
- Source: `gh issue view 294` comment 2026-10-03 (upstream PRs #2041-#2045 shipped Finding #6 class).
- Warrant: Session logs + whereami + ticket comments together pin which cli anchors shipped against which upstream cures. Triage class derives from this cross-check per ticket.

Spot-verified citations:

- `#319 /interpret-input intent field driver` → whereami L20 names Session A PR #333-#339 shipping walking skeleton + 4 authoring drivers ✓
- `#305 identifier-leak` → ticket comment names upstream PR `a312a31b` merged; cli driver anchor PR #335 shipped ✓
- `#234 user-scope reset` → PR #288 nuke-and-fresh-install.sh + PR #289 rename landed 2026-09-29a ✓
- `#230 drive-script assertions` → PR #218 cli#217 drive-shape cure landed 2026-09-22c ✓

---

## Findings — 36 total

### Class A — Kunal-rerun BLOCKED on upstream Slot 9 (status-comment, keep open)

Cli anchor driver shipped; waits on upstream cure then bundle sync. Each ticket's close-keyword lands in the cli release PR body when `dist/lite/` re-bundles cured substrate.

#### #332 — Lite /launch → /build → deployed app, but no deploy path exists

**Severity:** 🟡 P2 (feature gap, not regression)
**Class:** adopter-contract — lite tier promises less than skill chain promises
**Action:** Status-comment. BLOCKED on upstream Slot 9 (Class G); cli#307 driver anchor shipped PR #350.

#### #331 — /autonomous is lite but procedure lives in strategy/

**Severity:** 🟡 P2 (adopter cannot run /autonomous on lite)
**Class:** lite packaging gap
**Action:** Status-comment. BLOCKED on upstream Slot 9. No cli-side cure path (ships upstream).

#### #330 — /build critiques: review caught ~20 Builder defects

**Severity:** 🟡 P2 (methodology, not single-point defect)
**Class:** build-phase discipline gap
**Action:** Status-comment. Adopter follow-up comments 2026-10-03 add 7 critiques across 6 steps. BLOCKED on upstream Slot 9 reshape of `/build` Phases 4-7.

#### #329 — Lite ships adr-discipline-check.sh but never wires it

**Severity:** 🟡 P2 (dead-letter hook)
**Class:** bootstrap-pair discipline break
**Action:** Status-comment. BLOCKED on upstream wiring fix.

#### #328 — First supervised /build run: 14 gaps playing Phases 4-7 by hand

**Severity:** 🟡 P2 (methodology)
**Class:** build-phase coverage
**Action:** Status-comment. Adopter follow-up comments 2026-10-03 add 11 more findings across 6 steps. BLOCKED on upstream.

#### #327 — /build passes a spec with zero steps and hides YAML parse errors

**Severity:** 🔴 P1 (correctness — adopter builds silently against zero-step spec)
**Class:** cli#307-related (Session C stage 1 driver shipped)
**Action:** Status-comment. Cli#307 driver anchor shipped PR #350 (`4230826`). Flips GREEN at bundle sync against cured upstream.

#### #326 — /build Phase 2b looks up preview-state by goal slug; misses adopter mode

**Severity:** 🟡 P2
**Class:** preview-state wire gap
**Action:** Status-comment. BLOCKED on upstream.

#### #325 — /launch mocks have no contrast check

**Severity:** 🟡 P2 (quality guard)
**Class:** process+quality
**Action:** Status-comment. BLOCKED on upstream.

#### #324 — /launch calls /ux-migration MUST; /ux-migration says skip for greenfield

**Severity:** 🟡 P2 (contract drift)
**Class:** writer-vs-reader contract
**Action:** Status-comment. BLOCKED on upstream.

#### #323 — save-state.sh auto-save commits prototype edits before operator review

**Severity:** 🟡 P2 (discipline-break)
**Class:** cli#305 adjacent — save-state hook class
**Action:** Status-comment. Related to upstream PR #2062 scope. Verify at next bundle sync.

#### #322 — `/launch Phase 14 template uses scope-bounded` (jargon gate blocks)

**Severity:** 🟢 P3 (cosmetic — jargon match)
**Class:** adopter-prose discipline
**Action:** Status-comment. BLOCKED on upstream.

#### #321 — Pre-flight skill-registry warning is false alarm on lite installs

**Severity:** 🟡 P2 (cries wolf)
**Class:** checks-that-misfire
**Action:** Status-comment. BLOCKED on upstream.

#### #316 — state-validate silently skips all checks in lite (no schemas shipped)

**Severity:** 🟡 P2 (silent-pass hook)
**Class:** lite packaging gap
**Action:** Status-comment. BLOCKED on upstream.

#### #315 — state accessor can't read input-artifact; scripts/state.sh missing in lite

**Severity:** 🟡 P2 (missing module)
**Class:** lite packaging gap
**Action:** Status-comment. BLOCKED on upstream.

#### #312 — No producer for structural_hints.verb_goal_pairs; /build reads it

**Severity:** 🟡 P2 (writer-vs-reader contract)
**Class:** B — contract drift
**Action:** Status-comment. BLOCKED on upstream.

#### #311 — artifact-ingestion-gate treats parent_bet: null as a declared parent

**Severity:** 🟡 P2 (check misfires)
**Class:** D — cries wolf
**Action:** Status-comment. BLOCKED on upstream.

#### #310 — /build capability check: flaky 2s network probe, wrong fallback message

**Severity:** 🟡 P2 (flake class)
**Class:** D — cries wolf
**Action:** Status-comment. BLOCKED on upstream.

#### #309 — /build pre-flight refuses on hosting_platform none with a /launch reason

**Severity:** 🟡 P2 (wrong refuse message)
**Class:** D — misfires
**Action:** Status-comment. BLOCKED on upstream.

#### #306 — /onboard-repo label step fails on macOS bash 3.2 (declare -A)

**Severity:** 🔴 P1 (portability floor — breaks every macOS adopter)
**Class:** E — portability
**Action:** Status-comment. BLOCKED on upstream. Note: Session A plan L47 pins bash 3.2 as a required floor.

---

### Class B — cli anchor shipped, awaits bundle sync verify (status-comment, keep open)

Driver anchor landed as RED. Flips GREEN at the next cli release pulling cured upstream substrate.

#### #319 — interpret-input.sh never writes the intent field the skill promises

**Severity:** 🟡 P2
**Class:** B — writer-vs-reader
**Action:** Status-comment. Driver anchor PR #333 (Session A walking skeleton) shipped. Awaits bundle sync for GREEN.

#### #320 — /personas builds default slug from git email; leaks account ID/handle

**Severity:** 🔴 P1 (privacy)
**Class:** A — identity leak
**Action:** Status-comment. Driver anchor PR #336 (Session A /personas full driver) shipped.

#### #318 — /personas and /jtbd-tasks conflict on persona path; no create mode

**Severity:** 🟡 P2
**Class:** B — writer-vs-reader
**Action:** Status-comment. Driver anchor PR #336 (/personas write-side) + PR #337 (/jtbd-tasks read-side) shipped.

#### #317 — /launch chain skills disagree on output paths (4 mismatches)

**Severity:** 🟡 P2
**Class:** B — writer-vs-reader
**Action:** Status-comment. Driver anchor PR #339 (full-chain path contract) shipped.

#### #314 — /launch --local says open on phone, but local-serve binds 127.0.0.1 only

**Severity:** 🟡 P2 (portability — adopter phone can't reach loopback)
**Class:** E — portability
**Action:** Status-comment. Driver anchor PR #338 (/launch --local phase gate) shipped.

#### #308 — lib/state.sh needs PyYAML; stock macOS lacks it

**Severity:** 🔴 P1 (portability — every stock macOS adopter)
**Class:** C — lite packaging + E — portability
**Action:** Status-comment. Driver anchor PR #344 (Session B /sprint driver) shipped.

#### #305 — Identifier-leak check blocks on its own files and skips commit author

**Severity:** 🔴 P1 (privacy + bootstrap break)
**Class:** A — privacy + F — process guard
**Action:** Status-comment. Upstream PR #2062 (`a312a31b`) MERGED per ticket comment. Driver anchor PR #335 shipped. Close at next bundle sync.

---

### Class C — Provably shipped cli-side, close now with cross-ref

#### #230 — Drive-script assertions check success-path artifacts; skills now talkative-refuse

**Severity:** 🟡 P2 (shipped)
**Class:** F — process guard
**Action:** CLOSE. Cured by PR #218 cli#217 drive-shape cure (merged 2026-09-22c, `d40f13d`).

#### #234 — smoke-reset-whole doesn't nuke .claude/

**Severity:** 🔴 P1 (shipped)
**Class:** reset discipline
**Action:** CLOSE. Cured by PR #288 (`scripts/nuke-and-fresh-install.sh` merged 2026-09-29a, `0b845dc`) + PR #289 rename (`b2cafc8`). `--nuke-user-scope` extension shipped under the same scope.

#### #240 — smoke-assert-skills: extend coverage to /riff + /onboard-repo drives

**Severity:** 🟡 P2 (shipped)
**Class:** test coverage
**Action:** CLOSE. Cured by batch-dispatch PRs #257 (/onboard-repo), #258 (/launch), #259 (/riff) during 2026-09-26f + batched smoke-assert extensions in PRs #260-#262.

#### #254 — docker-smoke: expect-based interactive drives

**Severity:** 🟡 P2 (shipped)
**Class:** interactive driver infra
**Action:** CLOSE. Cured by PR #255 walking skeleton + PR #256 real smoke-expect bodies + PR #260/261/262 three batches of 21 skill drives (2026-09-26d through 2026-09-27a).

---

### Class D — Smoke markers (close as session artifacts)

Smoke session marker tickets; they are run-receipts, not actionable bugs.

#### #237 — smoke: @thebassclef/lite@1.9.2-nosync · 2026-09-25

**Severity:** 🟢 P4 (session marker)
**Class:** receipt
**Action:** CLOSE. Session-marker ticket; smoke session complete; no action owed.

#### #238 — smoke: @thebassclef/lite@1.9.2-nosync-nuked · 2026-09-25

**Severity:** 🟢 P4 (session marker)
**Class:** receipt
**Action:** CLOSE. Session-marker ticket; smoke session complete; no action owed.

---

### Class E — Substrate-evolution / mirror-upstream (status-comment, keep open)

Cli-side cannot cure. Upstream owns the cure. Open as adopter-visible tracker.

#### #290 — bassclef v1.6.5 tag ships v1.6.4 in bassclef-version.json

**Severity:** 🔴 P1 (adopter sees stale version)
**Class:** release discipline break
**Action:** Status-comment. Mirrored upstream as `bassclef-upstream#2024`. Awaiting v1.6.6 re-tag; cli publish.yml L136+L281 ride the fix at bundle sync.

#### #291 — statusline dispatcher hardcodes rich-impl filename

**Severity:** 🟢 P3 (enhancement)
**Class:** substrate-evolution
**Action:** Status-comment. Mirror candidate for upstream per `.claude/rules/bassclef-evolution.md`. No cli cure path.

#### #284 — /whereami auto-update signal misreads user-scope substrate inheritance

**Severity:** 🟡 P2 (adopter-source)
**Class:** substrate-evolution
**Action:** Status-comment. Mirror candidate for upstream.

#### #283 — Cold adopter report: lite 1.9.7 in Docker

**Severity:** 🟡 P2 (adopter-report tracker)
**Class:** adopter-feedback
**Action:** Status-comment. Items split out as #305 (identifier-leak) + items 4-5 referenced in 2026-10-03 comment. Tracker ticket; keep open until all child items close.

---

### Class F — Prereq / parent tickets (status-comment, keep open)

#### #294 — Adopter-regression smoke drivers for Kunal #2036

**Severity:** 🟡 P2 (parent ticket)
**Class:** epic-parent
**Action:** Status-comment. Drivers 1-5 shipped PRs #298-#302 (2026-10-03b) covering findings #1, #2, #3, #4, #5, #6, #9. 2 E2E prototypes shipped PR #303. Session A-D shipped 11 more drivers. Awaits dist/lite bundle sync against upstream v1.7.0+ to flip GREEN.

#### #295 — cli#294 prereq: sync dist/lite with cured bassclef release

**Severity:** 🟡 P2 (prereq)
**Class:** bundle sync
**Action:** Status-comment. Bundle sync PR #297 merged 2026-10-03b (`32976ab`) pinned bassclef v1.7.0. #295 can CLOSE if bundle-sync task considered done; keep open if Session E or later owes a verify.

**Decision:** CLOSE. Bundle sync shipped. Close with cross-ref.

---

### Class G — Operator-task / infra-deferred (leave alone with one-line note)

Not Session E scope. Operator decides timing.

#### #279 — chore(npm-publish): restore kingofrock as required_reviewer

**Severity:** 🟡 P2 (operator task)
**Action:** No change. Operator restores at next npm publish gate review.

#### #276 — V2i drives need pre-seeded ~/.claude/.credentials.json

**Severity:** 🟡 P2 (deferred infra)
**Action:** No change.

#### #273 — chore: migrate CI secrets to 1Password service-account

**Severity:** 🟡 P2 (deferred infra)
**Action:** No change.

#### #267 — chore(security): restrict workflow edits via CODEOWNERS

**Severity:** 🟡 P2 (deferred security)
**Action:** No change.

#### #266 — chore(cli-254): migrate smoke sandbox auth from PAT to GitHub App

**Severity:** 🟡 P2 (deferred infra)
**Action:** No change.

#### #246 — integrated probe channel between operator and cold-adopter

**Severity:** 🟡 P2 (deferred infra)
**Action:** No change.

#### #244 — URGENT: docker-smoke behind — Mac cold-adopter leak reproduction

**Severity:** 🔴 P1 (p1 label; stale)
**Action:** Status-comment. The underlying leak class cured by bassclef-upstream#1954 (shipped v1.6.1) + cli#248 shadow detection (shipped PR #248 2026-09-26b). Mac cold-adopter leak class CLOSED but ticket's p1 priority inflates backlog signal. **Decision:** CLOSE with cross-ref to #1954 cure + PR #248.

#### #243 — docker-smoke: add auto_sync=true variant

**Severity:** 🟡 P2 (deferred)
**Action:** No change.

#### #241 — /riff cannot read .claude/luminaries/ in docker container sandbox

**Severity:** 🟡 P2 (active)
**Action:** Status-comment. Still active; `/riff` sandbox gap not cured.

#### #236 — smoke-report --publish should auto-create labels

**Severity:** 🟡 P2 (deferred)
**Action:** No change.

#### #235 — bassclef init reports '68 files refused (path collision)' on truly-fresh dir

**Severity:** 🟡 P2 (active bug)
**Action:** Status-comment. Still active; needs init.ts path-collision detection fix.

#### #232 — `Harness workflow race — 3-min propagation timeout`

**Severity:** 🟡 P2 (deferred)
**Action:** No change.

---

## Summary — proposed per-class actions

| Class | Count | Action |
|---|---|---|
| A — Kunal BLOCKED on upstream Slot 9 | 18 | Status-comment, keep open |
| B — cli anchor shipped, awaits bundle sync | 7 | Status-comment, keep open |
| C — provably shipped, close with cross-ref | 4 | **CLOSE** (#230, #234, #240, #254) |
| D — stale smoke markers | 2 | **CLOSE** (#237, #238) |
| E — substrate-evolution mirror | 4 | Status-comment, keep open |
| F — prereq / parent tickets | 2 | **CLOSE #295**, status-comment #294 |
| G — operator-task / infra deferred | 11 | 1 **CLOSE #244** (cured, stale p1); 10 no change |

**Totals:**
- **8 tickets to CLOSE** with evidence (#230, #234, #237, #238, #240, #244, #254, #295)
- **22 tickets to status-comment** (keep open, update status)
- **6 tickets to leave alone** (operator-task deferred)

**Net:** backlog drops from 36 → 28 open; the 28 that remain carry status comments naming current state. Next `/sprint` reads a clean backlog with each open ticket's current state at a glance.

---

## What success looks like

- 8 CLOSE actions landed with cross-ref evidence per ticket.
- 22 status comments landed; each ≤ 150 words; `/kiss` + `/ogilvy-writing-audit` passed before posting.
- Session log amended with final counts after execution.
- `gh issue list --state open --limit 50` returns 28 (down from 36).

## Out of scope

- Actual code cures. All upstream-dependent; cli waits on Slot 9 cadence.
- Mirror-filing to upstream. Already done for #290 (upstream#2024), #284 (candidate), #291 (candidate).
- Operator infra tasks (#266, #267, #273, #279) — operator timing.

## Refs

- `docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md` — Session A-C plan
- `docs/whereami.md` L17-21 — next_in_flight_goal
- `bassclef-upstream#2036` — Kunal rerun epic (RCA shape source)
- `bassclef-upstream#2039` — adopter-finding tracker shape
- `bassclef-upstream#2062` — identifier-leak cure (merged, awaits bundle sync)
- `bassclef-upstream#2024` — v1.6.5 tag mirror
