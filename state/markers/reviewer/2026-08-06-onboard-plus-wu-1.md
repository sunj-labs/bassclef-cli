# Reviewer pass — 2026-08-06-onboard-plus-wu-1

mode: sequential (autonomous orchestrator-gated overnight)
reviewed_at: 2026-08-06T02:56:00Z
source_files_changed: 5
files:
  - src/cli.ts (new, 60 lines)
  - src/index.ts (new, later edited; 14 lines)
  - src/commands/init.ts (new, 14 lines)
  - src/commands/sync.ts (new, 14 lines)
  - src/pipeline/README.md (new, boundary marker only — not source)

## Checks

- **Spec acceptance criteria:** PASS for WU-1-scoped items in bet
  `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L152-165. Verified: repo bootstrapped with TypeScript + Vite +
  files-array whitelist + Apache-2.0 LICENSE (L153); README-Cooper
  first-touch pass (L121 acceptance). N/A on this WU: `init`
  behavior (L154), `sync` upgrade (L155), publish pipeline (L156-158),
  cold-adopter harness (L160), Adam Sharpe security PRs (L161), Sam
  demo (L162), first tagged 0.0.2 release (L163). Explicitly
  deferred to their named workunits.

- **Tests present + green:** PASS. `tests/cli.test.ts` — 7 tests,
  all pass. Confirmed via `npm test` before commit; captured in
  commit body.

- **Test-after pattern check:** NONE FOUND. `tests/cli.test.ts:1-15`
  opens with an explicit test list per Beck discipline; every listed
  item is covered by a passing test. No orphan tests. No test
  helpers larger than the test itself.

- **ADR compliance:** PASS. ADR-001 landed for the build toolchain
  pick (Vite + TypeScript + Vitest). Reviewer-review flagged that
  ADR-001 mixes 4 decisions (toolchain, dual-format, no lifecycle
  scripts, Node 20 floor). Deferred split to before publish
  workunit — documented in PR body + session log. Not a BLOCK
  because 0.0.1 does not publish; the split is required before tag.

- **Designer sign-off:** N/A. No UX surface in WU-1. CLI text
  strings (USAGE, stub messages) passed a Cooper first-touch check
  in `/pattern-review` — PASS verdict on item 3.

- **/architect-review invoked:** INVOKED via CodeReviewer subagent
  during this session. 3 DEFECTs surfaced; all 3 fixed inline
  before commit. Report referenced in commit body + session log
  at `docs/session-logs/2026-08-06-onboard-plus-wu-1.md`.

## Findings

- NOTE: ADR-001 will need splitting into ADR-002 (dual-format),
  ADR-003 (no lifecycle scripts), ADR-004 (Node 20 floor) before
  the publish workunit. Documented as follow-up in PR #2 body.
- NOTE: 5 dev-server esbuild vulnerabilities (GHSA-67mh-4wv8-2f99)
  surface via `vite@5.4 -> esbuild@<=0.24.2`. Affect `vite serve`
  only, which this project never runs. `npm audit fix --force`
  would install `vite@8` (major breaking change). Reviewer eyes
  requested before upgrade.
- NOTE: `src/cli.ts` uses a linear if-chain for the argv dispatcher.
  Acceptable at N=2 verbs per Ousterhout economy-of-mechanism.
  Refactor to a command map when N≥4 (init/sync + likely publish/
  version). Flagged in decomposition Q2 and PR #2 body.
- NOTE: `src/index.ts` `version` export is the ONLY programmatic API
  at 0.0.1 — pinned as intentional semver contract per commit-body
  note and `src/index.ts:5-12`.

acknowledged: true
