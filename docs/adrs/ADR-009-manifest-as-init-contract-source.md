---
tier: standard
id: ADR-009
title: Wiring manifest is the init contract source at cli side
status: accepted
date: 2026-09-13
accepted: 2026-09-13
accepted_via: Step 1 of goal 2026-09-13 cli#68 Phase 1 authors this ADR; Step 2 amends ADR-002 file-list; Step 3 amends ADR-005 Sam demo acceptance; Step 4 amends ADR-007 with delta section citing this ADR.
supersedes: null
superseded_by: null
extends: [ADR-002, ADR-005, ADR-007]
authoring_luminaries:
  primary: [michael-nygard]
  supporting: [vaughn-vernon, alan-cooper, linus-torvalds]
lead_lens: michael-nygard
goal: docs/iteration-bets/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md
step: 1
references:
  - {type: adr, id: ADR-055, anchor: bassclef-upstream — reader-side contract with D1-D7 pins; this ADR cross-cites D1-D7 by number}
  - {type: adr, id: ADR-051, anchor: bassclef-upstream — Consumers section names cli MUST/MUST-NOT rules}
  - {type: coord, id: docs/coordination/2026-09-12e-cli-boundary.md, anchor: bassclef-upstream — Cockburn UC-init + Jacobson BCE + GRASP roles}
  - {type: adr, id: ADR-002, anchor: bassclef-cli init safety contract; file-list amended in the same PR}
  - {type: adr, id: ADR-005, anchor: bassclef-cli two-road distribution; Sam demo acceptance amended in the same PR}
  - {type: adr, id: ADR-007, anchor: bassclef-cli npm-lite substrate bundling; Acceptance delta added in the same PR}
  - {type: ticket, id: 68, anchor: cli-side ADR + OOAD updates}
  - {type: ticket, id: 73, anchor: umbrella plan tying #68 + #25 + init walker + smoke}
---

# ADR-009 — Wiring manifest is the init contract source at cli side

## Sources read

- bassclef-upstream `architecture/decisions/ADR-055-wiring-manifest-as-init-contract.md` L1-140 — D1-D7 reader-side contract
- bassclef-upstream `architecture/decisions/ADR-051-lite-extract-split-and-wiring-manifest-rename.md` Consumers section — cli MUST/MUST-NOT rules
- bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` — Cockburn UC-init + Jacobson BCE + GRASP
- cli#73 body — 4-phase execution plan
- cli#68 body — 6 doc edits named
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` L1-98 — current file-list contract (3 files)
- `docs/adrs/ADR-005-npm-distribution-architecture.md` — current Sam demo acceptance criterion
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` L58-135 — current bundle path contract

## What I'm NOT reading (with reason)

- Full RFC-0002 body — cited by ADR-055 references; findings folded into D1-D7 already
- bassclef-upstream `standards/bassclef-wiring-manifest.schema.json` — schema owned upstream; this ADR cites its role via ADR-055 D2

## Context

`@thebassclef/lite@0.1.x` shipped with an empty hooks block in `.claude/settings.json`. Every cold adopter since 0.1.0 saw `bassclef init` write an empty template. No hook fired at session-start. The class reproduced on every install (cold-adopter test PDF 2026-09-12 confirmed).

Root cause per bassclef-upstream ADR-055 §Context — the cli init path pivoted twice (ADR-005 → ADR-007) without re-verifying the file-list acceptance criterion. Cli filled the wiring gap with an empty template because there was no upstream contract to read.

Bassclef-upstream 12e (shipped at v0.39.0 with tag `6cdff4a4`, three PRs merged 2026-09-13) closed that gap:

- **PR 1 (bassclef-upstream#1615)** — schema at `standards/state-spine/schemas/bassclef-wiring-manifest.schema.json` + build step at `scripts/build-adopter-tree.sh`
- **PR 2 (bassclef-upstream#1616)** — dist templates + Feathers parity test at `.claude/hooks/tests/init-output-parity.test.sh`
- **PR 3 (bassclef-upstream#1617)** — ADR-055 (this ADR's authority) + ADR-051 Consumers section (cli rules) + UC-script-1330 path scope

The wiring manifest at bassclef-upstream `standards/bassclef-wiring-manifest.json` is now the authored source of truth for what cli init writes. Bassclef-upstream ADR-055 D1-D7 pin the reader-side contract. This ADR binds the cli side to that contract.

Forces at play:

- **Adopter contract lives at the manifest.** Per Vernon anticorruption discipline, the manifest IS the ACL between substrate authoring decisions and cli init behavior. Cli must not compose its own settings.json.
- **Sam sees the delta immediately.** Per Cooper Sam persona, silent success (empty hooks + no banner) reproduces the failure this class of goals cures. Cli must print `N hooks armed (<tier> tier)`.
- **Adopters keep working.** Per Linus (bassclef-cli) `.claude/rules/we-dont-break-adopters.md`, existing 0.1.x adopters must have a documented upgrade path. Existing safety invariants (refuse-overwrite, path-scoping) preserve unchanged.
- **Contract survives future pivots.** Per Nygard ADR lifecycle, this ADR pins the source of truth so the next Road 1 refactor cannot silently drop acceptance criteria again.

Alternatives considered:

1. **Cli composes its own settings.json from templates.** Rejected — reproduces the class that ADR-055 was authored to cure. See bassclef-upstream ADR-055 §Alternatives Alt A.
2. **Cli reads the manifest AND filters at runtime.** Rejected — upstream build step already emits tier-filtered `dist/<tier>/`. Runtime filter duplicates work + splits the tier decision across two places. Per Ousterhout deep-module discipline.
3. **Cli infers the tier from the installed package name.** Rejected — `dist/<tier>/` per-tier directory already carries the resolved tier decision. Cli reads the directory that matches the installed package.
4. **Extend cli-side ADR-002 without a new ADR.** Rejected — the manifest-as-authority decision cuts across ADR-002 (file-list), ADR-005 (Sam demo acceptance), and ADR-007 (bundle path). A new ADR at the crossroad reads better than four cross-references.

## Decision

The cli side honors 7 decisions cross-citing bassclef-upstream ADR-055 D1-D7. Each decision below matches ADR-055's corresponding D by number. Cli implementation ships per bassclef-cli#68 (Phase 1 OOAD) + bassclef-cli#25 (Phase 2 publish workflow) + Phase 3 init walker code.

### Decision 1 — Manifest is the sole authored source

Cli init MUST read the wiring manifest at `node_modules/@thebassclef/<tier>/dist/<tier>/standards/bassclef-wiring-manifest.json` as the sole authored source of truth for what to write to adopter `.claude/settings.json`.

Cli init MUST copy `dist/<tier>/.claude/settings.json` verbatim from the bundled tarball. Cli init MUST NOT compose its own settings.json. Cli init MUST NOT filter entries by tier at runtime — upstream did that at build time via `scripts/build-adopter-tree.sh`.

Per bassclef-upstream ADR-055 D1.

### Decision 2 — Read exactly 5 authored fields per hook entry

Cli init MUST read only the 5 pinned fields per entry — `id + hook + event + matcher + tier`. Nothing else. Walker output stays out. Computed hashes stay out. Extension fields stay out until a documented adopter ask lands.

Per bassclef-upstream ADR-055 D2 + Parnas information hiding + Hyrum observable-behavior discipline.

### Decision 3 — Entries iterate in array order

Cli init MAY assume entry order is commit-stable across manifest versions within the same major schema version. Cli init MAY iterate the ordered array in write order. Rename any field OR reorder entries in a non-commit-stable way — that is a breaking change per bassclef-upstream ADR-055 D3 + bassclef-cli `.claude/rules/we-dont-break-adopters.md` (ADR-031 discipline mirrored at cli side).

### Decision 4 — Fail loudly on missing or incompatible manifest

Cli init MUST fail loudly when the manifest is missing at the expected path OR when `schema_version` major is incompatible with the version cli was built for.

Silent skip is NOT acceptable. Sam MUST see a structured error naming:

- The path expected (`node_modules/@thebassclef/<tier>/dist/<tier>/standards/bassclef-wiring-manifest.json`)
- The schema_version required (currently major `2.x` per ADR-055)
- One remediation command (e.g., `npm install @thebassclef/<tier>@<latest>`)

This is a behavior change from prior cli init, which silently wrote an empty template. Phase 3 code lands the fail-loud path per bassclef-upstream ADR-055 D4.

### Decision 5 — Print hook-count banner after write

Cli init MUST print a hook-count banner after writing `.claude/settings.json`.

Banner shape: `N hooks armed (<tier> tier)`.

Sam reads the banner + sees the delta immediately. If N is 0, Sam sees N is 0. Silent success (empty hooks + no banner) reproduces the failure this class of goals cures.

Per bassclef-upstream ADR-055 D5 + Cooper Sam persona.

### Decision 6 — Schema field renames are breaking changes

Adding new optional fields to the manifest is safe (additive). Renaming any field OR removing any field is a Hyrum-class break and requires the full compat-shim + ledger + adopter changelog discipline at bassclef-upstream side.

Cli side responsibility: read fields by exact name from ADR-055 D2 (`id + hook + event + matcher + tier`). Any manifest that renames these fields breaks cli init. Cli surfaces the break via D4's fail-loud path — Sam sees which field cli expected + what was present.

Per bassclef-upstream ADR-055 D6 + bassclef-cli `.claude/rules/we-dont-break-adopters.md`.

### Decision 7 — Tier hierarchy: ultra ⊇ standard ⊇ lite

Cli reads whichever `dist/<tier>/` directory matches the installed package tier. Package `@thebassclef/lite` reads `dist/lite/`. Package `@thebassclef/standard` reads `dist/standard/`. Package `@thebassclef/ultra` reads `dist/ultra/`.

Ultra tier includes all standard entries plus ultra-only entries. Standard tier includes all lite entries plus standard-only entries. Lite tier is the base.

Upstream build step per bassclef-upstream ADR-055 D7 honors this hierarchy via the `tier_superset()` function. Cli reads the resolved tree without runtime filtering.

## Consequences

### Positive

- **Cold-adopter empty-hooks class cured at Phase 3 ship.** Cli init walks a populated tree; the manifest names 62 entries at current v0.39.0 shape. Session-start hooks fire on next Claude Code open. First install-time regression cure since ADR-007 pivot.
- **Cli init logic stays a deep module.** No settings composition. No runtime tier filter. Cli reads + copies + prints banner. Deep interface per Ousterhout.
- **Contract survives future refactors.** This ADR pins the source of truth. Next Road 1 pivot cannot silently drop acceptance criteria — cli-side ADR-005 §Sam-demo acceptance + this ADR + upstream ADR-055 form a three-way check.
- **Multi-target ready at cli boundary.** Homebrew, apt, vsix formulas that wrap cli reads the same `dist/<tier>/` shape via the same npm package. One reader-side contract.

### Negative

- **Cli-side implementation cost.** Phase 3 must re-author init walker + settings writer + hook-count banner. Estimated 60-100 turns per goal 2026-09-13 cli#68 Phase 1 goal doc §Steps.
- **Adopter migration on upgrade.** Existing adopters on `@thebassclef/lite@0.1.x` (empty hooks) must upgrade to the new package version to receive the fix. Migration path: `npm install @thebassclef/lite@<new-version>` + re-run `bassclef init`. Refuse-overwrite invariant per ADR-002 preserved.
- **Cli release coupling to upstream release.** Cli init depends on upstream shipping `dist/<tier>/` in the bundled substrate. If upstream ships a schema major bump (v2 → v3), cli must ship a corresponding release that reads the new shape. Managed via D6 + bassclef-cli `.claude/rules/we-dont-break-adopters.md`.

### Risks

- **Cli reads unpinned manifest fields.** Cli tooling may inspect fields not pinned in D2 (walker hash, entry order, mtime). Cure: this ADR pins D2's 5-field cap. Any observed dependency triggers a follow-on ticket to either pin the field officially OR remove the cli-side read.
- **Cli init silent-fail regression.** Cli implementation may skip D4's fail-loud requirement under CI pressure. Cure: Phase 3 test suite copies bassclef-upstream `.claude/hooks/tests/init-output-parity.test.sh` as characterization for cli init postcondition; Beck TDD RED first.
- **Tier misclassification at package boundary.** Adopter installs `@thebassclef/lite` but expects standard-tier hooks. Cure: `@thebassclef/<tier>` package name IS the tier decision; cli reads `dist/<tier>/` matching the installed package. No fallback.

## Refs

- bassclef-upstream ADR-055 (reader-side contract)
- bassclef-upstream ADR-051 Consumers section
- bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md`
- bassclef-cli ADR-002 (file-list — amended in Step 2 of this goal)
- bassclef-cli ADR-005 (two-road — amended in Step 3 of this goal)
- bassclef-cli ADR-007 (bundling — Acceptance delta added in Step 4)
- bassclef-cli#68 (Phase 1 ADR + OOAD updates)
- bassclef-cli#25 (Phase 2 publish workflow)
- bassclef-cli#73 (parent plan)
- @luminary michael-nygard — ADR lifecycle across pivots (lead)
- @luminary vaughn-vernon — anticorruption at manifest boundary
- @luminary alan-cooper — Sam persona (D5 banner)
- @luminary linus-torvalds — adopter invariant preservation (D6 + safety invariants)
