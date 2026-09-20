---
tier: project
title: cli#169 vitest test-run history + release cascade to v1.2.2
id: 2026-09-20c-169-vitest-test-run-history-plus-release-cascade
started_at: 2026-09-20T13:00:00Z
appetite: 100-165 turns (grounded — #169 instrumentation-only 60-100 per past code goals of comparable shape; release cascade 40-70 per 2026-09-17 v1.1.1 cascade)
mode: orchestrator-gated + agent-merges-within-scope
authoring_luminaries:
  primary:
    - kent-beck
  supporting:
    - michael-nygard
    - andreas-zeller
parent_goal_ids: []
references:
  - path: docs/whereami.md
    role: last update 2026-09-20T14:15:00Z; 2026-09-20b closed with cli#162 Docker harness shipped as PR #163
  - path: docs/specs/spec-169-test-run-history.md
    role: this session's spec (drafted this step)
  - path: docs/use-cases/UC-script-169-aggregate-test-runs.md
    role: this session's fully-dressed UC (drafted this step)
  - path: docs/decompositions/2026-09-20c-169-vitest-instrumentation.md
    role: this session's decomposition (drafted this step)
  - ticket: sunj-labs/bassclef-cli#169
    role: parent ticket — test-run history / vitest JSON reporter
  - ticket: sunj-labs/bassclef-cli#165
    role: sister — vitest coverage config (open PR #168; merges in release cascade)
  - pr: sunj-labs/bassclef-cli#163
    role: Docker cold-adopter harness V1 (merges in release cascade)
  - pr: sunj-labs/bassclef-cli#167
    role: CLAUDE.md ADR list extension (merges in release cascade)
  - pr: sunj-labs/bassclef-cli#168
    role: vitest coverage config with istanbul (merges in release cascade)
  - adr: sunj-labs/bassclef-upstream/architecture/decisions/ADR-049-telemetry-opt-in-and-local-storage.md
    role: opt-in default off principle — #169 is local-only, no adopter telemetry
verification_status: draft
---

# Goal — cli#169 test-run history + release cascade v1.2.2

## Sources read

- `docs/whereami.md:1-327` — 2026-09-20b closed; 4 PRs open (#161, #163, #167, #168); v1.2.1 last published
- `gh issue view 169` — vitest JSON reporter + aggregation + `npm test:report`; local-only per ADR-049
- `gh issue view 165` — vitest coverage config; source of PR #168
- `gh issue view 170 + 171` — sister tickets deferred to next session (DORA + adopter telemetry)
- `package.json` scripts: `test`, `test:watch` present; no `test:report` yet; vitest 2.0.0
- `vitest.config.ts` — no `reporters` field; only `include` + `testTimeout`
- `docs/next-session-plan-2026-09-17-cli-pickup.md` — 3 days old; Option e SHIPPED per whereami 09-18a + 09-20b; plan doc stale

## What I'm NOT reading (with reason)

- cli#170 + cli#171 ticket bodies in depth — sister instrumentation tickets deferred to next session
- Docker harness PR #163 diff — riding into release cascade as-is; architect-review at Handoff 4 already signed off yesterday

## Problem (≤500 chars)

Vitest reports pass/fail per run only. No historical duration curve. No cross-release view. No flake tracking. Developers on cli maintenance cannot see a test that fails 10% of the time until it fails in front of them.

## Goal

Ship two things this session, in order:

1. **cli#169** — vitest JSON reporter + `scripts/aggregate-test-runs.sh` + `npm run test:report`. Local-only state at `state/events/test-runs/`. Gitignored.
2. **Release cascade v1.2.2** — merge PR #163 (Docker harness), PR #167 (CLAUDE.md ADRs), PR #168 (vitest coverage), plus the #169 PR this session ships. Bump 1.2.1 → 1.2.2. Tag. Dispatch publish. Operator gate at Touch ID.

## Value prop

Developers get a duration histogram and flake-rate table on demand. Adopters get the Docker cold-adopter harness live and the ADR + coverage doc extensions cascaded in one release.

## Anchor luminaries

- **Primary** — Kent Beck. Tests are a first client of the code they exercise. Test-runtime health rides that same shape. History-of-runs makes the client's behavior legible.
- **Supporting** — Michael Nygard. Feedback loops from `Release It` — every deploy leaves a trace; every test run should too.
- **Supporting** — Andreas Zeller. Hypothesis-falsification pairing. Flake rate IS the falsifiable hypothesis that "test T is deterministic."

## Steps

| Step | Produces | Consumes | Turns | Risk |
|---|---|---|---|---|
| 0 prep | this doc + markers + spec + UC + decomposition | ticket #169 body + whereami | 6-10 | 🟢 low |
| 1 pre-mortem light | risk ledger at `docs/risk-ledgers/2026-09-20c-169-pre-mortem-light.md` | design chain from Step 0 | 8-12 | 🟢 low |
| 2 RFC adversarial | RFC-000N at `docs/rfcs/` — 5 outside luminaries; HIGH/MED/LOW findings; folds pre-code | design chain + pre-mortem ledger | 15-25 | 🟡 med — RFC may surface reshape need |
| 3 Beck TDD RED | tests at `scripts/tests/aggregate-test-runs.test.sh` | folded design | 10-15 | 🟢 low |
| 4 implement GREEN | `vitest.config.ts` reporter addition, `scripts/aggregate-test-runs.sh`, package.json `test:report` script, `.gitignore` `state/events/test-runs/` | RED tests | 15-25 | 🟢 low |
| 5 architect-review | review report; fold findings | GREEN diff | 10-15 | 🟢 low |
| 6 PR + merge #169 | PR body + merge to main within scope | reviewed diff | 8-12 | 🟢 low |
| 7 release cascade | merge #163, #167, #168; decide #161; bump 1.2.2; tag; publish; verify | main with #169 + Docker + docs | 30-50 | 🟡 med — Touch ID gate; publish workflow flake risk |
| 8 closeout | session log + whereami + retro | union of prior steps | 8-12 | 🟢 low |

## Per-step compounding

| Step | Where the payoff shows up | How often | What must be true first | Teaches shape later work reuses | What breaks half-done |
|---|---|---|---|---|---|
| 0 prep | per-branch | continuous | ticket #169 in the tracker | no (baseline) | 🟢 low — no scope anchor |
| 1 pre-mortem | per-branch | continuous | design chain drafted | yes — ledger shape for future goals | 🟢 low — risks discovered late |
| 2 RFC | per-branch | continuous | design + ledger | yes — outside-council shape reused per goal 20b | 🟡 med — code ships without dissent view |
| 3 RED | per-test-run | continuous | folded design | yes — Beck cycle | 🟢 low — tests written after |
| 4 GREEN | per-test-run | continuous | RED tests | yes — RED→GREEN discipline | 🟢 low — regressions slip |
| 5 architect-review | per-release | per-release | GREEN diff | yes — post-code review lens | 🟢 low — drift accumulates |
| 6 PR + merge | per-release | per-release | reviewed diff | no | 🟡 med — CI flake blocks release cascade |
| 7 release | per-release | per-release | main clean | yes — cascade playbook | 🔴 high — bad tarball ships to adopters (mitigated by publish.yml assert gates) |
| 8 closeout | per-session | per-session | all prior | no | 🟢 low — next session re-derives |

## Out of scope

- Adopter-facing telemetry (that's cli#171 — separate opt-in surface per ADR-049)
- DORA metrics for publish workflow (that's cli#170 — sister ticket)
- Historical backfill from past test runs (starts from first JSON emit forward)
- Web UI or dashboard rendering (report is stdout text)
- Cross-machine aggregation (local only)

## Acceptance

- [ ] `npm test` writes a JSON file to `state/events/test-runs/<ISO>.json` per run
- [ ] `scripts/aggregate-test-runs.sh` reads all `state/events/test-runs/*.json` and emits summary (duration histogram + per-test flake list)
- [ ] `npm run test:report` invokes the aggregator
- [ ] Tier 0 tests cover: empty state, single run, multi-run, flake calculation, malformed JSON graceful skip
- [ ] `state/events/test-runs/` added to `.gitignore`
- [ ] PR #169 merged to main
- [ ] Release cascade completes: PRs #163 + #167 + #168 merged, v1.2.2 tagged + published to npm
- [ ] Registry-verified `@thebassclef/lite@1.2.2` install works clean
- [ ] whereami flipped; session log written; retro run

## Refs

- Closes sunj-labs/bassclef-cli#169
- Bundles: sunj-labs/bassclef-cli#163, #167, #168 (release cascade)
- Sister tickets deferred to next session: sunj-labs/bassclef-cli#170, #171
- ADR-049 bassclef-upstream telemetry opt-in default off
- Prior release cascade shape: docs/session-logs/2026-09-17-cli-1.1.1-init-reporting-shipped.md
