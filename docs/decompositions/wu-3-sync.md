---
tier: standard
name: WU-3 — bassclef sync command decomposition
slug: wu-3-sync
authored: 2026-08-06
authored_by: agent
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
wu: 3
luminaries:
  primary: saltzer-schroeder
  supporting: [alan-cooper, john-ousterhout]
  rotation_reason: sync writes to adopter disks over EXISTING files — one level worse than init. Safety posture leads, UX and design judgment support.
---

# WU-3 — `bassclef sync` command decomposition

WU-2 landed init. WU-3 lands sync. Sync's mutation is different in kind
from init's: init CREATES new files under fail-safe defaults; sync
MODIFIES files the adopter has been living with. The safety story
grows a new concern — adopter edits.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L123 (WU-3 scope), L136 (discipline touchpoint — /decompose per
  command)
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` — WU-3 inherits
  ADR-002's mediation model; sync extends it, does not replace it
- `docs/decompositions/wu-2-init.md` — WU-2's design lens (luminary
  consult + challenger pass); WU-3 reuses the writers + resolver
- `src/commands/init.ts` L131-236 — the plan/write/manifest cycle
  WU-3 mirrors on read/detect/update
- `src/commands/init-templates/manifest-json.ts` — the manifest shape
  WU-3 reads; extend with content hash for adopter-edit detection
- `src/lib/write-safely.ts` — the atomic-write function WU-3 reuses
- `.claude/luminaries/saltzer-schroeder.md` L69-142 (all 8 principles)
- `.claude/luminaries/alan-cooper.md` L96-152 (persona + worked
  example)
- `.claude/luminaries/john-ousterhout.md` L50-63 (deep modules, define
  errors out of existence)

## Luminary consult — sync-specific challenges

### Saltzer-Schroeder (primary)

Sync's mutation surface is HARDER than init's. Init could refuse-on-
exists safely — the file was theirs, we did not create it. Sync must
answer a subtler question: has the adopter changed the file since we
last touched it?

| Principle | How it shapes WU-3 |
|---|---|
| **1. Economy of mechanism** | One `sync` command. One check function: `detectChange(manifestEntry, currentFileContent, currentTemplate)` returns a small typed result. Reader inspects in one read. |
| **2. Fail-safe defaults** | Refuse to overwrite unless `--force`. Same shape as init. Refuse to overwrite adopter-edited files unless `--force`. Two independent checks; either alone is enough to trigger refusal. |
| **3. Complete mediation** | Every file read AND every file write goes through the audited lib layer. Add `readAndHash(path)` in `src/lib/`. No `fs.readFileSync` scattered elsewhere. |
| **4. Open design** | Manifest format is public. Content hash algorithm named (SHA-256). Every check the command runs is documented in `--help` and README. |
| **5. Separation of privilege** | Update requires TWO conditions: template version bumped AND `--force` OR adopter did not edit. Adopter-edited + template-changed = refuse without `--force`. |
| **6. Least privilege** | Sync writes ONLY to files listed in the manifest. Never writes to files init did not create. Never expands scope. |
| **7. Least common mechanism** | Per-file check + per-file update. Failure on file A does not affect file B's decision. |
| **8. Psychological acceptability** | Refusal messages name WHAT differs (template version, adopter edit) AND WHAT TO DO (--force, --dry-run). Sam sees a summary, not a wall of diffs. |

### Alan Cooper (supporting — Sam persona)

Sam's re-sync moments:

1. **Cold re-run — no changes since init.** She expects: "already
   current, nothing to do." Fast, quiet, exit 0.
2. **New package version — templates bumped.** She expects: "these
   files have updates available. Run with --force to apply." Named
   list of files, no giant diff dump. Optional `--dry-run` shows the
   diff.
3. **She edited settings.json to add a permission.** She expects:
   "you have edited settings.json. Sync will not overwrite it. Run
   `bassclef sync --force` to replace your edits, or edit manually
   using the shipped template as a reference." Refusal explains the
   trade-off; does not blame her.
4. **She ran `bassclef init` in a directory but never opened a session,
   ran again after upgrade.** Manifest is untouched, but templates
   are newer. She expects the same happy-path shape as case 2.

Cooper anti-pattern to avoid: showing a full unified diff by default.
Sam wants a summary. `--diff` opts in to full detail.

### John Ousterhout (supporting)

- **Deep module:** `bassclef sync` interface is one command + a small
  flag set. Implementation hides: manifest parse + validate,
  content-hash compute, template comparison, per-file decision,
  refusal message assembly, manifest update on success. Adopters
  see one command.
- **Define errors out of existence:** Sync on an unchanged repo is
  NOT an error, it is a no-op with exit 0. Sync on a repo where
  everything is already current is NOT an error, same. Sync on a
  manifest that lacks a content hash (older init that predates
  WU-3) FALLBACK to compare current file to current template — do
  the reasonable thing rather than error.

## Pre-mortem light — 3 lenses × 3 risks

### Saltzer-Schroeder lens

1. **RISK: Sync silently reverts adopter's added `permissions.additionalDirectories` entry to empty.** Adopter added `../some-repo`; template shipped empty; sync sees version bump and rewrites without checking content.
   - Owner: default check in `runSync`
   - Mitigation: manifest content hash. If adopter's current file hash != manifest's hash-at-init, refuse without `--force`. Add content hash to init manifest (WU-2 amendment; forward-compatible since 0.0.2 unreleased).

2. **RISK: Path traversal on a corrupted manifest — attacker edits `.bassclef/init.manifest.json` on a shared workspace to include `path: "../../etc/passwd"`; sync writes to `/etc/passwd`.**
   - Owner: manifest read + validate + relative path check
   - Mitigation: every `path` field in the manifest must resolve to a path UNDER the target directory. `resolveTargetDir` semantics extended to check the joined path. Refuse traversal even with `--allow-any-dir`.

3. **RISK: Mid-sync failure — first file writes, second fails, manifest never updates. Next sync re-attempts BOTH files, potentially against a partially-updated state.**
   - Owner: transaction semantics
   - Mitigation: update the manifest incrementally — as each file succeeds, the manifest gets a new entry for that file. Manifest write is atomic (writeSafely with force=true). If sync exits mid-way, the manifest reflects reality.

### Cooper lens

4. **RISK: Adopter runs sync, sees three files listed as "updates available", panics.**
   - Owner: summary output shape
   - Mitigation: one-line summary — "2 files have updates available. Run `bassclef sync --force` to apply, or `bassclef sync --dry-run` to preview." Full list only under `--verbose`.

5. **RISK: Adopter's manifest is missing (deleted the .bassclef dir, or older init predates the manifest).**
   - Owner: startup path
   - Mitigation: if manifest missing, sync FALLBACK — infer template versions from the marker keys inside each file (settings.json's `$bassclef.template_version`, substrate.config.md's front-matter). If markers missing too, print a specific error naming `bassclef init` as the remediation.

6. **RISK: Adopter's file has been edited AND the template has been bumped. Both changed. Sam sees "settings.json refused" but does not know why.**
   - Owner: refusal message
   - Mitigation: refusal message names the CATEGORY: "settings.json — you have edited this file since init, and a newer template is available. Run `--force` to replace, or edit manually. See `--diff` for details."

### Ousterhout lens

7. **RISK: The manifest schema evolves in a later WU (add a field). Old sync reads a newer manifest, ignores unknown fields — future field becomes silently ignored on old versions.**
   - Owner: manifest schema versioning
   - Mitigation: manifest carries a `template_version` field for its own shape. Sync checks compatibility — if manifest's own template version is newer than sync's max, refuse with a clear "upgrade @thebassclef/core to sync this manifest" message.

8. **RISK: The check function grows a matrix of (template changed × adopter edited × force flag), and its return type is a union of six possible outcomes. Complexity leaks into runSync's decision code.**
   - Owner: `detectChange` return shape
   - Mitigation: return a small union with three cases: `Current`, `NeedsUpdate`, `EditedAndNeedsUpdate`. runSync branches on the case + force flag; six-cell matrix collapses into six lines of code.

9. **RISK: Templates get shipped as source constants (per WU-1 ADR-001). A future template revision changes the settings.json content in a way that breaks Claude Code. Sync applies the bad template.**
   - Owner: template revisions before release
   - Mitigation: not addressed by sync. This is a CI concern (publish workunit) — pre-publish check that generated files parse correctly. Note in ADR-003 as out of scope for sync.

## Boundary objects

| Boundary | Shape |
|---|---|
| `bassclef sync` command line | Verb + optional flags. Success = one-line summary. Refusal = per-file reason + remediation. Failure = specific error. |
| Updated files | Same three the init manifest lists. Sync never touches files outside the manifest. |
| `--help` text | Lists every flag + describes adopter-edit detection + refusal categories + escape hatches. |
| `--dry-run` output | Lists per-file: `no change`, `update available (template X.Y → X.Z)`, `edited by you`, or `edited by you + update available`. Same shape as a real run without the writes. |
| `--diff` output | Unified diff per file that would change. Opt-in; not shown by default. |

## Entity objects

| Entity | Where it lives | Read or written by WU-3? |
|---|---|---|
| Init manifest | `<target>/.bassclef/init.manifest.json` | Both — read at start, updated after each successful write |
| Template files (settings.json, substrate.config.md) | inside target directory | Read (for content hash), written (on successful update) |
| Template source constants | compiled into `dist/cli.js` | Read (imports resolve at load time) |
| Current package version | `src/index.ts` (already shipped) | Read (stamped into updated manifest) |
| Content hash algorithm | Node's `crypto.createHash('sha256')` | Function, not state |

## Control objects

| Control | Responsibility | Shape |
|---|---|---|
| `runSync(args)` in `src/commands/sync.ts` | Parse args, resolve target dir, read manifest, decide per file, apply updates, write manifest | ≤ 150 lines. Delegates check + IO. |
| `detectChange(entry, currentContent, newTemplate, newTemplateVersion)` | Compare current file's content hash to manifest-recorded hash; compare template version | Pure function. Returns typed result. ≤ 30 lines. |
| `readManifest(dir)` in `src/lib/manifest-io.ts` | Read + validate the manifest JSON. Handle missing + malformed cases. | ≤ 60 lines. Handles both current shape and legacy (no hash) shape. |
| `writeManifest(dir, manifest)` | Atomic write via writeSafely + force=true; the manifest is intentionally overwritten each time. | ≤ 20 lines. |
| `hashContent(content)` in `src/lib/hash.ts` | Deterministic SHA-256 of a UTF-8 string. | ≤ 10 lines. |
| Modified init writer | Init writes content hash into manifest at first init. Sync writes hash on update. | Amend `src/commands/init.ts` writeManifest. |

## Interface shape

```
bassclef sync [options]

