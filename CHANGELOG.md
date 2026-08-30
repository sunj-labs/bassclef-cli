# Changelog

All notable changes to `@thebassclef/core` land here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The full versioning + changelog discipline lands in WU-5 per iteration
bet 2026-08-06b.

## [Unreleased]

### Added — scope-b1 (npm-lite substrate bundling; PR #36)

- npm-lite substrate bundling — `@thebassclef/core` now ships 149 substrate files (skills + rules + hooks + luminaries + agents + standards + ADRs + libs + templates) alongside the CLI. Adopters get a working bassclef install from `npm install -g @thebassclef/core && bassclef init`. Prior 0.0.2 wrote only 3 config files and stopped.
- `scripts/prepublish-bundle-substrate.mjs` — pure Node prepublish script that reads the sibling `bassclef-upstream/lite-manifest.json` and writes `substrate/` under the package root at publish time. Three fail-fast checks (manifest load + source existence preflight + count + size postflight). 5MB size ceiling.
- `src/lib/copy-substrate.ts` — one public `copySubstrate` function that walks the bundled 149-entry manifest, verifies each source's SHA-256 against the manifest hash, and dispatches through `writeSafely` with per-directory progress signals and fix-oriented error messages.
- `src/lib/paths.ts` — `SUBSTRATE_ROOT` + `CLAUDE_TARGET_ROOT` constants (single source of truth per R6 discipline).
- `detectLegacyManifest` in `src/lib/manifest-io.ts` — reads two signals (files.length === 3 OR schema_version < 0.1.0) to identify the v0.0.2 shape adopters upgrading from.
- `bassclef sync` extension — walks the 149-entry manifest with L2 output shape (per-directory summary default; `--verbose` shows per-file lines).
- `MANIFEST_SCHEMA_VERSION` bumped from 0.0.2 to 0.1.0 (H1 schema evolution discipline).
- ADR-007 — pins the substrate bundling contract (bundle mechanism + prepublish safety envelope + init copy semantics + sync output shape + manifest schema evolution).
- Full RFC-0001 council review (linus + hyrum + brooks + saltzer-schroeder + norman) — 16 findings; scope trimmed to scope-b1 with migration Path A + RemoteFetchStrategy + 4 minor RFC cures deferred to scope-e.

### Added — scope-e (bassclef migrate subcommand; PR #39)

- `bassclef migrate` subcommand — upgrades adopters from 0.0.x install shapes to the current 149-file substrate without losing config edits. Two paths auto-selected via `detectAdopterState`: Path A upgrades a 0.0.2 install with 3-file legacy manifest (adds 146 substrate files; preserves 3 config files via SHA-256 hash comparison); Path B dispatches full init for 0.0.1 name-reservation state. Interactive prompt confirms the shape before writes; `--yes` bypasses for CI. Full contract in ADR-008 + UC-migrate + `docs/migrations/0.1.0.md`.
- `computeConfigHashes` in `src/lib/manifest-io.ts` — computes SHA-256 for named config files under a target directory; LF-normalized per ADR-003 N1 (Windows adopter parity).
- `src/lib/prompt.ts` — thin Node `readline/promises` wrapper with `ttyOverride` injection for test isolation.
- `CONFIG_FILES` + `CURRENT_ENTRY_COUNT` constants in `src/lib/paths.ts` — single source of truth per R6 discipline.
- ADR-008 — pins the migrate subcommand contract (two-path branch + interactive prompt + config hash preservation + failure catalog).

### Changed

- `bassclef init` final line now names the `.claude/` folder + suggests `.gitignore` addition (RFC N4 refinement — Sam sees what to commit).
- `src/lib/copy-substrate.ts` — bundle path resolution uses `import.meta.url` + relative walk-up-to-package.json instead of `createRequire` (RFC S2 refinement — idiomatic ESM; falls back to the prior path if package.json is unreachable).

### Fixed

### Notes

**Adopter migration ships as MINOR** is the precedent this release documents (RFC L3 refinement). Future migrations that touch adopter-visible state MUST bump MINOR at minimum. PATCH releases stay reserved for bug fixes that require no adopter action.

**Version bump for migrate:** operator judgment picks between PATCH (0.1.1 — new additive command; adopters not running migrate see no change) or MINOR (0.2.0 — signals "new capability worth reading the CHANGELOG for"). Decision pinned at release time per ADR-008 D6.

