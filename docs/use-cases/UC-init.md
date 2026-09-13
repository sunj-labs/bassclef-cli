---
tier: standard
id: UC-init
name: Initialize bassclef in a project
level: user goal
primary_actor: Sam (adopter)
scope: bassclef-cli — `bassclef init` command
authored: 2026-08-08
authored_by: agent
amended: 2026-09-13
amended_scope: goal 2026-09-13 cli#68 Phase 1 Step 5 — postconditions rewritten to match dist/<tier>/ tree walk per bassclef-upstream ADR-055 D1 + coord doc §Cockburn UC-init. Verbatim copy per V2 pre-mortem catch.
cockburn_ceremony: fully-dressed
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
goal: docs/iteration-bets/2026-09-13-cli-68-oo-ad-updates-post-adr-007-pivot.md
governs_source:
  - src/commands/init.ts
  - src/commands/init-argv.ts
  - src/commands/init-templates/*.ts
  - src/lib/write-safely.ts
  - src/lib/resolve-target-dir.ts
  - src/lib/copy-substrate.ts
references_adr: ADR-002-bassclef-init-safety-contract.md
references_new_adr: ADR-009-manifest-as-init-contract-source.md
references_coord: bassclef-upstream/docs/coordination/2026-09-12e-cli-boundary.md
---

# UC-init — Initialize bassclef in a project

## Scope

The `bassclef init` command shipped in `@thebassclef/<tier>`. Post-ADR-055 pivot (2026-09-13), init walks the bundled `dist/<tier>/` tree and writes each file to the adopter repo at matching path. Prior scope (write 3 named files) preserved for historical audit at §History below.

## Level

User goal — Sam runs one command and gets a working project with hooks armed at session-start.

## Primary actor

Sam. New adopter. Has `@thebassclef/<tier>` installed via npm. Not a bassclef expert. Reads output on a terminal. Attention budget: 5 minutes on first install.

## Stakeholders + interests

| Stakeholder | Interest |
|---|---|
| Sam | Wants a working repo in one command; wants the banner to confirm what happened; does not want silent overwrites. |
| Sam's employer | Wants no files written outside Sam's project directory; no root-only paths touched. |
| Maintainer (bassclef-cli operator) | Wants every write auditable via manifest; wants safety defaults adopters cannot accidentally bypass; wants hook-count banner to close the empty-hooks class since 0.1.0. |
| Future upgrade path | Wants a content hash written at init so `bassclef sync` can detect adopter edits later. |
| Bassclef-upstream author | Wants the manifest at `standards/bassclef-wiring-manifest.json` to be the sole authored source of truth per ADR-055 D1. |

## Preconditions

Per bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` §Cockburn UC-init §Preconditions (verbatim):

1. Sam has installed `@thebassclef/<tier>@<version>` via npm
2. Sam is in a git repo root
3. Bundled substrate at `node_modules/@thebassclef/<tier>/dist/<tier>/` present
4. Wiring manifest at `node_modules/@thebassclef/<tier>/dist/<tier>/standards/bassclef-wiring-manifest.json` present with valid schema (schema_version field present + `additionalProperties: false` satisfied)

Additional preconditions inherited from ADR-002 safety contract (see §Invariants):

- Directory is not owned by root
- Directory is under `$HOME` OR Sam passed `--allow-any-dir` opting out
- Sam is not running as root OR she passed `--allow-root` opting out

## Success guarantee (postconditions)

Per bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` §Cockburn UC-init §Postconditions (success) (verbatim):

1. Adopter repo mirrors `dist/<tier>/` tree exactly (file-for-file)
2. `.claude/settings.json` in adopter repo matches manifest entries where `tier ≤ <tier>`
3. Session-start hooks fire on next Claude Code session
4. `bash .claude/hooks/tests/init-output-parity.test.sh` (from substrate) passes

Cli-side reinforcements:

- Each file has a SHA-256 content hash recorded in `.bassclef/init.manifest.json`
- Every write went through `writeSafely()` — the single audited mutation point (ADR-002 complete mediation preserved)
- Terminal output ends with the hook-count banner: `N hooks armed (<tier> tier)` per ADR-055 D5
- Exit code 0

## Minimal guarantee (failure postconditions)

Per bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` §Cockburn UC-init §Postconditions (failure) (verbatim):

1. Adopter repo unchanged
2. Structured error message with file path expected + remediation

Cli-side reinforcements per ADR-002 safety contract:

- If any write fails, the manifest reflects reality: successful writes recorded, failed writes reported per file
- Partial `.tmp` files cleaned up on failure
- Original files untouched if the safety check refused (default deny on existing files)
- Non-zero exit code (1 for policy refusal, 2 for safety-check failure at write time, 3 for invalid args, 4 for manifest missing per ADR-055 D4, 5 for schema incompatible per ADR-055 D4)

## Main success scenario

Per bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` §Cockburn UC-init §Main success scenario (verbatim):

1. Sam runs `bassclef init`
2. cli reads `dist/<tier>/` tree from bundled substrate
3. cli walks tree; copies each file to adopter repo at matching path
4. cli reads wiring manifest; writes `.claude/settings.json` with entries filtered by tier
5. cli prints hook-count banner: `N hooks armed (<tier> tier)`
6. Sam opens Claude Code in the repo; hooks fire at session-start

Cli-side reinforcements (safety machinery preserved):

- Before step 2: CLI parses argv via `parseInitArgs`; checks root refusal per ADR-002; resolves target directory via `resolveTargetDir`; checks manifest-exists refusal per ADR-002 (unless `--force`)
- Each copy in step 3 goes through `writeSafely(path, content, { force, mode: 0o644 })` — atomic existence check via `O_CREAT | O_EXCL | O_NOFOLLOW`
- Step 4 setting.json copy is byte-for-byte from `dist/<tier>/.claude/settings.json` per ADR-009 D1; cli does NOT compose its own settings.json
- After step 5: cli writes `.bassclef/init.manifest.json` recording path + template + template version + SHA-256 hash per file written

## Extensions

Per bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` §Cockburn UC-init §Extensions (verbatim):

**4a. Manifest missing or schema invalid**

- cli exits non-zero with structured error naming the path expected + schema_version required. Silent skip is NOT acceptable (Hyrum W3 finding folded per RFC-0002)
- Exit code 4 (manifest missing) or 5 (schema incompatible)
- Message shape: "Wiring manifest missing at `<path>`. Cli built for schema_version `<major>.x`. Run `npm install @thebassclef/<tier>@<latest>` to fix."

**4b. Existing `.claude/settings.json` in adopter repo**

- cli refuses overwrite; asks OR appends non-destructively (Cooper C2 finding folded to cli scope per RFC-0002)
- Per ADR-002 Default 1: refuse-overwrite is the default; `--force` disables per-file existence check
- Message shape names `--force` as remediation

**5a. Sam runs `bassclef init` a second time**

- cli detects existing files; asks OR skips per ADR-002 refuse-overwrite invariant
- Per ADR-002 manifest-exists refusal: cli exits 1 with message naming `bassclef sync` as update path + `bassclef init --force` as re-baseline path

Cli-side extensions preserved from prior UC-init (ADR-002 safety contract):

**1a. Sam passes `--dry-run`:**

- cli runs steps 2-5 as normal (walks tree, filters manifest, formats banner)
- Instead of writing, cli prints `would create` / `would skip` / `would refuse` per file
- Exit 0. No files written.

**3a. Sam is root and did not pass `--allow-root`:**

- cli prints "refused — run as non-root, or pass --allow-root"
- Exit 1

**Root-refusal path:**

- Target directory is outside `$HOME` OR not owned by Sam: cli prints "refused — target outside $HOME. Pass --allow-any-dir if intentional." Exit 1

**Symlink refusal (unconditional per ADR-002 Default 5):**

- Target path is a symlink at write time (`ELOOP` from `O_NOFOLLOW`)
- Exit 2 with "refused — symlink at target path"
- `--force` does NOT override this — symlink refusal is unconditional

**Write-time failure paths (ADR-002 preserved):**

- Parent directory not writable — reports "error — parent not writable" for that file; continues attempting the others; exit 2 if any file errored
- Verification failure post-write — deletes the partial file (rollback per-file); reports "error — verification failed" for that file; continues attempting the others
- Manifest write fails after per-file writes succeeded — files on disk with new content; manifest stale; next `bassclef sync` detects "content differs from manifest" per file and refuses without `--replace-edits`

## Special requirements

- Every message reads at grade 8 or lower per `.claude/rules/plain-english-discipline.md`
- No bassclef-internal jargon in output (substrate, adopter, workunit, telemetry, andon, provenance, luminary). Enforced by `/kiss words` review on output strings before commit
- All safety-related refusals name the specific override flag that would opt out
- All safety-related refusals name the specific file involved
- Hook-count banner per ADR-055 D5 renders at the end of successful output; shape `N hooks armed (<tier> tier)` where `N` is the count of hook entries in the manifest for the tier

## Frequency

Once per project. Occasionally re-run with `--force` after major version bumps if the adopter chooses to re-baseline.

## Technology + data variations

- POSIX first-class for this bet. Windows support is a future step (out of scope)
- Directory can be any depth under `$HOME`
- Target files carry Unix line endings (LF). Windows CRLF normalized to LF at hash time per ADR-003 N1
- Tier resolves from the installed npm package name: `@thebassclef/lite` reads `dist/lite/`, `@thebassclef/standard` reads `dist/standard/`, `@thebassclef/ultra` reads `dist/ultra/`
- Per ADR-055 D7 tier hierarchy: ultra ⊇ standard ⊇ lite. Upstream build step at `scripts/build-adopter-tree.sh` honors this via `tier_superset()` function

## Composes with

- ADR-002 pins the safety contract this UC implements
- ADR-005 (amended 2026-09-13) — Sam demo acceptance criterion this UC's Success guarantee satisfies
- ADR-007 (amended 2026-09-13) — bundle path contract; ADR-007's D4 init copy semantics feed this UC
- ADR-009 (new 2026-09-13) — manifest as init contract source; D1-D7 read at cli side
- bassclef-upstream ADR-055 — reader-side contract; D1-D7 pin this UC's postconditions
- bassclef-upstream `docs/coordination/2026-09-12e-cli-boundary.md` — Cockburn UC-init + Jacobson BCE + GRASP; this UC copies §Cockburn UC-init verbatim per V2 pre-mortem catch
- `docs/decompositions/wu-2-init.md` — code-shape decomposition for the prior 3-file shape (Phase 3 authors a new decomposition for the tree-walk shape)
- `docs/decompositions/npm-install-harness-domain.md` — harness domain; amended 2026-09-13 to add `AdopterSessionSimulator` object that simulates Sam's post-init session-start
- UC-sync — sibling UC; sync consumes the manifest init writes
- UC-migrate — sibling UC; migrate handles the 0.0.x → 0.1.x transition
- `docs/interaction-design/2026-08-08-npm-distribution.md` — thread-level state and sequence diagrams

## History

**Prior UC-init (2026-08-08 → 2026-09-13).** Postconditions read "3 files exist under the target directory: `.claude/settings.json`, `substrate.config.md`, `.bassclef/init.manifest.json`." That framing matched the pre-ADR-055 world where cli composed a minimal settings.json template.

**Why the rewrite.** Bassclef-upstream 12e shipped at v0.39.0 pinning the reader-side contract at ADR-055. Cli init walks `dist/<tier>/` tree from bundled substrate. `dist/<tier>/.claude/settings.json` is pre-composed by the upstream build step and copied verbatim. The prior UC-init's 3-file postcondition no longer describes the shipped state after Phase 3 lands.

**Prior text preserved in git history.** Every prior version of this UC lives in `git log docs/use-cases/UC-init.md`. Nygard ADR lifecycle discipline: contracts get amended in place; history preserves via version control.

**When this rewrite becomes the shipped state.** Phase 3 (cli init walker code) lands the code that satisfies the new postconditions. Until Phase 3 ships, cli init runs on the current 3-file shape. This UC-init describes the target state Phase 3 implements.
