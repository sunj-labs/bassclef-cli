---
tier: standard
id: ADR-007
title: Pin the npm-lite substrate bundling contract — substrate/ in package + Strategy manifest source + adopter migration semantics + 0.1.0 minor bump
status: accepted
date: 2026-08-28
accepted: 2026-08-28
accepted_via: Step 3 of goal 2026-08-28d authors this ADR; Step 5-6 code ships the contract; Step 7 signoff runs grep audit against ledger.
supersedes: null
superseded_by: null
authoring_luminaries:
  primary: [john-ousterhout, david-parnas]
  supporting: [michael-nygard, michael-feathers, kent-beck, alan-cooper]
lead_lens: john-ousterhout
goal: docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md
step: 3
references:
  - docs/decompositions/2026-08-28-npm-lite-bundling.md
  - docs/use-cases/UC-npm-lite-substrate-bundling.md
  - docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md
  - docs/adrs/ADR-001-npm-package-build-toolchain.md
  - docs/adrs/ADR-002-bassclef-init-safety-contract.md
  - docs/adrs/ADR-003-bassclef-sync-safety-contract.md
  - docs/adrs/ADR-005-npm-distribution-architecture.md
---

# ADR-007 — Pin the npm-lite substrate bundling contract

## Context

`@thebassclef/core@0.0.2` writes 3 config files at `bassclef init` and stops. Adopters need 146 substrate files (skills + rules + hooks + luminaries + agents + standards + ADRs + libs + scripts + templates + presence + root-docs) to actually run bassclef. Canvas amendment on 2026-07-27 retired the tarball path and locked npm-native distribution. This ADR pins the 6 decision points Steps 5-6 code must honor.

Forces at play:

- **Adopter contract is at the boundary.** Per Ousterhout, Sam sees a shallow CLI surface (`init` + `sync`). The bundling + copy + migration path hides depth. Any decision that exposes bundle layout to consumer code violates the depth invariant.
- **Information hiding matters at the manifest.** Per Parnas, the manifest schema is the interface between build and adopter. Raw JSON reads outside a typed module leak schema across every call site. Any decision that skips the wrapper defeats R4.
- **Fail-fast at publish time.** Per Nygard, silent-degrade at publish ships broken tarballs to real adopters. Any decision that allows partial substrate to reach the tarball violates R7.
- **Adopter migration is the highest blast risk.** Per R8, existing 0.0.2 installs must upgrade to 0.1.0 without data loss on their config files. Any decision that touches the existing 3 files during migration violates the contract.
- **Package size cost.** Per napkin math, 146 small text files add roughly 500K-1MB to the tarball. Below the 50MB npm limit; not below imaginary limits. R9 pins a 5MB ceiling as a safety envelope.

Alternatives considered:

1. **Ship substrate as separate npm package** (`@thebassclef/lite-substrate`) that `@thebassclef/core` depends on. Rejected — adopter now installs 2 packages; version drift between them becomes a live risk; goal doc pinned single-package shape per canvas.
2. **Fetch substrate over network at `bassclef init` time.** Rejected — install-time network dependency; adopter machine offline OR firewall-blocked breaks first-touch; Sam bounces per Cooper.
3. **Copy substrate at `bassclef sync` time, not init.** Rejected — adopter has no substrate after `bassclef init` completes; `bassclef sync` never called by many adopters (per UC frequency section); Sam's 5-minute install window empty of substrate.
4. **Include manifest at publish time but not source files** (adopter fetches source per-file on first sync). Rejected — same network dependency problem as (2); split contract adds a failure mode.
5. **Symlink substrate from a global npm-installed cache dir.** Rejected — cross-platform symlink semantics differ; adopter edits break silently; Sam expects real files under her tree.

## Amendment 2026-08-29 — RFC-0001 disposition (scope-b1)

RFC-0001 council review (5 outside luminaries) accepted 2026-08-29 with disposition revised B. Impact on this ADR:

