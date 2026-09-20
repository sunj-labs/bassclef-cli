---
tier: project
title: Spec — vitest test-run history + flake detection
id: spec-169-test-run-history
authored: 2026-09-20
parent_ticket: sunj-labs/bassclef-cli#169
goal_doc: docs/iteration-bets/2026-09-20c-169-vitest-test-run-history-plus-release-cascade.md
---

# Spec — cli#169 vitest test-run history

## Sources read

- `gh issue view 169` — the parent ticket; source of the JSON-reporter + aggregation-script + `test:report` scope
- `docs/iteration-bets/2026-09-20c-169-vitest-test-run-history-plus-release-cascade.md` — this session's goal doc
- `~/src/sunj-labs/bassclef-upstream/architecture/decisions/ADR-049-telemetry-opt-in-and-local-storage.md` — opt-in default off principle
- `vitest.config.ts` (this repo) — current config has `include` + `testTimeout`; no `reporters`
- `package.json` scripts section — verified `test:report` slot is free

## What I'm NOT reading (with reason)

- Vitest 2.0.0 upstream reporter source — the JSON reporter shape is a documented public contract; not read to source in this pass, characterized by test fixtures instead
- Sister tickets #170 + #171 in depth — out of scope for #169

## What this ships

A local test-run history for bassclef-cli maintenance. Every `npm test` writes a JSON record. A shell aggregator reads the records and prints a summary. A new `npm run test:report` invokes the aggregator.

## Why

Vitest 2.0.0 reports pass/fail per run. No history. No duration curve. No flake rate. A test that fails 10% of the time hides until a bad run.

## What NOT to ship

- No adopter-facing telemetry surface. Zero network. Zero opt-in prompt at adopter runtime. Files stay local per ADR-049 opt-in default off (bassclef-upstream/architecture/decisions/ADR-049).
- No dashboard, no web UI, no plotting library. Text output only.
- No historical backfill from past runs. History starts from the first JSON emit.
- No cross-machine aggregation. Local per developer clone.

## Users

Cli maintainers. Not adopters. The state lives at `state/events/test-runs/` and is gitignored. Adopters never see it unless they run `npm test` on a clone of the cli repo themselves.

## Contract

### Vitest emits JSON per run

- Vitest config sets `reporters: ['default', 'json']` with `outputFile: 'state/events/test-runs/<timestamp>.json'`.
- Timestamp format: `YYYY-MM-DDTHH-MM-SS-mmm.json` (ISO with colons swapped for hyphens).
- File contains vitest's standard JSON reporter shape (root object with `testResults` array).

### Aggregator reads + summarizes

- `scripts/aggregate-test-runs.sh` reads every `state/events/test-runs/*.json`.
- Emits two sections to stdout:
  1. **Duration histogram** — sorted per-test mean duration; top 10 slowest.
  2. **Flake list** — per-test pass rate over last N runs; any test below 100% is listed.
- Default N = 20. Configurable via `--last N` flag.
- Optional `--json` emits machine-readable summary instead.

### npm run test:report

- Package.json `scripts.test:report` invokes `bash scripts/aggregate-test-runs.sh`.
- Adopter never runs this. Development-only.

### State gitignored

- `.gitignore` adds `state/events/test-runs/` at repo root.
- Directory is created by vitest on first run; no pre-creation needed.

## Failure modes

- **No test runs yet** — aggregator prints `No test runs recorded in state/events/test-runs/. Run 'npm test' first.` Exit 0.
- **Malformed JSON in a run file** — aggregator skips that file with `WARN: <path> is malformed; skipping.` on stderr. Continues with other files.
- **Missing `jq` on operator machine** — aggregator prints `MISSING: jq required. Install with brew install jq.` on stderr. Exit 1.
- **Vitest reporter write fails** — vitest's own error surfaces. No cli-side handling.

## Bounded

- Aggregator processes 20 files in under 500ms on developer Mac (measured empirically at Step 5).
- Individual JSON file capped by vitest's own output size — no rotation logic in V1.
- Aggregator is stateless. Recomputes from files on every invocation.

## Sequencing

- Vitest config change lands first (RED test drives the reporter output shape assertion).
- Aggregator ships next (RED tests drive its parsing + rollup shape).
- npm script + .gitignore ship last (mechanical).

## Acceptance

Same as the goal doc. This spec is the input to `/decompose`.
