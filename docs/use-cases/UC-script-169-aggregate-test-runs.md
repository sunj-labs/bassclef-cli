---
tier: project
title: UC-script-169 — aggregate-test-runs.sh
id: UC-script-169-aggregate-test-runs
authored: 2026-09-20
class: fully-dressed (Cockburn tiering per operator directive; script tier normally brief per .claude/rules/oo-ad-entry-point.md)
parent_ticket: sunj-labs/bassclef-cli#169
spec: docs/specs/spec-169-test-run-history.md
---

# UC-script-169 — aggregate-test-runs.sh (fully-dressed)

## Sources read

- `docs/specs/spec-169-test-run-history.md` — the spec drives every step; UC formalizes the main success scenario + extensions
- `gh issue view 169` — parent ticket; source of the primary actor + success criteria
- `.claude/rules/oo-ad-entry-point.md` — Cockburn tiering; adopter-facing script normally briefs; fully-dressed overridden per operator directive

## Primary actor

Cli maintainer (developer).

## Stakeholders and interests

- **Maintainer** — wants to see which tests slow the suite and which flake.
- **Adopters** — indirectly benefit from more stable releases; do not invoke this use case themselves.
- **Bassclef substrate** — enforces `state/events/test-runs/` is gitignored to prevent operator leaks.

## Preconditions

- `state/events/test-runs/` exists (created by vitest on first run) OR does not exist (aggregator handles empty case).
- `jq` is installed on the developer machine (macOS default installs; adopter machines out of scope).
- Bash 3.2+ (macOS default) available.

## Postconditions

**Success** — stdout carries two sections (duration histogram + flake list) reflecting the last N recorded runs.

**Minimal guarantee** — no state file is modified; no network call made; exit code communicates success or a named failure class.

## Main success scenario

1. Maintainer runs `npm run test:report`.
2. Aggregator locates `state/events/test-runs/` under the repo root.
3. Aggregator enumerates all `*.json` files, sorted newest first.
4. Aggregator caps the working set at the last N files (default 20, or `--last N` if flag passed).
5. For each file, aggregator parses vitest's `testResults` array with `jq`.
6. Aggregator computes:
   - Per-test mean duration across the N runs
   - Per-test pass count / run count
7. Aggregator writes:
   - Section 1: `## Duration — top 10 slowest tests` (sorted desc by mean duration)
   - Section 2: `## Flake — tests with < 100% pass rate` (sorted asc by pass rate)
8. Exit 0.

## Extensions

**2a. `state/events/test-runs/` does not exist.**

1. Aggregator prints `No test runs recorded in state/events/test-runs/. Run 'npm test' first.` to stdout.
2. Exit 0.

**5a. One or more JSON files malformed.**

1. Aggregator prints `WARN: <path> is malformed; skipping.` to stderr per bad file.
2. Aggregator continues with the good files.
3. If ALL files are malformed, aggregator prints `ERROR: no valid test-run records found.` to stderr and exits 2.

**anywhere. jq not installed.**

1. Aggregator prints `MISSING: jq required. Install with brew install jq.` to stderr.
2. Exit 1.

**anywhere. --json flag passed.**

1. Aggregator writes machine-readable JSON summary to stdout instead of the two text sections.
2. Shape: `{"generated_at": "<ISO>", "runs_read": N, "duration": [{"test": "...", "mean_ms": ...}, ...], "flake": [{"test": "...", "pass_rate": ...}, ...]}`.
3. Exit 0.

## Frequency

Per maintainer curiosity — typically after a `npm test` run or before a release cascade. Not automated. Not fired by CI.

## Special requirements

- No network calls.
- No file writes (read-only aggregation).
- No prompts (batch-safe for CI use later).

## Assumptions

- Vitest's JSON reporter shape stays stable across minor versions (vitest 2.0.x contract).
- The `state/events/test-runs/` directory is gitignored (bassclef substrate obligation).
- `jq` is on `$PATH` — same assumption as every other bassclef bash script.

## Open issues

- What happens when a test is renamed across runs? V1 treats it as two separate tests. Future refinement.
- What happens on Windows (WSL)? Same as macOS bash path; not separately tested in V1.
