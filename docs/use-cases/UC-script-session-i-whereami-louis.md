---
id: UC-script-session-i-whereami-louis
type: brief
status: active
primary-actor: Louis (context-switcher persona)
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - alan-cooper
    - kent-beck
    - michael-feathers
---

# UC — Louis × /whereami Tier A chain driver (Session I PR 2)

## Scope

Second Tier A chain driver per docs/plans/tier-a-dynamic-driver-roadmap.md. Rides scripts/lib/persona-assert.sh from PR #376. Pattern scale check — walking skeleton proves the shape; this PR proves the shape scales.

## Primary actor

Louis — context-switcher persona. Has bassclef installed. Picks up a project after days away. Runs /whereami first to orient. Needs scannable one-screen state.

## Preconditions

- scripts/lib/persona-assert.sh exists (shipped PR #376).
- 3 fixture captures at scripts/tests/fixtures/louis-whereami/.

## Main scenario

1. Runner invokes bash scripts/tests/smoke-drive-e2e-whereami-louis.test.sh.
2. Test sources the shared persona-assert lib.
3. T01 — golden fixture passes end + experience + life (Louis gets oriented in <40 lines of clean prose).
4. T02 — bad-jargon fails ONLY experience (dancing bear — Louis gets the info but bounces on jargon).
5. T03 — bad-wall fails ONLY life (dancing bear — chain works, no jargon, but Louis cannot scan).
6. Test emits session-i-louis | 3/3 cases passed. Exits 0.

## Extensions

4a — assertion lib missing. Test emits SKIP with code 77.
4b — any case fails. Test prints FAIL to stderr. Exits 1.

## Postconditions

- 3/3 cases pass against committed fixtures.
- Pattern scale confirmed — no changes to shared lib; only new fixtures + test + UC.

## Related

- cli#375 — tracker
- docs/plans/tier-a-dynamic-driver-roadmap.md
- PR #376 — walking skeleton this driver rides
- scripts/lib/persona-assert.sh — shared contract
