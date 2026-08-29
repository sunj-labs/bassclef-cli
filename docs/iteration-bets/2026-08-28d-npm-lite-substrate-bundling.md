---
goal: 2026-08-28d-npm-lite-substrate-bundling
title: npm-native lite substrate bundling (Phases 1 + 2)
project: bassclef-cli
execution_repo: sunj-labs/bassclef-cli
status: in_flight
authored: 2026-08-28
authored_by: agent
in_flight_goal: 2026-08-28d-npm-lite-substrate-bundling
parent_goal: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
parent_roadmap: bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md
sibling_plan: bassclef-upstream/docs/plans/2026-08-28c-npm-distribution-no-symlinks.md
parent_ticket_upstream: bassclef-upstream#1417
upstream_pr_merged: bassclef-upstream#1418 (SHA 5e39053b)
time_budget: 390-495 turns
time_budget_source: |
  Plan doc L74-86 grounds 350-500 turns for 8 substantive steps. Revised table adds
  ~40 turns for risk-ledger v2 extension at Step 3.5 plus grep audit at Step 7.
  Total range 390-495 stays inside the 500-turn ceiling per plan doc L58.
  Prior comparable — iteration i (docs/session-logs/2026-08-27-iteration-i-npm-install-harness.md)
  shipped 8 substantive steps in ~150 turns actual for a similar shape (test-first + OOAD
  + Beck RED/GREEN); the wider top of this range covers Phase 1 + Phase 2 combined scope
  and adopter migration path.
authoring_luminaries:
  primary: [john-ousterhout, david-parnas]
  supporting: [michael-nygard, michael-feathers, kent-beck, alan-cooper]
lead_lens: john-ousterhout
tickets:
  - {repo: bassclef-upstream, id: 1418, anchor: parent PR (MERGED)}
  - {repo: bassclef-upstream, id: 1417, anchor: parent gap ticket}
  - {repo: bassclef-upstream, id: 1420, anchor: evolution ticket filed this session}
  - {repo: bassclef-upstream, id: 1421, anchor: hook fix ticket filed this session}
  - {repo: bassclef-upstream, id: 1257, anchor: Phase 3 runtime smoke follow-on}
  - {repo: bassclef-upstream, id: 741, anchor: lite release infrastructure}
references:
  - {type: canvas, id: bassclef-upstream/docs/canvases/2026-07-19-bassclef-lite.md, anchor: Q7 amendment 2026-07-27 L292-296}
  - {type: plan, id: bassclef-upstream/docs/plans/2026-08-28c-npm-distribution-no-symlinks.md, anchor: 5-phase parent plan}
  - {type: standard, id: bassclef-upstream/standards/lite-manifest-assembly.md, anchor: v1.2 assembly doc}
  - {type: audit, id: bassclef-upstream/docs/audits/2026-08-28c-npm-install-lite-readiness.md, anchor: v1.1 verification}
  - {type: plan, id: docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md, anchor: local prep doc}
  - {type: risk-ledger, id: docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md, anchor: pre-mortem light output}
  - {type: manifest, id: bassclef-upstream/lite-manifest.json, anchor: 146 entries manifest_version 1.2.19}
adr_references:
  - {id: ADR-005, anchor: parent ADR npm distribution architecture}
  - {id: ADR-007, anchor: TO AUTHOR at Step 3}
---

# npm-native lite substrate bundling (Phases 1 + 2)

## Problem

`@thebassclef/core@0.0.2` writes 3 config files and stops. Adopters need 146 substrate files to run bassclef. The canvas amendment on 2026-07-27 locked npm as the ship path. The tarball path retired.

This goal bundles the substrate inside the npm package. `bassclef init` copies the 146 files to the adopter's `.claude/` tree. `bassclef sync` walks the extended manifest for updates. Zero symlinks. No sibling checkout.

## Value

Sam runs two commands and gets a working bassclef:

```
npm install -g @thebassclef/core
bassclef init
```

First-touch friction drops to zero. Every subsequent update runs `bassclef sync`. The extended manifest becomes the contract for standard+/ultra tiers per ADR-005.

Per @luminary john-ousterhout — the CLI surface is shallow (`init` + `sync`); the copy path hides depth (manifest walk + hash verify + fail-fast). Adopter code calls one method.

Per @luminary david-parnas — the manifest is the interface. Bundle layout is implementation. Consumer code walks the manifest, not the filesystem.

Per @luminary michael-nygard — every publish path fails fast. Missing manifest → `npm pack` exits nonzero with a clear message. Adopter migration ships as a minor bump (0.1.0) with a documented upgrade path.

## Evidence

- **Source** — plan doc `docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md`; parent PR `bassclef-upstream#1418` (MERGED SHA `5e39053b`); canvas amendment L292-296
- **Warrant** — 14-lens panel at bassclef-upstream voted A 12, D 3 for Shape A (bundle in npm) layered under Shape D; canvas amendment retired the tarball path; operator confirmed Option b (combined Phase 1 + Phase 2) this session

