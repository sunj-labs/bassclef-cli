---
tier: lite
decomposition: lite-rename-sync-publish
title: GRASP decomposition — rename+sync+publish for @thebassclef/lite@0.1.0
authored: 2026-09-07
goal: 2026-09-07-lite-rename-sync-publish
method: GRASP + Ousterhout deep-modules
authoring_luminaries:
  primary: [john-ousterhout, vaughn-vernon]
  supporting: [jerome-saltzer-and-michael-schroeder]
references:
  - {type: goal, id: docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md}
  - {type: spec, id: docs/specs/lite-rename-sync-publish.md}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-07-lite-rename-sync.md}
---

# Decomposition — lite-rename-sync-publish

## Sources read

- `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md` — goal + step chain
- `docs/specs/lite-rename-sync-publish.md` — acceptance per step + branch strategy
- `docs/risk-ledgers/2026-09-07-lite-rename-sync.md` — Ousterhout #1 drove deep-module lens; Saltzer #1 drove tarball auditor
- `scripts/prepublish-bundle-substrate.mjs` — existing substrate sync producer (deep module today)
- `src/lib/copy-substrate.ts` — bundled-manifest consumer (returns 4 result buckets — Ousterhout note in ledger)
- `.claude/rules/pattern-annotation.md` — @pattern annotation contract for named patterns

## What I'm NOT reading (with reason)

- `docs/ia-models/` — no UI surface; CLI-only work
- `.claude/luminaries/*.md` individual files — high-level lens already applied via risk ledger

## Objects and responsibilities

### 1. `SubstrateSync` (adapter) — deep module

**Responsibility:** hide the complexity of syncing `substrate/**` from upstream v1.5.0 git tag to local bundle root.

**Interface (shallow):**
- `sync(upstreamTagSha, bundleRoot) -> { syncedFileCount, manifestHash }`
- One call site (Step 2 command); returns success + integrity signal