**REMOVED:**
- **Decision 2** (Strategy pattern for manifest source) — per RFC finding B3 (YAGNI). Prepublish uses sibling checkout only. `BASSCLEF_MANIFEST_URL` env var not supported in 0.1.0. RemoteFetchStrategy restoration deferred to scope-e when CI need surfaces + with S1 signature verification.
- **Decision 5** (sync migration semantics — Path A) — per RFC finding B1 (second-system effect). Migration ships as scope-e (next /longrun; possibly a `bassclef migrate` subcommand). 0.0.2 adopters run `bassclef init --force` until scope-e ships.

**AMENDED:**
- **Decision 1** — bundle path `substrate/<path>` becomes explicitly semver-locked (H3 cure). Additive changes OK; rearrangements are MAJOR.
- **Decision 3** — Prepublish safety envelope loses the "strategy selection" step. Sibling manifest missing is the only failure mode; still fails fast (R7).
- **Decision 4** — Init copy adds two behaviors — per-directory progress line as each directory completes (N1 cure) + error messages that name the fix not the cause (N2 cure).

**ADDED:**
- **Decision 5-cure** (sync output shape) — per L2. Default output is per-directory summary. `--verbose` shows per-file. Preserves adopter scripts binding to 0.0.2 output shape.
- **Decision 7** (manifest schema evolution) — per H1. Init manifest schema is semver-locked. Add-only; never remove fields. Schema version bumps at MINOR when fields added; MAJOR when fields removed OR types change.

Original decisions D2 and D5 below preserved for audit trail. Both marked `SUPERSEDED (scope-b1)` inline. Refer to RFC-0001 disposition table for the full mapping of RFC findings to cure locations.

## Decision

The npm-lite substrate bundling contract for `@thebassclef/core@0.1.0` and every subsequent iteration.

### Decision 1 — Bundle mechanism

`@thebassclef/core` includes a `substrate/` directory at the package root. `substrate/` carries all 146 files from the tier:lite manifest per `bassclef-upstream/lite-manifest.json`. Layout matches the source tree — `substrate/.claude/hooks/foo.sh` mirrors `bassclef-upstream/.claude/hooks/foo.sh`.

Bundling runs via `package.json` `scripts.prepublishOnly` — hook fires on `npm publish` before `npm pack` collects files. The prepublish script writes `substrate/` locally; `npm pack` includes it per the extended `files:` whitelist.

`substrate/` is gitignored — it exists only during publish + install; never committed. This matches the ADR-001 invariant that only build outputs (not source) ship in the package.

Rationale — Ousterhout deep module. Sam's install path stays two commands. Bundle mechanism hides inside prepublish. R1 compensator lives at `src/lib/copy-substrate.ts` (one public method).

### Decision 2 — Manifest source discovery via Strategy pattern (SUPERSEDED scope-b1 per RFC B3)

**Note (2026-08-29):** SUPERSEDED. Sibling checkout is sole manifest source in 0.1.0. See Amendment section at top for rationale. Text below preserved for audit trail.

Prepublish script picks manifest source at runtime via Strategy:

- **Default** — sibling checkout at `../bassclef-upstream/lite-manifest.json`. Matches operator machine layout observed at whereami L2.
- **Override** — env `BASSCLEF_MANIFEST_URL=<raw-url>` opts into remote fetch from GitHub raw content. For CI + fresh machine scenarios.

Both strategies implement one interface — `loadManifest(): LiteManifest`. Callers never see which strategy fired.

Ruled out:
- Auto-fallback (sibling → fetch) — hides failure mode; obscures which source shipped; Nygard bulkhead violation
- Fetch-only — network dependency at every publish; brittle
- Sibling-only — no escape hatch for CI

Rationale — Parnas information hiding + Nygard fail-fast. Strategy hides source choice from prepublish logic. Both strategies fail fast when source unreachable (R7 compensator). `@pattern` per decomposition Q0.

### Decision 3 — Prepublish safety envelope

The prepublish script fires 3 checks that must all pass before `substrate/` is considered complete:

1. **Manifest load** — Strategy returns a manifest with ≥ 1 entries; fail nonzero on empty or unreachable source
2. **Preflight — source existence** — every entry's source file exists at expected path; fail nonzero on first missing
3. **Postflight — count + size** — `substrate/` contains exactly `manifest.entries.length` files AND total size < 5MB; fail nonzero on any mismatch