Options:
  --dir <path>       Target directory. Default: current working directory.
  --force            Replace files that differ. Default: refuse.
  --dry-run          Print what would change; write nothing.
  --diff             Print a unified diff of each file that would change.
  --allow-root       Allow running as root. Default: refuse.
  --allow-any-dir    Allow --dir outside your home directory. Default: refuse.
  --verbose          Print per-file result.

Files sync will consider updating:
  <files listed in .bassclef/init.manifest.json>

Categories in the summary:
  no change              — current version, adopter hasn't edited
  update available       — newer template exists, adopter hasn't edited
  edited by you          — adopter edited, current template
  edited + update        — adopter edited, newer template exists

Exit codes:
  0  Success (all up to date, OR all updates applied under --force)
  1  Refused (updates available but --force not passed; missing manifest;
     path escape; root; outside HOME; not owned)
  2  Safety check failed at write time (symlink, unwritable parent)
  3  Invalid args
```

## Test list first (Beck)

Tier 0 — MUST pass before merge:

- [ ] no manifest → refuses; exit 1; message names `bassclef init`
- [ ] manifest present, all files current → no changes; exit 0
- [ ] manifest present, one template bumped, adopter did not edit, no `--force` → refuses; exit 1; lists the file
- [ ] manifest present, one template bumped, `--force` → writes update; manifest gets new version; exit 0
- [ ] manifest present, adopter edited settings.json, no `--force` → refuses; exit 1; message names "edited by you"
- [ ] manifest present, adopter edited settings.json, `--force` → replaces; new hash + version in manifest; exit 0
- [ ] `--dry-run` on repo with updates available → lists changes; writes nothing
- [ ] manifest carries a path outside target dir (attack case) → refuses; exit 1
- [ ] manifest is malformed JSON → refuses; exit 1; message names manual repair
- [ ] running as root without `--allow-root` → refuses; exit 1
- [ ] symlink at a manifest-listed target path → refuses even with `--force`; exit 2
- [ ] manifest lacks content hash (older init) → fallback: compare current file to current template; still refuses unless `--force` if content differs

Tier 1 — SHOULD pass:

- [ ] `--diff` produces a unified diff for a changed file
- [ ] mid-sync failure — second file write fails; manifest reflects first file's new version, second entry unchanged

## Open questions

Q1 — Where do template versions live for comparison? Current design:
`SETTINGS_TEMPLATE_VERSION` and `SUBSTRATE_CONFIG_TEMPLATE_VERSION`
are exported from the template files. Sync imports them + compares
to the manifest values. If a future template is renamed, sync must
handle "template no longer exists" case gracefully.

Q2 — Compatibility with older manifests (no content hash field).
Approach: treat missing hash as "unknown state" — compare current
file content to the current template. If bytes match → treat as
"no adopter edits". If differ → treat as "edited by you" (safer
default). Add hash on next successful sync.

Q3 — Manifest schema version. When we amend the manifest shape,
does sync need to know the manifest's own version? Yes. Add a
`manifest_schema_version` field alongside the `$bassclef` block.
Sync refuses to touch manifests newer than its known max; older
manifests parse in compat mode.

## What WU-3 must produce

- [ ] `src/commands/sync.ts` — rewrite from stub to real command
- [ ] `src/commands/sync-argv.ts` — small argv reducer
- [ ] `src/lib/manifest-io.ts` — read + validate + write manifest
- [ ] `src/lib/hash.ts` — SHA-256 helper
- [ ] Amend `src/commands/init.ts` to include content hash in manifest
- [ ] Amend `src/commands/init-templates/manifest-json.ts` to include hash field + manifest_schema_version field
- [ ] `src/cli.ts` — wire sync flags
- [ ] `tests/sync.test.ts` — Tier 0 tests
- [ ] `tests/manifest-io.test.ts` — read + validate tests
- [ ] `tests/hash.test.ts` — hash function tests
- [ ] `docs/adrs/ADR-003-bassclef-sync-safety-contract.md` — records the safety contract
- [ ] `CHANGELOG.md` `[Unreleased]` block updated

## What WU-3 does NOT ship

- Bundled substrate assets (skills, rules, hooks, luminaries, agents) —
  the bet's aspirational "runs the equivalent of session-start hook"
  wording. Distribution shape is a publish-workunit concern; sync's
  scope in WU-3 is file-template updates only.
- Interactive prompt / TTY UX — later work
- Three-way merge — later work; refuse-on-adopter-edit is safe today
- Whole-sync transactional rollback — per-file success + per-file
  manifest update gives per-file honesty. Full staging area is later.

## Challenger pass — 2026-08-06

Second-agent read of the decomposition before code. Five KILL-level
fixes fold in. PATCHes below cover the smaller shape corrections.

### K1 — Split `--force` into two independent flags

Original design (L54, L212-213) had `--force` disable both the
version check AND the adopter-edit check. Saltzer-Schroeder principle
5 says those are independent privileges — one flag disabling both is
a privilege-conflation defect.

Revised: two independent flags.

| Flag | Disables |
|---|---|
| `--force` | Refusal on version-outdated files. Sync applies the new template. Adopter-edit refusal still fires; symlink refusal still fires. |
| `--replace-edits` | Refusal on adopter-edited files. Sync applies over the adopter's changes. Version-outdated refusal still fires; symlink refusal still fires. |
| Both flags together | Sync applies to every candidate file regardless of version or edit state. Symlink refusal still fires unconditionally. |

`--force` alone on an adopter-edited file still refuses. Adopter must
type both flags to lose their edits.

### K2 — Per-file write-manifest sequence + inconsistency detection

Original design (L110-112) said "incremental manifest update". Fine,
but a crash between file write and manifest write leaves the file at
the new version with the manifest still recording the old hash. Next
sync sees hash mismatch, incorrectly reports "edited by you".

Revised sequence per file:

1. Compute new content hash from the current template output.
2. Call `writeSafely(path, newContent, {force: true})`.
3. On success, update the manifest entry (path, template, template_version,
   content_hash_sha256, updated_at) and write the whole manifest via
   the audited path.
4. On failure at step 2, leave the manifest entry untouched; report
   the file as errored.

Crash between step 2 and step 3: the file is new, the manifest is
old. Next sync detects `currentHash != manifest.content_hash`. The
refusal message names the possible causes:

```
settings.json — content differs from manifest.
This can happen if:
  1. You edited the file since init.
  2. A prior sync did not finish.