**Implementation (deep):**
- Fetch upstream tag SHA into a temp working tree
- Read tier filter (skip `tier: upstream` files)
- Copy filtered files under `substrate/**` in bundle root
- Regenerate `substrate/.bassclef/lite-manifest.json` from the new content (compute content_hash per entry; include new `problem` + `value` fields per upstream #1480; omit `upstream_commit` per upstream #1508)
- Return summary

**Existing file:** `scripts/prepublish-bundle-substrate.mjs` — extend to handle v1.5.0 shape (no upstream_commit; problem+value additive).

**Pattern:** `@pattern patterns/code/eip/message-translator.md` (Vernon anticorruption layer — translates upstream v1.5.0 shape into bundle-consumer contract stable across versions).

### 2. `CopySubstrate` (consumer) — deep module (existing)

**Responsibility:** hide the complexity of copying bundle content into an adopter's project directory with content-hash integrity check.

**Interface (shallow — existing):**
- `copySubstrate(targetDir, { bundleRoot, force?, dryRun?, onProgress? }) -> { copied[], refused[], errored[], wouldCopy?, erroredMessages? }`

**Implementation (deep — existing):**
- Read bundled manifest at `<bundleRoot>/.bassclef/lite-manifest.json`
- For each entry — hash content, compare against `entry.content_hash`, copy if match
- Refuse if target exists (unless force)

**Ousterhout note (from risk ledger #6):** interface currently leaks 4 result buckets — pre-existing shape; not fixed this ship. Follow-on ticket if adopter feedback surfaces.

**Existing file:** `src/lib/copy-substrate.ts` — no changes needed; grep confirms zero reads of `upstream_commit`; additive fields pass through.

### 3. `TarballAuditor` (new — Saltzer #1 mitigation)

**Responsibility:** hide the complexity of verifying the publish tarball contains zero operator-private paths.

**Interface (shallow):**
- `auditTarball(tarballPath) -> { auditPassed: boolean, offendingPaths: string[] }`

**Implementation (deep):**
- Run `tar tf <tarballPath>` to list files
- Filter against forbidden-path patterns: `operator-private/`, `chronicle/`, `journals/`, `state/markers/`, `docs/session-logs/`
- Return list of offenders + boolean

**New file:** `scripts/audit-tarball.mjs`

**Tier 0 test file:** `tests/harness/tarball-cleanliness.test.ts` — asserts audit returns `auditPassed: true` on a fresh dry-run tarball; asserts audit returns `auditPassed: false` on a fixture tarball with a seeded operator-private path.

**Pattern:** `@pattern patterns/code/gof/facade.md` (simple facade over `tar tf` + grep; hides shell command complexity from the publish workflow).

### 4. `PublishAdapter` (workflow — existing)

**Responsibility:** hide the complexity of the npm publish pipeline (trusted-publisher OIDC + provenance + `--ignore-scripts` + 2FA).

**Interface (shallow — existing):**
- GitHub Actions workflow `publish.yml` fires on release published; consumes package.json name + version; publishes to npm

**Implementation (deep — existing at `.github/workflows/publish.yml`):**
- Set up Node ≥ 20 + npm ≥ 11 (per memory `feedback_npm_11_required_for_trusted_publisher`)
- Run `npm publish --provenance --access public --ignore-scripts`
- Trusted-publisher OIDC binds workflow identity to npm registry auth (no token in workflow)

**No changes needed for this goal** — same pipeline handles the second package. Step 5 verifies trusted-publisher config supports lite before Step 6 fires.

### 5. `CoordinationComment` (Step 8 — trivial)

**Responsibility:** post a comment on coord ticket #51 updating Q1 status.

**Interface:** `gh issue comment 51 --body <text>` (existing CLI).

**No new module** — one-shot CLI call in Step 8.

## Coupling and cohesion

**Low coupling (good):**
- `SubstrateSync` writes manifest; `CopySubstrate` reads it. Coupled through the manifest schema contract, not direct code call.
- `TarballAuditor` reads tarball; `PublishAdapter` writes tarball. Coupled through `tar tf` output format, not code.
- `CoordinationComment` reads goal doc content; no code coupling.

**High cohesion (good):**
- Each object owns one responsibility.
- `SubstrateSync` handles ALL substrate-refresh mechanics.
- `TarballAuditor` handles ALL publish safety scan mechanics.

## Ousterhout deep-modules analysis

Applied per pre-mortem lens 3 (Ousterhout #1 HIGH — content-hash mismatch could ship silently).

**Deep (interface + implementation match):**
- `SubstrateSync` — one call, one manifest artifact returned; upstream schema drift hidden.
- `TarballAuditor` — one call, boolean + list of offenders; grep+tar complexity hidden.

**Shallow (interface leaks implementation — do not fix this ship):**
- `CopySubstrate` returns 4 result buckets — pre-existing; not v1.5.0-specific. Ledger risk #6 says defer.

## GRASP roles

| Object | GRASP role | Rationale |
|---|---|---|
| SubstrateSync | Information Expert | Owns knowledge of upstream shape + bundle structure |
| CopySubstrate | Information Expert | Owns knowledge of manifest + hash contract |
| TarballAuditor | Pure Fabrication | New object introduced for auditing; not tied to a domain entity |
| PublishAdapter | Controller | Coordinates npm publish + trusted-publisher + 2FA gate |
| CoordinationComment | Pure Fabrication | Trivial one-shot; no domain model |

## Interfaces summary

- `SubstrateSync.sync(sha, bundleRoot) -> { syncedFileCount, manifestHash }`
- `CopySubstrate.copySubstrate(targetDir, options) -> { copied[], refused[], errored[], wouldCopy?, erroredMessages? }`
- `TarballAuditor.auditTarball(tarballPath) -> { auditPassed, offendingPaths }`
- `PublishAdapter` — GitHub Actions workflow (declarative)
- `CoordinationComment` — shell one-liner via `gh`

## Refs

- Goal: `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md`
- Spec: `docs/specs/lite-rename-sync-publish.md`
- Risk ledger: `docs/risk-ledgers/2026-09-07-lite-rename-sync.md`
- Ousterhout, J. *A Philosophy of Software Design* (2018) — deep modules
- Vernon, V. *Implementing Domain-Driven Design* (2013) — anticorruption layer
- Larman, C. *Applying UML and Patterns* (2004) — GRASP
- `.claude/rules/pattern-annotation.md` — @pattern annotation contract
