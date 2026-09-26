---
session_id: 2026-09-26e
tier: standard
started_at: 2026-09-26T17:25Z
ended_at: 2026-09-26T21:35Z
mode: overnight autonomous (agent-merges-within-scope)
turn_count: ~80
outcome: shipped
parent_session: 2026-09-26d
---

# 2026-09-26e — overnight cli#254 sub-step 1 shipped

## Flash

Overnight run after 2026-09-26d closeout. Real smoke-expect.sh bodies shipped as PR #256 (merged 2d33dbd). Sub-step 1 of the 6-sub-step cli#254 chain. 35/35 Tier 0 tests GREEN; sibling suite (registry + 3 drive stubs) preserves 42/0 GREEN.

## What shipped

### PR #256 — feat(cli-254): real smoke-expect.sh bodies (sub-step 1)

Squash-merged as `2d33dbd`.

**Ceremony commit (a4c3f55):**
- Temperance marker — scope: real bodies only; NOT drive cures / Docker / entry.sh wire
- Luminary marker — Ousterhout lead + Beck + Feathers supporting
- Pre-mortem light — 3 lenses (Ousterhout / Feathers / Saltzer-Schroeder) × 5-8 risks + 6 folds pre-code
- RFC adversarial — 3 outside lenses (Hoare / Fowler / Deming) + 3 folds pre-code
- ADR-deviation marker — outcome=ADR-honored (no ADR governs docker smoke path)
- UC amendment (`UC-script-254-interactive-skill-drives.md`) — sub-step 1 scope section

9 folds landed pre-code total.

**Code commit (db7c74e):**
- `scripts/lib/smoke-expect.sh` — 5 real bodies (drive_start / send / expect / capture / end) + 2 private helpers (_smoke_expect_tcl_escape / _smoke_expect_load_session). Version 0.1.0-skeleton → 1.0.0.
- `scripts/tests/fixtures/fake_claude.sh` — deterministic stand-in for interactive claude. Reads stdin line by line, emits "RESP: <line>" per input, exits on EOF. Supports env knobs for startup delay + latency + exit-on-phrase.
- `scripts/tests/smoke-expect.test.sh` — extended from 16 skeleton assertions to 35 real-behavior assertions.
- Lead-lens sign-off marker + Reviewer marker.

## Gate Evidence

| Gate | Marker | Notes |
|---|---|---|
| /temperance | `state/markers/temperance/feat-254-smoke-expect-real-body.marker` | Scope: real smoke-expect.sh bodies only |
| /luminary | `state/markers/luminary/feat-254-smoke-expect-real-body.marker` | Ousterhout lead |
| /pre-mortem | `state/markers/pre-mortem/feat-254-smoke-expect-real-body.marker` | 3 lenses × 5-8 risks + 6 folds |
| /rfc | `state/markers/rfc/feat-254-smoke-expect-real-body.marker` | 3 outside lenses + 3 folds |
| /adr-deviation | `state/markers/adr-deviation/feat-254-smoke-expect-real-body.marker` | ADR-honored |
| /lead-lens-signoff | `state/markers/lead-lens-signoff/feat-254-smoke-expect-real-body.marker` | Ousterhout confirmed GO |
| /reviewer | `state/markers/reviewer/feat-254-smoke-expect-real-body.marker` | 7 lenses used; 3 NOTEs; PASS |
| /verify | passed | 35/35 Tier 0 GREEN locally + PR #256 CI GREEN (test+typecheck 26s) |
| /loop discipline | iteration 1 | RED (25/35 fail against skeleton) → GREEN (35/35 pass); 2 mid-development bugs surfaced + cured |

## Discoveries

1. **Sourcing a library with `set -euo pipefail` propagates the flags to the caller.** The walking skeleton's smoke-expect.sh had `set -euo pipefail` at the top. Test file sourced it → parent shell inherited `set -e` → bare `drive_expect "pat"` return 42 killed the test runner. Cure: remove `set -euo pipefail` from library top; libraries shouldn't force flags on callers. Test file compensates with `set +e` post-source.

2. **`close` and `expect eof` conflict in the same script.** After `catch { close }`, the spawn_id is closed. Subsequent `expect eof` fails with "spawn id exp5 not open". Cure: use `close` + `catch { wait }` (no `expect eof`). expect(1) documentation implies eof after close is invalid.

3. **Bash 3.2 `${var//[/\\[}` pattern quirk.** In zsh, `[` in the pattern half is a bracket-expression start; escape with `\[`. In bash 3.2, `${var//[/\\[}` works as expected (literal `[`). Test with `bash script.sh` explicitly, not the harness's zsh wrapper.

## What worked

- **Beck TDD RED-first held.** Rewrote tests (35 assertions) against the skeleton → 25/35 FAIL confirmed RED. Landed bodies → 35/35 GREEN confirmed. Two mid-development bugs surfaced during the GREEN pass and were cured in-place.
- **Class (c) new-building-block ceremony absorbed 9 folds pre-code.** 6 from pre-mortem + 3 from RFC adversarial. Zero of those folds needed to be discovered post-code — the ceremony carried its weight.
- **Ousterhout deep-module lens paid off.** 5-verb interface stayed stable. Extension via env vars only. Callers never see Tcl.

## What didn't work

- **Initial commit `git add` staged files but the block hook reset the staging.** Actually the git commit blocked (jargon word in message) → my `git add ... && git commit` chain rolled back only the commit; staging should have persisted. Second `git status` showed unstaged. Cure: retry add. Lesson: hook blocks may look like they preserve state; verify.
- **Docker smoke didn't run for PR #256** (paths didn't include harness/docker). Sub-step 1 tests locally but real-claude integration deferred to sub-step 5. Documented as Deming D2 fold.

## Sub-step chain progress

| Sub-step | Status |
|---|---|
| 0. Walking skeleton | shipped 2026-09-26 (PR #255) |
| **1. Real smoke-expect bodies** | **shipped 2026-09-26 overnight (PR #256)** |
| 2. /onboard-repo drive body | next session |
| 3. /launch drive body | pending |
| 4. /riff drive body (advisory skip if cli#241 blocks) | pending |
| 5. Dockerfile installs expect + real-claude integration test | pending |
| 6. entry.sh Step 8 wire + smoke-report rows | pending |

## Next session pickup

Plan doc updated at `docs/next-session-plan-2026-09-27-interactive-skill-drives.md`. Sub-step 2 scope enumerated with reads + approach + estimate (60-100 turns).

## Refs

- PR #256 (`2d33dbd`) — real smoke-expect.sh bodies merged
- Parent PR: #255 (walking skeleton merged 2026-09-26d)
- Plan doc: `docs/next-session-plan-2026-09-27-interactive-skill-drives.md` (updated with sub-step chain)
- Decompose: `docs/decompositions/2026-09-26-cli-254-interactive-drives.md`
- Risk ledger: `docs/risk-ledgers/2026-09-26-cli-254-interactive-drives.md`
- UC: `docs/use-cases/UC-script-254-interactive-skill-drives.md` (extended with sub-step 1 scope)
- Ceremony markers: `state/markers/{temperance,luminary,pre-mortem,rfc,adr-deviation,lead-lens-signoff,reviewer}/feat-254-smoke-expect-real-body.marker`
- Parent session: `docs/session-logs/2026-09-26d-longrun-cli-254-walking-skeleton.md`
- Ticket: cli#254 sub-step 1