Run `bassclef sync --diff` to see the change, or
    `bassclef sync --replace-edits --force` to overwrite.
```

Not perfect transactional semantics; honest about the failure mode
and gives Sam a clear next step.

### K3 — Fourth case: `Deleted`

Original `detectChange` returned three cases (Current, NeedsUpdate,
EditedAndNeedsUpdate). Missing: manifest lists the file, file is
gone.

Revised: four cases.

| Case | Meaning | Default action |
|---|---|---|
| `Current` | file exists, hash matches, version matches | no change |
| `NeedsUpdate` | file exists, hash matches manifest, template version is newer | refuse unless `--force` |
| `Edited` | file exists, hash does NOT match manifest | refuse unless `--replace-edits` |
| `Deleted` | file does not exist | refuse to recreate unless BOTH `--force` and `--replace-edits` |

Deleted respects adopter intent (they removed the file). Restoring
it needs both consent signals — this is stricter than either alone
because a deletion is a stronger act than an edit.

### K4 — Manifest schema version — one field, one location

Original decomp had `$bassclef.template_version` (manifest-json.ts L31)
AND named a separate `manifest_schema_version` (L253). Two version
fields with overlapping meaning WILL confuse future readers.

Revised: keep `$bassclef.template_version` — rename to
`$bassclef.manifest_schema_version` for clarity. That field is the
manifest's own shape version. Individual file entries carry
`template_version` for THEIR template's version. Two fields, two
distinct meanings:

- `$bassclef.manifest_schema_version` — shape of the manifest itself
- `files[].template_version` — version of THAT file's template

Sync refuses to touch a manifest whose `manifest_schema_version` is
newer than sync's known max. Error message names package upgrade.

### K5 — Fallback for missing hash is refuse-with-remediation, not guess

Original decomp said "if hash missing, compare current to current
template." A legacy manifest saw an OLDER template, so bytes always
differ from the CURRENT template — every legacy manifest becomes
"edited by you" and refuses to update until `--replace-edits`. That
mis-classifies. Sam has no idea what's going on.

Revised: if the manifest lacks `content_hash_sha256` for a file, we
cannot know if the adopter edited. Sync refuses to touch that file
with a specific message:

```
settings.json — content hash missing from manifest.
This manifest was written before content-hash tracking landed.
Run `bassclef init --force` to reset to the current template
(loses any adopter edits) or edit `.bassclef/init.manifest.json`
manually to add the current hash.
```

Refuse-with-remediation is safer than guess. Do not silently promote
a hash-less file to "adopter edited" — that misleads.

### P1 — Symlink refusal restated for sync

Adding to ADR-003 explicitly: sync inherits ADR-002's unconditional
symlink refusal. `--force` overrides existence and version checks;
`--replace-edits` overrides adopter-edit check. Neither flag can
override symlink refusal. `O_NOFOLLOW` fires at every write.

### P2 — File mode preserved

Adopter may have chmod'd `settings.json` to 0600. Sync preserves
the current mode when overwriting.

Revised writer contract: sync reads the current file's mode via
`fs.lstatSync` BEFORE writing, then applies that mode after the
atomic open. `writeSafely` gains an optional `preserveMode: string`
parameter (source mode, expressed as octal string like `"0600"`).

If the file did not previously exist (Deleted + `--force`
`--replace-edits`), mode defaults to 0644 same as init.

### P3 — Refusal message names WHEN

For the `Edited` and `EditedAndNeedsUpdate` cases, the refusal message
names:

- The manifest's `updated_at` for that file (when we last touched it)
- The file's current mtime (when it was last changed on disk)

Example:

```
settings.json — edited by you.
  last sync recorded:  2026-01-15T14:20:00Z
  file mtime is now:   2026-05-02T09:18:44Z
