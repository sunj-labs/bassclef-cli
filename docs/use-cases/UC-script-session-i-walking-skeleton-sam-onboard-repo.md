---
id: UC-script-session-i-walking-skeleton-sam-onboard-repo
type: brief
status: active
primary-actor: Sam (cold-adopter persona)
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - alan-cooper
    - kent-beck
    - michael-feathers
---

# UC — Walking skeleton for Tier A dynamic driver suite (Sam × /onboard-repo)

## Scope

Session I PR 1 per docs/plans/tier-a-dynamic-driver-roadmap.md. Thinnest end-to-end slice that proves the persona-assertion pattern Tier A chain drivers will share. One persona slice (Sam, cold install), one skill (/onboard-repo), 3 Cooper goal levels asserted via `scripts/lib/persona-assert.sh`.

## Primary actor

Sam — cold-adopter persona per docs/plans/tier-a-dynamic-driver-roadmap.md. Fresh `npm install -g @thebassclef/lite`. No bassclef vocab. Follows README CTA.

## Preconditions

- `scripts/lib/persona-assert.sh` exists.
- 3 fixture captures land at `scripts/tests/fixtures/sam-onboard-repo/`.

## Main scenario

1. Runner invokes `bash scripts/tests/smoke-drive-e2e-onboard-repo-sam.test.sh`.
2. Test sources `scripts/lib/persona-assert.sh`.
3. T01 — golden fixture passes all 3 Cooper goal levels (end + experience + life).
4. T02 — bad-jargon fixture passes end + life; FAILS experience (dancing-bear catch — chain works but jargon lands on Sam's screen).
5. T03 — bad-chain-failure fixture FAILS end goal (exit=3).
6. Test emits `session-i-sam | 3/3 cases passed`. Exits 0.

## Extensions

**4a — assertion lib missing.** `scripts/lib/persona-assert.sh` absent.
Test emits SKIP with code 77.

**4b — any case fails.** Test prints FAIL message to stderr. Exits 1. CI blocks merge.

## Postconditions

- 3/3 cases pass against committed fixtures.
- Pattern available for next 5 Tier A chain drivers to compose with.
- `scripts/lib/persona-assert.sh` is the shared contract: `persona_assert_end_goal`, `persona_assert_experience_goal`, `persona_assert_life_goal`.

## Related

- cli#375 — tracking issue for the full Tier A roadmap
- docs/plans/tier-a-dynamic-driver-roadmap.md — the durable plan
- scripts/smoke-drive-onboard-repo.sh — the live-claude driver this walking skeleton rides (docker-smoke V2 Step 6)
- scripts/tests/smoke-drive-e2e-onboard-repo-cascade.test.sh — sibling e2e test (Kunal #9 403 fallback)
- @luminary alistair-cockburn — walking skeleton
- @luminary alan-cooper — 3-level goals (end + experience + life)

## Why walking skeleton

Cockburn: "Build the walking skeleton first — the thinnest possible end-to-end slice that exercises every architectural layer, every deploy step, every test layer, before adding any feature." Session I PR 1 does exactly that for the persona-assertion pattern. Later PRs (/whereami, /sprint, /riff, /launch, /build) ride this lib unchanged, adding only their own fixture + persona slice.
