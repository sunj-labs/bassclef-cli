---
session_id: 2026-09-26d
tier: lite
started_at: 2026-09-26T14:40Z
ended_at: 2026-09-26T17:25Z
mode: /longrun converged + agent-merges-within-scope
turn_count: ~205
outcome: shipped
parent_session: 2026-09-26c
---

# 2026-09-26d — /longrun cli#254 walking skeleton shipped

## Flash

Second /longrun tonight after prior closeout. Walking skeleton for cli#254 (interactive skill drives) shipped as PR #255 with full OOAD ceremony. 58/0 Tier 0 tests GREEN across smoke-expect + 3 drive stubs + registry.

## What shipped

### PR #255 — feat(cli-254): interactive skill drive skeleton (WIP)

Merged as `8fd0555`.

**Ceremony floor (commit e0b6b5d):**
- Session + branch temperance markers
- Luminary marker — Cockburn lead + Beck/Feathers/Nygard supporting
- Pre-mortem light ledger — 18 risks, 6 folds pre-code
- Brief Cockburn UC per adopter-facing-script tier

**Decompose + RFC (commit 63d934d):**
- GRASP + BCE analysis (entities, boundaries, control)
- 3 GoF/Vernon pattern annotations (Strategy + Template Method + Anticorruption Layer)
- RFC council — Vernon + Hyrum + Linus + Saltzer-Schroeder — 4 more folds
- ADR-deviation marker (outcome: ADR-honored — no ADR governs docker smoke path)

**Walking skeleton (commits 20aac89 + d1d5689):**
- `scripts/lib/smoke-expect.sh` — anticorruption layer per Vernon V1 fold. 5 verbs (drive_start/send/expect/capture/end). Sentinel exit 42 for unimplemented.
- `scripts/lib/smoke-drives-registry.sh` — function-based lookup for bash 3.2 portability.
- 3 drive stubs — /onboard-repo + /riff + /launch.
- 5 Tier 0 test files at `scripts/tests/` — 16+16+9+9+8 = 58 assertions all GREEN.

## Gate Evidence

| Gate | Marker | Notes |
|---|---|---|
| /temperance (session) | `state/markers/temperance/main-2026-09-26d.marker` | Scope: cli#254 walking skeleton |
| /temperance (branch) | `state/markers/temperance/feat-254-interactive-skill-drives.marker` | Scope: 3 stubs + shared lib + tests |
| /luminary | `state/markers/luminary/feat-254-interactive-skill-drives.marker` | Cockburn lead |
| /pre-mortem | `state/markers/pre-mortem/feat-254-interactive-skill-drives.marker` | 18 risks, 6 folds |
| /ADR-deviation | `state/markers/adr-deviation/feat-254-interactive-skill-drives.marker` | ADR-honored |
| /verify | passed | 58/0 local + PR #255 CI GREEN (test+typecheck 34s, docker-smoke 6m44s) |
| /loop discipline | iteration 1 | Two mid-development RED signals cured (readonly re-source; bash 3.2 assoc-array) |

## Discoveries

1. **bash 3.2 (macOS default) doesn't support `declare -A`.** Refactored registry to function-based lookup. Portable across bash 3.2 (macOS) and bash 5 (Debian CI). Follow-on candidate: substrate should note the version constraint when authoring shared libs.

2. **`.claude/hooks/tests/` is gitignored per adopter substrate discipline.** New bash tests at cli side go to `scripts/tests/` (matches `shadow-detection.test.sh` + `aggregate-test-runs.test.sh` precedent). Prior `.claude/hooks/tests/docker-harness-entry.test.sh` was tracked because it landed pre-gitignore.

3. **Auto-save vs tag ops race** (learned last session) — the `git fetch origin && git reset --hard origin/main` pattern between merge and next-step avoided a repeat tonight.

## What worked

- **Beck TDD RED-first held.** Two mid-development fails caught the bugs before they shipped: `readonly` re-source race and bash 3.2 array unsupported. Both cured in-session.
- **Cockburn walking-skeleton pattern paid off.** Interface (smoke-expect.sh) landed before content. Tomorrow builds on a verified frame with 58 tests as regression net.
- **10 folds landed pre-code.** 6 from pre-mortem + 4 from RFC council. Ceremony absorbed the risks before code write.

## What didn't work

- **First commit missed the tests.** Committed source files; `.claude/hooks/tests/` gitignored dropped 5 test files silently. Cure: moved to `scripts/tests/` + separate commit. Cost: one extra commit + investigation turn.
- **Session grew past comfort.** Started at ~130 turns cumulative from prior /longrun tonight; ended at ~335. Combined day totals rare but not new. Tomorrow starts fresh.

## Next session pickup

Plan doc still at `docs/next-session-plan-2026-09-27-interactive-skill-drives.md`. Tomorrow's /longrun picks up at:

1. Real `smoke-expect.sh` implementation — spawns expect subprocess, captures I/O
2. Real drive bodies per skill
3. Dockerfile install of `expect`
4. `entry.sh` Step 8 wire
5. Behavioral tests (positive-artifact assertions per drive)
6. `docs/runbook/docker-smoke.md` exit-code table extension (L2 fold from RFC)

## Refs

- PR #255 (`8fd0555`) — walking skeleton merged
- Plan doc: `docs/next-session-plan-2026-09-27-interactive-skill-drives.md`
- Decompose: `docs/decompositions/2026-09-26-cli-254-interactive-drives.md`
- Risk ledger: `docs/risk-ledgers/2026-09-26-cli-254-interactive-drives.md`
- UC: `docs/use-cases/UC-script-254-interactive-skill-drives.md`
- Parent session: `docs/session-logs/2026-09-26c-longrun-cascade-v1.6.1-cli-v1.9.4-plus-triage.md`
- Ticket cli#254 (parent), cli#241 (/riff MCP dep), cli#253 (smoke drift sibling)