Run `bassclef sync --diff` to see the change.
Run `bassclef sync --replace-edits` to replace your edits.
```

### P4 — Refusal message includes the next-step invocation

Every refusal message ends with a specific command to run. Cooper's
psychological acceptability principle applied at the CLI text level.

### P5 — Sync only touches files carrying `$bassclef` marker

If sync reads a file whose content lacks the `$bassclef` marker (or
`bassclef_template:` front-matter for markdown), sync refuses to
touch it even under both flags. Rationale: the file is not ours.
Adopter can force by manually adding the marker + running sync.

### P6 — Template-changed-but-version-not-bumped catches at test time

Add a Tier 0 test that hashes each template's output at a
version-locked constant and fails if the template output changes
without the `_TEMPLATE_VERSION` constant changing. Prevents future
WU from silently shipping a template revision that sync would not
detect.

### P7 — Init + sync interaction on existing manifest

Amend init: if the manifest already exists AND its
`manifest_schema_version` matches sync's, init refuses with a
"already initialized. Run `bassclef sync` to update." message.
`bassclef init --force` re-baselines the manifest (loses old
`created_at`; the reason `--force` is required).

### P8 — Reformat case documented, not normalized

Sam re-indents settings.json. Byte hash differs. Sync refuses. The
refusal message hints:

```
content differs from init (may be a reformat).
Run `bassclef sync --diff` to see.
```

No pre-hash normalization. Sync stays honest — bytes are bytes.

### N1 — LF/CRLF normalization is a decision, not a deferral

Original decomp put line-ending normalization in "does NOT ship."
Actually it's a decision that must live in ADR-003. Decision: sync
normalizes to LF before hashing. This gives Windows adopters
byte-identical hashes to POSIX adopters.

### N2 — Scope honesty

Substrate distribution stays deferred. Sync's value in 0.0.2 → 0.0.3
is the framework itself — the manifest, the safety contract, the
detection semantics. Templates may not revise between those releases,
in which case sync is a no-op for the adopter. That's honest: the
adopter's first successful sync SIGNAL is a valuable outcome even
without a real update.

### N3 — Test coverage for crash recovery

Adding Tier 1 test:

- [ ] simulate crash between file write and manifest write (write
  new file directly to disk without updating manifest); next sync
  detects hash mismatch and produces the ambiguous refusal message
  from K2

### N4 — runSync line budget

Raised to 200 lines. Same code paths as init plus edit detection.
If it grows past 200, extract the per-file decision helpers.

## Revised file list

- [ ] `src/commands/sync.ts` — real command
- [ ] `src/commands/sync-argv.ts` — small argv reducer (mirrors
      init-argv shape)
- [ ] `src/lib/manifest-io.ts` — read + validate + write manifest;
      handles both current shape (with hashes) and legacy shape
      (without) via the K5 refusal path
- [ ] `src/lib/hash.ts` — SHA-256 helper; normalizes CRLF to LF
      before hashing
- [ ] Amend `src/commands/init.ts` — add content_hash_sha256 per file
      to the manifest; refuse if manifest exists unless `--force`
- [ ] Amend `src/commands/init-templates/manifest-json.ts` — add
      `content_hash_sha256` field per file entry; rename
      `$bassclef.template_version` to
      `$bassclef.manifest_schema_version`
- [ ] Amend `src/lib/write-safely.ts` — accept `preserveMode?: string`
- [ ] `src/cli.ts` — wire sync flags
- [ ] `tests/sync.test.ts` — Tier 0 tests (12+ including all four
      detectChange cases + K2 crash recovery)
- [ ] `tests/manifest-io.test.ts`
- [ ] `tests/hash.test.ts`
- [ ] `tests/template-version-lock.test.ts` — the P6 mechanical
      check
- [ ] `docs/adrs/ADR-003-bassclef-sync-safety-contract.md`
- [ ] `CHANGELOG.md` `[Unreleased]` block updated
