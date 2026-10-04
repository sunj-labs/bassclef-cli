---
tier: upstream
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - michael-feathers
    - linus-torvalds
---

# Next session plan — Session F — un-anchored driver build-out

## Scope in one sentence

Ship RED characterization drivers for 12 Q1/Q2 cli tickets that have observable behavior today, before upstream Slot 9 lands.

## Context (read first — session is fresh)

Session E closed backlog triage. 8 tickets closed with evidence. 11 status comments posted. 36 open → 28 open. Session E chronicle at `docs/session-logs/2026-10-05-session-e-backlog-triage-plus-release-close-sweep-promote.md`.

Session E also surfaced the un-anchored driver gap. The Eisenhower matrix (operator-authored) sorted 23 open cli tickets into Q1 (hard blocks) + Q2 (contract breaks) + Q3 (triage). Of those 23, **7 already have cli-side driver anchors shipped** across Sessions A-D. **2 are truly blocked** on upstream Slot 9 cadence (#331 + #332). The remaining **12 can characterize RED today** without waiting on upstream.

Session F is the walking-skeleton session for those 12 drivers. Walking skeleton: ship ONE driver end-to-end first, prove the pattern, then grow to the other 11.

## Luminary map

- **Lead:** `alistair-cockburn` — walking skeleton. One driver fully wired before adding depth to the rest. Prior Sessions A-D proved the pattern.
- **Supporting:** `michael-feathers` — characterization before cure. Each driver asserts RED behavior exists TODAY against upstream substrate at bassclef v1.7.0. When upstream ships a cure in Slot 9+, each driver flips GREEN on the next cli bundle sync.
- **Supporting:** `linus-torvalds` — adopter stability. Cross-cutting invariants (bash 3.2 only; no PyYAML; no absolute paths) stay enforced via `scripts/tests/lib/lite-runtime-invariants.sh` from Session A.

## Three principles the plan carries

1. **Walking skeleton (Cockburn).** Session F ships ONE driver end-to-end first — pick the thinnest-value one that proves the Session F pattern. Then grow to the other 11.
2. **RED today (Feathers).** Each driver asserts current observable behavior. No cure authoring in cli — cures live upstream. Cli ships the characterization.
3. **No new runtime (Torvalds).** Session A shipped the Dockerfile.lite-adopter runtime + invariants lib. Session F drivers plug in; no new container, no new helper lib.

## 12 drivers in Session F scope

Sorted by Session E Eisenhower Q + harness value. Walking skeleton pick marked ★.

| Ticket | Surface | What the driver asserts (RED today) | Q | Fixture class |
|---|---|---|---|---|
| **#306** ★ | /onboard-repo | `bash --norc -c 'declare -A x; echo "$x"'` succeeds under lite runtime (bash 3.2 compat) | Q1 | bash-3.2-fresh |
| #321 | all | pre-flight skill-registry warning absent in lite install output | Q1 | lite-install-fresh |
| #316 | all | state-validate fires on malformed state write (not silently skipping) | Q1 | state-malformed-fresh |
| #329 | all | adr-discipline-check.sh fires on PreToolUse Edit matching ADR paths | Q1 | adr-edit-fresh |
| #311 | /build | artifact-ingestion-gate accepts `parent_bet: null` (not refusing) | Q2 | parent-bet-null-fresh |
| #324 | /launch | /launch calls /ux-migration with skip-on-greenfield flag | Q2 | greenfield-launch |
| #322 | /launch | /launch Phase 14 template body passes `/kiss words --rewrite` | Q2 | phase-14-template |
| #323 | /riff | save-state.sh refuses to commit paths under `prototypes/` without operator confirmation | Q2 | prototype-save-fresh |
| #312 | /build | structural_hints.verb_goal_pairs has a producer in the chain | Q2 | verb-goal-pairs-fresh |
| #326 | /build | /build Phase 2b accepts preview-state lookup under adopter mode | Q2 | adopter-mode-preview |
| #310 | /build | /build capability check runs with ≥10s timeout AND emits correct fallback | Q2 | network-slow |
| #325 | /launch | /launch mocks pass WCAG contrast at AA level | Q2 | contrast-check |

**Not in Session F scope:**
- #331 (/autonomous procedure) — BLOCKED on Slot 9
- #332 (/launch → /build → deploy chain) — BLOCKED on Slot 9
- #315 (state accessor read input-artifact) — lite packaging gap; needs upstream to ship `scripts/state.sh` in lite tier first
- #330, #328 — triage/class tickets, not driver scope

## Walking skeleton — #306 bash 3.2 declare -A

**Why first.** The invariant is already pinned in `scripts/tests/lib/lite-runtime-invariants.sh` from Session A. Driver only needs to assert the lite entry-point runs under `bash --norc` on macOS. Thinnest wire-up; proves the Session F pattern against a known-RED surface.

**Assertion.** `scripts/tests/smoke-drive-adopter-306-bash32.test.sh` runs `/onboard-repo` label step under macOS bash 3.2 fixture. Expects RED (declare -A fails). When upstream ships the fix (strip `declare -A` or add bash 4+ guard with fallback), the driver flips GREEN.

**Fixture.** `scripts/tests/fixtures/bash-3.2-fresh/` — PATH stripped to `/usr/bin`; shell forced to `bash --norc`; env -i to prevent host bash state leak.

## Red-first assertions per driver

Each driver follows the Session A pattern:

```bash
# 1. Load invariants
source scripts/tests/lib/lite-runtime-invariants.sh
assert_lite_runtime

# 2. Run observable surface against lite substrate
output=$(bash dist/lite/.claude/skills/<skill>/<entry-point>.sh <args> 2>&1)
exit_code=$?

# 3. Assert RED (the broken behavior IS observed)
if ! grep -q "<expected RED signal>" <<< "$output"; then
  echo "FAIL: driver no longer RED — upstream may have cured; verify"
  exit 1
fi

# 4. When upstream ships cure + cli bundle-syncs:
#    - assertion flips to assert GREEN (behavior cured)
#    - ticket closes with cross-ref via /release-close-sweep (upstream#2068)
```

## Container runtime

Reuse `Dockerfile.lite-adopter` from Session A. No new container. Drivers add via:
- New file: `scripts/tests/smoke-drive-adopter-<NNN>-<slug>.test.sh`
- New fixture dir (when needed): `scripts/tests/fixtures/<slug>/`

## Session F time budget

**100-200 turns** across one or two sessions:

- Walking skeleton (#306) end-to-end + ONE additional driver: 60-80 turns
- Grow to 5-6 more drivers: 60-80 turns
- Remaining 4-5 drivers: fold into Session G

Session A grounded this estimate (12 drivers across Sessions A-D at ~230 turns total; Session F picks the un-anchored tail).

## Fresh-session kickoff

On session restart, operator types:

```
/longrun prep
```

Preset picker (Step 0.85) reads this plan doc as Signal 1. Fires converged preset. Prep renders:
- Problem + Value + Evidence opener
- Recommend: #306 walking skeleton
- Scan-table of the 11 other drivers
- Ask hints for step plan + other-option cards

Full ceremony per Session A pattern:
1. `/temperance` at Session F scope
2. `/luminary` to pin Cockburn + Feathers + Torvalds
3. `/pre-mortem light` on #306 walking skeleton (3 lenses × 5 risks)
4. Ship #306 driver + fixture + container-wire as PR #1
5. Grow to #321, #316, #329 as follow-on PRs same session
6. Session G folds off this harness

## Related tickets

- **cli#306** through **cli#329** — the 12 driver targets
- **bassclef-upstream#2068** — Path A proof fires here when the first bundle sync lands with Slot 9 cures (post-Session F)
- **bassclef-upstream#2067** — /release-close-sweep proposal (Session F exercises the manual version against Session F's drivers)

## What success looks like

Session F ships:

- At minimum one driver (#306) running RED today end-to-end
- Pattern template clear enough for Session G to pick up 4-5 more drivers
- 11 remaining drivers scoped as follow-on tickets if not shipped same session
- Zero new container work; zero new helper lib work; everything builds on Session A harness

## Not success — anti-patterns

- Trying to ship cures. Cures live upstream. Cli ships characterization only.
- Expanding scope to #331 or #332. Both BLOCKED on Slot 9. Session F keeps hands off.
- Rewriting Session A invariants lib. The lib works. Reuse.
