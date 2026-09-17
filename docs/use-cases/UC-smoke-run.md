---
tier: project
title: UC-smoke-run — cold-adopter smoke evidence run
id: UC-smoke-run
date: 2026-09-18
level: user-goal
scope: bassclef-cli smoke test system
goal_id: 2026-09-18a-smoke-evidence-capture
status: draft
shape: fully-dressed
references:
  - path: docs/specs/smoke-evidence-capture.md
    role: authoring spec
  - path: docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md
    role: parent goal
---

# UC-smoke-run — cold-adopter smoke evidence run

## Sources read

- `docs/specs/smoke-evidence-capture.md` — full read; anchors the entity list and acceptance criteria this use case operationalizes
- `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md` — full read; scope, out of scope
- `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` — full read of the manual plan this use case supersedes at Steps 5-7

## What I'm NOT reading (with reason)

- Fixture cure code — out of scope; fixtures are pins, not cures

## Directive (per operator)

**Artifacts drive code.** Step 1 through Step 8 implementations MUST cite this use case's main flow steps and extension branches. When a branch case surfaces during implementation, extend this file first.

## Use case

**UC-smoke-run** — Run the cold-adopter smoke, capture per-hook and per-skill output, assert four checks per surface, produce a markdown report, and post the report as a GitHub issue.

## Scope

The bassclef-cli smoke test system on the cold-adopter Mac profile.

## Level

User-goal. One operator can run the sequence, get the issue link, hand off to the agent for diagnosis.

## Primary actor

Operator on the cold-adopter profile.

## Stakeholders and interests

| Stakeholder | Interest |
|---|---|
| Operator | Fast signal on release readiness. Under 5 minutes from cold reset to posted issue. |
| Agent | Structured evidence to run `/diagnose` against. Every RED row links to raw capture. |
| Adopters | Every release passes the smoke before they see it. |
| bassclef-upstream | Coordination tickets get filed with real evidence, not eyeball notes. |

## Preconditions

- Cold profile has `gh` authenticated as `kingofrock` (per whereami L63)
- `npm` global path writable
- `~/tmp` writable
- `claude` CLI on PATH
- `@thebassclef/lite@<version>` available on npm registry

## Success guarantee (postcondition)

An issue on `sunj-labs/bassclef-cli` carries the smoke report. Report body has pass/fail per check. RED rows link to raw capture files. Every capture file survives on disk under `docs/smoke-captures/<date>/`. Agent can `gh issue view <N>` and run `/diagnose` per RED row.

## Minimal guarantee

Raw capture files land on disk even when assertions or publishing fail. The operator can hand-inspect a failed run.

## Main success scenario

1. Operator runs `bash scripts/smoke-reset.sh --whole` on the cold profile.
2. System clears npm global cache, `~/.claude/projects/<repo>/`, and `~/tmp/bassclef-smoke-test`.
3. Operator runs `npm install -g @thebassclef/lite@<version>`.
4. System installs the package globally.
5. Operator runs `mkdir ~/tmp/bassclef-smoke-test && cd ~/tmp/bassclef-smoke-test && git init && bassclef init`.
6. System writes 379 files, arms 24 hooks, prints hook-count banner.
7. Operator runs `bash scripts/smoke-capture.sh`.
8. System reads `.claude/settings.json`, enumerates wired SessionStart hooks, fires each hook against a fresh session, captures stdout plus stderr per hook to `docs/smoke-captures/<date>/hooks/<hook-basename>.out`.
9. Operator runs `bash scripts/smoke-assert-hooks.sh`.
10. System reads each capture file, runs four checks per hook, writes `hooks-assertions.json` with pass/fail rows.
11. Operator runs `bash scripts/smoke-drive-skills.sh`.
12. System fires five skills (`/temperance`, `/luminary don-norman`, `/kiss words <sample>`, `/state-a-problem brief <sample>`, `/whats-the-plan`) via `claude -p`, captures each response to `docs/smoke-captures/<date>/skills/<skill-slug>.out`.
13. Operator runs `bash scripts/smoke-assert-skills.sh`.
14. System reads each skill capture, runs the same four checks per skill, writes `skills-assertions.json`.
15. Operator runs `bash scripts/smoke-report.sh --publish`.
16. System reads both assertion JSON files, writes `docs/smoke-captures/<date>/report.md` with the pass/fail matrix, posts a GitHub issue on `sunj-labs/bassclef-cli` with the `smoke-run` label, returns the issue number to stdout.
17. Operator pastes the issue link to the agent.
18. Agent runs `gh issue view <N>` and reads the report body.
19. For each RED row, agent runs `/diagnose` and files or updates a ticket.

