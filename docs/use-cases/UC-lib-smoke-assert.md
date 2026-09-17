---
tier: project
title: UC-lib-smoke-assert — shared assertion + schema libraries
id: UC-lib-smoke-assert
date: 2026-09-18
level: subfunction
scope: bassclef-cli smoke test system — sourced libraries
goal_id: 2026-09-18a-smoke-evidence-capture
status: draft
shape: brief
references:
  - path: docs/use-cases/UC-smoke-run.md
    role: parent UC (fully-dressed)
  - path: docs/specs/smoke-evidence-capture.md
    role: authoring spec
  - path: docs/decompositions/smoke-evidence-capture.md
    role: entity model plus BCE — names both libs
  - path: docs/risk-ledgers/2026-09-18-smoke-evidence-capture-pre-mortem.md
    role: F4 + F6 folds that require shared libs
---

# UC-lib-smoke-assert — shared assertion + schema libraries

## Sources read

- `docs/use-cases/UC-smoke-run.md` — parent UC, fully-dressed
- `docs/specs/smoke-evidence-capture.md` § Four checks + § Interfaces
- `docs/decompositions/smoke-evidence-capture.md` § Entity model + § Cross-cutting concerns
- `docs/risk-ledgers/2026-09-18-smoke-evidence-capture-pre-mortem.md` F4 + F6

## Why this UC exists

Per `.claude/rules/oo-ad-entry-point.md` matrix — new files under `lib/*.sh` require a brief use case. This UC is that brief for two libraries that share one purpose: hold the assertion contract and the AssertionResult schema in one place so both `smoke-assert-hooks.sh` and `smoke-assert-skills.sh` reuse them without duplication.

## Actors

- `scripts/smoke-assert-hooks.sh` — Step 2 driver, sources both libs
- `scripts/smoke-assert-skills.sh` — Step 5 driver, sources both libs

## Preconditions

- `jq` on PATH (schema helper uses jq for JSON emit)
- Capture files exist per UC-smoke-run § Main flow

## Main scenario (compressed)

1. Driver script sources `lib/smoke-schema.sh` and `lib/smoke-assert.sh`
2. Driver calls one of four check functions per capture: `check_no_not_found`, `check_no_silent_skip`, `check_no_unexpected_blocked`, `check_paths_exist`
3. Each check returns a status line — `<STATUS>|<check-name>|<message>`
4. Driver calls `assertion_result_json` to shape the status as an AssertionResult JSON object
5. Driver aggregates JSON objects into `hooks-assertions.json` or `skills-assertions.json`

## Postconditions

- Each check function signature stable — `(capture_file, allowlist_file_or_empty)`
- Each check function fails clean on missing file (returns FAIL with a clear message rather than crashing)
- `assertion_result_json` emits a single JSON object matching the AssertionResult schema

## Pre-mortem folds baked in

- **F4** (Fowler — assertion signature drift): one contract in `lib/smoke-assert.sh`; any new check amends the contract in one place
- **F6** (Fowler — AssertionResult schema baked into report): one schema helper in `lib/smoke-schema.sh`; ReportBuilder consumes via the same shape

## References

- Parent UC: `docs/use-cases/UC-smoke-run.md`
- Spec: `docs/specs/smoke-evidence-capture.md`
- Decomposition: `docs/decompositions/smoke-evidence-capture.md`
- Pre-mortem: `docs/risk-ledgers/2026-09-18-smoke-evidence-capture-pre-mortem.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
