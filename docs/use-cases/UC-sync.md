---
tier: standard
id: UC-sync
name: Sync bassclef templates when a new version publishes
level: user goal
primary_actor: Sam (adopter)
scope: bassclef-cli — `bassclef sync` command
authored: 2026-08-08
authored_by: agent
cockburn_ceremony: fully-dressed
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
governs_source:
  - src/commands/sync.ts
  - src/commands/sync-argv.ts
  - src/lib/manifest-io.ts
  - src/lib/hash.ts
  - src/lib/write-safely.ts
references_adr: ADR-003-bassclef-sync-safety-contract.md
---

# UC-sync — Sync bassclef templates when a new version publishes

## Scope

The `bassclef sync` command shipped in `@thebassclef/core`. Reads the init manifest, detects change per file, applies updates under the right flag combination.

## Level

User goal — Sam upgrades a previously-initialized project without losing edits.

## Primary actor

Sam. Has an initialized project (`.bassclef/init.manifest.json` exists). Updated `@thebassclef/core` to a newer version via `npm install -g @thebassclef/core@latest`.

## Stakeholders + interests

| Stakeholder | Interest |
|---|---|
| Sam | Wants a safe upgrade. Does not want her `settings.json` edits clobbered. |
| Sam's compliance | Wants an audit trail — the manifest records what changed and when. |
| Maintainer | Wants adopter edits detected mechanically, not by heuristic. |
| Future WU-8 (Sam demo) | Wants the upgrade path to prove out in a fresh-machine demo. |

## Preconditions

- `@thebassclef/core` installed at the current version (post-upgrade).
- `.bassclef/init.manifest.json` exists in the target directory.
- Manifest's `manifest_schema_version` matches the sync's known max.
- Sam is not running as root OR she passed `--allow-root`.

## Success guarantee (postconditions)

- Every file listed in the manifest is in one of four states:
  - `Current` — hash matches manifest, template version matches
  - `NeedsUpdate` — hash matches manifest, template version differs (refused unless `--force`)
  - `Edited` — hash does not match manifest (refused unless `--replace-edits`)
  - `Deleted` — file gone from disk (refused unless BOTH `--force` and `--replace-edits`)
- Any writes went through `writeSafely()` with the current file's mode preserved.
- The manifest reflects reality after each successful write.
- Terminal output summarizes per-file outcomes.
- Exit code 0.

## Minimal guarantee (failure postconditions)

- Per-file write success is per-file. Failure on file A does not affect file B's outcome.
- Manifest updates are per-file. If sync exits mid-way, the manifest matches the actual state of successfully-written files.
- If mid-sync crash leaves a file at the new content but the manifest still records the old hash, next sync detects the hash mismatch and reports "content differs from manifest" with both possible causes named (adopter edit vs prior sync crash).
- Symlink refusal fires unconditionally. Neither `--force` nor `--replace-edits` overrides it.

## Main success scenario

1. Sam runs `bassclef sync` from her project directory.
2. CLI parses argv via `parseSyncArgs`.
3. CLI checks if Sam is root — refuses if yes and `--allow-root` not passed.
4. CLI reads the manifest via `readManifest(targetDir)` — refuses with "run `bassclef init`" if missing.
5. CLI validates manifest schema version — refuses if newer than sync's known max.
6. For each file in the manifest:
   1. CLI calls `classify(entry, currentContent, newTemplate, newTemplateVersion)`.
   2. `classify` reads current content, computes SHA-256, compares to manifest hash and template version.
   3. `classify` returns one of four cases: `Current`, `NeedsUpdate`, `Edited`, `Deleted`.
7. CLI decides action per case + flag combo (see extensions).
8. For each update:
   1. CLI reads the current file mode via `lstat`.
   2. CLI calls `writeSafely(path, newContent, { force: true, preserveMode })`.
   3. On success, CLI updates the manifest entry (path, template version, new hash, updated_at) and writes the manifest atomically.
9. CLI prints per-file result and a one-line summary.
10. Exit 0.

## Extensions

**1a. Sam passes `--dry-run`:**
- CLI runs classify per file but writes nothing.
- Output shows per-file "would update" / "would refuse" / "no change" with the reason for each.
- Exit 0.

**1b. Sam passes `--diff`:**
- CLI produces a unified diff per file that would change.
- Applies with or without `--dry-run`.

**4a. Manifest is missing:**
- CLI refuses. Names `bassclef init` as the fix.
- Exit 1.

**4b. Manifest is malformed JSON:**
- CLI refuses. Names manual repair.
- Exit 1.

**5a. Manifest schema version is newer than sync knows:**
- CLI refuses. Names package upgrade as the fix.
- Exit 4.

**7a — Case `Current`:**
- No action.

**7b — Case `NeedsUpdate` (template version newer, adopter did not edit):**
- Without `--force`: CLI refuses. Names `--force` as the override.
- With `--force`: CLI applies the new template. Manifest updated.

**7c — Case `Edited` (hash mismatch):**
- Without `--replace-edits`: CLI refuses. Refusal message names:
  - `last sync recorded: <manifest updated_at>`
  - `file mtime is now: <current mtime>`
  - suggests `bassclef sync --diff` to inspect
  - suggests `bassclef sync --replace-edits` to overwrite
- With `--replace-edits`: CLI applies the new template. Manifest updated.

**7d — Case `Deleted` (file gone):**
- Without BOTH flags: CLI refuses. Deletion is stricter than edit.
- With `--force --replace-edits`: CLI restores the file at template default mode (0644).

**7e — Manifest lacks `content_hash_sha256` for a file (legacy manifest):**
- CLI refuses that file with a specific message. Names `bassclef init --force` as the re-baseline path.

**8a — Target path is a symlink:**
- `writeSafely` refuses even with both flags. Exit 2.

**8b — Parent directory not writable:**
- CLI reports "error — parent not writable" for that file. Continues attempting the others.

**8c — Mid-sync failure (file A written, manifest write failed):**
- File A on disk carries the new content.
- Manifest still records A's old hash.
- Next sync detects hash mismatch. Refusal message names both possible causes:
  - "You edited the file since init"
  - "A prior sync did not finish"
- Cure: `bassclef sync --replace-edits --force` re-baselines.

**8d — Manifest carries a path outside the target directory (attack case):**
- CLI refuses. Exit 1.
- Every `path` field must resolve under the target directory.

## Special requirements

- Every message at grade 8 or lower.
- No bassclef-internal jargon in output.
- All refusal messages end with a specific command to run.
- Refusal messages for `Edited` and `EditedAndOutdated` cases name both `updated_at` (manifest) and current mtime (disk).
- Symlink refusal cannot be overridden by any flag.

## Frequency

Occasional. Fires each time Sam wants to pull in template changes from a newer `@thebassclef/core` version. May be a no-op if templates did not change between versions.

## Technology + data variations

- POSIX only.
- Line endings normalized to LF before hashing (per ADR-003 N1). Windows adopters get byte-identical hashes to POSIX adopters.

## Composes with

- ADR-003 pins the safety contract this UC implements.
- `docs/decompositions/wu-3-sync.md` covers the code-shape decomposition.
- `docs/interaction-design/2026-08-08-npm-distribution.md` covers arc-level state and sequence diagrams.
- UC-init — sibling UC; init writes the manifest sync consumes.
