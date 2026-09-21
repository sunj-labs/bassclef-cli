---
tier: lite
slug: 2026-09-21-pre-tag-version-sync
date: 2026-09-21
scope: Epic #194 Stories 1-3 — pre-tag version-sync guardrails
time_budget: 100-150 turns
authoring_luminaries:
  primary: michael-nygard
  supporting: [kent-beck, saltzer-schroeder]
rfc_signoff: docs/rfcs/2026-09-21-pre-tag-version-sync-council.md (Revised A, 2 MEDIUM folded, 2 LOW deferred)
references:
  - docs/specs/2026-09-21-pre-tag-version-sync.md
  - docs/use-cases/UC-version-sync-guardrails.md
  - docs/decompositions/2026-09-21-pre-tag-version-sync.md
  - docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md
  - docs/rfcs/2026-09-21-pre-tag-version-sync-council.md
---

# Goal — pre-tag version-sync guardrails

## Sources read

- `docs/whereami.md` L1-266 — active state + v1.5.0 mis-ship recap
- `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md` — session-of-record for the mis-ship
- Epic #194 body via `gh issue view 194` — 6 stories total; this goal covers 1-3
- `tests/version-sync.test.ts` L1-32 — existing test (2 of 4 files)
- `.github/workflows/publish.yml` L1-306 — release-time check surface
- `scripts/bump-version.mjs` L1-80 — existing bump helper
- `README.md` L38 — version marker delimiters
- `CHANGELOG.md` L1-25 — Keep-a-Changelog format
- Every ceremony artifact under this goal's `references:` — spec + UC + decomp + risk ledger + RFC

## What I'm NOT reading (with reason)

- Epic #195 body — Docker harness ergonomics, separate scope this session

## Problem (via `/state-a-problem brief`)

The v1.5.0 release cycle failed because a hand-edit of `package.json` skipped the sibling version files. The pre-publish check caught the drift — but only after the tag was cut and the publish workflow fired at `release: published`. The class costs one wasted publish attempt per occurrence. This session moves the same check to PR time so the miss surfaces at PR review, not at release.

## Value prop (via `/value-prop tweet`)

Ship the pre-tag version-sync check + a pre-commit hook + a CONTRIBUTING note in one PR. Next release cycle catches drift at PR CI instead of at publish. Target: 33% faster releases + 50% fewer false-starts.

## Evidence

Source: session log `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md` L28-38 + Epic #194 body Story 1. Warrant: the epic body lists Story 1 (pre-publish check on PR events) explicitly as the class-killer for the v1.5.0 pattern.

## Acceptance

Per spec `docs/specs/2026-09-21-pre-tag-version-sync.md` § Acceptance list:

- [ ] `tests/version-sync.test.ts` covers all 4 files
- [ ] `.github/workflows/pr-checks.yml` runs `npm test` + `npm run typecheck` on every `pull_request`
- [ ] `scripts/git-hooks/pre-commit-version-sync.sh` blocks commit on drift
- [ ] `scripts/install-git-hooks.mjs` installs the hook idempotently
- [ ] `CONTRIBUTING.md` documents `npm run bump` + `npm run install-hooks`
- [ ] Tier 0 coverage for the hook + installer
- [ ] Verification test bump end-to-end after cure lands

## Steps

