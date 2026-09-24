# Changelog

All notable changes to `@thebassclef/lite` land here.

**Package rename note.** Versions up to and including `0.1.1` shipped as
`@thebassclef/core`. From `0.1.0` of `@thebassclef/lite` onward, the
free-tier package name is `@thebassclef/lite`. `@thebassclef/core@0.1.1`
stays live on npm until a later unpublish session; new adopters land on
lite via `npm install -g @thebassclef/lite`. Per coord ticket #51 Q1;
memory `project_lite_is_free_tier_package.md`; ADR-004 Amendment 2026-09-07.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The full versioning + changelog discipline lands in WU-5 per iteration
bet 2026-08-06b.

## [Unreleased]

### Added

### Changed

### Fixed

### Notes

## [1.9.0] - 2026-09-24
### Added

### Changed

- Bumped bassclef substrate pin `v1.4.0` → `v1.5.0` in `.github/workflows/publish.yml` (both checks + publish jobs). Bundled `dist/lite/` now ships v1.5.0 substrate with the Q1 tail — three first-5-10-min friction cures.

### Fixed

### Notes

- v1.5.0 substrate cures shipped by bassclef-upstream 2026-09-23:
  - **#1929** — bassclef-sync adopter template emits the same RESTORED/DEGRADED + JSON postcondition contract as the operator-side hook. v1.4.0 shipped this on operator scope only; adopter template kept the old ambiguous shape.
  - **#1691 Cure 2** — new PreToolUse Bash hook `git-stash-u-guard.sh` fires ADVISORY when `git stash -u` runs in a repo where any substrate dir is gitignored. Never blocks. Skippable via `SKIP_GIT_STASH_U_GUARD=1`.
  - **#1926** — new SessionStart fragment `01-adopter-message-channel.sh` prints welcome text on first-run adopters (all 3 state files absent). Points at `/onboard-repo`. Silent on onboarded installs.
- Manifest `lite-manifest.json` at 1.11.0 (up from 1.10.0). 434 entries. Adopter-simulator-lite clean.
- All three cures additive with env overrides; MINOR bump per ADR-031 adopter contract.
- Peer request source: bassclef-upstream-d1 session; chronicle `chronicle/2026-09-23c-q1-tail-plus-v1.5.0-shipped.md`.

## [1.8.0] - 2026-09-23
### Changed

- Bumped bassclef substrate pin `v1.3.0` → `v1.4.0` in `.github/workflows/publish.yml` (both checks + publish jobs). Bundled `dist/lite/` now ships v1.4.0 substrate with four Q1 Sam+Louis first-5-min friction cures.

### Notes

- v1.4.0 substrate cures shipped by bassclef-upstream 2026-09-23T00:12Z:
  - **#1895** — fresh-install gate uses time-based grace window (24h default; `FRESH_INSTALL_GRACE_SECONDS` env override)
  - **#1849** — dispatcher recognizes bundled substrate (silent when `.claude/hooks` + `.claude/rules` + `.claude/skills` populated at CWD; `BASSCLEF_DISPATCHER_STRICT=1` env override)
  - **#1902** — install.sh writes `$CLAUDE_PROJECT_DIR/.claude/hooks/bassclef-sync.sh` command in `settings.json` (was `$HOME`)
  - **#1911** — source-side `bassclef-version.json` rewrite
- All four cures additive with env overrides; MINOR bump per ADR-031 adopter contract.
- Cross-post: bassclef-cli#219 (peer request from bassclef-upstream-48).

## [1.7.0] - 2026-09-22
### Added

### Changed

- Substrate pin bumped `v1.2.0` → `v1.3.0` in `.github/workflows/publish.yml`
  (both `checks` and `publish` jobs, plus the tag-resolves guard). Bundled
  tarball now carries bassclef substrate v1.3.0 (released 2026-09-22T11:06:47Z).
  Scope: Q1 first-5-10-min UX cures — `blocked_banner` severity arg (advisory
  tone for normal-state fragments), `bassclef-version.json` at release-cut
  carries the actual git tag not the internal release name, fresh-install
  manifest gate (`81-hook-manifest-staleness` guards on install-time mtimes),
  `95-settings-hook-verify` caller cure (missing-hooks list surfaces at
  banner), `/longrun prep` reads whereami primary queue as third converged
  signal, adopter git safety docs in `.claude/bassclef-orientation.md`.
  Release notes: <https://github.com/sunj-labs/bassclef/releases/tag/v1.3.0>.

### Fixed

### Notes

- **Slice B partial only.** The every-Bash-call PreToolUse error flood on
  lite adopters is NOT fully cured by v1.3.0. Deep cure — tier-template
  split of `settings.json` so the lite bundle ships lite-only wiring —
  deferred to bassclef-upstream #1901 (post-v1.3.0). Related install-path
  split ($HOME vs $CLAUDE_PROJECT_DIR) deferred to bassclef-upstream #1902.
  Adopter-facing effect: banner shape improves; underlying flood persists
  until #1901 ships. Tracked at cli #208.

## [1.6.0] - 2026-09-22
### Changed

- Substrate pin bumped `v1.1.1` → `v1.2.0` in `.github/workflows/publish.yml`
  (both `checks` and `publish` jobs). Bundled tarball now carries bassclef
  substrate v1.2.0 (released 2026-09-21T22:32:51Z). Release notes:
  <https://github.com/sunj-labs/bassclef/releases/tag/v1.2.0>.

### Added

