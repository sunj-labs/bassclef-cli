---
tier: upstream
trigger: inbound-message-from-peer-bassclef-upstream-51
---

# Trigger plan — upstream Slot 9 (cli#331 + cli#332) lands

## When this plan fires

An inbound message arrives from peer `bassclef-upstream-51` (or sibling upstream peer) stating:

- "Slot 9 shipped" or "Class G cures merged" or similar
- Names upstream PR(s) that cure `cli#331` (/autonomous procedure) + `cli#332` (/launch → /build → deploy chain)
- Confirms the public bassclef release page is live OR will land within a session's reach

Alternative triggers (same plan fires):

- Peer SendMessage names an upstream PR body containing `Closes bassclef-cli#331` and/or `Closes bassclef-cli#332`
- Direct observation during a cli `/sprint` that `bassclef-upstream` has merged commits containing those closing-keywords between the current cli bundle SHA and upstream main

## Scope — what cli does on trigger

### Step 1 — verify the cure landed

```bash
# Confirm upstream closing-keyword cross-refs
cd ~/src/sunj-labs/bassclef-upstream
git fetch origin main
git log --merges --since="2 weeks ago" origin/main \
  | grep -B2 -E '(Closes|Fixes|Resolves)[[:space:]]+bassclef-cli#(331|332)'
```

Expected: one or more merge commits each citing a cli close-keyword.

### Step 2 — read the cure patches

Read the merged upstream PR body + diff. Confirm:

- Does the cure change the `/autonomous` SKILL body to work on lite tier (procedure out of `strategy/`)?
- Does the cure ship a visible `/deploy-prod` behavior for lite (even if "no-deploy, say so clearly" refusal)?

Each answer is the characterization pivot. GREEN assertion for the driver depends on what the cure actually does.

### Step 3 — build the two drivers

**cli#331 — /autonomous driver.**

```bash
# scripts/tests/smoke-drive-adopter-331-autonomous-lite.test.sh
#
# Asserts: /autonomous skill body on lite does NOT reference strategy/*.
# After cure: skill body resolves without needing strategy/ sibling.

source scripts/tests/lib/lite-runtime-invariants.sh
assert_lite_runtime

output=$(bash dist/lite/.claude/skills/autonomous/SKILL.md.resolve 2>&1 || true)
if grep -q "strategy/" <<< "$output"; then
  echo "FAIL: /autonomous still references strategy/ (not shipped on lite)"
  exit 1
fi
echo "PASS: /autonomous resolves without strategy/ sibling"
```

**cli#332 — /launch → /build → deploy driver.**

```bash
# scripts/tests/smoke-drive-adopter-332-full-chain-deploy.test.sh
#
# Asserts: full chain /launch → /build → deploy either (a) deploys to a
# real target OR (b) refuses visibly with a clear "no-deploy-path" message.

source scripts/tests/lib/lite-runtime-invariants.sh
assert_lite_runtime

output=$(bash scripts/tests/fixtures/launch-build-deploy-chain/run.sh 2>&1)
# Accept either: successful deploy OR explicit refusal
if ! grep -qE "(deployed|no deploy path|cannot deploy)" <<< "$output"; then
  echo "FAIL: full chain silent on deploy outcome"
  exit 1
fi
echo "PASS: full chain either deploys or refuses visibly"
```

### Step 4 — bundle sync + release

Create a cli release branch that:

1. Bumps bassclef pin in `.github/workflows/publish.yml` L136 + L281 to the new upstream SHA/tag
2. Re-runs the bundle generator so `dist/lite/` picks up cured substrate
3. Verifies both drivers flip RED → GREEN against the new bundle
4. Bumps cli version via `npm run bump` (patch for cure-only release)

### Step 5 — close cli#331 + cli#332 with cross-ref

In the cli release PR body:

```
Closes bassclef-cli#331 — /autonomous procedure cured by upstream PR #<NNNN>
Closes bassclef-cli#332 — full-chain deploy path cured by upstream PR #<NNNN>
```

GitHub auto-closes both tickets when the release PR merges.

### Step 6 — (optional) exercise /release-close-sweep Path A

If `scripts/release-close-sweep.sh` has shipped from upstream#2068 by this point, invoke it on the release branch pre-merge to characterize the auto-close pattern against real data. This becomes the first-consumer proof.

## Related work this trigger closes

- **cli#331** — /autonomous lite procedure
- **cli#332** — full-chain deploy path
- All Class A sub-tickets anchored under #294 that correspond to Slot 9 scope (if any — Slot 9 primarily is Class G)
- **bassclef-upstream#2068 Path A proof** — first exercise point

## Time budget

**30-60 turns** total:

- Verify upstream cure (Step 1-2): 10 turns
- Build 2 drivers (Step 3): 20 turns
- Bundle sync + release (Step 4-5): 15 turns
- Verify + close (Step 5): 5-10 turns

Grounded on cli#305 bundle-sync pattern (similar shape, ~45 turns actual).

## Not scope on trigger

- Session F un-anchored drivers (separate plan at `docs/next-session-plan-2026-10-05-session-f-driver-build-out.md`)
- Full /release-close-sweep Path A build-out (upstream#2068; depends on operator capacity, not just trigger)
- Any OTHER Kunal-rerun cures that may have landed in the same upstream window (handle via normal bundle-sync discipline)

## Luminary map on trigger

- **Lead:** `michael-feathers` — characterization. Both drivers assert behavior cured; test shape depends on what upstream actually shipped
- **Supporting:** `linus-torvalds` — adopter contract. Both tickets have been open since 2026-10-03; closing them cleanly matters for backlog signal
- **Supporting:** `alistair-cockburn` — same walking-skeleton pattern as Session A-D drivers

## Session kickoff on trigger

Operator types:

```
/longrun prep
```

Operator says: "upstream Slot 9 landed; cure cli#331 + cli#332".

Preset picker reads BOTH:
- `docs/next-session-plan-2026-10-05-upstream-slot-9-landing-trigger.md` (this doc; fresh if trigger fires within 48h of filing)
- `docs/whereami.md` (next_in_flight_goal field, which this close updates)

Fires converged preset against this plan. Session ships both drivers + release in one pass.

## What NOT success looks like

- Building drivers against GUESSED cure shape. Read upstream PR diff FIRST.
- Shipping release without re-bundling. The dist/lite/ must contain cured substrate; stale bundle flips driver GREEN by coincidence.
- Closing tickets before release lands on npm. Adopters won't see the cure until release publishes.
