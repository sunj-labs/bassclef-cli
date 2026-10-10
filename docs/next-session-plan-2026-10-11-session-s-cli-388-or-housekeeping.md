---
tier: lite
id: next-session-plan-2026-10-11-session-s
status: proposed
started: 2026-10-11
parent_inventory: docs/plans/tier-a-driver-inventory-state.md
parent_chronicle: docs/chronicle/2026-10-10-session-r-cli-373-filed-upstream-2177.md
goal: Pick between cli#388 Tier A architect-review, housekeeping, OR waiting on upstream cascade
---

# Session S plan — exploratory

Session R shipped cli#373 + filed upstream#2177. Session Q + P + O closed clean. The queue carries one bigger cli ticket + two cascade blockers + three housekeeping items.

## Recommended session sequence

Three Q1 options plus one hygiene cluster. Operator picks shape at prep.

**Step 1 — cli#388 Tier A architect-review on full harness.** Review all 6 Tier A flow drivers + regression suite as a system. Big ticket per Session Q chronicle L102 (60-80 turns, 🟡 med). Covers 7+ files, cross-stack system view. First-pass likely surfaces 3-5 findings tickets.

**Step 2 — Housekeeping cluster.** Three small items that compound at closeout:
- Clean 10 stray session-N marker files under `state/markers/` (untracked since 2026-10-07)
- Fix `whereami.md` `last_updated:` schema shape (one-line format correction per `standards/whereami-schema.md`)
- File `fix` ticket on bassclef-upstream for missing `pre-push-pre-ship.sh` hook (DEGRADED signal persists across sessions)

~30-50 turns total. Pure hygiene, no architectural shift.

**Step 3 — Wait on upstream cascade (no cli work tonight).** upstream#2177 (cli#329 routing) + upstream#2175 (cli#328 umbrella) both wait on peer pickup + /release. When peer ships, cli pulls via sync. No cli session needed if operator wants a quiet pause.

## Scope choice at prep

Session S prep picks between three shapes:

- **Shape a — depth (Step 1 alone):** cli#388 architect-review. ~60-80 turns. Produces review doc + 3-5 follow-on tickets.
- **Shape b (recommend) — hygiene (Step 2 alone):** Housekeeping cluster. ~30-50 turns. Three small cures land clean, close three nagging signals.
- **Shape c — depth-plus-hygiene (Step 1 + Step 2):** ~100-130 turns. Only if operator has wider time budget.

Default recommend: **Shape b — hygiene cluster**. Three small cures compound across every future session. architect-review runs best after a quiet main (fewer in-flight changes). Shape a stays available when cli surface stops moving.

Pick **a** when operator wants to push cli architecture visibility forward tonight. Pick **c** only with wider time budget.

## Entry state (reads at prep)

**Must read at Session S prep:**
- `docs/whereami.md` — Session R closeout state + PRIMARY queue
- `docs/chronicle/2026-10-10-session-r-cli-373-filed-upstream-2177.md` — Session R narrative
- For Shape a: `docs/architecture/reviews/2026-10-10-session-p-cli-415-cross-repo-validator.md` (last architect-review for reference pattern)

**Open tickets at Session S start:**
- cli#388 — Session L architect-review on full Tier A harness (Shape a target)
- cli#329 — adr-discipline-check wiring (waits on upstream#2177 cascade)
- cli#417 + cli#418 — follow-ons from cli#415 architect-review (both wait on upstream)
- cli#199 — Epic parent (stays open)

**Blocked on upstream cascade:**
- upstream#2177 (filed Session R) — adr-discipline-check tier flip or rule reword; peer picks
- upstream#2175 — cli#328 10-fix umbrella; peer runs batches A-D
- upstream#2173 — architect-review substrate-cli sibling filing

## Pre-flight checks (per /longrun Step 0.75 shipped-state check)

Before confirming scope, Session S prep grep-tests each recommended path:

```bash
# Step 1 cli#388 — has an architect-review doc landed since Session Q?
ls docs/architecture/reviews/ | grep -i 'tier-a\|full-harness' | head -3

# Step 2 housekeeping — stray session-N markers still present?
ls state/markers/temperance/session-n* state/markers/pre-mortem/session-n* 2>/dev/null | wc -l

# Step 2 whereami schema — last_updated field format status?
grep -n '^last_updated:' docs/whereami.md
```

## Compounding axis — Shape b (recommended)

- **Deliverable** — 10 stray marker files cleaned (git rm or document); whereami `last_updated:` field matches schema shape; upstream `fix` ticket filed for missing `pre-push-pre-ship.sh` hook.
- **Problem** — Cumulative hygiene debt across the last 4 sessions. Marker files pollute `git status` output. Whereami schema warning fires at every session start. Missing hook silently reduces pre-push safety. All three fire at every session; none block work tonight; all compound.
- **Value prop** — Session start reads clean. Three nagging signals go dark. Future sessions start without the DEGRADED banner.
- **Turns** — 30-50. Each item independently small (~10-15t); no new coupling.
- **Risk** — 🟢 low. All three are reversible via git revert. Rework < 15 min per item.
- **Shipping priority** — P3. Compounding payoff but no acute pain today.

## Luminary pick

- **Primary** — @luminary john-ousterhout. Deep module hygiene; the marker cleanup pattern reduces session-start cognitive load.
- **Supporting** — @luminary linus-torvalds (adopter contract — DEGRADED signal visible to adopters at every session; muting it preserves the contract).

## Session S closeout contract

- All 10 session-N markers resolved (removed OR documented in a chronicle note)
- `whereami.md` `last_updated:` schema warning gone from SessionStart
- upstream `fix` ticket filed for `pre-push-pre-ship.sh` (link in chronicle)
- Chronicle + whereami flipped
- No new regression tests (hygiene session)

## Deferred to Session T

- cli#388 Tier A architect-review (Shape a candidate)
- cli#328 batch cures as upstream#2175 batches ship
- cli#417 + cli#418 follow-ons as upstream release cascades
