# Next session plan — cli#294 driver authoring (after bundle sync)

## What triggers this plan

A bassclef release lands that includes PRs #2041 + #2042 + #2043 + #2044 + #2045. Peer `bassclef-upstream-b3` was running `/release` Step 1 dry-run at session close 2026-10-03a. Watch for a cross-session message from the peer naming the release tag.

Blocker before this plan fires: cli#290 (bassclef v1.6.5 tag ships v1.6.4 content). If the peer's release reuses that tag OR fires a fresh tag that bypasses the defect, this plan fires. If the defect blocks the release, resolve cli#290 first.

## ## Recommended session sequence

### Step 1 — cli bundle sync (cli#295)

- **Deliverable**: PR that updates `dist/lite/` to the cured bassclef release. Published as cli v1.9.9 (or whatever next bump).
- **Produces**: cured substrate on cli main; cli#295 closed; all 4 parts of PR #2041 cure present in `dist/lite/` (verify via grep for `/Users/<name>` sanitization in trace-helper, `docs/sdlc-traces/` in shipped gitignore, `lib/identifier-leak-check.sh` present, save-state call to the lib).
- **Consumes**: bassclef release artifact (new tag + new npm package)
- **Turns**: 30-60 (grounded against v1.9.4 cascade in goal 2026-09-26c at ~50 turns + v1.9.8 cascade at ~40 turns)
- **Risk**: 🟡 med — publish workflow needs Touch ID at npm-publish env gate; one CI cycle for prepublish parity
- **Ceremony**: temperance (scope: pin to new bassclef tag) + luminary Linus lead (adopter contract) + ADR-honored (no new ADR; follows ADR-002/003/004/005)

### Step 2 — driver 1 (trace-log-privacy)

- **Deliverable**: `scripts/tests/smoke-drive-adopter-trace-log-privacy.test.sh` + registry entry + Tier 0 test + PR
- **Produces**: adopter-regression anchor for Kunal findings #1 + #5; cli#294 progress 1/5
- **Consumes**: Step 1 cured substrate + existing `fake_claude.sh` + `smoke-expect.sh` + risk ledger at `docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md` + brief UC at `docs/use-cases/UC-script-cli-294-driver-1-trace-log-privacy.md`
- **Turns**: 20-30 (narrow driver + fixture reuse)
- **Risk**: 🟡 med — fixture may need stub of a leak path to prove RED-first
- **Ceremony**: temperance + luminary Feathers lead (per ledger) + /loop RED→GREEN cycle; PR body cites pre-cure SHA for characterization

### Step 3-6 — drivers 2 through 5 (stacked PRs)

Same shape as Step 2, one driver per PR. 20-30 turns each. Order:

- **Step 3** driver 5 (`smoke-drive-onboard-free-tier-403.test.sh`) — findings #9; needs mock `gh api`
- **Step 4** driver 2 (`smoke-drive-build-against-template.test.sh`) — findings #2 + #3; needs template fixture + heading-grace coverage
- **Step 5** driver 3 (`smoke-drive-state-under-zsh.test.sh`) — finding #6 class closure across 10 lib/*.sh files per PR #2045 widening
- **Step 6** driver 4 (`smoke-drive-env-reach-override.test.sh`) — finding #4; checks for `lib/skip-env-inline-check.sh` dependency

### Step 7 — closeout

- **Deliverable**: all 5 drivers merged; cli#294 closed; closeout session log
- **Produces**: 5 regression anchors + session log + whereami flip + retro
- **Consumes**: union of Steps 1-6
- **Turns**: 10-15

**Total**: 130-200 turns (grounded above). Fits a single `/longrun` with converged preset if run contiguously; splits across 2 sessions if operator prefers.

## Reading order at next session start

1. `docs/whereami.md` — read current state
2. This file — read the plan
3. `docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md` — risk ledger with 10 folds already landed
4. `docs/use-cases/UC-script-cli-294-driver-1-trace-log-privacy.md` — brief UC for driver 1
5. `docs/session-logs/2026-10-03a-cli-294-ceremony-prep-plus-bundle-sync-blocker.md` — what happened this session
6. cli#295 body — bundle sync prereq spec

## Signals that unblock this plan

- Peer cross-session message naming the release tag
- `bassclef-version.json` in cli main shows v1.6.6+ (or whatever release tag ships the 5 cure PRs)
- `dist/lite/.claude/hooks/trace-helper.sh` has sanitization code (grep for sanitize function)

Any of the 3 confirms the unblock. Any absent at session start → bundle sync still owed; this plan waits.

## Release-notes shape (per peer `bassclef-upstream-b3` message 2026-10-03b)

When cli#295 fires and the next cli release-notes.md gets generated against the bundled bassclef release, use per-finding RCA structure (symptom → root cause → fix → verification). Not flat change-logs. Inherits the shape bassclef is shipping Kunal's #2036 release under. Spirit filed at bassclef-upstream#2039.

Operator may also file an analogous ticket on bassclef-web for docs-gen shape alignment.

## Related tickets

- cli#294 — parent (5 adopter-regression smoke drivers)
- cli#295 — bundle sync prereq (blocks cli#294)
- cli#290 — bassclef v1.6.5 tag defect (may block bundle sync)
- cli#284 — /whereami auto-update signal misreads user-scope substrate inheritance (independent; not in this plan)
- cli#291 — statusline dispatcher hardcodes rich-impl filename (independent; not in this plan)

## Luminary map (preserved from ceremony prep)

- **Lead**: `michael-feathers` — characterization tests (RED on pre-cure SHA; GREEN on cured main)
- **Supporting**: `linus-torvalds` (adopter contract) + `alan-cooper` (goal-directed per driver)