| Step | Produces | Consumes (from prior step) | Risk |
|---|---|---|---|
| **0** prep | goal doc + spec + UC + decomp + risk ledger + RFC + all markers | — (session start) | 🟢 low |
| **1** Beck RED — extend `tests/version-sync.test.ts` | Failing test that reads all 4 files + 4 not-found cases per RFC F1 | Step 0 spec + decomp Interface 1 error contract | 🟢 low |
| **2** Extract lib | `src/lib/version-markers.ts` — `readVersionSet` + `checkVersionSet` + `formatDriftMessage` + `VersionMarkerNotFound` | Step 1 test list drives interface shape | 🟢 low |
| **3** Beck GREEN — pure function + reader per source | Test passes | Step 1 fixture + Step 2 lib | 🟢 low |
| **4** Node CLI wrapper | `scripts/check-version-set.mjs` | Step 2 lib exports | 🟢 low |
| **5** Shell hook | `scripts/git-hooks/pre-commit-version-sync.sh` | Step 4 CLI wrapper + `jq`/`node` fallback per pre-mortem R4 | 🟢 low |
| **6** Installer | `scripts/install-git-hooks.mjs` + `npm run install-hooks` npm script | Step 5 hook file | 🟢 low |
| **7** PR-CI workflow | `.github/workflows/pr-checks.yml` runs `npm test` + `npm run typecheck` on `pull_request`, no `paths:` filter (per pre-mortem R3 + RFC F2) | Step 3 test suite | 🟡 med — touches CI |
| **8** CONTRIBUTING doc | `CONTRIBUTING.md` naming `npm run bump` + `npm run install-hooks` (per RFC F4) | Steps 6 + 7 exist and are wired | 🟢 low |
| **9** Verify | End-to-end test bump: `npm run bump patch`, hook fires clean, PR-CI green | Steps 0-8 | 🟢 low |
| **10** Ship | PR opened + merged within scope; whereami updated | union of steps 0-9 | 🟢 low |

## /temperance + /luminary + /loop discipline

- **/temperance** fired at branch start. Marker at `state/markers/temperance/feat-194-pre-tag-version-sync-guardrails.marker`. Scope decision: ship Stories 1-3 as one PR. Drift trigger: any step over 1.5× estimate OR any R1-R5 materializes.
- **/luminary** primary lens `michael-nygard` — fail loud earlier in the pipeline. Marker at `state/markers/luminary/feat-194-pre-tag-version-sync-guardrails.marker`.
- **/loop** iteration count 1 (first pass through the cycle).

## Compounding value (recommended only)

- **Deliverable:** Pre-commit hook + PR-CI workflow + CONTRIBUTING note. Extended `tests/version-sync.test.ts`. New `src/lib/version-markers.ts` + 3 scripts.
- **Problem:** Version drift ships to tag; pre-publish check catches it too late. Cost per occurrence: one wasted publish attempt.
- **Value prop:** Every future release cycle catches drift at PR CI. Cycle time drops. Approve gate friction drops (fewer false-starts).
- **Turns:** 100-150 (grounded per past shape: 2026-09-17 3-ticket PR batch ran ~150 turns).
- **Risk:** 🟡 med — touches `.github/workflows/` (release-critical). PR CI trigger is additive. Revert = one commit.
- **Shipping priority:** P1.

## Non-goals

- No auto-fix on drift. Hook + PR-CI both fail loud.
- No husky adoption. Hand-rolled git hook + Node installer.
- No coverage of Epic #194 Stories 4-5 (approval-gate notifications). Ticket #192 covers those.
- No coverage of Epic #195. Separate goal.
- No coverage of ticket #193 (Node 20 + ubuntu-latest bump). Separate scope.

## Follow-on tickets (to file at closeout)

- **F3 (RFC · Parnas):** audit whether `src/index.ts` can import version from `package.json` — reduces 4 sources to 3.
- **F5 (RFC · Norman):** first-commit signifier when hook is uninstalled.

## Refs

- Spec: `docs/specs/2026-09-21-pre-tag-version-sync.md`
- Use case: `docs/use-cases/UC-version-sync-guardrails.md`
- Decomposition: `docs/decompositions/2026-09-21-pre-tag-version-sync.md`
- Risk ledger: `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md`
- RFC: `docs/rfcs/2026-09-21-pre-tag-version-sync-council.md`
- Epic #194 body
- ADR-004 (publish pipeline safety contract) — ADR-honored per marker at `state/markers/adr-deviation/`
- Closes: partial #194 (Stories 1-3 of 6)
