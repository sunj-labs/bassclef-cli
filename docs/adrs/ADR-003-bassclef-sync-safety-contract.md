---
tier: standard
id: ADR-003
title: Pin the safety contract for `bassclef sync` — two independent force flags + content-hash detection + per-file manifest commits
status: accepted
date: 2026-08-06
accepted: 2026-08-08
accepted_via: PR #5 merged — WU-3 sync command shipped the safety contract this ADR pins
supersedes: null
superseded_by: null
---

# ADR-003 — Pin the safety contract for `bassclef sync` — two independent force flags + content-hash detection + per-file manifest commits

## Context

WU-3 of iteration bet `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
lands the second `@thebassclef/core` command that writes files to a
user's disk. Sync's mutation is DIFFERENT in kind from init's:

- Init CREATES files where none existed. Refuse-on-exists is a safe
  default.
- Sync MODIFIES files the adopter has been using. Refuse-on-exists is
  not enough; sync must distinguish "outdated because we updated the
  template" from "adopter has intentionally changed the file."

Forces at play:

- **Adopter-edit detection is required.** Silent overwrite of Sam's
  edited settings.json is worse than useless — it destroys her work
  and breaks her trust.
- **Content-hash needs a baseline.** The init manifest must carry the
  content hash of every file it wrote so sync can compare later.
- **Manifest updates must be atomic per file.** Whole-sync transaction
  is out of scope; per-file honesty is enough for WU-3.
- **Two force flags, not one.** Version-outdated is one privilege;
  adopter-edited is another. Saltzer principle 5 says these are
  independent.

Alternatives considered:

1. **Single `--force` flag.** Simpler CLI. Rejected: conflates two
   independent privileges and destroys adopter work with less consent
   than the operation deserves.
2. **Three-way merge.** Take original template + adopter file + new
   template, produce a merged file. Rejected: requires a
   schema-aware merger per file type and a UI for conflict resolution.
   Deferred to a later WU.
3. **Silent overwrite by default.** Chosen by some install tools.
   Rejected: same reason as init's ADR-002.

## Decision

`bassclef sync` ships with the following contract for 0.0.x. Any
listed default, flag, or exit code becomes MAJOR-bump-triggering.

**Default behavior when no flags are passed:**

Sync reads `.bassclef/init.manifest.json`. For each file listed:

1. Compute the current file's content hash (SHA-256 of the file's
   UTF-8 bytes with CRLF normalized to LF).
2. Compare that hash to the manifest's recorded hash for the file.
3. Compare the current package's template version to the manifest's
   recorded template version.
4. Classify per file into one of four cases (below).
5. Apply per-case default action.

**Four cases:**

| Case | Condition | Default action |
|---|---|---|
| `Current` | file exists, hash matches manifest, version matches | no change (no-op) |
| `NeedsUpdate` | file exists, hash matches manifest, template version is newer | REFUSE unless `--force` |
| `Edited` | file exists, hash does NOT match manifest | REFUSE unless `--replace-edits` |
| `Deleted` | file does not exist | REFUSE unless both `--force` AND `--replace-edits` |

**Ambiguity case (crash recovery):**

If the current file's bytes match neither the manifest's hash nor the
current template's output (a partial sync could have written the
current template to disk but crashed before updating the manifest),
sync classifies as `Edited`. The refusal message names both possible
causes (adopter edit OR interrupted prior sync).

**Refusal always names:**

- The category (version-outdated, edited, deleted).
- For `Edited` cases: manifest `updated_at` + current file mtime.
- The specific command to run to proceed (`--force`, `--replace-edits`,
  or both).
- `--diff` and `--dry-run` as inspection paths.

**Escape-hatch matrix:**

| Flag | Disables |
|---|---|
| `--force` | The `NeedsUpdate` refusal. Sync applies the new template. |
| `--replace-edits` | The `Edited` refusal. Sync applies the current template over adopter edits. |
| Both flags TOGETHER | The `Deleted` refusal, plus everything above. Sync recreates missing files. Neither flag alone restores a deleted file. |
| `--allow-root` | The root refusal. |
| `--allow-any-dir` | The `$HOME` scope check + target-dir ownership check. |

Flags are orthogonal. Symlink refusal via `O_NOFOLLOW` fires
unconditionally — NO flag can bypass. Parent-directory writability +
post-write file identity still fire.

**Per-file write sequence:**

1. Compute new content hash from the current template output.
2. Preserve the current file's mode (read via `lstatSync` before write).
3. Call `writeSafely(path, newContent, {force: true, preserveMode})`.
4. On success, update the manifest entry for that file
   (`content_hash_sha256`, `template_version`, `updated_at`).
5. Write the whole manifest via `writeSafely` with force=true.

Steps 3 and 4 are not transactional together. A crash between them
leaves the file at the new version with the manifest at the old
hash — next sync detects the mismatch and reports `Edited` with the
ambiguity message.

**Content hash:**

- Algorithm: SHA-256.
- Input normalization steps applied in order before hashing:
  1. Strip a leading UTF-8 BOM (U+FEFF) if present. Editors on Windows
     and older tools sometimes add one on save.
  2. Replace every CRLF sequence (`\r\n`) with LF (`\n`). Windows
     adopters running Git may have autocrlf convert on checkout.
- Explicitly NOT normalized:
  - Trailing whitespace on lines (semantic in Markdown code fences +
    YAML)
  - Unicode NFC/NFD normalization
  - Whitespace inside strings (multi-space, tabs vs spaces)
  - Re-indentation
- Purpose: make hashes stable across common cross-platform save shapes
  while still catching intentional edits.

**Manifest schema versioning:**

- `$bassclef.manifest_schema_version` — the manifest's own shape.
- Individual `files[].template_version` — that file's template version.
- Sync refuses to touch a manifest whose `manifest_schema_version` is
  newer than sync's known max (`> MANIFEST_SCHEMA_VERSION`).
  Message names package upgrade.

**Files sync will touch:**

- Only files listed in the manifest.
- Only files whose content carries the `$bassclef` marker key (for
  JSON) OR `bassclef_template:` YAML front-matter (for markdown). If
  the marker is missing from a manifest-listed file, sync refuses with
  a "file is not managed by bassclef" message even under both force
  flags.

**Dry-run:**

- `--dry-run` prints the case + planned action per file.
- Writes nothing (not the target files, not the manifest).
- Exit code matches what a real run would produce.

**Init amendments (backward-compatible for unreleased 0.0.2):**

- Init writes `content_hash_sha256` per file into the manifest.
- Init refuses if the manifest already exists (exit 1) unless `--force`
  is passed. `--force` re-baselines the manifest (new `created_at`,
  new hashes). This preserves the manifest as a WU-3 contract.

**Exit codes:**

- `0` — success (all Current, or all updates applied)
- `1` — refused (updates available without `--force`; edited without
  `--replace-edits`; deleted without both; missing manifest; malformed
  manifest; running as root; outside HOME; not owned)
- `2` — safety check failed at write time (symlink, unwritable parent,
  post-write verification)
- `3` — invalid args
- `4` — manifest schema is newer than this package understands.
  Distinct from `1` so scripted callers can react by upgrading the
  package instead of prompting the user.

**Complete-mediation scope:**

Every filesystem WRITE in the sync chain flows through `src/lib/write-safely.ts`
(`writeSafely` and `mkdirSafely`). Reads are unmediated by design —
they do not change state, and a `readSafely` shim would not close a
TOCTOU gap. The safety check that matters is the atomic-open at write
time (`O_CREAT | O_EXCL | O_NOFOLLOW`), not a paired read/write API.

## Status

`proposed` — ships with the WU-3 PR. Flip to `accepted` before 0.0.2
tag.

## Consequences

**Easier:**

- Adopters know their edits are safe — the tool tells them exactly
  what changed and asks before touching anything.
- Sync is a durable substrate for later work (three-way merge, TTY
  UI, interactive apply).
- The framework separates version updates from edit conflicts
  cleanly.

**Harder:**

- Sam has to type TWO flags to lose her edits + apply a version bump.
  For a returning user with intentional edits, this is exactly the
  friction that respects her.
- CI callers must decide whether to pass `--force` alone or
  `--force --replace-edits`. Two flags means two decisions.
- The refusal messages are longer than "no". Doubles CLI text
  volume — but that's Cooper's psychological acceptability paying
  off.

**Enables:**

- Later `bassclef uninit` reads the manifest to reverse the writes.
- Later `bassclef sync --three-way-merge` uses the manifest as its
  merge base.
- Publish workunit's CI can call `bassclef sync --dry-run` on
  fixtures to verify template revisions did not miss version bumps.

**Blocks (until reconsidered):**

- No interactive prompt. Later WU with `--interactive`.
- No file-level diff by default. `--diff` opts in.
- No bundled substrate copy. Sync only touches the two files
  manifest lists.

**Invariants established (semver-locked for 0.x):**

Defaults:

- Default refuses to overwrite version-outdated files. `--force` required.
- Default refuses to overwrite adopter-edited files. `--replace-edits` required.
- Default refuses to recreate deleted files. Both flags required.
- Default refuses to run as root. `--allow-root` required.
- Default refuses to write outside `$HOME`. `--allow-any-dir` required.
- Default refuses to write to a directory not owned by the current uid.
  `--allow-any-dir` required.
- Symlink refusal is unconditional. No flag can bypass.

File format:

- Content hash is SHA-256 of UTF-8 bytes with CRLF → LF normalization.
- Manifest schema version lives at `$bassclef.manifest_schema_version`.
- Per-file template version lives at `files[].template_version`.
- Sync only touches files carrying the `$bassclef` marker (JSON) or
  `bassclef_template:` front-matter (Markdown).

Exit codes:

- `0` success. `1` refused by policy. `2` safety check at write time.
  `3` invalid args. `4` manifest schema newer than this package
  understands (operator upgrades the package).

File paths:

- Manifest lives at `<target>/.bassclef/init.manifest.json`. Path is
  fixed — any change is a MAJOR bump.

Single-writer assumption:

- Sync assumes ONE writer at a time on the target directory. There
  is no file lock. Two concurrent bassclef processes on the same
  target dir race the manifest. Adopters running `bassclef` in
  scripts must serialize themselves. A `.bassclef/lock` file may
  land in a later WU if a real use case surfaces.

Read-vs-write mediation:

- Writes flow through `writeSafely` with `O_CREAT | O_EXCL | O_NOFOLLOW`.
  Reads are direct `readFileSync` without a shim. An attacker with
  rename rights in the target dir can force a classifier verdict
  (silent no-op or false-Edited denial-of-service) between read and
  write. The invariant the ADR protects: no attacker-controlled path
  can be WRITTEN to. Reads inform the classifier; writes are the
  point where safety fires.

Any change to a listed default, file format element, flag semantic, or
exit code is a MAJOR bump under semver.

## References

- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L123 (WU-3 scope)
- Decomposition: `docs/decompositions/wu-3-sync.md` (full luminary
  consult + pre-mortem + challenger pass + revised design)
- ADR-002 — init safety contract. Sync inherits ADR-002's
  complete-mediation model + symlink refusal.
- ADR-031 — we-don't-break-adopters. Sync's default choices are
  semver-locked.
- Luminaries:
  - `saltzer-schroeder.md` — 8 principles. Principle 5 (separation of
    privilege) drove the two-force-flags decision.
  - `alan-cooper.md` — Sam persona; refusal messages designed for
    psychological acceptability.
  - `john-ousterhout.md` — define errors out of existence + deep
    modules.
- POSIX man pages: `open(2)` (`O_EXCL`, `O_NOFOLLOW`); `lstat(2)`
- Prior art: `npm update` (auto-applies), `git pull` (refuses on
  local changes), `rustup update` (uses lockfile). Sync sits closest
  to `git pull`.
