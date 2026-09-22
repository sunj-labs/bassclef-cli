---
plan_date: 2026-09-23
parent_ticket: cli #217
target: docker-smoke skill drives dispatch skills honestly
authoring_luminaries:
  primary: michael-feathers
  supporting: [kent-beck, alan-cooper]
---

# Next-session plan — cli #217 drive-shape cure

## Recommended session sequence

Fix docker-smoke skill drives so they actually dispatch skills and produce real signal.

**One session. Full OOAD ceremony per `.claude/rules/oo-ad-entry-point.md` matrix (substrate code + Tier 0).**

## Problem (via /state-a-problem brief)

Docker-smoke drives fire `claude -p "/temperance"` and similar. `-p` mode routes leading-slash strings to Claude Code's CLI slash-command matcher, not the Skill tool. Every drive says "Unknown command" and exits 0. V1 assertions pass by coincidence because the grep pattern misses that string. Smoke reports green while zero skills dispatched. This surfaced during v1.7.0 validation and is filed at cli #217.

## Value prop (via /value-prop tweet)

Trustworthy skill-drive signal on every release cascade. Fixes a false-green class that has masked no-op drives since goal 2026-09-20d. Smoke stops lying.

## Evidence

- Source: cli #217 body (filed 2026-09-22) — full trace of the invocation pattern + local repro captures
- Source: `/tmp/onboard-out/onboard-repo.out` — literal `Unknown command: /onboard-repo` + exit 0
- Source: `scripts/lib/smoke-assert.sh:39` — grep pattern `(not found|No such file or directory)` never matches "Unknown command"
- Warrant: three drive scripts share the wrong shape; assertion set can't catch the no-op

## Steps

| Step | Ships | Consumes | Turns |
|---|---|---|---|
| **0** prep | goal doc + temperance + luminary markers | session-start | 3-5 |
| **1** Cockburn brief use case + /decompose | `docs/use-cases/UC-hook-docker-smoke-drive-shape.md` | Step 0 |  8-15 |
| **2** /pre-mortem light — 3 lenses × 5-8 risks | risk ledger | Step 1 | 10-15 |
| **3** Beck TDD RED — add positive-artifact tests | 5 new Tier 0 tests fail against unfixed drives | Step 2 | 15-25 |
| **4** Fix drive-skills.sh — natural-language prompts + artifact checks | 3 drive scripts rewritten | Step 3 | 20-30 |
| **5** Beck TDD GREEN — full local suite passes | 30+/30+ tests GREEN | Step 4 | 5-10 |
| **6** /architect-review — verify drive shape against Claude Code contract | review report + install-class audit | Step 5 | 10-15 |
| **7** /rfc adversarial — outside lenses (hyrum + linus + saltzer-schroeder + norman) | RFC council findings | Step 6 | 15-25 |
| **8** Open PR + park at PR-open | PR body with full ceremony evidence | Step 7 | 5-10 |
| **9** Post-merge cold smoke on v1.7.0 | real red or real green from drives | Step 8 | 5-10 |

**Total turns:** 96-160. Grounded on cli #212 full ceremony this session — 80-140 turns. Extra budget covers the wider scope (3 scripts touched, 5 skills each need positive assertions).

## Compounding value — recommended only

- **Deliverable:** 3 drive scripts fixed. 5 V1 skills gain positive-artifact assertions. V2 assertions verified equivalent. Docker smoke stops lying.
- **Problem:** false-green smoke masks skill dispatch failures. Every green run since goal 2026-09-20d is suspect.
- **Value prop:** every future release cascade tests what adopters actually see. No more no-op green.
- **Turns:** 96-160 (grounded on cli #212 full ceremony tonight).
- **Risk:** 🟢 low — well-scoped defect in test infrastructure. No adopter impact. Fix-forward CI clears any bug. Rework under 15 min.
- **Shipping priority:** P1 — blocks trust in every future adopter smoke signal.

## Ceremony chain (full OOAD per matrix)

Substrate code = fully-dressed use case. But the fix EDITS existing scripts (not new files), so Cockburn brief tier applies per matrix. Chain:

1. Read all 3 drive scripts fully (Feathers characterization)
2. Brief use case at `docs/use-cases/UC-hook-docker-smoke-drive-shape.md`
3. `/decompose` GRASP + cross-cutting audit
4. `/pre-mortem light` — 3 lenses × 5-8 risks (Feathers + Beck + Cooper)
5. Beck TDD RED — write tests first, watch them fail
6. Fix the 3 drive scripts
7. Beck TDD GREEN
8. `/architect-review` — install-class scope (cli-internal per cli #212 architect-review)
9. `/rfc adversarial` — 3-5 outside luminaries (hyrum + linus + saltzer-schroeder + norman)
10. Open PR + park at PR-open
11. Post-merge cold smoke against v1.7.0

## Positive-artifact assertions per skill (new — V1 currently missing)

Each V1 skill needs one file OR one output line it MUST produce for the assertion to PASS:

| Skill | Positive artifact |
|---|---|
| `/temperance` | `state/markers/temperance/*.marker` exists after drive |
| `/luminary don-norman` | output contains "Don Norman" OR luminary body was read |
| `/kiss words --rewrite ...` | output contains "rewritten" OR "grade" |
| `/state-a-problem brief ...` | output contains "Problem:" OR "Who:" |
| `/whats-the-plan` | output contains "Plan:" OR "Step" |

V2 drives already use this pattern (`.claude/settings.json` for /onboard-repo, HTML file for /riff).

## Refs

- Cli #217 (parent)
- Cli #210 (subclass — /onboard-repo scaffold)
- Cli #199 (Epic — /riff HTML end-to-end Story 2)
- Cli #212 + PR #216 (sister false-green class, already cured)
- Local repro artifacts: `/tmp/onboard-out/onboard-repo.out`, `/tmp/v1-nlp/`
- Docker smoke logs tonight: 35773533870 (v1.7.0), 35778151786 (v1.7.0 re-run), 35778995946 (force-red)
- Feedback memory: `feedback_riff_needs_onboard_repo_scaffold.md`

## Not doing this session

- Fixing individual skill defects (some V1 skills may have real bugs surfaced once real dispatch happens — file separately)
- Rewriting docker-smoke.yml case statement further (already extended in cli #212 cure)
- Force upgrading V2 assertions — V2 already uses positive-artifact pattern

## Session start checklist

1. Read this plan doc
2. Read cli #217 body
3. Read `.claude/rules/oo-ad-entry-point.md` for ceremony matrix
4. Fire `/longrun prep` — will auto-detect this plan doc and use converged preset
5. Confirm scope, then execute the 11-step chain

## Peer-message state at session hand-off

- `bassclef-upstream-c2` released the cli-c6 smoke-gate on their v1.4.0
- `bassclef-upstream-48` investigating source-side bassclef-version.json defect
- Cli #208 body correction posted — flood claim not source-verified; peer #1901 verdict pending