## [0.0.2] - 2026-08-13
### Changed — ADR-005 second amendment (Model C contract accepted)
- `docs/adrs/ADR-005-npm-distribution-architecture.md` gains a §Amendment 2026-08-12 pass 2 section. Flips the pass-1 pending markers to accepted after bassclef-upstream answered on the four questions.
- Q1 resolved — bassclef-upstream ships `lite-manifest.json` at repo root with `manifest_version` semver. 108 entries in 1.2.2. bassclef-cli reads the manifest, not raw frontmatter (per bassclef-upstream #1143 anti-pattern).
- Q2 resolved — bassclef-upstream ADR-051 D1 (commit `d54e701a`, PR #1185) moves primary extract upstream. bassclef-upstream ships `dist/lite/` pre-built with operator-private filter + andon scan applied. bassclef-cli reads the tree unchanged; keeps `tier-filter.mjs` + `andon-scan.mjs` as backup gates per Saltzer-Schroeder complete mediation.
- Q3 resolved — bassclef-cli auto-follows latest v-tag at build time. Records picked tag in `package.json` build metadata. Runtime `bassclef sync` stays orthogonal.
- Q4 pending — paid tier extraction contract deferred until free tier ships cleanly.
- bassclef-cli #25 filed to track the reader implementation on this side. Waits on bassclef-upstream #1184 shipping `scripts/build-lite-bundle.sh` + `dist/lite/` tree.
- Confirmation of (A) for extraction shape posted at bassclef-upstream #1184 (comment 5265798011).
- Iteration e (first tag 0.0.2) sequencing unchanged. Model C bundled ship shape lands in a follow-on cut once #1184 ships.

### Changed — ADR-005 amendment for Model C (open core with paid tiers)
- `docs/adrs/ADR-005-npm-distribution-architecture.md` gains a §Amendment 2026-08-12 — pivot to Model C section. Direction accepted; extraction contract with bassclef-upstream pending upstream reply.
- New shape: `@thebassclef/core` = free CLI + lite substrate bundled (change from prior "dist, README, LICENSE, nothing else"). `@thebassclef/standard-pro` + `@thebassclef/ultra-pro` = paid packages installed via npm auth token. `@thebassclef/lite` reserved defensively per issue #16 but likely never ships as a real package.
- Iteration e (first tag 0.0.2) unchanged. Model C ship shape (bundle lite substrate) lands in a later cut once upstream confirms the extraction contract.
- Prompt drafted for bassclef-upstream asking them to clarify the extraction contract (manifest shape, pull mechanism, version pinning, paid-tier symmetry). Prompt lives in session turn output; operator sends it to bassclef-upstream by hand.

### Added — iteration h substrate hook spec (Phase 2 evidence)
- `docs/proposed-substrate-hooks/requirement-annotation-check.md` — full spec of the PreToolUse hook that should ship on bassclef substrate. Describes trigger (Edit / Write / MultiEdit on source, test, vite.config.ts, tsconfig.json, docs/requirements/*.md), inputs, per-class behavior (source, test, registry), failure format per bassclef `blocked-items.md`, override paths, sibling composition (with `pattern-annotation-validate.sh` and `assert-verify-steering.sh`), bash implementation sketch, and 12 Tier 0 test cases. Serves as Phase 2 concrete-shape evidence for the Traceability Subsystem promote at `docs/promotes/2026-08-11-traceability-subsystem.md`.
- Promote updated — Phase 1 evidence section names the spec; Phase 2 §Ships list points at the spec path; §Acceptance adds a hook-fires-per-spec item.
- Iteration h is not implementation. The spec is a design doc adopters + upstream reviewers read before the substrate PR opens. Zero runtime impact until Phase 2 ships.

### Added — iteration g git pre-commit hook (traceability bridge)
- `scripts/pre-commit-traceability.sh` — bash hook that runs `tests/requirements-traceability.test.ts` before every commit that touches `src/`, `scripts/`, `tests/`, `vite.config.ts`, or `docs/requirements/`. Fast — one Vitest file, roughly 200ms cold. Path-filtered so unrelated commits are not slowed. Fails with an actionable message pointing at the requirements doc.
- `scripts/install-git-hooks.sh` — one-time helper. Copies the pre-commit script into `.git/hooks/pre-commit`. Idempotent; refuses to overwrite an unrelated existing hook unless `--force`. `--dry-run` prints what would happen.
- README gains a Contributing section documenting the one-command install + the `SKIP_TRACEABILITY_CHECK=1` bypass.
- **Not a bassclef substrate hook.** This is a git-side hook the adopter installs by hand. The substrate hook equivalent (PreToolUse Edit/Write) lives in Phase 2 of the Traceability Subsystem promote as the abstracted subsystem shape. Iteration g bridges the gap until Phase 2 ships.

### Added — iteration d traceability enforcement
- **Mechanical enforcement for the requirement diagram (Phase 1.5 of the Traceability Subsystem promote).** New `tests/requirements-traceability.test.ts` — 8 Tier 0 tests. Parses the registry from `docs/requirements/2026-08-11-npm-distribution.md`. Walks `src/`, `scripts/`, `vite.config.ts` for `@requirement R-NPM-XXX` annotations. Walks `tests/` for `@verifies R-NPM-XXX` annotations. Asserts every satisfied non-meta requirement has at least one satisfy edge AND at least one verify edge. Asserts every referenced ID exists in the registry (no orphans).
- **`@requirement` annotations added to 8 source files.** `src/commands/init.ts` (R-NPM-002), `src/commands/sync.ts` (R-NPM-003), `vite.config.ts` (R-NPM-001), `scripts/tier-filter.mjs` (R-NPM-004), `scripts/andon-scan.mjs` (R-NPM-005), `scripts/validate-tag.mjs` (R-NPM-006), `scripts/bump-version.mjs` (R-NPM-007), `.github/workflows/publish.yml` (R-NPM-006, R-NPM-011, R-NPM-012).
- **`@verifies` annotations added to 7 test files.** `tests/init.test.ts` (R-NPM-002), `sync.test.ts` (R-NPM-003), `tier-filter.test.ts` (R-NPM-004), `andon-scan.test.ts` (R-NPM-005), `workflow-path.test.ts` (R-NPM-006), `bump-version.test.ts` (R-NPM-007), `pack-no-source-maps.test.ts` (R-NPM-001).
- **Meta-requirement exemption.** R-NPM-012 (All Tier 0 tests GREEN) exempt from per-file checks — satisfied by the workflow running vitest and verified by the same step. Named in the exempt set inside `requirements-traceability.test.ts`.
- **CI enforcement.** The publish workflow's `Test` step in the `checks` job runs `npm test`, which runs vitest, which runs the new traceability test. Any future PR that changes source without updating the diagram (or vice versa) fails CI at the checks step.
- Iteration d closes the Feathers rule applied to docs: the diagram now has a safety net.

### Added — semver + changelog methodology (WU-5)
- `standards/npm-versioning-and-changelog.md` — semver rules for 0.x and 1.0+ phases, changelog format per Keep a Changelog 1.1.0, deprecation grace window rules per adopter cohort size.
- `scripts/bump-version.mjs` — one command per bump size (`npm run bump patch|minor|major`). Rewrites `CHANGELOG.md` — renames `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`, inserts fresh empty `[Unreleased]` block, updates compare links. Atomic writes for both `package.json` and `CHANGELOG.md`. Refuses on dirty working tree (except package.json + CHANGELOG.md), missing CHANGELOG, empty Unreleased block, invalid bump arg.
- `--allow-dirty` flag to bypass dirty-tree check. `--date YYYY-MM-DD` flag to override today's UTC date.
- Pre-release strip per semver §11 — any bump from `0.1.0-rc.1` lands on `0.1.0`.
- 27 Tier 0 tests covering parseArgs, computeNewVersion, renameUnreleasedBlock, refuseIfDirty.
- `docs/use-cases/UC-script-bump.md` — brief use case per Cockburn tiering.
- `docs/decompositions/wu-5-methodology.md` — WU-5 decomposition with pre-mortem light + test list.
- `npm run bump` script wired in `package.json`.

### Added — publish pipeline
- `.github/workflows/publish.yml` — one-job GitHub Actions workflow at a semver-locked path. Triggers on `release: [published]` and `workflow_dispatch`. Publishes to npm via trusted publisher with `--provenance --ignore-scripts`.
- `scripts/validate-tag.mjs` — refuses tags that do not string-equal `package.json` version, tags outside the semver format, and tags not reachable from `origin/main`. Also picks the dist-tag (`latest` for stable, `next` for pre-release).
- `scripts/andon-scan.mjs` — scans every file `npm pack` would ship for operator-private terms (absolute home paths, `docs/operator-private/` references, emails outside LICENSE + package.json author). Per-file `# andon-allow: <regex>` header supported. Exit 2 on any hit.
- `scripts/tier-filter.mjs` — refuses any shipped Markdown file whose YAML frontmatter has `tier: upstream`. Handles LF, CRLF, UTF-8 BOM, leading blank lines, and quoted values (single + double). Exit 3 on any hit.
- `docs/publish-setup.md` — one-time operator playbook covering npm 2FA, package name reservation, trusted publisher config, GitHub Environment, per-release flow, and a post-publish audit habit.
- ADR-004 — publish pipeline safety contract. Semver-locks workflow path, triggers, permissions, ordered checks, dist-tag rule, exit codes, tag-format regex, refusal message shape, and tier-filter YAML normalization.

### Added — sync command
- `bassclef init` — writes `.claude/settings.json` + `substrate.config.md` + `.bassclef/init.manifest.json` into a project directory. Safety contract in ADR-002 (fail-safe overwrite, atomic writes, path scoping, symlink refusal unconditional).
- Init flags: `--force`, `--dry-run`, `--dir <path>`, `--allow-root`, `--allow-any-dir`, `--verbose`.
- Init manifest carries template versions + content hashes + per-file outcomes so sync can upgrade cleanly.
- ADR-002 — bassclef init safety contract. Semver-locks defaults, files, escape-hatch matrix, exit codes.
- `bassclef sync` — reads the init manifest, detects change per file (four cases: Current / NeedsUpdate / Edited / Deleted), applies updates under `--force` (versions) + `--replace-edits` (adopter edits). Content-hash detection catches adopter edits via SHA-256 with BOM strip + CRLF normalization.
- Sync flags: `--force`, `--replace-edits`, `--dry-run`, `--diff`, `--dir`, `--allow-root`, `--allow-any-dir`, `--verbose`.
- Exit code 4 added for "manifest schema is newer than this package understands."
- ADR-003 — bassclef sync safety contract. Semver-locks two-force-flag design, content-hash normalization steps, single-writer assumption, exit codes.

### Changed
- Init refuses to re-baseline an existing manifest without `--force`. `bassclef sync` is the path for updates; init is greenfield-only.
- Init manifest schema bumped to 0.0.2 (adds `content_hash_sha256`, `updated_at`; renamed `template_version` → `manifest_schema_version` at the `$bassclef` block).
- **CLI unknown-command exit (iteration b).** `bassclef <unknown>` now exits 3 (invalid args per ADR-002 §Exit codes) instead of 1. Aligns with the "Unknown → exit 3" boundary contract in the interaction design doc. Scripted callers that keyed on `!= 0` still pass; callers that keyed specifically on `== 1` need to update. Semver-locked from 0.0.2.

### Fixed — iteration b drift pass
- **ADR Status body drift (D-1.1 + D-2.4 + D-3.3 + D-4.2).** ADRs 001-004 had Status bodies that read "proposed" while their frontmatter said "accepted". Bodies now match the frontmatter. Reason: the ADRs were authored 2026-08-06 in a proposed state then flipped to accepted 2026-08-08 without updating the body prose. ADR-005 was authored fresh at 2026-08-08 without a Status body and stays that way.
- **ADR-001 shebang banner invariant (D-1.2).** Named the semver-locked contract that Vite `rollupOptions.output.banner` MUST inject `#!/usr/bin/env node` on `dist/cli.js`. The invariant lived in `vite.config.ts` L54-55 but not in the ADR — a silent-failure class if removed.
- **ADR-002 files count (D-2.1).** Context section said `bassclef init` writes two files; Invariants section said three. Both now say three (`.claude/settings.json`, `substrate.config.md`, `.bassclef/init.manifest.json`).
- **ADR-002 complete-mediation extension (D-2.2).** Named `mkdirSafely` alongside `writeSafely` under §Complete-mediation. Init's parent-directory creation runs through the same audited surface as writes.
- **ADR-003 case table extension (D-3.1).** Named `NoMarker` and `UnknownHash` as first-class sync cases. Both were shipped in `sync.ts` and UC-sync but not listed in the ADR's case table.
- **UC-sync unified-diff wording (D-3.4).** UC-sync claimed `--diff` produces a unified diff per file. Actual code shows a template-version summary; full unified diff is later work. UC now reflects the real shape and cites the code comment.
- **UC-script-bump `--allow-dirty` logging claim (D-8.2).** UC said the flag logs to stderr; code silently returns. UC now reflects the real shape and marks the stderr log as a possible follow-on.
- **Interaction-design git-tag data source (D-8.3).** Boundary contract said the workflow reads the tag via `${{ github.ref }}`. Actual workflow reads via `github.event.release.tag_name` or `inputs.tag`. Doc now matches.
- **CLI unknown-command exit-code drift (D-5.2).** See Changed above.
- **Whereami D-9.1 skipped.** The stale setup-docs line lives on the unmerged session-close PR #10, not on main. Handled separately when that PR resolves.

### Added — iteration f traceability primer
- `docs/requirements/2026-08-11-npm-distribution.md` — first requirement diagram for @thebassclef/core, using SysML notation («containment», «deriveReqt», «refine», «satisfy», «verify»). Registers R-NPM-001 through R-NPM-013 from bet L152-164 acceptance items. Traceability matrix maps each requirement to its ADR, use case, source, and test files. Mermaid graph shows the chain end to end. Gap analysis names 5 requirements pending later iterations. Applied test case for the Traceability Subsystem promote at `docs/promotes/2026-08-11-traceability-subsystem.md`.

### Security
- **Source-map exclusion (iteration a).** `package.json` `files` field is now an explicit whitelist (`dist/*.js`, `dist/*.cjs`, `dist/*.d.ts`) instead of the bulk `dist` entry. `vite.config.ts` `sourcemap` flipped from `true` to `'hidden'` — build still emits map files for local debugging but strips the `//# sourceMappingURL=` reference from shipped `.js`. Together the two layers block the shipping pattern that produced the Anthropic v2.1.88 leak in March 2026 (59.8 MB source map exposed ~513K lines of TypeScript per InfoQ + Layer5 write-ups). Semver-locked from 0.0.2 per ADR-001 §Invariants.
- `tests/pack-no-source-maps.test.ts` — 6 Tier 0 tests verify both layers of the source-map exclusion. Runs on every `npm test`.

### Added — iteration c design decisions
- **Publish workflow split into two jobs (c.1.B per audit finding D-4.1).** `.github/workflows/publish.yml` now has a `checks` job (validate-tag + build + test + typecheck + andon + tier filter) and a `publish` job with `needs: checks` and `environment: npm-publish`. Approval fires AFTER checks land green, so the approver sees the check output on the workflow run page before clicking approve. Two new Tier 0 tests in `tests/workflow-path.test.ts` pin the two-job shape and the environment-on-publish-only invariant.
- **Namespace reservation intent (c.2).** ADR-005 gains a §Namespace reservation section naming the future package identities `@thebassclef/lite`, `@thebassclef/standard`, `@thebassclef/ultra` and the manual `npm publish` reservation shape. Operator ticket filed on bassclef-cli for the actual reservation step.

### Changed
- Init refuses to re-baseline an existing manifest without `--force`. `bassclef sync` is the path for updates; init is greenfield-only.
- Init manifest schema bumped to 0.0.2 (adds `content_hash_sha256`, `updated_at`; renamed `template_version` → `manifest_schema_version` at the `$bassclef` block).
- **CLI unknown-command exit (iteration b).** `bassclef <unknown>` now exits 3 (invalid args per ADR-002 §Exit codes) instead of 1. Aligns with the "Unknown → exit 3" boundary contract in the interaction design doc. Scripted callers that keyed on `!= 0` still pass; callers that keyed specifically on `== 1` need to update. Semver-locked from 0.0.2.
- **Cross-ADR ownership reshaped (c.3.A per audit finding D-2.3 + D-3.2).** Init's manifest-exists refusal invariant moved from ADR-003 §"Init amendments" (which the audit surfaced was cross-ADR ownership drift) into ADR-002 §Invariants where init behavior belongs. ADR-003 §"Init amendments" section removed. Behavior unchanged; documentation now respects Ousterhout deep-module discipline (one contract, one file).

### Notes
- Settings template ships MINIMAL — no `../bassclef` sibling assumption. Sync populates references when templates ship real content.
- Content-hash algorithm is semver-locked from 0.0.2. Any change to the normalization steps is a MAJOR bump.
- No file lock — two concurrent bassclef processes on the same target dir race. Single-writer discipline is the operator's responsibility.
- **CHANGELOG 0.0.1 house-keeping (c.4.B per audit finding D-8.1).** The prior `[0.0.1] — 2026-08-06` section described state that had not actually been published to npm (no `v0.0.1` git tag exists; `docs/publish-setup.md` L21-31 names 0.0.1 as a manual reservation step still pending). Content merged upward into Unreleased. When the operator runs the manual reservation, the version bump script converts Unreleased to `[0.0.2]` for the first workflow-published release.

[Unreleased]: https://github.com/sunj-labs/bassclef-cli/commits/main
