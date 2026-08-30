---
tier: standard
id: UC-npm-lite-substrate-bundling
name: Install bassclef with full substrate via npm (two commands)
level: user goal
primary_actor: Sam (adopter)
scope: bassclef-cli — `@thebassclef/core` package + `bassclef init` + `bassclef sync` (extended for lite substrate bundling)
authored: 2026-08-28
authored_by: agent
cockburn_ceremony: fully-dressed
goal: docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md
governs_source:
  - src/commands/init.ts (amended at Step 6)
  - src/commands/sync.ts (amended at Step 6)
  - src/lib/copy-substrate.ts (new at Step 6)
  - src/lib/init-manifest.ts (new at Step 6)
  - src/lib/paths.ts (new at Step 6)
  - src/lib/write-safely.ts (new at Step 6; extracted from init)
  - scripts/prepublish-bundle-substrate.mjs (new at Step 5)
  - package.json (amended at Step 5 — files array adds substrate/**)
references_adr: ADR-007-npm-lite-substrate-bundling.md (to author at Step 3)
extends_uc:
  - UC-init (extended — copies substrate after config files land)
  - UC-sync (extended — walks manifest of 149 files, not 3)
risk_ledger: docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md
---

# UC-npm-lite-substrate-bundling — Install bassclef with full substrate via npm

## Scope

Two commands land 149 files on Sam's machine:

1. `npm install -g @thebassclef/core` — package download, includes `substrate/` tree with 146 files
2. `bassclef init` — writes 3 config files (existing) AND copies 146 substrate files to Sam's `.claude/` tree (new)

Followup: `bassclef sync` walks the extended 149-file manifest for updates.

This UC extends UC-init and UC-sync. Both existing UCs get amendments at Step 6 pointing at the new behavior.

## Level

User goal. Sam completes the install in two commands, under 5 minutes, without reading docs.

## Primary actor

Sam. New adopter. Reads terminal output. Attention budget: 5 minutes on first install. Does not know what "manifest" or "substrate tree" mean at the outset — expects the tools to work without terminology.

## Stakeholders + interests

| Stakeholder | Interest |
|---|---|
| Sam | Wants a working bassclef in two commands. Wants clear output naming what landed. Does not want a sibling checkout of any repo. |
| Sam's employer | Wants no files written outside Sam's project. No root paths touched. Package auditable via `npm view`. |
| Maintainer (bassclef-cli operator) | Wants every copied file recorded with content hash. Wants prepublish to fail fast when sibling manifest missing. Wants adopter migration path from 0.0.2 to 0.1.0 documented. |
| Bassclef substrate authors | Want single source of truth (`bassclef-upstream/lite-manifest.json`) driving package contents. Want npm-native distribution — no tarball, no symlinks. |
| Existing 0.0.2 adopters | Want a clean upgrade to 0.1.0. Want their existing 3-file init preserved. Want the new 146 files added without touching their edits. |
| Future standard+/ultra tier consumers | Want the extended manifest to serve as the contract shape for higher tiers per ADR-005. |

## Preconditions

- Sam has Node.js ≥ 20 installed.
- Sam has npm access (public registry).
- `@thebassclef/core` published at version ≥ 0.1.0 (this goal's ship version).
- Sam has network access at install time.
- Sam is in a directory she wants to initialize (same as UC-init).
- Directory ownership + `--allow-root` + `--allow-any-dir` preconditions from UC-init still apply.
- Package's `substrate/` tree is populated at publish time (prepublish script ran; see R7 in ledger).

## Success guarantee (postconditions)

- `@thebassclef/core@0.1.0` (or newer) installed globally; `bassclef` binary on `$PATH`.
- After `bassclef init`:
  - 3 config files exist at their UC-init paths (unchanged behavior).
  - 146 substrate files copied to Sam's tree under `.claude/hooks/`, `.claude/skills/`, `.claude/rules/`, `.claude/luminaries/`, `.claude/agents/`, `standards/`, `architecture/decisions/`, `lib/`, `scripts/`, `presence/install/`, `templates/`, and repo-root files.
  - Init manifest at `.bassclef/init.manifest.json` records all 149 entries with content hash + template version per file.
  - Every copy went through `writeSafely()` — one audited mutation point.
  - Terminal output prints a per-directory summary (e.g., "hooks: 25 files copied") plus a total count.
- Exit code 0.
- Sam runs `bassclef sync` at any later point; classifier reports Current / NeedsUpdate / Edited / Deleted per file against the 149-file manifest.

## Minimal guarantee (failure postconditions)

- If any copy fails partway, the manifest reflects reality: successful copies recorded; failed copies reported per file.
- Partial `.tmp` files cleaned up on failure.
- Existing files at target paths unchanged if the safety check refused (default deny per UC-init).
- Specific error message names the file + failure mode.
- Non-zero exit code (1 for policy refusal, 2 for safety-check failure at write time, 3 for invalid args).

## Main success scenario

1. Sam runs `npm install -g @thebassclef/core`.
2. npm downloads the tarball produced by `prepublish-bundle-substrate.mjs` — package includes `substrate/` at its expected paths.
3. npm installs the `bassclef` binary at `$(npm bin -g)/bassclef`.
4. Sam runs `bassclef init` from her project directory.
5. CLI parses argv via `parseInitArgs` (unchanged from UC-init).
6. CLI runs root + directory + already-initialized checks (unchanged from UC-init).
7. CLI renders the 3 config templates via `renderTemplates(targetDir, packageVersion)` (unchanged from UC-init).
8. For each config template, CLI calls `writeSafely(path, content, { force, mode: 0o644 })` (unchanged from UC-init).
9. **New step** — CLI dispatches `copySubstrate(targetDir, manifest)` from `src/lib/copy-substrate.ts`:
   - Locate `substrate/` directory inside the installed package (via `require.resolve('@thebassclef/core/package.json')` + relative path).
   - Load bundled manifest at `substrate/.bassclef/lite-manifest.json` — 146 entries.
   - For each entry: read source from `substrate/<path>`, call `writeSafely(targetDir/<path>, content, { force, mode })`.
   - Verify content hash matches manifest entry before write.
10. CLI writes extended init manifest via `writeInitManifest(targetDir, results)` — records path, template version, content hash for all 149 files.
11. CLI prints per-directory summary (`hooks: 25 files`, `skills: 47 files`, `rules: 32 files`, `luminaries: 12 files`, etc.) plus a one-line total (`149 files landed`).
12. Exit 0.
13. Sam has a fully-populated bassclef project. Sam runs `bassclef sync` at any later point.
14. `bassclef sync` reads init manifest via `readInitManifest(targetDir)`.
15. Sync walks 149 files, computes current-vs-manifest classification per file (Current / NeedsUpdate / Edited / Deleted).
16. Sync reports counts + applies updates per flag combination (existing UC-sync behavior — unchanged).

## Extensions

**2a. Package sibling manifest missing at prepublish time** (R7 in ledger):
- `prepublish-bundle-substrate.mjs` cannot find `../bassclef-upstream/lite-manifest.json`.
- Script exits non-zero with "manifest missing at expected path: ../bassclef-upstream/lite-manifest.json".
- `npm pack` fails; package not published. Sam never sees this — the maintainer sees it.
- Cure: maintainer checks out bassclef-upstream sibling OR script falls back to GitHub raw URL (design decision at Step 2 decompose).

**2b. Some substrate files missing from package** (R7 in ledger):
- Prepublish script iterated 146 manifest entries but wrote fewer to `substrate/`.
- Script's fail-fast check catches count mismatch before `npm pack`.
- Exits non-zero with "expected 146 files; wrote N".
- Cure: check sibling checkout completeness; re-run prepublish.

**4a. Sam passes `--dry-run`:**
- CLI runs steps 5–9 as normal but with a dry-run flag on `copySubstrate`.
- Instead of copying, CLI prints per-directory `would copy: N files` for substrate paths.
- Exit 0. No files written.

**9a. Substrate source file hash does not match manifest entry** (R7 fallback):
- `copySubstrate` computed a SHA-256 that differs from the manifest's `content_hash`.
- Bundle was corrupted at some point (unlikely but possible — CDN mangling, disk error).
- Copy aborts for that file; error names the file + expected vs actual hash.
- Sam gets partial init; manifest reflects what landed successfully.
- Cure: `npm install -g @thebassclef/core --force` re-downloads; re-run `bassclef init --force`.

**9b. Target substrate path already exists as Sam's edit** (existing UC-init behavior):
- `writeSafely` sees the target file present; default refuses (per UC-init step 7).
- Sam gets "N files copied, M refused (already exists — pass --force to overwrite)" summary.
- Sam picks: rerun with `--force` (loses her edits) OR investigate the paths.

**9c. Target substrate path is a symlink** (attacker case per UC-init step 7a):
- `writeSafely` sees `ELOOP` from `O_NOFOLLOW`.
- Even with `--force`, symlink refusal is unconditional.
- Exit 2 with "refused — symlink at target path: <path>".

**13a. Sam upgraded from 0.0.2 to 0.1.0 and runs `bassclef sync`** (R8 — adopter migration):
- Sync reads init manifest — sees 3 entries (0.0.2 legacy shape).
- Sync detects legacy manifest via `manifest_version` field.
- Sync dispatches migration path: for each of the 146 new substrate files, run `writeSafely` with default-deny (does not overwrite Sam's edits).
- Sync rewrites init manifest to 149-entry shape.
- Reports: `146 files added; 0 existing files touched; run bassclef sync again to refresh existing files if desired.`
- Migration doc at `docs/migrations/0.1.0.md` explains the change to Sam.

**15a. Sam edited one of the substrate files** (existing UC-sync behavior extended):
- Sync classifier detects `Edited` state (content hash differs from manifest AND differs from bundled source).
- Sync refuses to overwrite that file without `--replace-edits`.
- Reports the specific file + the reason.
- Sam picks: keep her edit (do nothing) OR accept the update (rerun with `--replace-edits`).

**15b. Substrate file deleted by Sam or by a tool:**
- Sync classifier detects `Deleted` state.
- Sync refuses to re-create by default.
- Reports the specific file + the reason.
- Sam picks: leave it deleted (do nothing) OR restore (rerun with a future `--restore-deleted` flag; out of scope this goal).

## Special requirements

- Every terminal message reads at grade 8 or lower per `.claude/rules/plain-english-discipline.md`.
- No bassclef-internal jargon in output. Enforced by `/kiss words` review on output strings before commit.
- Every substrate copy goes through `writeSafely()` — one audited mutation point (R3 compensator in ledger).
- `copySubstrate` has one public method signature — R1 in ledger (Ousterhout deep module).
- `initManifest` reads and writes wrapped in typed module — R4 in ledger (Parnas interface).
- All paths derived from two constants (`SUBSTRATE_ROOT`, `CLAUDE_TARGET_ROOT`) — R6 in ledger.
- Prepublish script is pure Node — no `execSync`, no shell-outs (R2 in ledger).
- Prepublish fails fast on missing manifest (R7 in ledger).
- Adopter migration ships as 0.1.0 minor bump with migration doc (R8 in ledger).
- Package size ≤ 5MB — CI enforces (R9 in ledger).

## Frequency

- `npm install -g @thebassclef/core` — once per machine at adoption. Occasionally repeated for major upgrades.
- `bassclef init` — once per project. Occasionally re-run with `--force` after major version bumps.
- `bassclef sync` — Sam runs at will (weekly or monthly cadence typical).

## Technology + data variations

- POSIX only for this goal. Windows support is a future goal (out of scope).
- Node.js ≥ 20 required (existing constraint).
- Directory can be any depth under `$HOME`.
- Target files carry Unix line endings (LF). Windows CRLF normalized to LF at hash time per ADR-003 N1 (existing behavior).
- Package size grows from 232K (v0.0.2) to ≤ 5MB (v0.1.0) per napkin math (146 small text files ≤ 1MB total).
- Bundled `substrate/` uses same relative path layout as `bassclef-upstream` source tree — no re-mapping.

## Composes with

- ADR-005 pins the two-road split (@thebassclef/core = lite tier vehicle).
- ADR-007 (to author at Step 3) pins Shape A layered under Shape D for lite substrate bundling.
- UC-init — extended by this UC at step 9 (copy substrate after config files).
- UC-sync — extended by this UC at step 14-16 (walks 149-file manifest).
- `docs/decompositions/2026-08-28-npm-lite-bundling.md` (Step 2 output) covers the code-shape decomposition + `@pattern` calls.
- Risk ledger `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` — every "Special requirements" line above pins to a ledger row.
- `bassclef-upstream/standards/lite-manifest-assembly.md` v1.2 — the definitive contract for what belongs in the manifest.
