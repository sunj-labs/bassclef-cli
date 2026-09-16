---
tier: lite
id: UC-prepublish-recursive-hook-copy
name: Copy the whole sibling hook tree into the cli tarball
level: subfunction
extends: UC-init
primary_actor: BassclefCliMaintainer
scope: bassclef-cli — the `prepublish-bundle-substrate.mjs` script that builds `dist/lite/` at pack time
authored: 2026-09-16
authored_by: agent
cockburn_ceremony: fully-dressed
bet: docs/iteration-bets/2026-09-16-cli-1.0.3-prepublish-recursive-hook-copy.md
governs_source:
  - scripts/prepublish-bundle-substrate.mjs
references_adr:
  - ADR-004-npm-publish-safety-contract.md
  - ADR-007-npm-lite-substrate-bundling.md
  - ADR-055 (bassclef-upstream — reader contract)
references_input_artifact: docs/input-artifacts/2026-09-16-cli-1.0.3-prepublish-recursive-hook-copy.json
references_decomposition: docs/decompositions/2026-09-16-cli-1.0.3-prepublish-domain.md
references_risk_ledger: docs/risk-ledgers/2026-09-16-cli-1.0.3-prepublish-recursive-hook-copy.md
---

# UC-prepublish-recursive-hook-copy — Copy the whole sibling hook tree into the cli tarball

## Sources read

- `docs/use-cases/UC-init.md` — parent use case; init reads the tarball this prepublish step builds
- `docs/iteration-bets/2026-09-16-cli-1.0.3-prepublish-recursive-hook-copy.md` — goal doc
- `scripts/prepublish-bundle-substrate.mjs` L307-346 — the function this UC replaces
- `/tmp/bc-v0.42.0-check/bassclef/dist/lite/.claude/hooks/` — the source tree the walker should copy
- Cold-adopter-1 smoke output 2026-09-16 — evidence the current shape fails

## Stakeholders and interests

| Stakeholder | Interest |
|---|---|
| Cold adopter (persona: `ColdAdopter`) | `claude` session boots clean on fresh install of `@thebassclef/lite@1.0.3` — no source errors |
| Bassclef cli maintainer | Prepublish script fails loud if the sibling tree is missing OR has drifted; never ships a silently-partial tarball |
| Bassclef upstream maintainer | Cli respects upstream's `dist/lite/` curation — no cli-side filter drops files upstream chose to ship |
| Reader of npm tarball (adopter tooling, security scanner) | Tarball tree matches what upstream's `dist/lite/.claude/hooks/` carries at the pinned tag |

## Preconditions

1. Sibling public bassclef checkout exists at `${BASSCLEF_SIBLING_ROOT}` (env var set by workflow) and points at the pinned tag from `.github/workflows/publish.yml`
2. `${BASSCLEF_SIBLING_ROOT}/dist/lite/.claude/hooks/` exists and contains at least one `*.sh` file
3. `${BASSCLEF_SIBLING_ROOT}/standards/bassclef-wiring-manifest.json` exists and parses as JSON with valid `hooks` block
4. The filtered `settings.json` (tier=lite) has been produced by prior pipeline step

## Postconditions

### Success

1. `dist/lite/.claude/hooks/` in the cli working directory contains an exact recursive copy of `${BASSCLEF_SIBLING_ROOT}/dist/lite/.claude/hooks/` — every `*.sh` file, every subdirectory (including `session-reflection.d/`), every helper (including `trace-helper.sh`)
2. Every file that was executable (mode 0755) in the sibling tree is executable in the cli tree
3. No symlinks were followed — every entry is a plain file or plain directory
4. Postflight assertion has run and confirmed every `command` declared in the filtered settings.json has a matching `*.sh` file in the copied tree
5. `npm pack` picks up the tarball; the tarball's `dist/lite/.claude/hooks/` matches the sibling's

### Failure (any triggers `fail()` which exits non-zero)

1. Sibling hook dir missing — build refuses to continue
2. Sibling hook dir empty — build refuses (Nygard fail-fast)
3. Any declared command lacks a matching binary in the tree — build refuses with the name of the missing command
4. Any entry in the tree is a symlink — build refuses (Saltzer-Schroeder defensive design; symlinks in an npm tarball can escape or duplicate)
5. Any file cannot be read or written for any I/O reason — build refuses with `err.code`

## Trigger

`npm publish` runs prepublish. `scripts/prepublish-bundle-substrate.mjs` calls `buildDistLiteTree(siblingRoot)` which invokes `copyHookBinaries(siblingRoot, distRoot, filteredSettings)`.

## Main success scenario

