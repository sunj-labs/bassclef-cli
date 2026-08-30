---
tier: standard
id: ADR-008
title: Pin the bassclef migrate subcommand contract — two-path branch + interactive prompt + config hash preservation + failure catalog
status: accepted
date: 2026-08-30
accepted: 2026-08-30
accepted_via: Step 3 of goal 2026-08-30a authors this ADR; Step 4 tests pin the contract; Steps 5-6 code ships the shape; Step 7 signoff runs grep audit against ledger.
supersedes: null
superseded_by: null
authoring_luminaries:
  primary: [linus-torvalds, john-ousterhout]
  supporting: [david-parnas, michael-nygard, alan-cooper, michael-feathers]
lead_lens: linus-torvalds
goal: docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md
step: 3
references:
  - docs/decompositions/2026-08-30-migrate.md
  - docs/use-cases/UC-migrate.md
  - docs/pre-mortem-mappings/2026-08-30-migrate.md
  - docs/adrs/ADR-002-bassclef-init-safety-contract.md
  - docs/adrs/ADR-003-bassclef-sync-safety-contract.md
  - docs/adrs/ADR-007-npm-lite-substrate-bundling.md
  - docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md
---

# ADR-008 — Pin the bassclef migrate subcommand contract

## Context

`@thebassclef/core@0.1.0` shipped 149 substrate files via scope-b1 (PR #36 merged 2026-08-30). Adopters on prior versions have no clean upgrade path. Two states matter:

- **0.0.2 legacy** — 3-file init manifest. `bassclef init --force` overwrites the 3 config files (per ADR-002 D1). Adopter loses her `.claude/settings.json` + `substrate.config.md` + `CLAUDE.md` edits.
- **0.0.1 name-reservation** — no init manifest. Adopter has nothing to migrate but no automated path to reach 0.1.0 shape either.

Goal 2026-08-30a picked Option b (per plan doc L64) — ship `bassclef migrate` as a new subcommand rather than folding auto-migrate into `bassclef sync`. This ADR pins the 6 decisions the code must honor.

Forces at play:

- **Adopter contract lives at the config-file boundary.** Per Linus, adopters editing `.claude/settings.json` between init and migrate expect their edits to survive. Any decision that overwrites edited config files violates the userspace stance.
- **One CLI verb hides the two paths.** Per Ousterhout, Sam sees `bassclef migrate` — one command. Path A (legacy) and Path B (no-manifest) live behind detection. Any decision that surfaces the branch to the operator violates the depth invariant.
- **Explicit adopter action beats surprise.** Per Cooper (goal doc L91), Sam runs the command deliberately at her timing. Interactive prompt confirms the shape before writes fire. Any decision that writes without confirmation violates Cooper's lens.
- **Every failure names its fix.** Per Nygard (goal doc L97), refusal messages end with a specific command Sam can run. Any decision that reports a cause without a cure violates the fail-with-fix discipline.
- **Testability of interactive surface.** Per Feathers, prompt logic must characterize under test without a live TTY. Any decision that binds prompts to real stdin makes the module untestable.

Alternatives considered:

1. **Auto-migrate inside `bassclef sync`** (scope-e Option a per plan doc L59-62). Rejected — silent state change during a routine sync violates Cooper lens. Adopter can't decide when the upgrade happens.
2. **Ship both paths (auto + explicit)** (scope-e Option c per plan doc L69-71). Rejected — belt-and-suspenders adds surface for the same job; more testing; two documented upgrade paths confuse adopters.
3. **Prompt only for destructive changes; write silently for pure adds.** Rejected — the distinction (add vs preserve vs skip) is exactly what the prompt shows; hiding it defeats the visibility.
4. **Third-party prompt library (`enquirer` / `prompts`).** Rejected — violates minimal-dep discipline; adds attack surface per Saltzer-Schroeder; Node built-in `readline/promises` covers the shape.
5. **Reimplement init flow inside migrate for Path B.** Rejected — violates Ousterhout deep-module reuse; two code paths drift; every init bugfix owed to two places.

## Decision

The `bassclef migrate` contract for `@thebassclef/core@0.1.1` and every subsequent iteration.

### Decision 1 — Two-path branch via detectAdopterState

Migrate calls `detectAdopterState(targetDir)` — a new composed function in `src/lib/migrate.ts` that wraps existing `readManifest` (from `src/lib/manifest-io.ts`) and existing boolean `detectLegacyManifest` (also from `manifest-io.ts`). The composed function returns a four-value discriminated shape:

- **`current`** — manifest present at 0.1.0 shape (files.length !== 3 AND schema_version >= 0.1.0). Migrate prints "Already at 0.1.0 shape. Nothing to migrate." Exits 0.
- **`legacy-3-entry`** — manifest present at 0.0.2 shape (files.length === 3 OR schema_version < 0.1.0). Migrate dispatches Path A.
- **`no-manifest`** — `readManifest` throws `ManifestReadError` with kind `'Missing'`. Migrate dispatches Path B.
- **`{ kind: 'error', message }`** — `readManifest` throws with kind `'Malformed'` or `'SchemaTooNew'`. Migrate refuses with exit code matching the failure catalog (D4).

Unknown shapes that pass basic manifest structure but do not match legacy or current heuristics (e.g., 5-entry v0.1.0 manifest) trigger the Nygard exit-5 branch: "Adopter state does not match 0.0.x or 0.1.0. Reinstall `@thebassclef/core` then rerun."

Rationale — Ousterhout deep-module discipline. Sam types one verb; Migrate hides the branch. R4 compensator (unknown state → fail-fast) lives at this decision. `detectLegacyManifest` stays a pure boolean in manifest-io.ts (preserves the scope-b1 shape shipped in commit c84fa84); the composition lives in migrate.ts where the four-value shape is needed.

**Step 3.5 amendment (2026-08-30):** Decision 1 originally phrased `detectLegacyManifest` as returning the three-value enum. Reading `src/lib/manifest-io.ts` L116-121 confirmed it returns boolean. The four-value shape moved to the new `detectAdopterState` in `src/lib/migrate.ts`. The `no-manifest` path now catches the existing `ManifestReadError kind: 'Missing'` per `manifest-io.ts` L34-40. No change to adopter-visible behavior.

### Decision 2 — Interactive prompt via readline/promises + tiny module

`src/lib/prompt.ts` exports `confirm(question, opts)` — one function wrapping Node's built-in `readline/promises`. Contract:

- Default answer is No (Enter alone returns false)
- `--yes` argv flag passes `ttyOverride: 'yes'` — bypasses prompt
- Test suites pass `ttyOverride: 'yes' | 'no'` — bypass real TTY
- No TTY available AND no override → return false with a stderr note (safe default)

Path A shows the prompt with the shape: `Ready to migrate: 146 to add; 3 to preserve; 0 to skip. Proceed? [y/N]`. Sam confirms — Migrate proceeds. Sam declines — Migrate exits 0 with "Aborted. No files changed."

Path B skips the prompt for the init dispatch itself but names what's about to happen: `No prior manifest detected. Running full init for 149 files.`

Rationale — Cooper lens (goal doc L91) — no surprise state change; Sam sees the shape before writes fire. Feathers characterization — `ttyOverride` makes the module testable without a live TTY (R5 compensator).

### Decision 3 — Config file hash preservation contract

Path A calls `computeConfigHashes(targetDir, CONFIG_FILES)` before any write. The function returns SHA-256 for each of the three named files that exists on disk:

- `.claude/settings.json`
- `substrate.config.md`
- `substrate.secrets.md`

**Step 3.5 amendment (2026-08-30):** The third config file is `substrate.secrets.md`, NOT `CLAUDE.md`. Confirmed by reading `tests/fixtures/v0.0.2-init-manifest.json` L26-30 — the v0.0.2 legacy manifest carries exactly these three files. `CLAUDE.md` in the original draft was a factual error. Corrected here + in the risk ledger + in the decomposition.

For each hash, Migrate records the current SHA-256 in the new 149-entry manifest. Any file whose hash differs from the template default (adopter edited it) stays untouched on disk — the write path only fires for files classified as `add`. The manifest records the current hash so `bassclef sync` classifier operates correctly on the next run.

Line endings normalized to LF before hashing (per ADR-003 N1 discipline). Windows adopters get byte-identical hashes to POSIX adopters.

Rationale — Linus adopter-contract stance (R2 compensator). The three files are the boundary between bassclef substrate and adopter customization. Their content survives migration under this contract.

### Decision 4 — Failure mode catalog (Nygard)

Every failure path names its cure. The catalog per UC-migrate extensions maps to specific commands:

| Failure | Exit | Cure named |
|---|---|---|
| Argv parse error | 1 | Corrects the argv shape (`--dir` requires a value; unknown flag rejected by name) |
| Root without `--allow-root` | 1 | "Run as the project owner, OR pass `--allow-root`" |
| Manifest malformed JSON | 1 | "Repair manually, OR run `bassclef init --force` to reset" |
| Manifest schema newer than Migrate knows | 4 | "Upgrade `@thebassclef/core` to at least the version that wrote this manifest" |
| Unknown adopter state (D1 branch else) | 5 | "Reinstall `@thebassclef/core` then rerun" |
| Sam declines at prompt | 0 | (no cure needed; state unchanged) |
| Per-file write refusal (parent not writable, symlink) | 2 | Per-file line names the specific reason; global suggest `bassclef sync --replace-edits --force` for re-baseline |
| Mid-migration crash then retry | (varies) | On retry: reports hash mismatch on already-written files, names both causes (adopter edit vs prior crash), suggests `bassclef sync --replace-edits --force` |

Refusal messages end with the specific command. No cause-only messages ship.

Rationale — Nygard fail-with-fix (R3 + R4 compensators). Sam sees what happened AND what to do next in the same line.

### Decision 5 — Path B integration via runInit reuse

Path B dispatches `runInit(argv)` from existing `src/commands/init.ts`. Migrate does not re-implement init logic. The reuse path:

1. Migrate constructs an argv slice matching init's contract (target dir + flag mapping)
2. Migrate calls `runInit(argv)` — init writes 149 files + manifest via its own safety envelope
3. Migrate surfaces init's exit code as its own

Migrate adds no wrapper behavior on Path B other than the pre-dispatch line ("No prior manifest detected. Running full init for 149 files.") and the post-dispatch folder-guidance line (RFC N4).

Rationale — Ousterhout deep-module reuse (R6 compensator). Init already carries the full safety envelope (ADR-002); every bugfix to init serves migrate for free. Two code paths would drift.

### Decision 6 — Version bump + release cadence

This work ships as `@thebassclef/core@0.1.1` — patch bump per semver.

Justification per semver:
- **PATCH** — new subcommand is additive; no existing CLI verb changes shape; no exit code semantics change for `init` or `sync`
- Not **MINOR** — while a new subcommand is a new capability, the RFC L3 disposition (goal doc L143) names "adopter migration ships as MINOR" as the precedent for major-adopter-affecting migrations. The migrate command itself IS the adopter-affecting change, but its shape (opt-in explicit command) means adopters who don't run it see no change. **AMENDMENT NOTE:** If operator judgment says the new subcommand warrants MINOR to signal "new capability worth reading the CHANGELOG for," bump to 0.2.0 instead. Decision deferred to release-time per operator preference.
- Not **MAJOR** — no breaking API change; no removed feature; no incompatible schema shift

Release cadence — one release per goal completion. This goal ships 0.1.1 (or 0.2.0 per amendment above). Subsequent iterations may ship patch versions (0.1.2, 0.1.3...) for bug fixes without re-invoking this ADR.

RFC L3 CHANGELOG note — the 0.1.1 (or 0.2.0) CHANGELOG entry names "adopter migration ships as MINOR" as a documented precedent even if this release itself is PATCH. Future adopter-migration releases MUST bump MINOR at minimum.

Rationale — matches `standards/npm-versioning-and-changelog.md`. RFC L3 refinement absorbed here as a precedent-setting CHANGELOG entry.

## Status

`accepted` on 2026-08-30 via Step 3 of goal 2026-08-30a. Ratified by Step 7 signoff (grep audit against ledger) + Step 8 closeout (PR body pins the ADR).

## Consequences

**Easier:**

- Sam runs one command (`bassclef migrate`) and upgrades from 0.0.x to 0.1.0+ without config data loss.
- Adopters on 0.0.1 (name-reservation only) get an automated first-touch path via Path B.
- Every failure names its cure — Sam does not have to search for the fix.
- `--dry-run` lets Sam preview the shape before committing.
- `--yes` covers CI + scripted upgrades.

**Harder:**

- Two new command files + two new lib files ship (per decomposition § Control objects). Test-suite grows by ~28 Tier 0 tests. CI runtime up slightly.
- Interactive prompt adds one new concern (`src/lib/prompt.ts`) to reason about. Testability discipline (`ttyOverride`) mitigates.
- Path B integration means changes to init.ts must consider migrate's dispatch. Small; init's contract is stable per ADR-002.

**Enables:**

- Future migrations (0.2.0, 1.0.0, later) follow the same shape — detect state, prompt, preserve edits, dispatch add/preserve/skip.
- `bassclef migrate --dry-run` becomes a diagnostic tool operators run to check adopter state without side effects.
- Non-interactive CI upgrades via `--yes`.

**Blocks (until reconsidered):**

- No cross-adopter batch migration (one adopter at a time; operator dispatches per project). Batch tooling is a possible extension.
- No rollback command (`bassclef unmigrate`). If Sam wants to revert, she uses git. Rollback shape adds complexity out of scope this goal.
- No automatic detection at `bassclef sync` time. Adopter must run `migrate` explicitly (Cooper lens). Auto-detection is scope-e Option a and stays deferred unless adopter feedback justifies revisit.

**Invariants established (semver-locked for 0.1.1 and beyond):**

Two-path branch:
- `detectLegacyManifest` returns exactly three values: `current`, `legacy-3-entry`, `no-manifest`. Renaming a value requires ADR amendment.
- Unknown shape → exit 5. Removing the fail-fast is MAJOR.

Interactive prompt:
- `confirm(question, opts)` — API shape stable. `ttyOverride` param stable for test injection.
- `--yes` flag semantics stable. Renaming requires ADR amendment.
- Default answer is No. Changing the default is MAJOR (adopter safety regression).

Config file hash preservation:
- Three named files hashed per Path A: `.claude/settings.json`, `substrate.config.md`, `substrate.secrets.md`. Adding a file to the list is MINOR. Removing one is MAJOR.
- LF normalization before hashing. Removing normalization breaks Windows adopters.

Failure catalog:
- Every refusal message ends with a specific command. Losing this is MAJOR (Nygard regression).
- Exit codes stable: 0 success/abort, 1 argv/root/manifest error, 2 write refusal, 4 schema version, 5 unknown state.

Path B integration:
- Reuses existing `runInit` entry point. Extracting shared `initCore` deferred unless test friction surfaces.

Version:
- 0.1.1 (or 0.2.0 per operator judgment) ships this goal. Future migration goals bump MINOR at minimum (RFC L3 precedent).

Any change to a listed decision, safety check, or invariant is a MAJOR bump per `standards/npm-versioning-and-changelog.md`.

## Traceability to risk ledger

Every decision above pins to at least one risk ledger row. Every ledger row has at least one decision.

| Decision | Ledger rows honored |
|---|---|
| D1 — Two-path branch + detectLegacyManifest | R4 (unknown state → fail-fast) |
| D2 — Interactive prompt + tiny module | R5 (prompt testability) + R7 (no-TTY safe default) |
| D3 — Config file hash preservation | R2 (Linus adopter contract) |
| D4 — Failure mode catalog | R3 (mid-migration bulkhead) + R4 (unknown state) |
| D5 — Path B integration via runInit reuse | R6 (Ousterhout deep-module reuse) |
| D6 — Version bump + release cadence | (documented via CHANGELOG L3 note; not a code-level row) |

R1 (argv reducer errors — small deterministic surface) lives at the code-shape layer per decomposition § Control objects.

## References

- Goal doc — `docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md`
- Decomposition (Step 2) — `docs/decompositions/2026-08-30-migrate.md`
- UC-migrate (Step 1) — `docs/use-cases/UC-migrate.md`
- Risk ledger (this Step 3) — `docs/pre-mortem-mappings/2026-08-30-migrate.md`
- ADR-002 — init safety contract (Path B inherits)
- ADR-003 — sync safety contract (Path A borrows classifier semantics)
- ADR-007 — parent bundle contract (Path A reads the bundled 149-entry manifest)
- RFC-0001 — disposition names scope-e deferrals absorbed here (N3, N4, S2, L3)
- Parent roadmap — `bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` (5 existing + 9 signup adopters)
- Luminaries:
  - `linus-torvalds.md` — "we don't break userspace"; D3 preserves adopter edits
  - `john-ousterhout.md` — deep modules; D1 + D5 hide depth
  - `david-parnas.md` — information hiding; D2 wraps readline behind confirm()
  - `michael-nygard.md` — fail-with-fix; D4 failure catalog
  - `alan-cooper.md` — deliberate adopter action; D2 interactive prompt
  - `michael-feathers.md` — characterization tests; D2 ttyOverride makes prompt testable
