---
decomp_id: 2026-09-26-cli-254-interactive-drives
authored_at: 2026-09-26T15:00Z
scope: cli#254 — expect-based interactive skill drives
authoring_luminaries:
  lead: alistair-cockburn
  supporting: [kent-beck, michael-feathers, michael-nygard]
rfc_council: [vaughn-vernon, hyrum-wright, linus-torvalds, jerome-saltzer-and-michael-schroeder]
---

# Decomposition + RFC — cli#254 interactive skill drives

## Sources read

- `docs/next-session-plan-2026-09-27-interactive-skill-drives.md` L27-77 — recommended session sequence + prereqs + interactive tech decisions
- `docs/risk-ledgers/2026-09-26-cli-254-interactive-drives.md` (entire) — 18 risks + 6 top folds pre-code
- `docs/use-cases/UC-script-254-interactive-skill-drives.md` (entire) — brief Cockburn UC scoped for scripts/*.sh class
- `docs/whereami.md` L28-31 — operator_recap 2026-09-22c prior drive-shape cure (PR #218) that shipped headless V2 with positive-artifact assertions
- `scripts/smoke-drive-skills.sh` L117 — current headless drive using `claude -p` (source of the gap this scope closes)
- `scripts/lib/smoke-assert.sh` — existing positive-artifact assertion library the new drives extend
- `harness/docker/entry.sh` — existing entry.sh Step 7 shape that Step 8 extends
- `.claude/rules/pattern-annotation.md` L57-62 — @pattern annotation contract for GoF + Vernon patterns applied here
- `.claude/rules/oo-ad-entry-point.md` — ceremony matrix (script scope = brief UC + Tier 0 tests)
- Ticket `gh issue view 254` — parent ticket body + acceptance criteria

## What I'm NOT reading (with reason)

- `.claude/skills/onboard-repo/SKILL.md` — deferred to drive-implementation phase; brief UC is enough for decomposition
- `.claude/skills/riff/SKILL.md` — same
- `.claude/skills/launch/SKILL.md` — same
- Playwright MCP setup docs — cli#241 blocks /riff full path; scope handles the block via advisory skip

## GRASP + BCE analysis

### Entities (nouns that persist state)

- **DriveResult** — captured stdout + stderr + exit code per drive invocation. Ephemeral file at `state/harness-runs/<ts>/interactive/<skill>.out`.
- **DriveConfig** — per-drive scratch dir + prompts + timeout + assertion set. Read from `scripts/lib/smoke-drives-registry.sh` (new).
- **AssertionResult** — pass/fail/skip + evidence path per positive-artifact check.

### Boundaries (adapters to external systems)

- **`scripts/lib/smoke-expect.sh`** (new) — anticorruption layer between the driver scripts and `expect`. Hides expect's Tcl syntax quirks; exposes a bash-friendly interface (`drive_start`, `drive_send`, `drive_expect`, `drive_capture`, `drive_end`).
- **`harness/docker/entry.sh` Step 8** (extension) — orchestrator that fires each drive + collects results.

### Control (business logic — one entity per skill)

- **`scripts/smoke-drive-interactive-onboard-repo.sh`** (new) — Strategy for /onboard-repo. Fires interactive claude; navigates Phase 0-N; asserts settings.json + substrate.config.md land.
- **`scripts/smoke-drive-interactive-riff.sh`** (new) — Strategy for /riff. Fires interactive claude; sends prompt with target; asserts HTML OR captures MCP-absent refuse.
- **`scripts/smoke-drive-launch.sh`** (new) — Strategy for /launch. Fires interactive claude; walks gallery + spec + stories + plan; asserts each artifact class.

### Patterns applied (per pattern-annotation rule)

- **@pattern patterns/code/gof/strategy.md** — driver-per-skill; shared interface at `smoke-expect.sh`.
- **@pattern patterns/code/gof/template-method.md** — smoke-expect.sh defines the drive workflow skeleton; per-skill scripts fill in prompt + assertions.
- **@pattern patterns/code/vernon/anticorruption-layer.md** — smoke-expect.sh hides claude+expect-specific mechanics from callers.

### Interfaces (contracts across boundaries)

- **DriveScript interface** — every drive script MUST expose `main(scratch_dir, cli_version, timeout_sec) → exit_code (10-19)`. Contract enforced by Tier 0 tests.
- **Exit code vocabulary** — 10 (expect script bug), 11 (claude timeout), 12 (assertion fail), 13 (missing prereq), 14 (INFRA fail like disk full), 15-19 reserved.
- **Assertion result shape** — JSON at `state/harness-runs/<ts>/interactive/<skill>.json` with `{status: PASS|FAIL|SKIP, evidence: <path>, reason: <string>}` per check.

## RFC council — 4 outside luminaries

Council pick per plan doc L27 (outside the authoring set). Lenses focused on risks the primary set can miss.

### Vernon lens — anticorruption layer

**Finding V1 (MEDIUM):** smoke-expect.sh must not leak `expect` Tcl syntax to callers. Callers stay in bash. Anticorruption boundary preserves substitutability if we ever swap expect for pty-node.
**Disposition:** FOLD pre-code. Define smoke-expect.sh interface first (walking-skeleton commit); write per-skill drives against the interface.

### Hyrum lens — observable behavior over time

**Finding H1 (MEDIUM):** interactive drive semantics become adopter expectations after N runs (Hyrum's Law). Renaming an assertion class post-ship breaks adopter parsers.
**Disposition:** FOLD pre-code. Version the assertion result shape at `schema_version: 1`; treat as adopter-observable per ADR-031.

### Linus lens — adopter contract

**Finding L1 (LOW):** Dockerfile adds `apt install expect` — container size grows ~5MB. Adopters who rebuild locally pay the size cost.
**Disposition:** DEFER. 5MB is negligible vs Debian slim base (~74MB). Not worth mitigation.

**Finding L2 (MEDIUM):** entry.sh Step 8 changes exit-code composition. Adopters running the harness locally see new exit codes 10-19.
**Disposition:** FOLD. Extend `docs/runbook/docker-smoke.md` exit-code table BEFORE the code cure.

### Saltzer-Schroeder lens — complete mediation

**Finding S1 (MEDIUM):** every drive must channel through smoke-expect.sh. A drive that bypasses (calls `expect` directly) breaks the anticorruption boundary + defeats future refactors.
**Disposition:** FOLD pre-code. Tier 0 test asserts each drive script sources smoke-expect.sh + does not call `expect` directly (grep-based check).

## Folds summary (pre-code)

From pre-mortem: 6 folds (F1, F5, B1, B6, C3, C4).
From RFC: 4 more folds (V1, H1, L2, S1).

Total folds landing in the design: **10**.

Deferred: F3 (MCP two-branch on /riff), L1 (Dockerfile size), C1 (skeleton-first split — architectural intent still walking-skeleton).

## Next — Beck TDD RED phase

Ship in commits:

1. **Commit 1 — walking skeleton** (Cockburn C1 fold amended): smoke-expect.sh interface + 3 empty drive stubs + Tier 0 tests that fail RED because stubs are empty. Skeleton verifies wire.
2. **Commit 2** — smoke-expect.sh real implementation; skeleton tests go GREEN; drive-specific tests stay RED.
3. **Commits 3-5** — one drive per commit; each ships RED-first then GREEN.
4. **Commit 6** — Dockerfile install + entry.sh wire + runbook update.

Force-red validation in PR body per Beck B6 fold.

## Refs

- Plan doc: `docs/next-session-plan-2026-09-27-interactive-skill-drives.md`
- UC: `docs/use-cases/UC-script-254-interactive-skill-drives.md`
- Risk ledger: `docs/risk-ledgers/2026-09-26-cli-254-interactive-drives.md`
- Ticket: cli#254
- Pattern annotations to add during commits: Strategy + Template Method + Anticorruption Layer per `.claude/rules/pattern-annotation.md`
