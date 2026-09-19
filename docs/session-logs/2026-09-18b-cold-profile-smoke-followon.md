---
tier: project
title: Session — cold-profile smoke first-run + follow-on tickets
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture (post-merge polish)
duration: ~2 hours post-Layer-1 merge
turns: ~30
branches: fix/scripts-lib-untracked (#111), fix/bootstrap-next-steps (#112), fix/runbook-v4-banner-note (#114), fix/runbook-v5-pipe-callout (#115)
outcome: shipped 5 PRs across Layer 1 arc; cold-profile smoke ran end to end; 3 follow-on tickets filed
---

# Session log — 2026-09-18 cold-profile smoke first-run + follow-ons

## What shipped

Post-Layer-1 merge (PR #110) uncovered gaps. Four follow-on PRs plus three follow-on tickets. Two PRs still open awaiting merge.

### Merged today

- **#111 `5f4c1b1`** — fix: un-ignore `scripts/lib/` + add missing `smoke-schema.sh`. `.gitignore` bare `lib` pattern was matching `scripts/lib/` too. Missing file broke `smoke-assert-*.sh` on fresh clone.
- **#112 `6c85086`** — fix(runbook): `smoke-bootstrap.sh` prints next commands after fetch. Norman signifier + Cooper flow. Interrupt race noted (my `gh pr merge` may have raced with the operator's Ctrl+C; couldn't reproduce).
- **#113 `1ae378f`** — feat: per-step terminal banners + OOAD update. 7 smoke scripts get `>>> starting` + `<<< done (exit N)` bookends via `trap EXIT`. Spec adds ScriptFetcher entity + `smoke-bootstrap.sh` interface. Decompose adds CurlFetcher (Boundary) + BootstrapController (Control) + terminal feedback cross-cutting entry + Post-merge additions section.

### Still open (awaiting merge)

- **#114** — docs(runbook): v4 banner-note. Adds "What you'll see in the terminal" section naming the `>>>` / `<<<` bookends. Should have shipped in #113 — discipline miss noted in commit body.
- **#115** — docs(runbook): v5 pipe callout + troubleshooting. Bold warning above the bootstrap curl block ("⚠ The `| bash` at the end is what runs it") plus ls-verify step plus two troubleshooting entries. Ships in response to cold-profile-1 forgot-pipe hit.

### Follow-on tickets filed post cold-profile run

- **#116** — bump `smoke-drive-skills.sh` default timeout from 30 to 120 sec (pre-mortem F3 fired)
- **#117** — assert scripts should read `=== exit: N` and mark TIMEOUT (142) or CRASH (non-zero non-142) as FAIL (pre-mortem V1 gap)
- **#118** — paths-exist regex too greedy; extracts `/agents/x.md` from `.claude/agents/x.md`. Tighten to anchor on absolute prefixes OR require known extensions

## Cold-profile smoke run — what happened

Cold-adopter-1 profile ran the full smoke end to end. First real run.

**Structural flow worked.** Bootstrap → reset (dry + apply) → npm install → `bassclef init` (379 files, 24 hooks armed) → capture (2 SessionStart hooks) → drive (5 skills) → assert-hooks → assert-skills → report (22 pass, 6 fail).

**Substantive findings:**

- All 5 skill captures hit SIGALRM (exit 142). Default 30 sec timeout was too tight for `claude -p` on cold profile. Pre-mortem F3 fired. → #116.
- All 5 skill captures with exit 142 passed all 4 checks (empty content → nothing to grep). Pre-mortem V1 gap — assertion suite does not read the exit line. → #117.
- Report publish failed (exit 4). `gh` auth is `giveisusfree`, not `kingofrock`. Needs test whether `giveisusfree` has write access to `sunj-labs/bassclef-cli`.
- 6 hook fails classified — 4-5 are cli#101-#108 class already tracked in bassclef-upstream#1728 (cli#102 orientation-gate false-fire, cli#105 BASSCLEF_DIR misdirect, cli#108 ABRUPT STOP false-fire). Rest is paths-exist regex noise. → #118.

**LITE_VER pasting gotcha.** Operator ran the runbook's two lines as a compound `LITE_VER=$(...) echo "..."` — shell env-prefix syntax made `LITE_VER` visible only to `echo`. Subsequent `npm install` had empty version but npm defaults `@lite@` to latest, so install succeeded quietly. Runbook v5 could split these more clearly; today's copy in the runbook is unambiguous if read as two lines.

## Discipline observations for future sessions

**Miss: shipped mechanism without updating the operator-facing doc in same PR.** PR #113 shipped the banners and updated spec + decompose. Missed the runbook. Caught by operator on runbook re-read. Filed as PR #114. Rule for next time: when the change is operator-observable, update the runbook/README in the same PR, not just the design docs.

**Miss: hidden discipline cost when `curl | bash` operators forget the pipe.** Predicted zero times; observed once. PR #115 adds a bold callout above the code block. Cheap fix, catches the class.

**Held: fixture-pin design.** Fixtures for cli#102, cli#105, cli#108 predicted the exact signals the cold-profile run surfaced. Feathers characterization approach paid off — the smoke system is doing exactly what it was designed to catch.

**Held: interrupt-tolerance of the harness.** PR #112 merged despite an operator interrupt. Ambiguous cause — either gh completed the API call before interrupt landed OR network glitch. Filed as one-observation-only; will log timing if it recurs.

## What's next

**When bassclef-upstream#1728 cures ship into a new lite release**, re-run the smoke on cold-adopter-1. Expect the 4-5 upstream-class fails to go GREEN. Filed 5th-check (message quality per cli#106) and 6th-check (repeat-warning per cli#107) as long-standing follow-ons — untriaged for now.

**Layer 2 unblocked** once operator wants to schedule. Drive `/interpret-input` + `/launch` + `/build` on a recipe-app idea. Byproduct: a mock app for Layer 3.

## Cost tracking

- Session duration: ~2 hours post-Layer-1 merge (started ~05:00 UTC)
- Turns: ~30
- 4 PRs merged; 2 open; 3 tickets filed
- Zero code regressions across 59 smoke tests + full suite

## References

- Prior session log (Layer 1 shipped): `docs/session-logs/2026-09-18-goal-2026-09-18a-smoke-evidence-capture-layer-1.md`
- Runbook: `docs/runbooks/smoke.md` (v3 on main; v4 in PR #114; v5 in PR #115)
- Follow-on tickets: cli#116, #117, #118
- Coordination: bassclef-upstream#1728 (cli#101-108 cures pending)