Any check failing exits the script nonzero. `npm publish` aborts. No partial substrate reaches the tarball.

Rationale — Nygard bulkhead (R7 + R9 compensators). Fail fast at publish beats debugging silent-empty tarball later.

### Amendment 2026-08-30 — mechanism change (issue #40 cure)

The original D1 text and this D3 text both said "Bundling runs via `package.json` `scripts.prepublishOnly` — hook fires on `npm publish` before `npm pack` collects files." That claim is **wrong** and pre-launch /architect-review caught it (issue #40).

Per npm docs, `npm publish --ignore-scripts` skips ALL lifecycle scripts including `pre*` hooks. ADR-004 §D3 mandates `--ignore-scripts` on publish (belt-and-suspenders against arbitrary script execution from transitive deps). The two ADRs contradicted each other silently: adopters would install `@thebassclef/core@0.1.0+` and get an empty 8-file tarball with no `substrate/`.

**New mechanism (post-#40):** Bundling runs as an **explicit workflow step** in `.github/workflows/publish.yml` — `node scripts/prepublish-bundle-substrate.mjs` runs as an ordinary node process, not as a lifecycle hook. Both `checks` and `publish` jobs run the step before pack + publish see the tarball.

**Additional safety (Saltzer-Schroeder complete mediation):** the checks job now asserts `substrate/` file count ≥ 100 in the pack dry-run output. Any future regression fails at checks time, before the environment approval fires.

The 3 preflight/postflight checks inside `prepublish-bundle-substrate.mjs` are unchanged and still fire under the new mechanism.

**Prerequisite for the new mechanism:** the workflow clones `sunj-labs/bassclef-upstream` as a sibling (`../bassclef-upstream`) so the script resolves it via default heuristic. This requires a `BASSCLEF_UPSTREAM_TOKEN` repo secret (PAT with read scope on the private upstream repo). Operator setup is one-time.

The `prepublishOnly` entry in `package.json` L49 is retained for the local-publish path (developer running `npm publish` from their machine without `--ignore-scripts`) but is no longer load-bearing for the CI publish.

### Decision 4 — `bassclef init` copy semantics

`bassclef init` at v0.1.0 dispatches `copySubstrate(targetDir, options)` after config files land. Copy semantics inherit from UC-init:

- **Default deny on existing** — any target substrate file already present at the adopter's path is refused (not overwritten). Result reports per-file `refused` count.
- **`--force` overrides** — same flag semantics as config-file overwrite (per ADR-002 D1). Existing files replaced.
- **Symlink refusal unconditional** — even under `--force`, symlink at target path refused via `O_NOFOLLOW`. Same rule as ADR-002 D3.
- **Bundle hash verification** — each source file's SHA-256 is verified against the bundled manifest entry BEFORE writing. Mismatch aborts that file with `errored` status (R7 fallback).
- **Dry-run supported** — `--dry-run` at init prints per-directory `would copy: N` counts without writing.

All writes go through `writeSafely()` from existing `src/lib/write-safely.ts` (R3 compensator; helper already exists from WU-2 init work — `copySubstrate` imports it, not re-implements). ADR-002 safety envelope preserved end-to-end.

Rationale — reuse existing safety contract. Adopter sees consistent semantics whether copying config or substrate. No new safety surface to reason about.

### Decision 5 — `bassclef sync` migration semantics (SUPERSEDED scope-b1 per RFC B1)

**Note (2026-08-29):** SUPERSEDED. Migration Path A deferred to scope-e (next /longrun). 0.1.0 sync walks the 149-entry manifest with existing classifier only; no legacy detection; no migration. See Amendment section at top. Text below preserved for audit trail.

`bassclef sync` at v0.1.0 detects legacy manifest via `detectLegacyManifest()` — new function added to existing `src/lib/manifest-io.ts` module (not a new file; extends the module that already handles read/write per WU-2 init work). Two paths:

**Path A — legacy manifest present (adopter upgrading from 0.0.2 to 0.1.0):**

1. Compute SHA-256 of each existing config file (3 entries per legacy shape)
2. Record hashes in the new 149-entry manifest — preserves classifier ground for existing files
3. Dispatch `copySubstrate(targetDir, {force: false})` — adds 146 new substrate files with default deny on existing
4. Rewrite `.bassclef/init.manifest.json` to 149-entry shape
5. Report `146 files added; 3 files preserved with computed hashes; <N> refused (already present)`

**Path B — current manifest present (adopter on 0.1.0 running sync normally):**

Existing sync classifier walks 149 entries (unchanged shape from UC-sync). Per-file Current / NeedsUpdate / Edited / Deleted classification. No migration path fires.

Rationale — R8 compensator. Existing 3 config files never touched during migration. New 146 files added with same safety envelope as init. Adopter upgrade path documented at `docs/migrations/0.1.0.md`.

### Decision 6 — Version bump + release cadence

This work ships as `@thebassclef/core@0.1.0` — minor bump per semver.

Justification per semver:
- MINOR — new backward-compatible functionality (init writes 146 more files; sync walks extended manifest; existing 0.0.2 adopters upgrade cleanly via Path A)
- Not MAJOR — no breaking API change; CLI verb shapes preserved; exit code semantics preserved
- Not PATCH — this is not a bug fix; the extended manifest is a new capability

Release cadence — one release per goal completion. This goal ships one release: 0.1.0. Subsequent iterations may ship patch versions (0.1.x) for bug fixes without re-invoking this ADR.

Rationale — matches the semver methodology at `standards/npm-versioning-and-changelog.md`. Adopter migration doc names the version explicitly so `bassclef sync` output can direct to it.

## Status

`accepted` on 2026-08-28 via Step 3 of goal 2026-08-28d. Ratified by Step 7 signoff (grep audit against ledger) + Step 8 closeout (PR body pins the ADR).

## Consequences

**Easier:**

- Sam runs 2 commands and gets a working bassclef. First-touch friction drops to zero.
- Extended manifest shape becomes the contract for standard+/ultra tiers per ADR-005 two-road split.
- Adopter upgrade from 0.0.2 to 0.1.0 is a one-command flow (`npm install -g @thebassclef/core && bassclef sync`).
- Every publish carries a documented fail-fast gate. Empty or partial substrate never ships.

**Harder:**

- Prepublish script depends on sibling checkout OR env-set URL. Fresh CI machine needs one or the other; documented in `docs/migrations/0.1.0.md`.
- Package size grows from 232K to roughly 500K-1MB. Below 5MB safety ceiling; below 50MB npm limit; not free.
- 27 Tier 0 tests added at Step 4. Test-suite runtime grows; CI cost per push grows slightly.
- Adopter migration path (Path A above) adds ~40 lines to `sync.ts`. Small; readable; still net-new surface to maintain.

**Enables:**

- Standard+ tier via `@thebassclef/standard` package — same prepublish pattern, standard-tier manifest input; ADR-005 contract holds.
- Ultra tier via `@thebassclef/ultra` package — same shape; larger manifest.
- Bundling a subset for domain-specific installs (e.g., "just the /longrun skill + its deps") via manifest filter — future extension; no shape break.
- Adopter opt-in auto-upgrade — `bassclef sync --check-updates` at start of every session. Future extension.

**Blocks (until reconsidered):**

- No macOS-only or Windows-only bundling in this goal. POSIX-only path resolution per existing UC-init constraint. Cross-platform is a follow-on.
- No per-adopter manifest customization. Every 0.1.0 install gets the full 146 files. Selective install is future work.
- No manifest signing / provenance verification beyond npm's built-in provenance (per ADR-004). Signed manifests are a possible v0.2 extension.

**Invariants established (semver-locked for 0.1.0 and beyond):**

Bundle mechanism:
- `substrate/` at package root — rename requires ADR amendment
- Populated at prepublish only — never committed to git
- Layout matches source tree — 1:1 path correspondence

Manifest source:
- Sibling default at `../bassclef-upstream/lite-manifest.json`
- Env override `BASSCLEF_MANIFEST_URL` — variable name is stable
- Both strategies implement `loadManifest(): LiteManifest` — interface stable

Prepublish safety:
- 3 checks (manifest load, preflight source existence, postflight count + size) — removing a check is a MAJOR bump
- Adding a check is a MINOR bump
- 5MB size ceiling — raising it is a MINOR bump; lowering is MAJOR

Init copy semantics:
- Default deny + `--force` override + unconditional symlink refusal — inherits ADR-002; changes require ADR-002 amendment
- Bundle hash verification before write — removing is MAJOR
- Dry-run per-directory summary shape — output format is user-facing; changes are MINOR

Sync migration semantics:
- Legacy detection triggers Path A once per upgrade — the detection function shape is stable
- Existing config file hashes computed + preserved during migration — removing this preservation is MAJOR
- Migration doc at `docs/migrations/0.1.0.md` — path stable; content amendable

Version:
- 0.1.0 is this goal's ship version. Patches (0.1.x) may ship without ADR re-invocation.
- 0.2.0 or later requires a follow-on ADR if it changes any invariant above.

Any change to a listed decision, safety check, or invariant is a MAJOR bump under the `@thebassclef/core` package version per `standards/npm-versioning-and-changelog.md`.

## Traceability to risk ledger

Every decision above pins to at least one risk ledger row. Every ledger row has at least one decision.

| Decision | Ledger rows honored |
|---|---|
| D1 — Bundle mechanism | R1 (one public method), R5 (consumer walks manifest not filesystem) |
| D2 — Strategy manifest source | R7 (fail-fast on missing) |
| D3 — Prepublish safety envelope | R7 (missing manifest) + R9 (size ceiling) |
| D4 — Init copy semantics | R3 (shared writeSafely) + R7 fallback (hash verification) |
| D5 — Sync migration semantics | R8 (adopter migration path) |
| D6 — Version bump + release cadence | R8 (documented upgrade doc) |

R2 (no execSync in prepublish) + R4 (extended manifest-io module with legacy detection) + R6 (path constants module) live in decomposition § Control objects; not ADR-level decisions because they're code shape rather than adopter contract.

**Correction landed at Step 4 preflight** — R3 and R4 build targets amended in ledger v2 to reference EXISTING `src/lib/write-safely.ts` and EXISTING `src/lib/manifest-io.ts` (both shipped by WU-2 init work per `tests/write-safely.test.ts` L26 + `tests/manifest-io.test.ts` L18-23). Original decomposition text mislabeled both as "new file"; extension approach preserves the ADR-002 complete-mediation invariant already established by those modules.

## References

- Goal doc — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md`
- Decomposition (Step 2) — `docs/decompositions/2026-08-28-npm-lite-bundling.md`
- Fully-dressed UC (Step 1) — `docs/use-cases/UC-npm-lite-substrate-bundling.md`
- Risk ledger v1 — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` (extended to v2 at Step 3.5)
- ADR-001 — build toolchain + files whitelist (substrate/ added to whitelist under Decision 1)
- ADR-002 — init safety contract (D4 inherits the envelope)
- ADR-003 — sync safety contract (D5 extends with migration path)
- ADR-005 — two-road split (@thebassclef/core is the lite vehicle; standard+/ultra reuse the shape)
- `bassclef-upstream/standards/lite-manifest-assembly.md` v1.2 — definitive contract for manifest content
- `bassclef-upstream/docs/plans/2026-08-28c-npm-distribution-no-symlinks.md` — 5-phase parent plan; 14-lens vote (A 12, D 3)
- Luminaries:
  - `john-ousterhout.md` — deep modules; D1 + D4 hide depth
  - `david-parnas.md` — information hiding; D2 Strategy + D5 legacy detection
  - `michael-nygard.md` — fail-fast; D3 bulkhead
  - `michael-feathers.md` — characterization tests pin the contract at Step 4
  - `kent-beck.md` — TDD rhythm; Step 4 RED before Step 5-6 source
  - `alan-cooper.md` — Sam's 5-minute install window; D1 preserves it
