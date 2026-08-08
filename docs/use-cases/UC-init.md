---
tier: standard
id: UC-init
name: Initialize bassclef in a project
level: user goal
primary_actor: Sam (adopter)
scope: bassclef-cli — `bassclef init` command
authored: 2026-08-08
authored_by: agent
cockburn_ceremony: fully-dressed
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
governs_source:
  - src/commands/init.ts
  - src/commands/init-argv.ts
  - src/commands/init-templates/*.ts
  - src/lib/write-safely.ts
  - src/lib/resolve-target-dir.ts
references_adr: ADR-002-bassclef-init-safety-contract.md
---

# UC-init — Initialize bassclef in a project

## Scope

The `bassclef init` command shipped in `@thebassclef/core`. Writes 3 files into a project directory: `.claude/settings.json`, `substrate.config.md`, `.bassclef/init.manifest.json`.

## Level

User goal — Sam runs one command and gets a working project.

## Primary actor

Sam. New adopter. Has `@thebassclef/core` installed globally. Not a bassclef expert. Reads output on a terminal. Attention budget: 5 minutes on first install.

## Stakeholders + interests

| Stakeholder | Interest |
|---|---|
| Sam | Wants a working repo in one command. Does not want silent overwrites. |
| Sam's employer | Wants no files written outside Sam's project directory. No root-only paths touched. |
| Maintainer (bassclef-cli operator) | Wants every write auditable via manifest. Wants safety defaults that adopters cannot accidentally bypass. |
| Future upgrade path | Wants a content hash written at init so `bassclef sync` can detect adopter edits later. |

## Preconditions

- `@thebassclef/core` installed via npm; `bassclef` binary on `$PATH`.
- Sam is in a directory she wants to initialize (default) OR she names one via `--dir <path>`.
- Directory is not owned by root.
- Directory is under `$HOME` OR Sam passed `--allow-any-dir` opting out.
- Sam is not running as root OR she passed `--allow-root` opting out.

## Success guarantee (postconditions)

- Three files exist under the target directory:
  - `.claude/settings.json` — Claude Code settings + SessionStart hook wiring
  - `substrate.config.md` — bassclef project manifest
  - `.bassclef/init.manifest.json` — content-hashed manifest for `bassclef sync`
- Each file has a SHA-256 content hash recorded in the manifest.
- Every write went through `writeSafely()` — the single audited mutation point.
- Terminal output names each file with its outcome (`created` / `unchanged`).
- Exit code 0.

## Minimal guarantee (failure postconditions)

- If any write fails, the manifest reflects reality: successful writes recorded, failed writes reported per file.
- Partial `.tmp` files cleaned up on failure.
- Original files untouched if the safety check refused (default deny on existing files).
- Specific error message names the file and the failure mode.
- Non-zero exit code (1 for policy refusal, 2 for safety-check failure at write time, 3 for invalid args).

## Main success scenario

1. Sam runs `bassclef init` from her project directory.
2. CLI parses argv via `parseInitArgs`.
3. CLI checks if Sam is root — refuses if yes and `--allow-root` not passed.
4. CLI resolves the target directory via `resolveTargetDir` — refuses if outside `$HOME` without `--allow-any-dir` or if not owned by Sam.
5. CLI checks if `.bassclef/init.manifest.json` already exists — refuses with "already initialized" if yes and `--force` not passed.
6. CLI renders the 3 templates via `renderTemplates(targetDir, packageVersion)`.
7. For each template, CLI calls `writeSafely(path, content, { force, mode: 0o644 })`.
8. `writeSafely` opens each file with `O_CREAT | O_EXCL | O_NOFOLLOW` — atomic existence + symlink refusal.
9. CLI writes the manifest via `writeManifest(targetDir, results)` — records path, template version, and SHA-256 hash per file.
10. CLI prints per-file result (`created`, `unchanged`, `refused`) plus a one-line summary.
11. Exit 0.

## Extensions

**1a. Sam passes `--dry-run`:**
- CLI runs steps 2–6 as normal.
- Instead of writing, CLI prints `would create` / `would skip` / `would refuse` per file.
- Exit 0. No files written.

**3a. Sam is root and did not pass `--allow-root`:**
- CLI prints "refused — run as non-root, or pass --allow-root".
- Exit 1.

**4a. Target directory is outside `$HOME`:**
- CLI prints "refused — target outside $HOME. Pass --allow-any-dir if intentional."
- Exit 1.

**4b. Target directory is not owned by Sam:**
- Same shape as 4a.

**5a. Directory already initialized (manifest exists) and `--force` not passed:**
- CLI prints "already initialized — run `bassclef sync` to update, or `bassclef init --force` to re-baseline."
- Exit 1.

**7a. Target path is a symlink (attacker case):**
- `writeSafely` sees `ELOOP` from `O_NOFOLLOW` at open time.
- Even with `--force`, the symlink refusal is unconditional.
- Exit 2 with "refused — symlink at target path."

**7b. Parent directory is not writable:**
- CLI reports "error — parent not writable" for that file.
- Continues attempting the other files.
- Exit 2 if any file errored.

**7c. Write succeeds but verification fails:**
- CLI deletes the partial file (rollback per-file).
- Reports "error — verification failed" for that file.
- Continues attempting the others.

**9a. Manifest write fails after per-file writes succeeded:**
- Files are on disk with new content.
- Manifest is stale (missing hashes).
- Next `bassclef sync` detects "content differs from manifest" per file and refuses without `--replace-edits`.
- Cure: run `bassclef init --force` to re-baseline the manifest.

## Special requirements

- Every message reads at grade 8 or lower per `.claude/rules/plain-english-discipline.md`.
- No bassclef-internal jargon in output (substrate, adopter, workunit, telemetry, andon, provenance, luminary). Enforced by `/kiss words` review on output strings before commit.
- All safety-related refusals name the specific override flag that would opt out.
- All safety-related refusals name the specific file involved.

## Frequency

Once per project. Occasionally re-run with `--force` after major version bumps if the adopter chooses to re-baseline.

## Technology + data variations

- POSIX only for this bet. Windows support is a future WU (out of scope).
- Directory can be any depth under `$HOME`.
- Target files carry Unix line endings (LF). Windows CRLF normalized to LF at hash time per ADR-003 N1.

## Composes with

- ADR-002 pins the safety contract this UC implements.
- `docs/decompositions/wu-2-init.md` covers the code-shape decomposition.
- `docs/interaction-design/2026-08-08-npm-distribution.md` covers arc-level state and sequence diagrams.
- UC-sync — sibling UC; sync consumes the manifest init writes.