- **Statusline for tarball adopters** (PR #181, merged into main first).
  `bassclef init` now writes `~/.claude/bassclef-statusline.sh` and folds
  the canonical `statusLine` field into the walker-copied settings.json.
  Adopters running `@thebassclef/lite@1.6.0` see the bassclef statusline
  the first time they open Claude Code. Pairs with `bassclef-upstream#1860`.
- Substrate v1.2.0 cures bundled by the pin bump:
  - `#1860` — statusline tarball fallback (dispatcher + rich impl learn
    a script-relative candidate path).
  - `#1877` — T3 inode check uses `ls -di` fallback (Linux CI flake gone).
  - `#1878` — release-script target-dirty guard runs before source tag.
  - `#1880` — hook classifier reads `NOT-WIRED-BY-DESIGN-EXCLUSIONS` from
    `standards/hook-invocation-patterns.json` (JSON label, not source scan).
  - `#1866` — Assertion 5 source-graph closure (opt-in via
    `ADOPTER_SIM_SOURCE_GRAPH=1`).
  - `#1875` — Assertion 6 tarball ref fidelity (opt-in via
    `ADOPTER_SIM_TARBALL_PATH=<path>` + `ADOPTER_SIM_EXPECTED_TAG=<tag>`).
  - `#1889` — source-graph walker rejects regex metachars in refs;
    `BASSCLEF_SGW_REGEX_FILTER=0` restores prior.

### Notes

- No source changes under `src/` beyond the automatic `VERSION` constant
  refresh via `npm run bump minor`. All substrate content comes from the
  bumped tag under `sunj-labs/bassclef@v1.2.0`.

## [1.5.1] - 2026-09-21

Patch on top of v1.5.0. The v1.5.0 publish attempt failed at
pre-publish checks because `src/index.ts` and `README.md` still
carried the prior version string. The GitHub v1.5.0 release stays
as an audit record but no npm tarball ships under that version.
v1.5.1 ships the same substrate content plus the version-sync fix.

### Fixed

- `src/index.ts` `export const version` now matches package.json.
- `README.md` version marker now matches package.json.
- Both files got missed in PR #190 because I hand-edited package.json
  instead of running `npm run bump minor` (which touches all three).

## [1.5.0] - 2026-09-21

Substrate sync to public bassclef v1.1.1. Adopters running `npm install
-g @thebassclef/lite` and refreshing get two adopter-visible fixes plus
wider auto-regen coverage on tier:lite substrate edits.

### Changed

- Bundled substrate now sources from `sunj-labs/bassclef@v1.1.1` (was
  `v1.1.0`). Six `ref:` and assertion strings in `.github/workflows/publish.yml`
  bumped in one commit.
- Bassclef v1.1.1 ships two adopter-visible cures. The classifier now
  reads `template-hook-exclusions.txt` so legitimately excluded hooks
  no longer trip warnings (bassclef-upstream#1867 / PR #1870). The
  auto-regen path filter widened to seven gap classes covering `lib/`,
  `scripts/`, `templates/`, `presence/install/`, root-docs,
  `.claude/hooks/*.sh`, and `standards/*.md` (bassclef-upstream#1872 /
  PR #1874).
- Bundled manifest hash updates automatically at publish time via
  `scripts/prepublish-bundle-substrate.mjs`.

### Notes

- Statusline PR #181 stays held for the paired v1.1.2 sync (upstream
  #1860 not in v1.1.1 per peer confirmation).
- V2 Docker cold-adopter harness will run against v1.5.0 after publish
  to verify the classifier tail cure works for adopters, not just for
  bassclef's own CI. Peer asked for that signal specifically.

## [1.4.1] - 2026-09-21
### Added

### Changed

### Fixed

- **Publish workflow substrate pin bumped v0.45.0 → v1.1.0.** `.github/workflows/publish.yml` hardcoded `ref: v0.45.0` on the bassclef sibling checkout (both sibling checkouts at L125 + L268, plus the assertion at L140). Every prior publish this session bundled v0.45.0 substrate, not the v1.0.0 (1.3.0) or v1.1.0 (1.4.0) substrate the CHANGELOG entries claimed. This release ships actual v1.1.0 substrate. Verified: published 1.4.0 tarball at inspection had `release/SKILL.md`, `journal-export/SKILL.md`, 10 runtime `/Users/` hits, no `_lib/wirings.sh`. See bassclef-upstream#1861 comment 5758242378 for the retraction of the v1.0.0 /diagnose report.

### Notes

- **1.4.0 was mis-shipped.** Adopters running `@thebassclef/lite@1.4.0` do NOT have v1.1.0 substrate — they have v0.45.0. Ship 1 install-class boundary cures, the F1b cure, path sanitization, and dead-wire pruning all did NOT reach adopters. Upgrade to `@thebassclef/lite@1.4.1` (or later) for the cures.
- **F1a + F4 stay open** at v1.1.0 substrate per bassclef-upstream#1861. V2 harness re-run against 1.4.1 tarball will confirm.

## [1.4.0] - 2026-09-21
### Added

### Changed

- **Bundled substrate refreshed to public bassclef v1.1.0** (paired with bassclef-upstream v1.1.0 — F1b cure + `/longrun` prep converged shape lock). `dist/lite/` rebuilt from public bassclef `b7613c5f`. Adopters running `npm install -g @thebassclef/lite@1.4.0` receive the v1.1.0 substrate. Prior release (1.3.0) shipped v1.0.0 substrate.

### Fixed

- **F1b cured — `_lib/wirings.sh` now ships in the lite tarball** (per bassclef-upstream#1861 + PR #1865). Prior tarballs at v1.3.0 and earlier omitted `_lib/wirings.sh`; the file is sourced by `session-reflection.d/08-settings-drift.sh` and its absence caused silent-skip in adopters. Verified by V2 Docker harness against v1.3.0 which reproduced the failure (see bassclef-upstream#1861 comment 5757054527). Lite manifest grew 429 → 430 entries.

### Notes

- **F1a + F4 stay open at v1.1.0 substrate.** Walker path mismatch (`bassclef-hook-connect.sh` under `presence/install/`) and `/onboard-repo` empty scratch dir under SDK dispatch are deferred to bassclef v1.1.1. V2 harness run against v1.4.0 will confirm these still reproduce.
- **Statusline PR #181 still held** for its upstream pair (bassclef-upstream#1860). Ships together when both land.

## [1.3.0] - 2026-09-21
### Added

### Changed

- **Bundled substrate refreshed to public bassclef v1.0.0** (paired with bassclef-upstream v1.0.0 Ship 1 — install-class boundary + cold-adopter unblock). `dist/lite/` rebuilt from public bassclef `1fcd6ed9`. Adopters running `npm install -g @thebassclef/lite@1.3.0` receive the v1.0.0 substrate. Prior release (1.2.2) shipped v0.46.0 substrate.
- **Install-class boundary lands in the lite tarball.** Operator-only skills (`.claude/skills/release/`, `.claude/skills/journal-export/`) and operator-only hooks (`.claude/hooks/bassclef-sync.sh`) no longer ship in `dist/lite/`. Adopter tarball is leaner; operator-only surfaces stay in the operator repo. Filter is enforced by Gate B in `scripts/generate-lite-manifest.sh` on the upstream side.

### Fixed

- **30 hardcoded operator paths sanitized** in bundled substrate (per bassclef-upstream v1.0.0 Ship 1). Prior tarballs shipped substrate files carrying operator-machine paths (`/Users/<name>/src/...`). v1.3.0 tarball has none.
- **33 dead hook wirings pruned** from bundled `settings.json` template (per bassclef-upstream v1.0.0 Ship 1). Adopters no longer see settings entries referencing hooks that were retired.

### Notes

- **Known findings deferred to v1.1.0 substrate.** Four V2 Docker harness findings (bassclef-upstream#1861) filed against `@thebassclef/lite@1.2.2` are partially addressed in v1.0.0. Peer signal: F1b cure (`_lib/wirings.sh` inclusion) lands in bassclef v1.1.0, F1a + F4 stay open pending further diagnosis. Adopters running v1.3.0 may still see F1b + F4 in fresh Docker installs.
- **Statusline PR #181 held for v1.1.0 pairing.** Cli-side statusline install (dispatcher copy to `~/.claude/bassclef-statusline.sh` + `statusLine` config field) waits for its upstream pair (bassclef-upstream#1860 — rich-impl fallback path). Ships together when both land.

## [1.2.2] - 2026-09-20
### Added

- **Vitest test-run history + flake detection aggregator** (bassclef-cli#169 → PR #172 → `14db575`). Vitest emits per-run JSON to `state/events/test-runs/` (local, gitignored). `scripts/aggregate-test-runs.sh` reads records and emits duration histogram + flake list. `npm run test:report` invokes the aggregator. Vernon anticorruption boundary — `parse_vitest_record` translates vitest 2.0.0 JSON shape to CanonicalRecord; Control operates on CanonicalRecords never on raw vitest JSON. 38 Tier 0 tests GREEN. Maintainer-side only; adopter tarball unchanged. Full OOAD chain shipped design → RFC-0006 adversarial council (5 outside luminaries) → pre-mortem light (15 risks) → RED/GREEN Beck TDD → architect-review READY.
- **Docker cold-adopter smoke harness V1 walking skeleton** (bassclef-cli#162 → PR #163 → `2a31709`). New `harness/docker/` — Dockerfile + entry.sh + exit-codes.sh + Tier 0 tests (18 GREEN). New workflow `.github/workflows/docker-smoke.yml` runs the harness against `@thebassclef/lite@latest` on every PR touching `src/**` or `harness/**`. Container starts from a clean Debian slim base — zero operator artifacts. Runbook at `docs/runbook/docker-smoke.md` documents local invocation. Full 4-handoff SDLC ceremony (pre-mortem light × 4 + adversarial RFC × 3 + architect-review at Handoff 4). Maintainer-side smoke; adopter tarball unchanged.
- **Vitest coverage config with istanbul provider** (bassclef-cli#165 → PR #168 → `8299bde`). `vitest.config.ts` adds `coverage: { provider: 'istanbul', reporter: ['text', 'json-summary', 'html'], thresholds: { lines: 40, functions: 45, branches: 25, statements: 35 } }`. `npm run test:coverage` script emits per-file coverage. Istanbul chosen over v8 because v8 sets `NODE_V8_COVERAGE` which propagates to subprocess-spawning tests (`runCli`) and breaks their exit codes. Baseline thresholds at current actuals; follow-on tickets to backfill migrate.ts + sync.ts + sync-argv.ts.

### Changed

- **CLAUDE.md architecture-decisions list extended with 8 ADRs** (bassclef-cli#164 → PR #167 → `0220e4d`). Adds ADR-004 through ADR-010 + ADR-057 to the CLAUDE.md ADR reference list. Prior list only named ADR-001 through ADR-003. New session context loads all 10 ADRs on `@import`. No behavior change; documentation-only.

### Fixed

### Notes

- **Cross-version install harness ticket** (bassclef-cli#173) filed as follow-on. Cli has no way to install last N npm versions and compare their test runs side-by-side; single-version harnesses (#100, #162) cover only one version at a time. #173 proposes extending Docker harness for N-version compare via `scripts/compare-versions.sh` or a scheduled CI workflow.

## [1.2.1] - 2026-09-19
### Added

- **Bundled substrate at bassclef v0.46.0** (from v0.45.0). Ships the cli-side dispatcher cure this project filed as cli#140 — the substrate dispatcher now checks `$CWD/lib/` as the second probe path when resolving `bassclef-dir-resolver.sh`, so cli sessions started outside `~/src/sunj-labs/` no longer hit resolver-missing errors (bassclef-upstream PR #1796). Also lands: pre-commit auto-regen manifest hook (reduces manifest-drift friction on local commits per bassclef-upstream #1752), workflow-metrics library (Module B4 measurement infrastructure per bassclef-upstream #1307), harness fixture consolidation Steps 1-3 (bassclef-upstream #1789), and two new luminaries — david-farley + jez-humble.

### Changed

- **Runbook Step 5 timeout 30s → 120s** (bassclef-cli#138 → PR merged as `5dcbe8e`). Docs matched the script default. Slower cold-adopter hardware needed the headroom for the smoke drive step.

### Fixed

- **Smoke bootstrap one-liner leads with `cd ~`** (bassclef-cli#146 → PR merged as `480a339`). Adopters land in their home dir before running `bassclef init`. Matches the runbook v4 shape. Sister guard: reset flow can delete the current working dir, so bootstrap warns on deleted-CWD after reset (bassclef-cli#144 → PR `4025a2f`).
- **Smoke script auto-creates the release label + surfaces `gh` errors** (bassclef-cli#141 → PR `ee77819`). Label derives per release; script creates it if missing instead of failing silently. `gh` CLI errors now surface to the operator rather than being swallowed.
- **Runbook adds `gh` account pre-flight** (bassclef-cli#143 → PR `95bd89f`). Runbook asserts `kingofrock` is the active `gh` account before hitting `sunj-labs`. Catches wrong-account authorization failures before the smoke starts.

### Notes

- **Install:** `npm install -g @thebassclef/lite@latest`. Verify: `bassclef --version` → `1.2.1`.
- **Migration path:** no migration required. PATCH bump. Existing adopters re-running `bassclef init` (or a fresh install) pick up the v0.46.0 substrate bundle.
- **First widely publicized release.** Public launch is 2026-09-20; this release ships the smoke bootstrap fixes cold-adopter runs surfaced plus the latest substrate.

## [1.2.0] — 2026-09-18

Additive minor release. Rolls up alpha.0 + alpha.1 (both shipped as preview at `@next` on npm) into a clean release at `@latest`. Diff from 1.1.1 is fully additive: no breaking changes, no schema shape change adopters must migrate. Existing adopters get the update on next `npm install -g @thebassclef/lite@latest`.

### Added

- **`.version` at top level of `.bassclef/init.manifest.json`** (bassclef-cli#129, closes bassclef-upstream#1749). `Manifest` interface in `src/lib/manifest-types.ts:68` gains the field; `manifestTemplate` in `src/commands/init-templates/manifest-json.ts:26` and `src/lib/migrate.ts:136` emit it as the installed cli semver. Duplicates `$bassclef.generated_by_version` on purpose — v0.45.0's session-start drift hook reads `.version` shallow via `jq -r '.version // ""'` and does not walk into `$bassclef`. Existing 1.1.1 installs will not gain the field until they reinstall (or run `bassclef init --force`).
- 3 Tier 0 tests at `tests/init-manifest-version-field.test.ts` pin the field is present, equals `package.json` version, and matches `$bassclef.generated_by_version`.
- **Bundled substrate at bassclef v0.45.0.** Ships seven adopter cures from upstream — cli#102 (no false BLOCKED banner on fresh install), cli#105 (BASSCLEF_DIR probe finds bundled path), cli#106 (clone-failure classifier names real cause), cli#107 (textstat warning fires once per session), cli#108 (no false ABRUPT STOP banner on fresh install), bassclef-upstream#1742 (`compare_wirings` guarded-command normalization), release-pipeline (PR body auto-populate + SESSION_LOCK guard). Plus the new drift hook + `.bassclef-source-config-validate.sh` mechanism.

### Fixed

- **stdout writes dropped on CLI exit under CI pipes** (bassclef-cli#134). `src/cli.ts:92` calls `process.exit(exitCode)` after `main` resolves. Node's writes to a pipe (spawnSync capture, `bassclef init | tee`, CI subprocess) are async; buffered writes still in Node's stream state get abandoned when `process.exit` fires. TTY writes are sync, so the bug never bit human runs. Publish CI at `tests/init.test.ts:274` caught the class after PR #128 unmasked it — 172 of 506 `would create` lines emitted on Linux CI vs the full 506 on macOS local. Fix: set stdout/stderr handles blocking at CLI entry so every write is synchronous. Per nodejs/node#3669, #6456, #19218.
- **Missing `.version` field in migrate manifest** (bassclef-cli#131). Follow-on to #129 — the `Manifest` type made `.version` required but `src/lib/migrate.ts:136` was the second construction site and wasn't updated. Vitest passes locally (esbuild transform) but strict `tsc --noEmit` on CI catches the class.
- **Test timeout 8s → 60s → 180s** in `tests/init.test.ts` `runCli` helper (PRs #128, #132). Slower CI hardware needs the headroom for `bassclef init` walking 445+ files.

### Notes

- **Install:** `npm install -g @thebassclef/lite@latest`. Verify: `bassclef --version` → `1.2.0`.
- **Migration path:** no migration required. Additive change.
- **1.2.0-alpha.0 / alpha.1 stay published at `@next` for reference.** Not deprecated; adopters can pin them if they need the specific pre-release SHA. `@latest` now points at 1.2.0.
- Bundled substrate at bassclef v0.45.0 (unchanged from alpha.1).

## [1.2.0-alpha.1] — 2026-09-18

Rolls up alpha.0 (which never landed on npm — publish workflow failed twice on the shipped tag) and adds the missing `.version` field to `.bassclef/init.manifest.json`. That field is the contract v0.45.0's session-start drift hook reads via `jq -r '.version // ""'`. Without it the hook silently returns 0 and adopters on stale lite never see the "update available" banner.

### Added

- **`.version` at top level of `.bassclef/init.manifest.json`** (bassclef-cli#129, closes bassclef-upstream#1749). `Manifest` interface in `src/lib/manifest-types.ts:68` gains the field; `manifestTemplate` in `src/commands/init-templates/manifest-json.ts:26` emits it as the installed cli semver. Duplicates `$bassclef.generated_by_version` on purpose — the drift hook stays a shallow read at `.version` and does not walk into `$bassclef`.
- 3 Tier 0 tests at `tests/init-manifest-version-field.test.ts` pin the field is present, equals `package.json` version, and matches `$bassclef.generated_by_version`.

### Fixed

- **Test timeout bump 8s → 60s** in `tests/init.test.ts` and `tests/init-hook-routing.test.ts` `runCli` helper (bassclef-cli#128). The 8-second cap killed the publish workflow twice when v0.45.0's 445-file `bassclef init` exceeded it on slower CI hardware. Local machines pass either cap; CI needs the headroom.

### Notes

- **Adopter reinstall required to activate the drift signal.** Existing lite installs on 1.1.1 or earlier will not gain the `.version` field until they run `npm install -g @thebassclef/lite@latest` (post-alpha promotion) or `@alpha`. Adopters on stale installs stay silent until they upgrade once through some other trigger.
- Install with `npm install -g @thebassclef/lite@alpha`. Verify with `bassclef --version` → `1.2.0-alpha.1`.
- Bundled substrate stays at bassclef v0.45.0 (no upstream bump this alpha).

## [1.2.0-alpha.0] — 2026-09-18

Substrate bumped to bassclef v0.45.0. Ships seven adopter cures upstream plus five cli-side PRs from tonight's session. First alpha in the 1.2.0 cycle. Adopters install with `npm install -g @thebassclef/lite@alpha`.

### Added

- `.claude/bassclef-configs.jsonc` — default settings file ships in the bundle so adopters find every tunable block with inline comments on first install. Was absent through 1.1.x. (bassclef-cli#104, PR #124)
- `.claude/` and `.bassclef/` added to the adopter `.gitignore` template. `git add -A` no longer sweeps 500+ synced files into an accidental commit. (bassclef-cli#99, PR #122)
- `scripts/lib/smoke-assert.sh` — two new check functions `check_no_timeout` and `check_no_crash` read the `=== exit: N` trailer. Skill captures that exit 142 (SIGALRM) or non-zero now FAIL the assertion suite instead of passing on empty content. (bassclef-cli#117, PR #125)

### Changed

- `bassclef init` banner reads as success on an empty target. The "N failed" phrasing on the hook line fires only when `errored > 0`, never on refused. The `0 files refused (path collision)` line only prints when refused > 0. (bassclef-cli#120, PR #121)
- `whereami.md` template ships at `docs/whereami.md` instead of the repo root. Bundle and rule now agree; the `/whereami` skill stops guessing. Adopters with an existing root file keep it (init preserves existing per ADR-002). (bassclef-cli#103, PR #123)
- `scripts/smoke-drive-skills.sh` — `TIMEOUT_SEC` default 30 → 120. First cold-adopter run hit `Alarm clock: 14` on every skill; new default covers observed p95. (bassclef-cli#116, PR #125)
- `scripts/lib/smoke-assert.sh` `check_paths_exist` — regex anchored to known-absolute prefixes (`/Users/`, `/opt/`, `/etc/`, `/tmp/`, `/var/`, `/private/`, `/home/`, `/root/`). Fragment paths like `/agents/x.md` in content no longer false-positive-fail as missing filesystem targets. (bassclef-cli#118, PR #125)
- `bassclef.upstream_tag` in `package.json` bumped v0.42.0 → v0.45.0. `dist/lite/` regenerated from the sibling checkout at v0.45.0.

### Fixed (from upstream v0.45.0)

- **cli#102** — no BLOCKED orientation banner on fresh install. `session-reflection.d/55-orientation-gate.sh` uses new `lib/fresh-install-check.sh` and stays silent when no commits + no SESSION_LOCK.
- **cli#105** — `BASSCLEF_DIR` probe finds the bundled path. New `lib/bassclef-dir-resolver.sh` walks peer → `$HOME/bassclef` → bundled → `$CWD` fallback. Prior 2-line resolver lost the bundled path under operator install.
- **cli#106** — clone-failure classifier names the real cause (auth / visibility / network / unknown). Adopter running with `gh` logged in against a private repo they cannot see no longer gets told to "set up GitHub auth."
- **cli#107** — textstat warning fires once per session, not once per prompt. Marker under `$HOME/.claude/state/sessions/<id>/textstat-warned`.
- **cli#108** — no ABRUPT STOP banner on fresh install. `session-reflection.d/10-abrupt-stop-recovery.sh` uses the fresh-install lib.
- **upstream#1742** — `compare_wirings` jq filter normalizes guarded command shape (`[ -f "path" ] && ... || true`). Adopter settings using the guarded form no longer report as missing. Empty banner suppressed.
- **release-pipeline** — release PR body auto-populates from `docs/release-notes/v<SEMVER>.md`. SESSION_LOCK write guards `.claude/` directory creation.

### Notes

- **Alpha release.** Install with `npm install -g @thebassclef/lite@alpha`. Verify with `bassclef --version` → `1.2.0-alpha.0`.
- **Sibling smoke tracking** in bassclef#1495 — this alpha ship gates the deferred smoke follow-on.
- Related bassclef-cli PRs: #121, #122, #123, #124, #125 (all merged 2026-09-18).

## [1.1.1] — 2026-09-17

`bassclef init` now reports the truth about what it wrote. Three defects
found in the 1.1.0 cold-adopter smoke, all in the same output path.

### Fixed

- **The install record names every file** (#93). `.bassclef/init.manifest.json`
  listed one file when 499 landed, so `bassclef sync` only ever checked
  that one. It now records every file the run touched — copied, refused,
  and errored — each with the hash of what was written. Entries are keyed
  by path and scope together, because hook helpers land in both your repo
  and your home directory and would otherwise collide.
- **`--json` goes to standard output** (#94). The report went to standard
  error while 151 lines of human text went to standard output after it,
  so `bassclef init --json 2>&1 | tail -1` returned prose. Now
  `bassclef init --json | python3 -m json.tool` works with no workaround.
- **`--json` names every catalog family** (#95). The report counted hooks
  and nothing else. It now reports skills, rules, agents, luminaries,
  hooks, libs, ADRs, standards, templates, presence templates, scripts,
  and root docs, and separates files that landed in your repo from files
  that landed in your home directory.
- The install record said it was generated by `@thebassclef/core`, which
  npm deprecated when the free tier was renamed.

### Changed — read this before upgrading

- **`bassclef init --json` writes to standard output instead of standard
  error.** If you have a script reading the object from standard error,
  it needs to read standard output instead. Under `--json` the routine
  human lines are no longer printed at all, so standard error carries
  errors and nothing else.
- **The install record grows from about 1 KB to about 198 KB** on the lite
  tier, because it now lists 499 files instead of one. `bassclef sync`
  takes no new action on those files — they refresh through
  `bassclef init --force`, as before.
- **The install record's `schema_version` moves from 2 to 3.** Records
  written by 1.1.0 still load.
- **`failed` in the `--json` report is now `refused` plus `errored`.** The
  two are also reported separately, which is the pair you want: a refused
  file is one your existing copy blocked, an errored file is one that
  could not be read or written. `failed` stays available through the 1.1.x
  line and retires at 1.2.0.

### Notes

- Design: `docs/adrs/ADR-010-init-reporting-contract.md`.
- Two review councils, one on the design and one on the shipped code:
  `docs/rfcs/RFC-0004-*` and `docs/rfcs/RFC-0005-*`. The design review
  caught a data-shape defect before the tests existed; the code review
  caught two the tests as written could not see.
- Tests: 303 at the start of this work, 345 at the end.

## [1.1.0] — 2026-09-16

**This release adds ~260 files under `.claude/` and repo root.** Adopter tarball grows from ~180KB (1.0.4) to ~800KB uncompressed. Review the shape before upgrade.

### Added

- **Lite catalog now ships in the npm tarball.** Prepublish reads `lite-manifest.json` v1.6.x at bassclef-upstream and copies every catalog entry to `dist/lite/` via identity path mapping. Cold adopters running `bassclef init` on 1.1.0 land 40 skills, 63 rules, 32 luminaries, 4 agents, 18 libs, 6 ADRs, 72 standards, 10 templates, 5 presence-templates, 7 scripts, and 6 root-docs — the full lite tier the tier tag has promised since 1.0.0.
- **New init banner lines report per-type counts.** `bassclef init` output now includes:
  - `Installed N skills, N rules, N agents, N luminaries under <repo>/.claude/.`
  - `Installed N libs, N ADRs, N templates, N presence-templates, N standards, N root-docs, N scripts under <repo>/.`
  - `N files refused (path collision).` (always emitted, even at 0)
- **ADR-057 — lite catalog destination-path invariant.** Pins the 13-row routing table for every manifest type. Every path shipped at 1.1.0 is immutable in 1.1.x per Hyrum's Law; moving a path is a MAJOR bump.
- **Distribution pre-flight discipline (proposed at bassclef-upstream).** Drafts at `docs/proposed-upstream/` for `standards/distribution-preflight.md` + `.claude/rules/distribution-preflight-check.md`. Six-check standard prevents future distribution builds from shipping a tarball that lies about what it contains. Wiring lands at cli 1.1.1+ after upstream merges.

### Fixed

- **Regression from cli 1.0.0 — skills / rules / agents / luminaries missing from npm tarball.** Root cause: git commit `1c7d919` (MAJOR 1.0.0) dropped the pre-1.0 `copyEntry` walker along with the `substrate/` directory. Replacement wired hooks only. cli 1.0.0 through 1.0.4 shipped hooks-only bundles despite the lite tier promising the full catalog. cli 1.1.0 restores catalog delivery via `lite-manifest.json`-driven prepublish. See cli#90 for the filing ticket.

### Notes

- **Bundle size grows ~5x.** Compressed tarball ~200-400KB. Install time grows by seconds, not minutes.
- **Walker unchanged.** cli 1.0.4 dual-scope hook behavior preserved. Non-hook file routing already lived at project scope by identity path mapping (surprise finding at Step 5); walker tests pin the invariant.
- **Adopter contract preserved.** No breaking changes to `bassclef init` API, `--json` output shape, exit codes, or existing banner lines. New content lands at previously-empty paths.
- **All 303 tests pass.** 7 new prepublish tests + 12 new walker characterization tests + all 284 pre-1.1.0 tests still green.
- **19 new tests added — Beck rhythm.** RED (2a84c8e) committed before GREEN (d2647fc). Fixture uses real manifest slice, not hand-authored shape (Feathers characterization).
- **Three architect-review gates cleared.** Design gate (2 BLOCKs cured inline: F-1 ADR-057 type coverage + F-2 banner counts). Spike gate (Cockburn walking skeleton passed; identity mapping surprise). Code gate (0 BLOCK; 1 AMBER for lowercase root-doc heuristic deferred to 1.1.1+).

## [1.0.4] — 2026-09-16

### Fixed

- **Walker dual-scope for undeclared hook files.** `bassclef init` now
  copies helper files (e.g., `trace-helper.sh`) and fragment files
  (e.g., `session-reflection.d/*.sh`) that `settings.json` does not
  name as `command:` to BOTH `~/.claude/hooks/` AND
  `<repo>/.claude/hooks/`. Declared hooks source these files via
  relative dirname (`$(dirname "$0")/trace-helper.sh`); a user-scope
  hook resolves the source call from `~/.claude/hooks/`, a project-
  scope hook from `<repo>/.claude/hooks/`. Prior to 1.0.4 the walker
  defaulted undeclared hook files to project scope only, which
  crashed `claude` SessionStart on cold-adopter installs:
  `session-reflection.sh: line 38: trace-helper.sh: No such file or
  directory`. Cure landed at `src/lib/copy-substrate.ts` walker loop;
  path-traversal + home-resolve checks still run via `classify()` per
  Saltzer-Schroeder complete mediation.

### Notes

- Falsification test on cold-adopter-1 (2026-09-16) confirmed manual
  `cp` of the helper to `~/.claude/hooks/` cures `claude` boot,
  isolating the fault to the walker's default routing.
- Adopter contract: no observable schema change; `settings.json` shape
  unchanged; `init.manifest.json` schema unchanged.
- 5 new Tier 0 tests pin the dual-scope invariant. Total: 284 tests
  pass on `main`.

## [1.0.3] - 2026-09-16

### Fixed

- **Cold-adopter hook-cascade class from 1.0.2** — `scripts/prepublish-bundle-substrate.mjs` now recursively copies the sibling `dist/lite/.claude/hooks/` tree instead of filtering by `settings.json.hooks[].command` leaf names. Helper scripts that other hooks source (like `trace-helper.sh`) and fragment directories (like `session-reflection.d/`) now ship in the tarball. Closes bassclef-cli#87. Root cause: 1.0.1's `copyHookBinaries` cure (bassclef-cli#79) undershipped by only copying declared commands, silently dropping helpers upstream added at v0.42.0.

### Changed

- **Postflight rewritten** — `assertDeclaredCommandsHaveBinaries` replaces the strict `copiedHookCount === declaredCount` equality check with a `copiedFiles >= declaredCount` sanity plus per-command binary presence check. Extra files (helpers, fragments) log INFO and pass. Every declared command still fails loud if its binary is absent.
- **Symlink refusal** — recursive walk `lstat`s every entry (top-level AND nested) and refuses symlinks per Saltzer-Schroeder complete mediation. An npm tarball must not carry a symlink.

### Notes

- Full OOAD ceremony landed with this fix — use case (fully-dressed Cockburn), IA model, interaction design (state + sequence diagrams), decomposition (GRASP + `@pattern`), primary luminary consult (Linus + Cockburn + Nygard + Feathers + Beck), adversarial RFC-0003 (Hunt-Thomas + Toulmin + Hyrum + Rich Hickey + Saltzer-Schroeder), risk ledger v2 (11 primary risks + 11 RFC folds).
- Live matcher grounding — Voyage + Haiku picked Linus + Cockburn as primary (0.82 confidence).
- Tarball impact: cli 1.0.3 ships every file the sibling `dist/lite/.claude/hooks/` tree contains at the pinned tag. File removals at upstream are now covert breaks per Hyrum; ADR-031 compat window applies.
- 1.0.2 should be deprecated on npm alongside 1.0.0 and 1.0.1 once 1.0.3 is smoke-verified.

## [1.0.2] - 2026-09-16

### Changed

- **Upstream pin bump v0.40.0 → v0.42.0** in `.github/workflows/publish.yml` (6 spots: 2 checkout refs, 2 tag-assertion comparisons, 2 header notes). Bassclef v0.42.0 ships install-class dispatch on adopter machines per bassclef-upstream ADR-058 + PR #1682 (goal 14c Step 6). Bundled hooks now install into `$HOME/.claude/hooks/` (operator scope) or `$CLAUDE_PROJECT_DIR/.claude/hooks/` (project scope) per each hook's `install-class` header.

### Fixed

- **Cold-adopter hook-cascade class from 1.0.1** — v0.42.0's self-contained lite bundle carries `trace-helper.sh` + `session-reflection.d/` fragments + 8 `lib/*.sh` modules that 1.0.1 adopters were missing. Fresh installs boot without `source` errors at SessionStart.

### Notes

- New lite luminary bundled — Andreas Zeller (Delta Debugging). David Agans stays upstream-tier.
- Wiring manifest bumped to `1.6.1` (291 → 292 entries).
- Wake-up flow triggered by bassclef-upstream release PR #1492 (commit `d99cdede`) publishing tag `v0.42.0` to public bassclef at 2026-09-16T06:12:29Z.
- Cli-side pin bump executed autonomously under orchestrator-gated + agent-merges-within-scope per operator directive.

## [1.0.1] - 2026-09-13
### Added

- **Walker routes hook binaries per settings.json prefix** — new
  `ScopeRouter` (Strategy + Chain of Responsibility) classifies each
  hook file the walker copies. Commands starting `$HOME/` land in
  `~/.claude/hooks/`; commands starting `$CLAUDE_PROJECT_DIR/` land
  in `<repo>/.claude/hooks/`. Third prefixes throw `UnknownScopePrefix`.
- **Executable bit preserved** — new `ExecutableBitEnforcer` sets
  mode 0755 on every copied `.sh`. Windows skips chmod with an INFO
  stderr note.
- **`--yes` flag** — non-interactive confirm for the 1.0.0 → 1.0.1
  upgrade advisory. CI + scripts pass `--yes`.
- **`--json` flag** — emits a structured stderr line
  `{copied, declared, failed, scope_counts, tier}` alongside the human
  banner so adopter tooling parses a stable machine shape.
- **Manifest schema v2** — top-level `schema_version: 2` marker + per-
  entry `scope: 'user' | 'project'` field. Old readers ignoring new
  fields keep working.
- **Prepublish copies hook binaries** — `scripts/prepublish-bundle-substrate.mjs`
  now copies every hook binary from sibling public bassclef into
  `dist/lite/.claude/hooks/`. Postflight asserts copied count equals
  declared count so the cli 1.0.0 empty-hooks class cannot recur.

### Changed

- **Banner shape** — was `N hooks armed (lite tier)`. Now
  `Installed N of M hooks (lite tier). N in <repo>/.claude/hooks,
  M in ~/.claude/hooks.` (Norman shape per RFC-0002 N1 fold).
- **Symlink error message** — includes the readlink target so adopters
  know what the pre-existing symlink points to.
- **Upgrade advisory** — first-run on a 1.0.0-installed target prints
  `cli 1.0.1 introduces user-scope hook installation at ~/.claude/hooks/`
  and waits for confirmation. `--yes` skips the prompt.

### Fixed

- **`@thebassclef/lite@1.0.0` cold-adopter regression** — cli 1.0.0
  shipped with settings.json referencing 24 hooks that were never in
  the tarball. Cold adopters hit 24 hook-not-found errors per Claude
  Code prompt. Cure ships the hook binaries in the bundle and routes
  each per settings.json prefix. Closes bassclef-cli#79. See
  bassclef-cli#80 for the retro `/diagnose` on the miss.
- **`.claude` literals extracted** — new `HOOKS_SUBPATH` +
  `SETTINGS_SUBPATH` constants in `src/lib/paths.ts` keep the R6
  single-source-of-truth rule clean.
- **Test isolation** — every test that spawns the CLI now sets
  `HOME=fakeHome` so user-scope hook writes land in a temp dir, not
  the operator's real `~/.claude/hooks/`.

### Notes

- Pins bassclef-upstream `v0.40.0` (tag cut 2026-09-13T20:40:20Z).
- Retires the placeholder regex stopgap from cli 1.0.0 — upstream
  dist-templates now use canonical `[REPO_NAME]` + `[TIER]` shapes
  only (closes bassclef-cli#77).
- 51 files changed +3310 / -114 vs `main` at merge time. Full OOAD
  chain (10 steps) shipped alongside the code — see
  `docs/iteration-bets/2026-09-13d-cli-1.0.1-hook-routing.md`.

## [1.0.0] - 2026-09-13

### Notes

- Deprecation-owed on npm — see 1.0.1 above.

## [0.1.3] - 2026-09-12
### Added

### Changed

- `bassclef init` output — final summary now prints one grand-total line
  (`N files total (2 config + N-2 substrate)`) so the number matches the
  on-disk footprint. Prior counter (`N created, M unchanged`) referred to
  config files only and confused readers who saw ~280 substrate copies
  scroll by. Same counter also renamed `N config files created, M unchanged`
  so its scope is explicit.
- `bassclef init --help` — "Files written under <target>" now names the
  bundled substrate tree (.claude/{agents,hooks,luminaries,rules,skills}/,
  standards/, templates/, scripts/, lib/, presence/install/,
  architecture/decisions/, plus top-level markdown files including
  CLAUDE-lite.md). Prior text listed only the 3-file scaffold.

### Fixed

- `bassclef init --dry-run` now previews the full substrate copy step, not
  just the 2 config files. Cold-adopter on 2026-09-12 ran the preview,
  saw 2 files, then saw 283 files land on the real run — a ~140x
  under-report of scope. Root cause: `runInit` returned after the config
  dry-run and never invoked the substrate copy path, which already
  accepted a `dryRun` option and just wasn't called with it. Regression
  test in `tests/init.test.ts` asserts dry-run "would create" count
  equals manifest entries + 2 config files. Closes #60.

### Notes

## [0.1.2] - 2026-09-11
### Notes

- Version 0.1.1 skipped for `@thebassclef/lite`. Git tag `v0.1.1` was
  already in use for the deprecated `@thebassclef/core@0.1.1` release
  from 2026-08-31 (commit `ef84d60d` — issue #45 cure). Moving the tag
  would break the audit trail for that release. Chose non-destructive
  path — bumped straight from `0.1.0` to `0.1.2` for lite. The `[0.1.1]`
  entry below stayed in the changelog for content history; there is no
  `@thebassclef/lite@0.1.1` on npm and no git tag `v0.1.1` on lite's
  commit line.

## [0.1.1] - 2026-09-11
### Changed

- Bundled substrate refreshed from bassclef lite-manifest v1.5.1 (173
  entries) → v1.5.7 (280 entries). Delta covers 6 patch versions of the
  upstream tier-alignment cure arc — batch 6 additions (upstream #1595)
  plus PRs #1599 + #1600 + #1601 (73 flipped files + 1 promoted file
  `.claude/rules/sibling-smoke-after-substrate-change.md`) plus #1603
  (v1.5.6 → v1.5.7 ledger catchup). About 15 already-present entries
  received a fresh `content_hash` after cleanup edits (README.md,
  CONTRIBUTING.md, `.claude/rules/loop-discipline.md`, and others). No
  schema change — `standards/lite-manifest.schema.json` unchanged since
  v1.5.0. Consumers pinning `~1.5` stay green; consumers reading
  `.entries[].content_hash` refresh the 15 files at next sync.

### Fixed

- Tarball audit test (`tests/harness/prepublish-bundle.test.ts`) false
  positive. Regex `(^|/)chronicle/` matched the legit alias skill dir
  `substrate/.claude/skills/chronicle/SKILL.md` (per ADR-040 D1 grace
  window through 2026-10-31 — `chronicle` is an alias for `session-log`
  that ships as a real skill). Tightened to `(^|/)chronicle/\d{4}-`
  which matches dated chronicle content files without false-positive on
  the skill dir. Same tightening applied to `docs/chronicle/`.

### Notes

- Refs: upstream `standards/lite-manifest-schema-changes.md` top entry
  "Tier alignment cure batch 6 + arc"; upstream PRs #1595 + #1599 +
  #1600 + #1601 + #1603; peer bassclef-web heads-up 2026-09-11.

## [0.1.0] - 2026-09-07 — `@thebassclef/lite` first substantive release

### Changed

- Package name renamed from `@thebassclef/core` to `@thebassclef/lite`.
  Adopters install with `npm install -g @thebassclef/lite`. Existing
  `@thebassclef/core@0.1.1` installs stay working; migration is
  additive — `npm uninstall -g @thebassclef/core && npm install -g @thebassclef/lite`.
- Bundled substrate refreshed from bassclef v1.2.19 → v1.5.0. New
  `problem` + `value` fields per manifest entry (upstream #1480).
  `upstream_commit` removed from bundled manifest (upstream #1508).
  `/build` skill promoted to lite (upstream #1462); 4 skills retagged
  (upstream #1478); 14 luminaries flipped to lite (upstream #1459).
- Publish pipeline (`.github/workflows/publish.yml`) targets
  `@thebassclef/lite`. ADR-004 Amendment 2026-09-07 documents the
  target rename; the safety contract itself is unchanged.

### Added

- Tier 0 test at `tests/harness/copy-substrate.test.ts` asserts the
  bundled-manifest consumer tolerates the v1.5.0 shape (absent
  `upstream_commit`; additive per-entry fields). Pins the contract
  against future schema shifts. Shipped in PR #52.
- Tier 0 tests at `tests/harness/prepublish-bundle.test.ts` assert
  `npm pack --dry-run` bundles zero operator-private paths and the
  tarball top-level dirs match a strict allowlist. Pre-mortem Saltzer #1
  cure. Shipped in PR #53.

### Notes

- Operator sets the npm trusted-publisher entry for `@thebassclef/lite`
  at `npmjs.com/settings/<user>/packages/@thebassclef/lite` once,
  pointing at `sunj-labs/bassclef-cli` + `.github/workflows/publish.yml`.
  Without this the first `@thebassclef/lite` publish fails.
- Refs: coord ticket #51 (Q1 rename+sync goal); goal doc
  `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md`;
  pre-mortem `docs/risk-ledgers/2026-09-07-lite-rename-sync.md`.

## [0.1.1] - 2026-08-31
### Added

- `scripts/prepublish-bundle-substrate.mjs` now writes the runtime manifest to `substrate/.bassclef/lite-manifest.json` after copying entries. `assertBundledManifestPresent` postflight verifies the file lives at the expected path with the expected shape (entries[] present + length matches source manifest). Postflight file count check updated to expect `entries.length + 1` for the bundled manifest.
- Three new Tier 0 tests in `tests/harness/prepublish-bundle.test.ts` pin the cure — bundled manifest exists at the runtime path, entries[] length matches source, body is valid JSON with trailing newline.

### Changed

- `dispatchSubstrateCopy` in `src/commands/init.ts` no longer silent-catches `copySubstrate` failures. When the bundled substrate is missing (packaged tarball shipped without the runtime manifest), init now fails loud with cure instructions — Nygard fail-with-fix pattern. Exits 2 with a stderr message naming the cause (missing bundle) and the fix (reinstall from npm or file an issue).

### Fixed

- **Critical — issue #45**: 0.1.0 tarball shipped without `substrate/.bassclef/lite-manifest.json`. Adopters running `npm install -g @thebassclef/core && bassclef init` got only 2 config files instead of the promised 149. Root cause: prepublish script never wrote the runtime manifest into the bundle; `copySubstrate` threw at runtime; `dispatchSubstrateCopy` silent-catch hid the failure. Two-part cure: prepublish writes the manifest into the bundle (with postflight assertion); init removes the silent-catch and fails loud with cure instructions.

### Notes

- Live smoke test on published 0.1.0 revealed the bug — install-then-init produced 2 files, not 149. 0.1.0 unpublished from npm; 0.1.1 ships the cure.

## [0.1.0] - 2026-08-30
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
