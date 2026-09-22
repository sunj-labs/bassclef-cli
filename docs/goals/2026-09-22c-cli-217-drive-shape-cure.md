---
tier: upstream
goal_id: 2026-09-22c
title: cli #217 drive-shape cure — natural-language prompts + positive-artifact asserts
status: in_flight
started: 2026-09-22
parent_ticket: bassclef-cli#217
parent_drivers:
  - Trustworthy skill-drive signal on every release cascade
  - False-green class since goal 2026-09-20d must not recur
appetite: 96-160 turns (grounded on cli #212 full ceremony subset ~150 turns; wider top covers 3 scripts + 5 skill asserts + full OOAD chain)
authoring_luminaries:
  primary: michael-feathers
  supporting: [kent-beck, alan-cooper]
adversarial_lenses: [hyrum-wright, linus-torvalds, saltzer-schroeder, don-norman]
references:
  - docs/next-session-plan-2026-09-23-cli-217-drive-shape-cure.md
  - docs/use-cases/UC-hook-docker-smoke-drive-shape.md
  - .claude/rules/oo-ad-entry-point.md
  - .claude/rules/loop-discipline.md
  - .claude/rules/testing-tier-config.md
  - cli #217 (parent)
  - cli #210 (subclass — /onboard-repo scaffold)
  - cli #199 (Epic — /riff HTML end-to-end Story 2)
  - cli #212 + PR #216 (sister false-green class, cured)
out_of_scope:
  - Fixing individual skill defects surfaced when real dispatch happens (file separately per skill)
  - Rewriting docker-smoke.yml case statement (already extended in cli #212)
  - Force-upgrading V2 assertions — V2 already uses positive-artifact pattern
acceptance:
  - 3 drive scripts fire natural-language prompts, not `-p "/slashname"`
  - smoke-drive-skills.sh gains 5 per-skill positive-artifact assertions
  - scripts/lib/smoke-assert.sh gains check_no_unknown_command as a generic guard
  - All new Tier 0 tests fail RED before source edits, pass GREEN after
  - Full vitest suite passes locally
  - Post-merge cold docker-smoke on v1.7.0 npm produces real signal (real GREEN or real RED, not false-green)
  - Report in /kiss + /feynman voices for the operator morning read
  - /promote tickets filed upstream for any first-5-min Sam/Louis friction surfaced by the real smoke
---

# Goal — cli #217 drive-shape cure

## Problem (via /state-a-problem brief)

Docker-smoke skill drives fire `claude -p "/temperance"` and similar. Claude Code's `-p` mode routes leading-slash strings to its own CLI slash-command matcher, not the Skill tool. Every drive says "Unknown command" and exits 0. V1 assertions pass by coincidence because the grep pattern `(not found|No such file or directory)` never matches "Unknown command". Smoke reports green while zero skills dispatched. This is filed at cli #217; two subclasses at cli #210 and #199.

## Value prop (via /value-prop tweet)

Every release cascade tests real skill dispatch. False-green class since goal 2026-09-20d disappears. Adopter smoke stops lying.

## Steps

| Step | Ships | Consumes | Turns |
|---|---|---|---|
| **0** prep | goal doc + temperance + luminary + pre-mortem markers | session-start | 3-5 |
| **1** brief UC + /decompose | UC-hook-docker-smoke-drive-shape.md + decomposition | Step 0 | 5-10 |
| **2** /pre-mortem light — 3 lenses × 5-8 risks | risk ledger | Step 1 | 8-12 |
| **3** /rfc adversarial — 4 outside lenses | RFC council doc | Step 2 | 10-15 |
| **4** Beck RED — new Tier 0 tests | tests fail against unfixed sources | Step 3 | 15-25 |
| **5** Fix 3 drives + smoke-assert additions | 3 scripts + 1 lib rewritten | Step 4 | 20-30 |
| **6** Beck GREEN — full suite passes | 483+/483+ tests GREEN | Step 5 | 5-10 |
| **7** /architect-review — 4-lens inline | review report + install-class audit | Step 6 | 10-15 |
| **8** /loop lead-lens sign-off | marker at state/markers/lead-lens-signoff/ | Step 7 | 2-3 |
| **9** Open PR + merge --admin on green | PR body with full ceremony evidence | Step 8 | 5-10 |
| **10** Post-merge cold smoke on v1.7.0 npm | real red or real green | Step 9 | 5-10 |
| **11** /kiss + /feynman findings report + upstream /promote | operator-morning report + tickets | Step 10 | 10-15 |

**Total:** 98-160 turns. Grounded on cli #212 full ceremony subset ~150 turns.

## Compounding value — recommended only

- **Deliverable:** 3 drive scripts rewritten; 5 V1 skills gain positive-artifact assertions; new generic `check_no_unknown_command` in lib; Docker smoke stops lying
- **Problem:** false-green smoke masks skill dispatch failures. Every green run since goal 2026-09-20d is suspect
- **Value prop:** every future release cascade tests what adopters actually see
- **Turns:** 98-160 (grounded)
- **Risk:** 🟢 low — test-infrastructure defect, no adopter impact, fix-forward CI clears any regression, rework under 15 min
- **Shipping priority:** P1 — blocks trust in every future adopter smoke signal

## Ceremony chain

Per `.claude/rules/oo-ad-entry-point.md` matrix — existing script extension = **brief UC + /decompose entry-point check**. Substrate/Tier 0 code adds `/architect-review` + `/rfc adversarial` per authoring luminary map.

1. Feathers characterization — read all 3 drives + lib fully (done Step 0)
2. Brief UC — `docs/use-cases/UC-hook-docker-smoke-drive-shape.md`
3. `/decompose` — GRASP + cross-cutting + Strategy pattern for per-skill assertions
4. `/pre-mortem light` — feathers + beck + cooper × 5-8 risks each; fold top 3
5. `/rfc adversarial` — hyrum + linus + saltzer-schroeder + norman challenge the cure
6. `/temperance` — scope + drift trigger stated
7. `/luminary` — feathers marker + supporting lenses cited
8. Beck TDD RED — write positive-artifact + `check_no_unknown_command` tests first
9. Fix 3 drives + smoke-assert.sh extensions
10. Beck TDD GREEN — full suite passes
11. `/architect-review` — 4-lens (feathers + saltzer-schroeder + linus + norman)
12. `/loop` lead-lens sign-off marker (feathers)
13. Open PR + park at merge

## Refs

Closes bassclef-cli#217.
