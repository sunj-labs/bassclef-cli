---
tier: lite
---

# Pre-mortem — session AA, option c (smoke, pin, audit log, trust verb)

Three lenses, light mode. Premise: it is a month on and this session's
four steps have embarrassed us. What happened?

Scope: `docs/next-session-plan-2026-11-08-after-1923.md` steps 1-4.
Tickets: `cli#482`, `cli#489`, `cli#488`.

## Michael Feathers — characterization (lead)

1. **The smoke passes and proves nothing.** The Docker harness runs in
   `TEST_MODE` or `DRY_RUN` and skips the npm install entirely
   (`harness/docker/entry.sh:258,263`). We read a green exit and claim
   1.9.23 was verified. Cure: assert the install actually ran — grep the
   captured output for the resolved version string, not just the exit code.
2. **The instruction-budget number gets read off the wrong profile.** Any
   contamination from a mounted host directory makes the byte count ours,
   not an adopter's. Cure: capture the file list the warning counts and
   confirm each path lives under the container's own home.
3. **The pin fix gets a test that reads the pin we just wrote.** The test
   asserts the bundler reads `.bassclef-pin` by writing the pin and reading
   it back — same path twice, which is the exact shape of the six defects
   the plan doc names. Cure: the test must pin a value that differs from
   the repo's current checkout, so a bundler ignoring the file fails.
4. **The fix for `cli#482` is never shown RED.** We write the fix, write the
   test, both pass, and never confirm the test fails on the old bundler.
   Cure: stash the fix, run the test, record the failure, restore. Per
   `up#2428`, filed on exactly this.
5. **The audit-log check counts entries without pairing them.** A check that
   counts `on` and `off` lines and compares totals passes on a log with two
   `on` and two `off` in the wrong order. Cure: walk the log in order and
   assert state transitions, not counts.
6. **The trust re-arm is tested by calling the re-arm directly.** Sixteen
   green tests over a function no publish path invokes — the `cli#484` shape
   from two days ago. Cure: one test asserts the caller relationship.

## Saltzer & Schroeder — complete mediation

1. **The re-arm depends on the publish job finishing.** A failed or cancelled
   publish leaves the gate open with nobody watching. Cure: the marker carries
   a deadline and a session-start check fires on it, independent of the
   publish outcome.
2. **The untracked audit log becomes unreadable to review.** Moving the record
   of truth off git means a reviewer cannot see it. Cure: tracked mirror for
   review, untracked file as the record, and a check that flags divergence.
3. **The deadline check is advisory and never seen.** A session-start warning
   printed to stderr among 88 hooks is not mediation. Cure: it blocks, or it
   writes to the same banner path `last-block` can replay.
4. **`trust` clears the gate for more than one publish.** One authorization,
   one publish. Cure: the marker is consumed on use, not on expiry.
5. **The pin move lands without reading the 39 commits.** A framework change
   reaches every adopter with no human having read it. Cure: the pin PR body
   lists what the 39 commits contain, by category.

## Linus Torvalds — adopter contract

1. **The pin move breaks a cold install.** 39 commits of framework change ship
   at once and the first adopter to run `bassclef init` hits a hook that needs
   something the cli does not provide. Cure: the Docker smoke runs against the
   new pin before the release, not after.
2. **Hook count swings and nobody notices which way.** 31 to 46 is a change in
   what every adopter loads. Cure: the PR body states the before and after
   count and names the added hooks.
3. **The instruction-budget warning gets worse, not better.** Moving the pin
   forward 39 commits probably adds rule files, and the budget is already at
   3.88x the limit (`up#2238`). Cure: measure the budget on the new pin before
   shipping it, and say the number out loud in the PR.
4. **The audit-log relocation breaks the publish gate for the next session.**
   A path change the gate script reads but `SKILL.md` still documents the old
   way. Cure: both move in the same PR.
5. **`trust` changes shape and the operator's phrasing stops working.** The
   operator says "trust" and gets a refusal because the verb now needs an
   argument. Cure: the bare verb keeps working; anything new is additive.

## Folded into the plan before edits begin

- Step 1 runs in Docker, not `nuke-and-fresh-install.sh` on this profile
  (Feathers 2 + the `~/.claude` move at `scripts/nuke-and-fresh-install.sh:339`).
- Step 1 asserts the install ran, by version string, not by exit code
  (Feathers 1).
- Every fix in steps 2-4 is shown RED on the old code before it ships
  (Feathers 4, per `up#2428`).
- Step 2's PR body lists the 39 commits by category and states the hook
  count before and after (Saltzer 5, Linus 2).
- Step 2 re-measures the instruction budget on the new pin (Linus 3).
- Step 4's re-arm marker carries a deadline and is consumed on use
  (Saltzer 1, Saltzer 4).
