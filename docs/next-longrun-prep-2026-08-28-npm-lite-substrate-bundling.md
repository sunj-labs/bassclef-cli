---
date: 2026-08-28
prepared_for: next /longrun session
goal_slug: 2026-08-28-npm-lite-substrate-bundling
tier: lite
parent_goal: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
sibling_plan: bassclef-upstream/docs/plans/2026-08-28c-npm-distribution-no-symlinks.md
parent_canvas: bassclef-upstream/docs/canvases/2026-07-19-bassclef-lite.md
parent_ticket_upstream: bassclef-upstream#1417
upstream_pr_merged: bassclef-upstream#1418 (SHA 5e39053b)
authoring_luminaries:
  primary: [john-ousterhout, david-parnas]
  supporting: [michael-nygard, michael-feathers, kent-beck, alan-cooper]
lead_lens: john-ousterhout
---

# Next /longrun prep — npm-native lite substrate bundling (Phases 1 + 2)

## Sources read

- Sibling plan `bassclef-upstream/docs/plans/2026-08-28c-npm-distribution-no-symlinks.md` — 5-phase sequence + 14-lens panel vote (A 12, D 3, B 1, C 0)
- Canvas `bassclef-upstream/docs/canvases/2026-07-19-bassclef-lite.md` L292-296 (amendment 2026-07-27) — tarball retired; npm-native locked as plan of record
- Assembly doc `bassclef-upstream/standards/lite-manifest-assembly.md` v1.2 — 6 parts + Flow 3 diagram + npm-native consumer story
- Verification report `bassclef-upstream/docs/audits/2026-08-28c-npm-install-lite-readiness.md` v1.1 — evidence for the gap
- bassclef-upstream ticket #1417 — parent gap ticket (Shape A layered under Shape D)
- Local `src/commands/init.ts` L104-129 — current 3-file init scope
- Local `src/commands/sync.ts` L48-61 — current 2-template sync scope
- Local `package.json` L34-40 — current `files:` array (dist + docs only)
- `bassclef-upstream/lite-manifest.json` L1-5 — 146 entries; manifest_version 1.2.19

## Problem

The `@thebassclef/core` npm package is a bootstrap installer today. It writes 3 config files and stops. Adopters need the 146 tier:lite files (skills + rules + hooks + luminaries + agents + standards + ADRs + libs + scripts + presence-templates + templates + root-docs) to actually run bassclef. Canvas amendment 2026-07-27 locked npm as the distribution vehicle — no tarball, no sibling checkout. This plan bundles the substrate inside the npm package and teaches `bassclef init` to copy it to the adopter.

## Goal

Ship two PRs. First PR makes `npm publish @thebassclef/core` produce a package that carries the 146 substrate files under `substrate/`. Second PR makes `bassclef init` copy those files to the adopter's `.claude/` at install time. `bassclef sync` walks the extended manifest for updates. Zero symlinks. No tarball. No sibling checkout.

## Evidence

- Source — sibling plan Phase 1 + 2 with correction note (SHA `fe50b749`); canvas amendment L292-296
- Warrant — panel of 14 lenses recommended Shape A (bundle in npm) layered under Shape D (additionalDirectories for standard+); operator flagged tarball regression; correction landed on bassclef-upstream main

## /longrun prep proposal (options)

### Option a — Phase 1 only (~100-200 turns)

Ships the `prepublishOnly` bundling. `npm pack` produces a package with `substrate/` populated per lite-manifest. No consumer-side changes; `bassclef init` still writes only 3 files. Adopters see nothing new until Option b lands. Safe walking-skeleton per Beck.

Scope:
- `package.json` `files:` array adds `substrate/**`
- `scripts/prepublish-bundle-substrate.mjs` — reads `bassclef-upstream/lite-manifest.json`; copies files by path into `substrate/`
- `.gitignore` lists `substrate/` (populated at publish, not committed)
- Tier 0 tests — fresh `npm pack`; unpack; verify 146 files land at expected paths; SHA256 matches source
- Requirement R-NPM-015 in registry — bundle contains manifest scope
- ADR-006 pins the bundle contract

### Option b — Phase 1 + Phase 2 combined (~300-500 turns)

Ships both bundling AND consumption. `bassclef init` copies substrate to adopter `.claude/` on install. `bassclef sync` walks the extended manifest. Full adopter-visible shift in one PR. Recommended shape per operator's ask (Sam magic demo end-to-end).