1. Prepublish reads `${BASSCLEF_SIBLING_ROOT}/dist/lite/.claude/hooks/` as the source tree
2. Prepublish creates `${cwd}/dist/lite/.claude/hooks/` if it does not exist (mode 0755)
3. Prepublish walks the source tree recursively, entry by entry:
   - For each subdirectory: create the same subdirectory in the destination tree
   - For each regular file: read the contents, write to the destination with the same relative path
   - Preserve the executable bit on every file
4. Prepublish counts copied files (both top-level and nested)
5. Prepublish invokes postflight assertion:
   - Every leaf command name in filtered settings.json exists as a `*.sh` file somewhere in the destination tree
   - `dist/lite/.claude/settings.json` was written and has `hookCount >= 1`
   - `dist/lite/standards/bassclef-wiring-manifest.json` is present
   - The 4 templates + settings + wiring manifest are all present
6. Prepublish returns `{ hookCount, copiedHookCount, ... }` to caller
7. `npm pack` reads `files` array from `package.json`, picks up `dist/lite/**`, ships the tarball

## Extensions

### 1a. Sibling hook dir missing

- Prepublish detects `!existsSync(sourceDir)`
- Prepublish calls `fail(...)` with remediation: "expected sibling clone to carry dist/lite/.claude/hooks/ at v0.42.0 or later; upgrade the sibling checkout"

### 1b. Sibling hook dir exists but has zero `*.sh` files

- Prepublish walks the tree, finds zero entries
- Prepublish calls `fail(...)` with remediation: "sibling dist/lite/.claude/hooks/ appears empty; may be a pre-v0.42.0 checkout"

### 3a. Symlink encountered during walk

- Prepublish detects a symlink via `lstat` (not `stat`)
- Prepublish calls `fail(...)` with remediation: "sibling tree contains a symlink at <path>; refusing to follow"

### 3b. File cannot be read (permission, encoding, missing after enum)

- Prepublish catches the I/O error
- Prepublish calls `fail(...)` with the file path + `err.code`

### 3c. Executable bit cannot be set on destination

- Prepublish attempts chmod, catches the error
- On Linux/macOS: `fail(...)` with the path + reason
- On Windows: log INFO, continue (executable bit is not enforced on Windows filesystems)

### 5a. Postflight — declared command has no matching binary

- Postflight finds a `command` leaf name in filtered settings.json with no matching `*.sh` in the destination tree
- Postflight calls `fail(...)` naming the missing command + the tree path checked
- Root cause could be: upstream drift (sibling was pinned to a tag that lacks this hook) OR settings.json filter is stale
- Remediation: verify sibling tag ships the file at that name

### 5b. Postflight — tree has files not declared in settings.json

- Postflight finds `*.sh` files in the destination tree that are NOT commands in settings.json
- Postflight logs INFO with the extra file names (these are helpers like `trace-helper.sh` OR fragments in subdirs)
- Postflight does NOT fail — helpers are expected and intentional

## Success guarantee

Every downstream `npm install -g @thebassclef/lite@1.0.3` on any macOS/Linux cold profile pulls the tarball, drops the walker into place, and reads a hook tree that matches upstream's curation. First `bassclef init` succeeds. First `claude` session opens without SessionStart source errors from missing helpers.

## Minimum guarantee

Even if prepublish partially fails, the tarball never ships with a mismatch between declared commands and available binaries. Postflight is the last-chance circuit breaker per Nygard.

## Scenarios excluded from this UC

- Sibling has schema version drift (major mismatch) — handled by prior `loadWiringManifest` step, not this walker
- Publish workflow itself fails at a step before this UC fires — handled by `.github/workflows/publish.yml` job-level assertions
- Adopter's `bassclef init` on the tarball — that's UC-init; this UC ends at `npm pack`

## Special requirements

- **Determinism**: two runs against the same sibling tag SHA produce byte-identical tarballs (mode + content + tree order). Enables provenance verification per npm's trusted-publisher shape.
- **Fail-fast**: no silent-skip on any file. If prepublish cannot copy a file, it dies.
- **No symlinks**: refuse to follow. Every entry is a plain file or plain directory.

## Frequency

Fires once per published version. Roughly every 1-2 weeks based on prior cadence.

## Business rules

- Every command declared in filtered settings.json MUST have a matching binary in the tarball tree
- The tarball tree MAY contain files not declared as commands (helpers, fragments — this is the fix's whole point)
- No file with the tag `install-class: upstream` shall reach the lite tarball (upstream applies this filter at bundle time; cli trusts that)
- The executable bit is preserved from source to destination on POSIX; Windows is best-effort

## Open issues

- Should cli emit a warning when the sibling tree has `.d/` fragment directories more than one level deep? Deferred — upstream v0.42.0 uses only one level.
- Should postflight also verify `install-class` header on each hook binary? Deferred — cli reads dist/lite/ as opaque; upstream owns that check.
