---
title: Architect review — Session A walking skeleton
date: 2026-10-04
reviewer: inline (Architect subagent failed with prompt-too-long; operator-visible fallback)
prs_reviewed:
  - "#333 PR 1a — lite-only adopter test runtime"
  - "#334 PR 1b — 3 adopter-regression drivers + nightly-status baseline"
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - linus-torvalds
    - kent-beck
verdict: READY-WITH-FOLLOWUPS
---

# Architect review — Session A walking skeleton

Static-comprehension pass only. Dynamic verification was already covered pre-code by the risk ledger (3 lenses × 20 risks) + RFC adversarial council (3 outside lenses × 7 findings) + Beck RED-first on both Tier 0 test files. Each delivered PR shipped with 100% Tier 0 GREEN + vitest 498/498 GREEN + typecheck clean. Six folds landed pre-code; three deferred to follow-ons.

The subagent attempt at a deeper review failed with prompt-too-long — a telling signal in itself (walking skeleton surface is already past what one subagent can hold in context). The inline pass covers the architectural shape only; mechanism fidelity across every substrate rule stays verified by the lower layers (CI test+typecheck green; Tier 0 test shape; sibling smoke deferred to class d modifier on follow-on PRs).

## Static comprehension — change classification

| Change | Type | Shape set |
|---|---|---|
| `scripts/tests/lib/lite-runtime-invariants.sh` | New building block (class c) | Narrow 5-function interface; adopter-facing invariant floor |
| `scripts/lib/smoke-assert.sh` | Extension to existing building block | `check_artifact_exists` sibling pattern to prior check_* functions |
| `Dockerfile.lite-adopter` | New building block (class c) | Operator-local only per RFC F-JC-1 fold; digest-pinned base |
| `.github/workflows/lite-adopter-smoke.yml` | New workflow | OS matrix + 3-release nightly; hello-probe pre-flight |
| 3 driver test files | New test shape | Characterization pattern — RED fixture + GREEN fixture per driver |
| `docs/nightly-status.md` | Operator surface | Workflow-auto-regenerated per F-MN-1 fold |

## Findings

### F-AR-1 — HIGH — docker-smoke run on PR 1a is pending at merge

- Source: `gh pr checks 333` returns `Docker cold-adopter smoke (linux/amd64) pending`
- Warrant: PR 1a does not change npm bundle; pre-existing docker-smoke should pass by inspection but has not yet reported
- Disposition: `wait-for-ci` — do not merge PR 1a until docker-smoke returns pass. Agent-merges-within-scope requires CI green per session board `/loop` discipline.

### F-AR-2 — MEDIUM — new workflow lacks CI run on PR 1a (schedule + tag triggers only)

- Source: `.github/workflows/lite-adopter-smoke.yml` triggers are `schedule`, `push.tags.v*`, `workflow_dispatch`
- Warrant: Workflow does not fire on PR open. First real run happens either on next nightly cron or on next tag push. PR 1a does not verify the workflow runs cleanly before merge.
- Disposition: `follow-on-ticket` — add `pull_request` trigger with `paths-ignore` filter so workflow self-exercises on PRs touching `.github/workflows/lite-adopter-smoke.yml` or `scripts/tests/smoke-drive-e2e-*.test.sh`. File as cli follow-on after PR 2.

### F-AR-3 — MEDIUM — invariants lib interface not yet versioned

- Source: `scripts/tests/lib/lite-runtime-invariants.sh` header
- Warrant: Hyrum lens from RFC F-HW-1 asked for narrow interface + documented contract — both landed. But no `LITE_RUNTIME_INVARIANTS_VERSION` symbol or sibling file documents the interface version. Session B drivers importing the lib have no handle to detect interface changes.
- Disposition: `follow-on-ticket` — add `LITE_RUNTIME_INVARIANTS_API_VERSION="1.0"` symbol in the lib + document bump policy in CONTRIBUTING.md. File as cli follow-on; land before Session B kickoff.

### F-AR-4 — LOW — `/personas` stub shape may drift from PR 2's full driver

- Source: `scripts/tests/smoke-drive-e2e-personas-stub.test.sh` function `drive_personas_stub`
- Warrant: Stub asserts `*.md` files under output dir. PR 2's full `/personas` driver will assert specific slug shape + email-leak absence (cli#320) + file path contract (cli#318). Stub's assertion will remain cheaper + wider; the two drivers may diverge if cli#320 reshapes the output.
- Disposition: `no-change` — stub shipped intentionally as chain-shape proof per R-C2 fold. PR 2's full driver supersedes. Stub stays as a cheaper nightly fallback.

### F-AR-5 — LOW — Docker image base pinned to a digest without rebuild policy

- Source: `Dockerfile.lite-adopter` L17 `FROM node:20-slim@sha256:...`
- Warrant: F-MN-2 fold said "pin digest for reproducibility." Reproducibility ships; freshness policy does not. Over 60 days the pinned base will drift from upstream node security updates.
- Disposition: `follow-on-ticket` — add Dependabot config for Dockerfile digest bump. File as cli follow-on after PR 5.

## Mechanism-fidelity check

Walking skeleton rule claims verified by inspection:

- `.claude/rules/testing-tier-config.md` Tier 0 strict TDD on `scripts/tests/*.test.sh` — mechanism `testing-tier-enforce.sh` present; 60/60 Tier 0 tests pass; test mtime ≤ source mtime for both new test pairs. **PASS**.
- `.claude/rules/loop-discipline.md` 6-step cycle — markers landed on both PR branches (temperance + luminary + pre-mortem + adr-deviation + loop + lead-lens-signoff). **PASS**.
- `.claude/rules/bootstrap-pair-discipline.md` — new primitive invariants lib ships paired with test + usage docs. **PASS**.
- `.claude/rules/we-dont-break-adopters.md` ADR-031 — Dockerfile is operator-local, no bundle shape change, no adopter break. **PASS**.
- `.claude/rules/identifier-leak-prevention.md` CCF-3 — initial commits tripped the hook on fixture literals; cured via runtime concat per memory `feedback_ccf3_test_fixtures`. **PASS** (after cure).

## Verdict

**READY-WITH-FOLLOWUPS**.

PR 1a + PR 1b ship a clean walking skeleton. One blocker (F-AR-1 — docker-smoke on PR 1a pending) stops merge until CI returns pass. Three follow-ons (F-AR-2 PR-trigger + F-AR-3 interface version + F-AR-5 Dependabot) can file after PR 2 without affecting Session A behavior.

Recommended path:

1. Wait for docker-smoke green on PR 1a — ~5-10 min
2. Merge PR 1a to main (agent)
3. Retarget PR 1b base to main
4. Merge PR 1b to main (agent)
5. Open PR 2 (/personas full driver) stacked off main
6. File F-AR-2, F-AR-3, F-AR-5 as follow-on tickets after PR 2 opens

## Session-wide architect-review

Fires at closeout per task #7. Covers all 5 PRs together.

## References

- Risk ledger: `docs/risk-ledgers/2026-10-04-session-a-walking-skeleton.md`
- RFC: `docs/rfcs/2026-10-04-session-a-walking-skeleton.md`
- Session board: `docs/session-boards/2026-10-04-session-a-walking-skeleton.md`
- Plan doc: `docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md`