Scope adds to Option a:
- `src/lib/copy-substrate.ts` — deep module hiding `substrate/` walk + per-file `writeSafely` per @luminary john-ousterhout
- `src/commands/init.ts` extended to dispatch `copy-substrate` after config-file step
- Init manifest schema extended — enumerate all installed files with content_hash + template_version
- `src/commands/sync.ts` classifier walks extended manifest — Current / NeedsUpdate / Edited / Deleted per file (existing shape)
- Tier 0 tests — fresh temp dir + `bassclef init` + verify files land at adopter paths + verify subsequent `sync` no-op
- Adopter manifest migration path — old adopter manifest (2-file scope) upgrades cleanly to new (146-file scope)

### Option c — Split into two /longrun sessions

Session 1 ships Option a (bundling). Session 2 ships Phase 2 (consumption). Smaller sessions; slower ship; needs a hold-back plan so Phase 1 sits in a pre-release version until Phase 2 catches up.

## Steps table (per Option b — recommended)

| Step | Produces | Consumes | Time budget |
|---|---|---|---|
| 0 prep | goal doc + gate markers + `/pre-mortem` light with 3-lens set (Ousterhout + Parnas + Nygard) | — | 20 turns |
| 1 use-case | `docs/use-cases/UC-npm-lite-substrate-bundling.md` (fully-dressed per Cockburn) | prep outputs | 30 turns |
| 2 decompose | `docs/decompositions/2026-08-28-npm-lite-bundling.md` with `@pattern` calls | UC-*.md | 30 turns |
| 3 ADR | `docs/adrs/ADR-006-npm-lite-substrate-bundling.md` — pins Shape A layered under Shape D | decomposition | 20 turns |
| 4 Tier 0 tests | `tests/harness/prepublish-bundle.test.ts` (Beck RED) + `tests/harness/copy-substrate.test.ts` (Beck RED) | ADR-006 | 60-100 turns |
| 5 Phase 1 source | `scripts/prepublish-bundle-substrate.mjs` + `package.json` extensions | RED tests → GREEN | 50-80 turns |
| 6 Phase 2 source | `src/lib/copy-substrate.ts` + init/sync extensions | Phase 1 GREEN + RED tests | 100-150 turns |
| 7 lead-lens signoff | signoff marker + PR body | Steps 1-6 evidence | 20 turns |
| 8 closeout | session log + whereami flip + PR | signoff | 20 turns |

## Blockers to watch

- Cross-repo read of `bassclef-upstream/lite-manifest.json` at publish time — script needs a discovery path. Two options — assume `../bassclef-upstream/` sibling (matches operator machine layout) OR fetch from GitHub raw URL at publish time (network dependency at publish, not install). Pick during Step 2 decompose.
- Package size grows from 232K to ~500K-1MB per napkin math (146 small text files). Verify no size limit hit; document in ADR-006.
- Adopter migration — existing bassclef-cli adopters running the 3-file init will hit the extended sync classifier on next `bassclef sync`. Migration doc + version bump policy pin the shape.

## Acceptance

- [ ] `npm pack` produces a package with `substrate/` at expected paths (146 files matching manifest)
- [ ] Fresh temp dir + `npm install <package> + bassclef init` writes 146 files to `.claude/` etc without touching sibling
- [ ] `bassclef sync` walks extended manifest with existing classifier (Current / NeedsUpdate / Edited / Deleted per file)
- [ ] Tier 0 tests GREEN in bassclef-cli CI
- [ ] ADR-006 committed with @luminary ousterhout + parnas + nygard sign-off
- [ ] Adopter migration doc drafted (existing 3-file init adopters upgrade cleanly)
- [ ] Ready for @thebassclef/core v0.1.0 minor bump + npm publish

## Refs

- bassclef-upstream PR #1418 (MERGED 5e39053b) — verification report + plan + assembly doc + drift check as required status check
- bassclef-upstream#1417 (parent gap ticket)
- bassclef-upstream#1257 (Phase 3 runtime smoke — closes after this PR + smoke test)
- bassclef-upstream#741 (lite release infrastructure)
- bassclef-upstream/docs/plans/2026-08-28c-npm-distribution-no-symlinks.md (5-phase parent plan)
- bassclef-upstream/standards/lite-manifest-assembly.md v1.2 (definitive doc for manifest assembly)
- bassclef-upstream/docs/canvases/2026-07-19-bassclef-lite.md (Sam magic demo canvas)
- Local `docs/adrs/ADR-005-npm-distribution-architecture.md` (parent ADR for two-road split)
- Local `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` (parent goal — v0.0.2 launch)
