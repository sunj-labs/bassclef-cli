---
tier: standard
id: UC-migrate
name: Migrate a bassclef adopter from 0.0.x to 0.1.0+ substrate
level: user goal
primary_actor: Sam (adopter)
scope: bassclef-cli — `bassclef migrate` command
authored: 2026-08-30
authored_by: agent
cockburn_ceremony: fully-dressed
cockburn_ceremony_note: |
  Goal doc L124 states brief tier. Fully-dressed lands here per two reasons:
  (1) sister UC-init + UC-sync ship fully-dressed for adopter-facing subcommands;
  (2) .claude/rules/oo-ad-entry-point.md table calls fully-dressed for new
  adopter-facing modules under src/. Delta absorbed in Step 1 turn budget.
goal: docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md
governs_source:
  - src/commands/migrate.ts
  - src/commands/migrate-argv.ts
  - src/lib/migrate.ts
  - src/lib/manifest-io.ts (extension — computeConfigHashes)
references_adr:
  - ADR-002-bassclef-init-safety-contract.md (Path B inherits)
  - ADR-003-bassclef-sync-safety-contract.md (Path A borrows classifier)
  - ADR-007-npm-lite-substrate-bundling.md (parent; bundle contract)
  - ADR-008-bassclef-migrate-subcommand.md (TO AUTHOR at Step 3; this UC's contract)
---

# UC-migrate — Migrate a bassclef adopter from 0.0.x to 0.1.0+ substrate

## Scope

The `bassclef migrate` command shipped in `@thebassclef/core@0.1.0+`. Detects the adopter's install state. Adds every missing substrate file. Preserves every edited config file. Writes a fresh init manifest recording every file's hash.

## Level

User goal — Sam upgrades her project's bassclef substrate from 0.0.x to 0.1.0 without losing config edits.

## Primary actor

Sam. Has `@thebassclef/core` at 0.1.0 or later after `npm install -g @thebassclef/core@latest`. Her project holds one of three states:
- **current** — 149-file init manifest at 0.1.0 shape (no migration needed)
- **legacy-3-entry** — 3-file init manifest at 0.0.2 shape (Path A migration)
- **no-manifest** — no `.bassclef/init.manifest.json` present (0.0.1 name-reservation state; Path B full init)

## Stakeholders + interests

| Stakeholder | Interest |
|---|---|
| Sam | Wants her `.claude/settings.json` + `substrate.config.md` edits preserved through the upgrade. |
| Sam's compliance | Wants an audit trail — the new manifest records every file's hash + when migration ran. |
| Maintainer | Wants adopter state detected mechanically, not by heuristic; wants both upgrade paths (Path A + Path B) covered by one command. |
| Sam's team (multi-seat) | Wants deterministic migration output so a second seat gets the same shape after their own upgrade. |
| Roadmap parent | 5 existing adopters + 9 signups per goal doc L69 → parent roadmap L18-19; each needs a clean upgrade path. |

## Preconditions

- `@thebassclef/core` installed at 0.1.0 or later (post-upgrade via npm).
- Target directory exists and is writable.
- Sam is not running as root OR she passed `--allow-root`.
- No other `bassclef` process is writing to the target directory.

## Success guarantee (postconditions)

- Target directory holds the 149-file 0.1.0 substrate layout.
- Every file Sam edited before migration retains its edited content.
- `.bassclef/init.manifest.json` records the SHA-256 hash of every file's current content + the template version.
- Terminal output names counts: `N added; M preserved with existing content; K skipped (already current); 0 errored`.
- Exit code 0.

## Minimal guarantee (failure postconditions)

- Per-file write success is per-file. Failure on file A does not affect file B's outcome.
- Manifest updates are atomic — if migration exits mid-way, the manifest matches the actual state of successfully-written files.
- If a mid-migration crash leaves file A at new content but the manifest still records the pre-migration hash, next migration run detects the hash mismatch and reports both possible causes (adopter edit OR prior migration crash).
- Symlink refusal fires unconditionally. No flag overrides it (per ADR-002).
- No config file the adopter edited is ever overwritten silently.
- Interactive prompt refusal (Sam says No) leaves the target directory untouched.

## Main success scenario

1. Sam runs `bassclef migrate` from her project directory.
2. CLI parses argv via `parseMigrateArgs`.
3. CLI checks if Sam is root — refuses if yes and `--allow-root` not passed.
4. CLI reads the target directory's `.bassclef/init.manifest.json` via `readManifest(targetDir)` — tolerates absent (routes to detection at step 5).
5. CLI calls `detectLegacyManifest(manifest)` — returns one of `current`, `legacy-3-entry`, `no-manifest`.
6. Branch on state:
   - **current** — CLI prints "Already at 0.1.0 shape. Nothing to migrate." Exit 0.
   - **legacy-3-entry** — Path A migration (step 7).
   - **no-manifest** — Path B full init dispatch (step 8).
7. Path A — legacy-3-entry migration:
   1. CLI calls `computeConfigHashes(targetDir, ['.claude/settings.json', 'substrate.config.md', 'CLAUDE.md'])` — SHA-256 per existing config file.
   2. CLI walks the bundled 149-entry manifest embedded in the package (per ADR-007 bundle contract).
   3. For each entry: CLI compares against target directory state and classifies as `add` (missing on disk), `preserve` (present with adopter-edited hash), or `skip` (present with template-default hash).
   4. CLI prints the intended shape — "146 files to add; 3 files to preserve; 0 to skip" (interactive prompt; Cooper lens).
   5. Sam confirms — CLI proceeds. Sam declines — CLI exits 0 with no writes.
   6. For each `add` entry: CLI calls `writeSafely(path, content, { preserveMode })`.
   7. For each `preserve` entry: CLI records the current SHA-256 in the new manifest without touching the file.
   8. For each `skip` entry: CLI records the template SHA-256 in the new manifest without touching the file.
   9. CLI writes `.bassclef/init.manifest.json` atomically with all 149 entries at 0.1.0 template version.
   10. CLI prints per-file lines under `--verbose`; the one-line summary always fires.
8. Path B — no-manifest full init dispatch:
   1. CLI prints "No prior manifest detected. Running full init for 149 files."
   2. CLI dispatches the init flow (per UC-init main scenario) with the current target directory.
   3. Init writes all 149 files + the 0.1.0 manifest.
   4. CLI prints init's summary + the folder guidance line (RFC N4 refinement).
9. CLI prints exit summary + suggests the `.claude/` folder + gitignore guidance line (RFC N4).
10. Exit 0.

## Extensions

**1a. Sam passes `--dry-run`:**
- CLI runs detection + classification but writes nothing (no manifest, no substrate files).
- Output shows "would add / would preserve / would skip" per file with the count summary.
- Interactive prompt fires but treats any confirmation as no-op.
- Exit 0.

**1b. Sam passes `--verbose`:**
- Per-file result line prints in addition to the count summary.
- Applies with or without `--dry-run`.

**1c. Sam passes `--yes` (non-interactive mode, for CI):**
- CLI skips the interactive prompt and proceeds directly to writes.
- Every other guarantee still holds — hash preservation, atomic manifest, symlink refusal.

**3a. Sam is root without `--allow-root`:**
- CLI refuses. Names `--allow-root` as the override AND recommends running as the project owner instead.
- Exit 1.

**4a. Manifest exists but is malformed JSON:**
- CLI refuses. Names manual repair or `bassclef init --force` as the reset path.
- Exit 1.

**4b. Manifest schema version is newer than migrate knows:**
- CLI refuses. Names the package upgrade as the fix ("your manifest was written by a newer `@thebassclef/core`; upgrade to at least that version").
- Exit 4.

**5a. `detectLegacyManifest` returns an unknown shape (neither current, legacy-3-entry, nor no-manifest):**
- CLI refuses. Prints "Adopter state does not match 0.0.x or 0.1.0. Reinstall `@thebassclef/core` then rerun." (per goal doc L97 Nygard failure-with-fix discipline)
- Exit 5.

**7.4a. Sam declines at the interactive prompt:**
- CLI exits 0 with the message "Aborted. No files changed."
- No writes happen. Manifest unchanged.

**7.6a. `writeSafely` refuses one file (parent not writable OR symlink target):**
- CLI reports the specific file + reason. Continues with the rest.
- Exit summary counts refusals: `146 added; 3 preserved; 1 refused (symlink); 0 errored`.
- Exit code 2 if any refusals fired.

**7.9a. Manifest write fails after some files landed (mid-migration crash):**
- Files on disk carry new content.
- Manifest still records the pre-migration hashes.
- On next `bassclef migrate` run, `detectLegacyManifest` still returns `legacy-3-entry` but hash comparison flags mismatch on the already-written files.
- CLI reports the mismatch and names both possible causes: "You edited the file since migration started" OR "A prior migration did not finish". Cure: `bassclef sync --replace-edits --force` re-baselines against the current template.

**7.7a. Adopter edited a substrate file (not just a config file):**
- The `preserve` case fires for any file whose current hash differs from the template hash — the classifier does not distinguish "edited config" from "edited substrate hook".
- Adopter's edit is preserved. New manifest records the current hash.
- Adopter can later re-baseline via `bassclef sync --replace-edits`.

**8.2a. Init dispatch fails (per UC-init failure modes):**
- CLI surfaces init's exit code and message. Migrate does not swallow the error.
- Exit code matches init's.

**9a. Target path holds a symlink where a bassclef file should land:**
- `writeSafely` refuses unconditionally. No flag overrides.
- Reported per file. Exit 2.

**9b. Target path is outside the current directory (attack case):**
- Every `path` field in the bundled manifest resolves under the target directory before write. Any escape refuses.
- Exit 1.

## Special requirements

- Every operator-facing message at grade 8 or lower (per `.claude/rules/plain-english-discipline.md`).
- No bassclef-internal jargon in output.
- All refusal messages end with a specific command to run.
- Interactive prompt uses Node's built-in `readline/promises` (no new dependency; per bassclef-cli tech stack — `configs.jsonc` L51 runtime: node ≥ 20).
- `--yes` flag exists for CI and non-interactive environments.
- Symlink refusal cannot be overridden by any flag (inherits from ADR-002 init safety envelope).
- Line endings normalized to LF before hashing (per ADR-003 N1) — Windows adopters get byte-identical hashes to POSIX adopters.
- Output shape matches sister sync command's post-N3 shape: "3 files preserved with existing content" in plain language (RFC N3 refinement).
- Final line names the `.claude/` folder + gitignore guidance (RFC N4 refinement — mirrors init's final line).

## Frequency

Once per adopter per major upgrade. Bounded — 5 existing adopters + 9 signups per goal doc L69 citation to parent roadmap L18-19. May fire again on future major upgrades (0.2.0, 1.0.0) that carry substrate additions.

## Technology + data variations

- POSIX only. Windows adopters covered by LF normalization at hash time.
- Node ≥ 20 (per `package.json` L52 `engines.node`).
- Interactive prompt via `readline/promises` (Node built-in; zero new dependencies).
- Non-interactive mode via `--yes` flag (CI + scripted upgrades).
- Bundled manifest embedded in the npm package under `substrate/` (per ADR-007 bundle contract; `package.json` L34-42 `files` array includes `substrate/**`).

## Composes with

- **UC-init** — Path B dispatches the init flow. Init writes the 149 files + manifest.
- **UC-sync** — Path A borrows sync's four-case classifier (`Current` / `NeedsUpdate` / `Edited` / `Deleted`) plus `writeSafely` + hash discipline.
- **ADR-002** — init safety envelope (atomic write + symlink refuse + root refuse).
- **ADR-003** — sync safety envelope (four-case classifier + hash discipline + LF normalization).
- **ADR-007** — parent bundle contract; migrate reads the bundled 149-entry manifest.
- **ADR-008** — TO AUTHOR at Step 3. Pins migrate's safety envelope + interactive prompt shape + failure modes + RFC refinement absorbed here.
- **`src/lib/manifest-io.ts`** — `detectLegacyManifest` already exists per scope-b1 commit c84fa84. Step 6 extends this file with `computeConfigHashes` + Path A / Path B classifier.
- **`docs/decompositions/2026-08-30-migrate.md`** — TO AUTHOR at Step 2. Covers GRASP responsibility assignment + @pattern annotations.
- **`docs/migrations/0.1.0.md`** — TO AUTHOR at Step 6. Adopter-facing migration doc; carries the RFC L3 CHANGELOG semver note.

## Refs

- Goal doc — `docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md`
- Plan doc — `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md`
- Parent goal (scope-b1 SHIPPED) — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md`
- RFC-0001 — `docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md` (revised B disposition names scope-e deferrals absorbed here)
- Risk ledger v4 — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` (§ Deferred to scope-e)
- Parent roadmap — `bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` (5 existing + 9 signup adopters)
- Sister UCs — UC-init.md, UC-sync.md
