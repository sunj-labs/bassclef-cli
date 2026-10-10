---
tier: lite
id: next-session-plan-2026-10-09-session-o
status: proposed
started: 2026-10-09
parent_inventory: docs/plans/tier-a-driver-inventory-state.md
goal: Attack the top-3 Q1 gaps on the 6 Tier A CTA skills + close the taxonomy cleanup
---

# Session O plan — attack the Q1 gaps on Tier A CTA skills

## Recommended session sequence

Three Q1 items from the freshly scored queue in `docs/plans/tier-a-driver-inventory-state.md` §"Next-session Q1 candidates (freshly scored 2026-10-09)". Plus one hygiene follow-on from Session N — the taxonomy rename (cli#407).

**Step 1 — cli#406 bassclef init 5-min value test (Sam-B feat).** Peer handoff from bassclef-upstream-d5 (2026-10-09). Peer-estimated ~20-line rewrite of the final output block in `src/commands/init.ts` per the Sam-verbatim shape in the ticket body. Catalog counts move behind `--verbose`. Highest Sam first-touch impact. Beck RED-first + ship in one PR. Target: ~30-50 turns.

**Step 2 — cli#328 + /build happy path pair.** cli#328 names 14 gaps in /build Phases 4-7 from a supervised run. /build currently has refusal-path capture only; the happy path needs a scratch-dir fixture with fake plan + git init. Pair cure. Big ticket (~100-200 turns per inventory). Session O may need to split this into substeps.

**Step 3 — cli#407 taxonomy rename.** Rename the three test families to plain names per operator catch during Session N. Move 3 mislabeled `smoke-drive-flow-*.sh` files into the regression family. Fold ADR-011 D3 clarification. Target: ~30-40 turns.

**Step 4 — cli#318 /personas and /jtbd-tasks path conflict** (if time budget permits). Clears a persona-chain blocker. 20-30 turns per inventory.

**Step 5 — cli#411 bassclef init writes bassclef-version.json.** Cures the statusline-shows-wrong-version class seen in the 2026-10-09 smoke run on cold-adopter-1 where v1.8.0 showed despite cli v1.9.12 install. Sibling cache cleanup via `--purge-adopter` (PR #410) is the short-term mitigation; init writing the file is the root-cause cure. ~40-60 turns. Includes Tier 0 test + manifest schema entry.

## Scope choice at prep

Session O prep picks between three shapes:

- **Shape a — focused depth (Step 1 + Step 3):** Sam-B feat + taxonomy rename. ~70-90 turns. Clean, closes two tickets.
- **Shape b — happy path push (Step 1 + Step 2):** Sam-B feat + /build happy path. ~130-250 turns. Unblocks the biggest Tier A gap.
- **Shape c — full queue (Step 1 + Step 2 + Step 3 + Step 4):** everything above. ~180-320 turns. Only pick if operator has a wide time budget AND accepts the compounding risk.
- **Shape d — Sam-touch pair (Step 1 + Step 5):** Sam-B feat + bassclef-version.json cure. ~70-120 turns. Both items polish the Sam first-5-min surface — final output copy + statusline shows the right version. High coherent payoff.

Default recommend: **Shape a** OR **Shape d**. Shape a closes a nagging hygiene miss from Session N. Shape d doubles down on Sam first-touch surface (Session N smoke proved its weight). Pick b if operator wants to push /build forward instead.

## Entry state (reads at prep)

**Must read at Session O prep:**
- `docs/plans/tier-a-driver-inventory-state.md` — the authoritative state + layer map
- `docs/whereami.md` live block — Session N closeout + NEXT-SESSION pointers
- `docs/adrs/ADR-011-cli-side-cure-anchor-drivers-and-flow-layer.md` — amendment 2026-10-09 captures the taxonomy
- `docs/chronicle/2026-10-08-session-n-cli-side-scope.md` — Session N narrative

**Open tickets at Session O start:**
- cli#406 — bassclef init 5-min value test (Q1 — Step 1 target)
- cli#407 — taxonomy cleanup (Q1 — Step 3 target)
- cli#328 — /build Phases 4-7 gaps (Q2 — Step 2 target)
- cli#318 — /personas + /jtbd-tasks path conflict (Q2 — Step 4 target)
- cli#388 — architect-review on full Tier A harness (Q2 — defer unless Shape c)
- bassclef-upstream#2154 — sister fallback shape fix (Q3 — upstream owns)

## Pre-flight checks (per /longrun Step 0.75 shipped-state check)

Before confirming scope, Session O prep grep-tests each recommended path:

```bash
# Step 1 cli#406 — has anything shipped?
git log --all --oneline -1 -- src/commands/init.ts
gh issue view 406 --json state,comments --jq '.state'

# Step 2 cli#328 — any PR against /build Phases 4-7 since 2026-10-07?
git log --all --oneline --since='2026-10-07' -- "dist/lite/.claude/skills/build/**" || true

# Step 3 cli#407 — any rename PR already open?
gh pr list --state open --search "407 in:title" --json number

# Step 4 cli#318 — any shift on /personas or /jtbd-tasks since Session L?
git log --all --oneline --since='2026-10-08' -- "dist/lite/.claude/skills/personas/**" "dist/lite/.claude/skills/jtbd-tasks/**" || true
```

## Compounding axis — Shape a (recommended)

- **Deliverable** — Sam-B first-touch feat ships. Catalog counts move behind `--verbose`. Final output block reads human-first. Taxonomy renamed per operator's agreed plain names. One hygiene miss cured.
- **Problem** — Sam opens cli for the first time, sees a wall of catalog counts, no clear "value test" signal. Operator-facing prose at the init surface currently reads terse but not plain. Separately, the test-family vocabulary caught the operator mid-session on 2026-10-09 — jargon layered on jargon.
- **Value prop** — Sam reads one honest sentence confirming bassclef is live. Operator reads one plain name per test family going forward.
- **Turns** — 70-90 (Step 1: 30-50; Step 3: 30-40). Grounded against prior Sam-touch work (PR #382 ~45 turns; PR #396 ~80 turns).
- **Risk** — 🟡 medium. Rewriting the final output block risks regressing operator-visible banner. The 6 Tier A flow drivers pin the surface; aggregate 20/20 GREEN before + after. Rework < 2h if a case flips.
- **Shipping priority** — P2.

## Luminary pick

- **Primary** — @luminary michael-feathers. Characterization at Sam's first-touch surface; Beck RED-first per bassclef-upstream-d5's suggestion.
- **Supporting** — @luminary alan-cooper (Cooper 3-level goals: end + experience + life; same lens the e2e-onboard-repo-sam driver already uses).

## Session O closeout contract

- All 6 Tier A flow drivers stay 20/20 GREEN
- cli#406 closes via Closes keyword in PR body
- cli#407 closes via rename PR
- Inventory doc updated with Session O outcome
- Chronicle + whereami flipped
- No new regression tests in Shape a path (hygiene session)

## Deferred to Session P

- cli#328 + /build happy path pair (Shape b candidate)
- cli#318 /personas + /jtbd-tasks path conflict
- cli#388 architect-review on full Tier A harness
- Depth-work on grep-only regression tests from Session N (/kiss scope SHOULD row)
