---
tier: standard
id: UC-npm-install-harness
name: Verify @thebassclef/core tarball installs and runs on fresh Node
level: user goal
primary_actor: CI Runner (GitHub Actions job)
scope: bassclef-cli — install harness (iteration i)
authored: 2026-08-27
authored_by: agent
cockburn_ceremony: fully-dressed
bet: docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md
step: 2
prep_source: docs/next-longrun-prep-2026-08-13-npm-install-harness.md
governs_source:
  - harness/npm-install.test.ts
  - harness/lib/fixture.ts
  - harness/lib/tarball-pack.ts
  - harness/lib/install-scope.ts
  - harness/lib/cli-invocation.ts
  - harness/lib/verification.ts
  - .github/workflows/harness.yml
references_adr: ADR-006-install-harness.md (Step 4 authors this)
references_decomposition: docs/decompositions/npm-install-harness-domain.md
---

# UC-npm-install-harness — Verify @thebassclef/core tarball installs and runs on fresh Node

## Sources read

- `docs/decompositions/npm-install-harness-domain.md` — Step 1 output; 6 entities + actors + verb-goal pairs feed this UC
- `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md` — parent goal for iteration i
- `docs/next-longrun-prep-2026-08-13-npm-install-harness.md` L44-48 — Option b scope carrying the harness contract
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` L67-98 — init behavior verified in Step 4 of main success scenario
- `docs/adrs/ADR-003-bassclef-sync-safety-contract.md` — sync behavior verified in Step 5
- `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` L99-151 — publish shape the harness rides after
- `docs/use-cases/UC-init.md` L1-58 — Cockburn fully-dressed template shape for cli convention

## Scope

The install harness in bassclef-cli — `harness/npm-install.test.ts` plus supporting library files + a CI workflow. Verifies that the npm-packed tarball installs cleanly on fresh Node 20 and that the installed CLI runs three verbs (`--version`, `init`, `sync`) without error.

## Level

User goal — CI Runner completes one workflow run and reports pass or fail on the release page.

## Primary actor

CI Runner — the GitHub Actions job defined at `.github/workflows/harness.yml`. Triggered on `release: published` event OR `workflow_dispatch` manual dispatch. Reads the harness process exit code as pass/fail signal.

## Stakeholders + interests

| Stakeholder | Interest |
|---|---|
| CI Runner | Wants a deterministic pass/fail signal within the workflow's time budget (~5 minutes). No flakes on slow npm registry. |
| Operator (Sanjay) | Wants every release to run through a real install path before it reaches Sam. Wants failure output that names the failing verb + captured stderr for debugging without a re-run. |
| Sam (adopter, indirect) | Wants first install to work. Never invokes the harness herself — the harness catches what she would have hit first. |
| Maintainer of future harness code | Wants clear object boundaries (per decomposition Step 1) so extending the harness for a fourth verb costs one file edit, not five. |
| npm registry | Wants low request volume — harness fires once per release, not on every commit. |

## Preconditions

- `@thebassclef/core@<version>` is either (a) built locally in the working copy (source of truth for the local-pack scenario) OR (b) published on npm at `<version>` (source of truth for the published-fetch scenario).
- The workflow file `.github/workflows/harness.yml` exists in the repo default branch.
- Node 20 is available on the CI runner (ubuntu-latest ships this).
- npm 11 is available OR upgraded during workflow setup (per iteration e cure documented in `docs/session-logs/2026-08-13-iteration-e-plus-npm11-cure.md`).
- The trigger fired — either a GitHub Release with `published` type OR a workflow_dispatch invocation naming a version.

## Success guarantee (postconditions)

- Two HarnessRun instances completed — one for local-pack scenario, one for published-fetch scenario.
- Each HarnessRun ran the full pipeline: TarballPack → InstallScope → CliInvocation × 3 verbs → VerificationResult × 3.
- Every VerificationResult returned pass.
- All Fixture temp directories removed (no leak on runner disk).
- Workflow exit code 0. GitHub UI shows green check on the release page.

## Minimal guarantee

- Any Fixture created has its temp directory removed. Cleanup runs on all exit paths (success, VerificationResult failure, install failure, mid-scenario crash) per Nygard fail-safe defaults.
- If any HarnessRun fails, the failing scenario + verb + captured stderr appears in the workflow log before exit.

## Trigger

One of:
- `release: types: [published]` — GitHub Releases event
- `workflow_dispatch:` with `tag` input for manual re-runs

## Main success scenario

1. **CI Runner** invokes the harness via `npm run harness:npm-install` in the workflow.
2. **HarnessRun (local-pack scenario)** creates a Fixture — scoped temp dir via `fs.mkdtempSync` + scoped npm prefix at `<tempdir>/.npm-global`. Cleanup callback registered in a `finally` block.
3. **TarballPack (local)** runs `npm pack` in the cli working copy. Reports the resulting `.tgz` path + version string extracted from the pack output.
4. **InstallScope** runs `npm install --prefix <fixture.npmPrefix> <tarball.path>`. Reports success + the installed CLI binary path at `<npmPrefix>/bin/bassclef`.
5. **CliInvocation (verb 1)** executes `<bin>/bassclef --version` with a 30-second timeout. Captures exit code + stdout + stderr. **VerificationResult (verb 1)** asserts exit code 0 + stdout contains the version string reported by TarballPack.
6. **CliInvocation (verb 2)** executes `<bin>/bassclef init` in a fresh subdirectory of the Fixture. Captures exit code + stdout + stderr. **VerificationResult (verb 2)** asserts exit code 0 per ADR-002 L223-225 + presence of the three expected files (`.claude/settings.json`, `substrate.config.md`, `.bassclef/init.manifest.json`) per ADR-002 L203-211.
7. **CliInvocation (verb 3)** executes `<bin>/bassclef sync --dry-run` in the initialized subdirectory. Captures exit code + stdout + stderr. **VerificationResult (verb 3)** asserts exit code 0 + stdout contains "already current" (or the equivalent no-change phrase per ADR-003).
8. **Fixture (local-pack)** cleanup fires — `fs.rmSync(tempdir, {recursive: true, force: true})`. Temp dir removed.
9. **HarnessRun (published-fetch scenario)** repeats Steps 2-8 with one change — Step 3 runs `npm pack @thebassclef/core@<version>` against the live npm registry instead of the local working copy.
10. **HarnessRun (aggregate)** reports both scenarios pass. Workflow exit 0. Release page shows green check.

## Extensions

**2a. Temp directory creation fails.**
Fixture reports the OS error. HarnessRun exits with structured error naming the OS error text. Workflow exit code 2. No cleanup needed (nothing was created).

**3a. `npm pack` fails in local working copy.**
TarballPack reports the npm error. HarnessRun exits with the pack error text. Fixture cleanup fires. Workflow exit code 3.

**3b. `npm pack @thebassclef/core@<version>` fails against live registry (published-fetch scenario).**
TarballPack reports the registry error. HarnessRun retries once after 5 seconds (per Nygard retry pattern for transient registry flakes). If second attempt fails, HarnessRun exits with the registry error text. Fixture cleanup fires. Workflow exit code 3.

**4a. `npm install` fails inside the Fixture prefix.**
InstallScope reports the npm error. HarnessRun exits with the install error text. Fixture cleanup fires. Workflow exit code 4.

**5a. `bassclef --version` fails or hangs.**
CliInvocation reports timeout or non-zero exit. VerificationResult reports fail with captured stderr. HarnessRun continues to Step 6 to gather full failure profile OR exits early on `--fail-fast` (workflow default). Fixture cleanup fires. Workflow exit code 5.

**5b. `bassclef --version` output does not contain expected version string.**
VerificationResult reports mismatch — expected string, actual stdout. HarnessRun continues per `--fail-fast` policy. Workflow exit code 5.

**6a. `bassclef init` refuses per ADR-002 policy (unexpected refusal in fresh dir).**
VerificationResult reports fail with the refusal message from stderr. HarnessRun exits. Fixture cleanup fires. Workflow exit code 6.

**6b. `bassclef init` succeeds but does not write all three expected files.**
VerificationResult reports which files are missing. HarnessRun exits. Fixture cleanup fires. Workflow exit code 6.

**7a. `bassclef sync --dry-run` reports pending changes when none should exist (freshly initialized dir).**
VerificationResult reports the unexpected diff. HarnessRun exits. Fixture cleanup fires. Workflow exit code 7.

**8a. Fixture cleanup fails.**
Fixture reports the cleanup error but does not fail the HarnessRun (the pipeline already succeeded before cleanup). HarnessRun logs the cleanup failure as a warning. Workflow exit code 0 (per Nygard — cleanup failure after success is a log-and-continue, not a fail).

**9a. Published-fetch scenario fails while local-pack passed.**
HarnessRun aggregate reports mixed result. Workflow exit code 8 (aggregate signal). Both scenarios' detail lands in the workflow log.

## Technology + Data variations

- **Node version.** Default Node 20 (matches release workflow per ADR-004 L109). Future variation may run harness on Node 18 + Node 22 to catch version-specific defects. Iteration i ships Node 20 only.
- **npm version.** Pinned to npm 11 in the workflow per iteration e cure (npm 10 silently omits trusted publisher headers per session log 2026-08-13). Harness inherits the same pin.
- **OS.** ubuntu-latest per workflow. macOS + Windows variations deferred to a follow-on iteration.
- **Fixture prefix path.** `<tempdir>/.npm-global` by default. Overridable via env var `HARNESS_NPM_PREFIX` for local debugging.

## Related information

- `ADR-006` (Step 4 authors this) — pins the harness contract with 5 decision points (harness/ dir, git-tracked, npm pack usage, CI triggers, tier alignment).
- Requirement `R-NPM-014` (Step 5 authors this row) — traceability from the UC's postconditions back to source + tests.
- Failure exit code registry — Extensions above define exit codes 2 through 8. ADR-006 will formalize the mapping.
- Load estimate — harness runs on every `release: published` event. Solo operator ships ~1-2 releases per week (per whereami L60-66 iteration e pace). Volume compatible with GitHub Actions free tier.
- Aging expectation — this UC governs iteration i + every future release for the life of `@thebassclef/core`. Extension to Node 18 + Node 22 + macOS is a follow-on iteration, not a rewrite.
- Verification harness — the harness IS the verification (Feathers characterization pattern). No separate test-of-test needed at Tier 0. Iteration adds meta-tests only if the harness itself starts producing false results.

## Cross-references

- Domain decomposition — `docs/decompositions/npm-install-harness-domain.md` (Step 1 output; 6 entities + BCE classification + candidate patterns)
- Parent goal — `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md`
- Prep doc — `docs/next-longrun-prep-2026-08-13-npm-install-harness.md`
- Sister use cases in cli — `UC-init.md`, `UC-sync.md`, `UC-script-publish.md`, `UC-script-bump.md`
- Cockburn, *Writing Effective Use Cases* (Addison-Wesley, 2001) — fully-dressed template shape this UC honors