## Sources read

- `docs/whereami.md` at session start (2026-08-28T15:06:34Z) — current project state; iteration i shipped 2026-08-27
- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` L1-80 — parent_goal; time budget 300-500 turns; primary luminaries alan-cooper + john-ousterhout + saltzer-schroeder
- `bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` — parent_roadmap; ACTIVE status; 5-iteration market entry sequence
- `docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md` — local prep doc with 3-option analysis; recommended Option b
- `bassclef-upstream/lite-manifest.json` header — verified manifest_version 1.2.19; entries array present
- `docs/adrs/` directory listing — confirmed ADR-006 taken by install-harness; ADR-007 is next available
- `gh pr view 36` — confirmed CONFLICTING at session start; resolved by merging origin/main at Step 0
- `gh label list --repo sunj-labs/bassclef-upstream` — confirmed bassclef-evolution and from:adopter labels for /promote filings

## Steps

| Step | Produces | Consumes | Time budget | Risk |
|---|---|---|---|---|
| **0** prep | goal doc + risk ledger v1 + gate markers + PR #36 rebase | this proposal | 25 turns | 🟢 |
| **1** use-case | `docs/use-cases/UC-npm-lite-substrate-bundling.md` (fully-dressed per Cockburn) | prep | 30 turns | 🟢 |
| **2** decompose | `docs/decompositions/2026-08-28-npm-lite-bundling.md` with `@pattern` calls + inline `@risk: R#` cites | UC | 40 turns | 🟡 |
| **3** ADR | `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` — pins Shape A layered under Shape D | decomposition | 20 turns | 🟢 |
| **3.5** ledger v2 | risk ledger extended — compensator + build target + verification + status columns per row | ADR-007 + decomposition | 20 turns | 🟢 |
| **4** Tier 0 tests | `tests/harness/prepublish-bundle.test.ts` + `tests/harness/copy-substrate.test.ts` (Beck RED) with `// @risk: R#` comments | ledger v2 | 60-100 turns | 🟡 |
| **5** Phase 1 source | `scripts/prepublish-bundle-substrate.mjs` + `package.json` extensions + `.gitignore` (commits carry `[risk: R#]`) | Step 4 RED → GREEN | 50-80 turns | 🟡 |
| **6** Phase 2 source | `src/lib/copy-substrate.ts` + `init.ts` + `sync.ts` extensions + `docs/migrations/0.1.0.md` (commits carry `[risk: R#]`) | Step 5 GREEN + Step 4 RED tests | 100-150 turns | 🔴 |
| **7** signoff | Ousterhout signoff marker + grep audit (`grep -r "@risk:" tests/` + `git log --grep "\[risk:"` cross-check ledger) + PR body | Steps 4-6 evidence | 25 turns | 🟢 |
| **8** closeout | session log + whereami flip + PR opened for review | signoff | 20 turns | 🟢 |

## Acceptance

- [ ] `npm pack` produces a package with `substrate/` at expected paths (146 files matching manifest)
- [ ] Fresh temp dir + `npm install <package> + bassclef init` writes 146 files to `.claude/` without touching sibling checkout
- [ ] `bassclef sync` walks extended manifest with existing classifier (Current / NeedsUpdate / Edited / Deleted per file)
- [ ] Tier 0 tests GREEN in bassclef-cli CI
- [ ] ADR-007 committed with @luminary ousterhout + parnas + nygard signoff
- [ ] Adopter migration doc drafted at `docs/migrations/0.1.0.md` (existing 3-file init adopters upgrade cleanly)
- [ ] Risk ledger at `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` has every row status `verified` at signoff (MUST — Step 7 blocks if any row lacks matching test + commit)
- [ ] Ready for @thebassclef/core v0.1.0 minor bump + npm publish

## Blockers to watch

- **Cross-repo read of `bassclef-upstream/lite-manifest.json` at publish time** — script needs a discovery path. Two options: assume `../bassclef-upstream/` sibling (matches operator machine layout) OR fetch from GitHub raw URL at publish time (network dependency at publish, not install). Pick during Step 2 decompose.
- **Package size grows** from 232K to ~500K-1MB per napkin math (146 small text files). Verify no npm size limit hit; document in ADR-007. Track under R9 in the ledger.
- **Adopter migration** — existing 3-file init adopters hit extended sync classifier on next `bassclef sync`. Migration doc + version bump policy pin the shape. Track under R8 in the ledger.

## References

- Local plan doc — `docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md`
- Local risk ledger — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md`
- Parent goal — `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- Parent ADR — `docs/adrs/ADR-005-npm-distribution-architecture.md`
- bassclef-upstream PR #1418 (MERGED) — sibling plan doc + assembly doc + verification report
- bassclef-upstream #1417 — parent gap ticket
- bassclef-upstream #1420 — evolution ticket (this session)
- bassclef-upstream #1421 — hook fix ticket (this session)
- bassclef-upstream #1257 — Phase 3 runtime smoke (closes after this + smoke test)