## Extensions

### 1a. Reset fails partway

1a1. `scripts/smoke-reset.sh --whole` reports partial clear at step X.
1a2. Operator inspects the failure, clears manually, re-runs `--dry-run` to verify.
1a3. Return to Step 1 of the main flow.

### 3a. npm install fails

3a1. `npm install -g @thebassclef/lite@<version>` returns error.
3a2. System logs stderr; operator diagnoses (network, auth, tag mismatch).
3a3. Common false-positive: registry lag after publish. Operator waits 3 minutes and retries.
3a4. Return to Step 3 of the main flow.

### 5a. `bassclef init` exits non-zero

5a1. Manifest missing (exit 4) or schema mismatch (exit 5) per ADR-002.
5a2. Failure is the real smoke signal for that release. Operator captures the exit and stderr.
5a3. Report posts with an INIT-FAILED row; agent picks up on the issue.

### 7a. No wired SessionStart hooks found

7a1. `scripts/smoke-capture.sh` exits non-zero with "no hooks wired".
7a2. This is a substrate defect (`.claude/settings.json` missing or empty).
7a3. Report skips hook checks; skill drive still fires.

### 9a. A hook's capture is empty

9a1. `hooks-assertions.json` records the hook with an EMPTY-CAPTURE row.
9a2. Report treats EMPTY as a fail unless the hook is on the empty-allowlist.

### 11a. `claude -p` returns non-zero for a skill

11a1. Skill capture file records the exit code and stderr.
11a2. `skills-assertions.json` records that skill with a NO-RETURN row (fail).
11a3. Report links to the failed capture.

### 11b. `claude -p` hangs past 30 seconds

11b1. Driver script kills the call at 30 seconds via `timeout`.
11b2. Skill capture records TIMEOUT.
11b3. `skills-assertions.json` records a TIMEOUT row (fail).

### 15a. `--publish` fails on gh auth

15a1. `gh` returns auth error.
15a2. Report writes to disk. Publish step exits non-zero. Operator publishes manually or fixes auth.

### 15b. `--publish` succeeds but issue creation returns odd status

15b1. gh returns 201 but no issue number.
15b2. Script exits non-zero. Report still on disk. Operator inspects.

### 18a. Agent cannot access issue

18a1. `gh issue view <N>` fails or returns limited body.
18a2. Agent falls back to the local `docs/smoke-captures/<date>/report.md` via git pull.
18a3. Return to Step 18 of the main flow.

## Special requirements

- Whole flow completes under 5 minutes on a warm cold profile.
- Every capture file must include stdout AND stderr streams.
- Skill drive runs sequentially (parallel dispatch skewed the eight findings on the manual smoke).
- Report is markdown (agent parses; operator reads).

## Technology and data variations

- Skill list in `smoke-drive-skills.sh` extends per Layer 2 and Layer 3.
- Fixture set in `.claude/hooks/tests/fixtures/2026-09-18-smoke-findings/` grows as new defect classes appear.
- Report format stays stable across layers to preserve agent parsing.

## Frequency of occurrence

Every release (a few per month). Every substrate touch that lands on hooks (roughly weekly). Every operator-initiated cold-profile check.

## Miscellaneous

Coordination ticket bassclef-upstream#1728 tracks the eight upstream findings this run's fixtures pin. When #1728 items ship, the fixtures update in the same PR that touches the affected check.

## References

- Spec: `docs/specs/smoke-evidence-capture.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Manual plan: `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md`
- Fixture pins: cli#101 through cli#108
