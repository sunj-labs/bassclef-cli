---
tier: project
title: UC-init-lite-catalog — bassclef init lays down the full lite catalog
uc_id: UC-init-lite-catalog
level: fully-dressed (Cockburn) — adopter-observable app code path per .claude/rules/oo-ad-entry-point.md
goal: docs/iteration-bets/2026-09-16-cli-1.1.0-lite-catalog.md
risk_ledger: docs/risk-ledgers/2026-09-16-cli-1.1.0-lite-catalog.md
date: 2026-09-16
authoring_luminaries:
  primary:
    - alistair-cockburn
  supporting:
    - linus-torvalds
    - jerome-saltzer-and-michael-schroeder
    - michael-nygard
---

# UC-init-lite-catalog

## Sources read

- Goal doc + risk ledger + decomposition (this session)
- `.claude/rules/oo-ad-entry-point.md` — Cockburn ceremony matrix; adopter app code = fully-dressed
- `src/commands/init.ts` — existing init command shape
- `src/lib/copy-substrate.ts` L143-150 — walker loop; 1.0.4 dual-scope seam
- `lite-manifest.json` schema at bassclef-upstream — entry shape

## Scope

`bassclef init` command, invoked on a fresh adopter repo, after `npm install -g @thebassclef/lite@1.1.0`.

## Primary actor

**Sam** (cold adopter). Solo builder. First-week user of bassclef. Wants to ship one feature. Reads on laptop or phone.

## Stakeholders and interests

| Stakeholder | Interest |
|---|---|
| Sam (adopter) | Runs `bassclef init` once, gets a working substrate with skills, rules, agents, luminaries on disk |
| Operator (sunj-labs) | Ships what the tier tag promises; adopters don't hit "skill not found" errors |
| Future adopters | Any file laid down at 1.1.0 stays at the same path in 1.1.1+ (Hyrum contract) |
| bassclef-upstream substrate authors | Manifest changes at v1.6.2+ ship the same shape to cli builds |

## Preconditions

- Node 20+ available
- `@thebassclef/lite@1.1.0` installed globally via npm
- Adopter is in a git repo (or has passed `--allow-any-dir`)
- HOME env resolves to adopter's home; not /root unless `--allow-root`

## Postconditions

**Success.**
- `dist/lite/` bundle contents from the tarball land on disk per ADR-057 destination-path table
- All 292 manifest entries copied to their target paths
- Init banner reports per-type counts + refused count
- Adopter can dispatch any lite-tagged skill; every rule loads; every agent resolves; every luminary reference works

**Failure with clean exit.**
- Manifest missing → exit 4, structured stderr, no files written
- Schema major mismatch → exit 5, structured stderr
- Path collision → refused count > 0, safe partial-copy state, banner names cure

## Main success scenario

1. Sam runs `bassclef init` in a fresh directory.
2. Init reads `dist/lite/standards/bassclef-wiring-manifest.json` (schema v2, hooks routing).
3. Init reads `dist/lite/standards/lite-manifest.json` (v1.6.x, catalog entries).
4. Init walks every file under `dist/lite/`.
5. For each file:
   - Hook file → walker routes per scope map (declared) OR dual-writes (undeclared) per 1.0.4 logic
   - Non-hook file → walker routes to project scope via `classify({command: '$CLAUDE_PROJECT_DIR/' + relPath}, opts)` per ADR-057
   - `writeSafely` writes the file; refuses on `AlreadyExists` or `SymlinkRefused`
6. Init emits count banner per type from `CopyResult.copiedEntries`.
7. Init emits refused-count line if any files were refused.
8. Init exits 0.

Sam sees the banner. Runs `claude`. Types `/skills`. Sees 40 skills registered. Types `/interview-me`. Sam's magic demo path fires.

## Extensions

### 4a. Manifest missing (@risk N1)
- 4a.1. Init cannot find `dist/lite/standards/lite-manifest.json`.
- 4a.2. Init emits `CopyFailure` kind `ManifestMissing` to stderr.
- 4a.3. Stderr names cure: "Reinstall @thebassclef/lite@1.1.0 or later to restore the manifest."
- 4a.4. Init exits 4. No files written.

### 4b. Schema major mismatch (@risk RH)
- 4b.1. Manifest reports `manifest_version: 2.x` but cli built for `1.x` schema (or vice versa).
- 4b.2. Init emits `CopyFailure` kind `SchemaIncompatible`.
- 4b.3. Stderr names cure: "Upgrade cli or downgrade @thebassclef/lite."
- 4b.4. Init exits 5. No files written.

### 5a. Adopter has existing file at target path (@risk L1)
- 5a.1. `writeSafely` refuses with `AlreadyExists`.
- 5a.2. Init increments `refused[]` array.
- 5a.3. Init continues copying remaining files.
- 5a.4. Step 7 banner reports refused count.

### 5b. Symlink at target (@risk SS2)
- 5b.1. `writeSafely` refuses with `SymlinkRefused`.
- 5b.2. Stderr names readlink target of the symlink.
- 5b.3. Init increments `refused[]`; continues.

### 5c. Path traversal in manifest entry (@risk SS1)
- 5c.1. `classify()` detects `..` in entry.path.
- 5c.2. Throws `PathTraversalRefused`.
- 5c.3. Init exits 2. No further files written.
- 5c.4. Stderr names cure: "File a bug at sunj-labs/bassclef-upstream — manifest entry has invalid path."

### 5d. HOME=/root without --allow-root (@risk SS3)
- 5d.1. `resolveHome()` throws `SudoBypassRefused`.
- 5d.2. Init exits 2. No files written.
- 5d.3. Stderr names cure: "Run without sudo, or pass --allow-root."

### 5e. Adopter vendored skills (@risk L3)
- 5e.1. Same as 5a from writeSafely's perspective — `AlreadyExists` refusal.
- 5e.2. Adopter's vendored file preserved.
- 5e.3. Banner reports refused count; adopter reviews.
- 5e.4. Adopter passes `--force` to overwrite (existing 1.0.x flag).

## Special requirements

- **Determinism.** Same manifest + same bundle + same adopter repo → same file set on disk. No timestamps or random IDs in outputs.
- **Idempotent second run.** Second `bassclef init` without `--force` refuses every file (existing 1.0.4 Ext 10a behavior). All 292 entries land in refused[].
- **Cross-platform.** Works on macOS + Linux. Windows out of scope per package.json engines.
- **Mediation preserved.** Every path through `classify()`. Path traversal, home resolve, sudo bypass — all existing checks fire.

## Technology variations

- Manifest source: bassclef-upstream sibling checkout (via `BASSCLEF_SIBLING_ROOT`). No HTTP fetch in 1.1.0.
- Package manager: npm (cli only). yarn / pnpm consumers get same tarball; layout unchanged.

## Frequency

Per cold adopter — once at first `bassclef init`. Existing adopters running `bassclef init --force` for an upgrade re-runs the same flow.

## Open issues

- Should banner report refused paths in full or just count? Decided: count only, with a `--verbose` flag to list paths. Handles L2 signal without spamming Sam's terminal.
- What if manifest ships a type the walker doesn't recognize? ADR-057 table names the closed set. Unknown type → build-time preflight blocks; init-time walker refuses to route.

## References

- Goal 2026-09-16-cli-1.1.0-lite-catalog
- Risk ledger 2026-09-16-cli-1.1.0-lite-catalog
- Decomposition 2026-09-16-cli-1.1.0-lite-catalog
- ADR-057 (ships in Step 6 same PR)
- ADR-002 init safety contract (unchanged)
- ADR-056 lite-bundle self-containment (extended by ADR-057 for the catalog slice)
