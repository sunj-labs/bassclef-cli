---
tier: standard
id: ADR-006
title: Pin the install harness contract — harness/ dir + git-tracked + local pack + release trigger + tier alignment
status: accepted
date: 2026-08-27
accepted: 2026-08-27
accepted_via: Iteration i Step 4 authors this ADR; Step 6 harness code ships the contract; Step 9 integration run confirms.
supersedes: null
superseded_by: null
authoring_luminaries:
  primary: [michael-feathers, john-ousterhout]
  supporting: [alistair-cockburn, michael-nygard, alan-cooper, saltzer-schroeder]
lead_lens: michael-feathers
bet: docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md
step: 4
references:
  - docs/decompositions/npm-install-harness-domain.md
  - docs/decompositions/npm-install-harness.md
  - docs/use-cases/UC-npm-install-harness.md
  - docs/adrs/ADR-002-bassclef-init-safety-contract.md
  - docs/adrs/ADR-003-bassclef-sync-safety-contract.md
  - docs/adrs/ADR-004-publish-pipeline-safety-contract.md
  - docs/adrs/ADR-005-npm-distribution-architecture.md
---

# ADR-006 — Pin the install harness contract

## Context

Iteration i of the parent goal at `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` ships an install harness. The harness verifies that the shipped npm tarball installs on a fresh Node and runs three verbs (`--version`, `init`, `sync`). Step 1 through Step 3 landed the domain decomposition + fully-dressed use case + GRASP responsibility assignment. This ADR pins the 5 decision points those artifacts left open for Step 6 code to honor.

Forces at play:

- **Adopter contract is at the boundary.** Per Feathers, the characterization test that pins actual behavior is the harness. Any decision that lets the harness drift from the real install path defeats its own purpose.
- **CI cost matters.** GitHub Actions free tier caps at 2000 minutes per month. Harness runs on every release. Solo operator ships ~1-2 releases per week per iteration e pace (whereami L60-66). A 5-minute harness × 8 releases = 40 minutes per month. Room to spare, but reruns on flakes add up fast.
- **Two scenarios, not one.** Local pack proves the pre-publish build. Published fetch proves the shipped artifact. Both matter; the harness owns both.
- **Tier alignment.** The harness verifies the npm package. It is not part of the npm package. Shipping harness code inside `@thebassclef/core` would grow the tarball for no adopter benefit.

Alternatives considered:

1. **Harness lives in `tests/`.** Rejected — `tests/` exercises source; harness exercises the built artifact. Mixing them blurs what each suite protects.
2. **Harness gitignored.** Rejected — operator direction at prep doc L44 said "harness should get deep treatment". Deep treatment includes review + traceability + git history.
3. **Fetch published tarball only (no local pack).** Rejected — cannot verify unreleased commits. Pre-publish defects would ship before the harness caught them.
4. **Run harness on every push, not just release.** Rejected — cost + noise; harness needs a `package.json` version + built `dist/` to make sense; running on every push would flake on WIP branches.
5. **Ship harness code inside `@thebassclef/core`.** Rejected — grows the tarball; adopters do not need the harness at install time.

## Decision

The install harness for `@thebassclef/core` ships with the following contract for iteration i and every subsequent iteration.

### Decision 1 — Directory placement

Harness lives at `harness/` at the repo root. Not `tests/`. Not `src/`. Not `.harness/`.

Rationale — Feathers characterization tests live at the artifact boundary. `tests/` is source-side. `src/` is source. `harness/` names the boundary role. A future maintainer scanning the repo tree sees `src/` (source), `tests/` (source tests), `harness/` (built-artifact tests). Three names, three roles.

### Decision 2 — Git tracking

Harness code IS git-tracked. Not gitignored.

Rationale — operator direction at prep doc L44 + Feathers characterization principle. Untracked harness is invisible harness; invisible harness is dead harness.

Layout inside `harness/`:

```
harness/
  npm-install.test.ts         ← Vitest test file with test-list block
  lib/
    fixture.ts                ← Fixture class (per GRASP Step 3)
    tarball-pack.ts           ← TarballPack class
    install-scope.ts          ← InstallScope class
    cli-invocation.ts         ← CliInvocation class
    verification.ts           ← VerificationResult class
    harness-run.ts            ← HarnessRun class
```

7 files. Each library file matches one object from the GRASP responsibility matrix.

### Decision 3 — Local pack + published fetch

Both scenarios run in every full harness invocation. Local pack scenario proves the pre-publish build. Published fetch scenario proves the shipped artifact.

Local pack — `npm pack` in the cli working copy; `TarballPack.local()` factory.

Published fetch — `npm pack @thebassclef/core@<version>` against live npm registry; `TarballPack.published()` factory with one retry after 5 seconds on failure (Nygard retry per UC extension 3b).

Both scenarios use identical downstream pipeline (Fixture → InstallScope → CliInvocation × 3 → VerificationResult × 3). Only the TarballPack factory differs.

### Decision 4 — CI trigger shape

Harness fires on:

- `release: types: [published]` — same trigger as ADR-004 publish workflow. Every release runs through the harness.
- `workflow_dispatch:` with `tag` input — manual re-runs for transient flakes; operator invokes from GitHub Actions UI.

Not `on: push:`. Not `on: schedule:`. Not `on: pull_request:` (harness needs a real published version to fetch; PR branches without a release do not have one).

Workflow file — `.github/workflows/harness.yml`. Not `publish.yml` (that path is semver-locked per ADR-004 L64-75 and hard-coded on npmjs.com side; the harness must not touch it).

### Decision 5 — Tier alignment

Harness stays inside bassclef-cli repo. Never ships in the `@thebassclef/core` npm tarball.

Enforcement — `package.json` `files` field is a whitelist per ADR-001 + ADR-005 L38. `harness/` is not in the whitelist. Belt-and-suspenders — `npm pack --dry-run --json` output (already run in ADR-004 publish pipeline step 9) does not include `harness/**`. If it does, publish tier-filter.mjs blocks.

## Exit code mapping

Formalizes UC extensions 2a-9a. Harness process exits with:

| Code | Cause | Extension |
|---|---|---|
| `0` | All HarnessRun instances passed | Main success |
| `2` | Fixture temp dir creation failed | 2a |
| `3` | `npm pack` failed (local OR published after retry) | 3a + 3b |
| `4` | `npm install` failed inside Fixture prefix | 4a |
| `5` | `bassclef --version` failed OR mismatched | 5a + 5b |
| `6` | `bassclef init` failed OR wrote wrong file set | 6a + 6b |
| `7` | `bassclef sync --dry-run` reported unexpected diff | 7a |
| `8` | Aggregate mixed result (one scenario passed, one failed) | 9a |

Code `1` reserved — not used by harness (matches convention that `1` is generic script error; harness always exits with a specific code from the mapping OR 0).

## Status

`accepted` on 2026-08-27 via iteration i Step 4. Ratified by Step 9 integration verify.

## Consequences

**Easier:**

- Every future release runs through a real install path before adopters see it.
- Adopters get a documented safety gate; contributors extending the harness know exactly where new files live.
- Failure output names the failing scenario + verb + exit code — one glance at the workflow log tells the operator which extension fired.

**Harder:**

- Harness adds a required-check on release. A release cannot merge to `latest` dist-tag without a green harness run. Operator must approve OR the workflow blocks.
- Fixture cleanup adds test infrastructure the maintainer must keep working (`fs.rmSync` semantics change across Node major versions; retest on Node upgrade).
- Two scenarios doubles run time vs one scenario. Trade-off named in Context — both scenarios catch different defects.

**Enables:**

- Adding Node 18 + Node 22 as separate scenarios in a follow-on iteration — matrix-strategy over the same HarnessRun class.
- Adding a fourth verb (e.g., `bassclef status`) — one static method on VerificationResult + one call site in HarnessRun.
- Reusing the harness pattern for future CLIs (e.g., `@thebassclef/lite` when Model C ships) — port the object model.

**Blocks (until reconsidered):**

- No macOS or Windows scenarios in iteration i. Ubuntu-only. macOS + Windows are follow-on iterations.
- No harness that runs on push. Every harness invocation needs a real version.

**Invariants established (semver-locked for iteration i and beyond):**

Directory placement:
- Harness at `harness/` — rename requires ADR amendment
- Library files at `harness/lib/*.ts` — one file per GRASP object

Git tracking:
- Harness IS git-tracked — no `.gitignore` entry for `harness/`

Scenarios:
- Local pack scenario runs on every full harness invocation
- Published fetch scenario runs on every full harness invocation
- Order — local pack first (fast fail on pre-publish defect), then published fetch (slower; live network)
- One retry on published fetch after 5 seconds

CI triggers:
- `release: types: [published]` + `workflow_dispatch: {tag: input}` — nothing else
- Workflow file `.github/workflows/harness.yml`

Tier alignment:
- `harness/**` NOT in `package.json` `files` whitelist
- Belt-and-suspenders — `npm pack --dry-run --json` in ADR-004 publish pipeline step 9 verifies

Exit codes:
- Mapping above is stable — changing an existing code is a MAJOR bump per semver
- Adding a new code (e.g., for a fourth verb) is a MINOR bump
- Removing a code is a MAJOR bump

Fixture contract:
- Cleanup runs on ALL exit paths (success, verification fail, install fail, mid-pipeline crash)
- Cleanup failure after success = warn-only (per Nygard fail-safe)
- Cleanup failure before success = fail HarnessRun

Any change to a listed decision, exit code, invariant, or file layout is a MAJOR bump under the harness's own contract (independent of the `@thebassclef/core` package version).

## References

- Goal doc — `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md`
- Prep doc — `docs/next-longrun-prep-2026-08-13-npm-install-harness.md`
- Domain decomposition (Step 1) — `docs/decompositions/npm-install-harness-domain.md`
- Fully-dressed UC (Step 2) — `docs/use-cases/UC-npm-install-harness.md`
- GRASP responsibility matrix (Step 3) — `docs/decompositions/npm-install-harness.md`
- ADR-001 — build toolchain + files whitelist (harness excluded via same mechanism)
- ADR-002 — init safety contract (harness verifies init behavior per UC main success Step 6)
- ADR-003 — sync safety contract (harness verifies sync behavior per UC main success Step 7)
- ADR-004 — publish pipeline (harness rides alongside; workflow file path never conflicts)
- ADR-005 — two-road split (harness verifies Road 1)
- Luminaries:
  - `michael-feathers.md` — characterization tests at adopter boundary
  - `john-ousterhout.md` — deep modules; each harness library file is a deep module
  - `alistair-cockburn.md` — walking skeleton (Step 6 code lands thin end-to-end first)
  - `michael-nygard.md` — fail-safe cleanup + retry pattern for transient flakes
  - `alan-cooper.md` — adopter is Sam; harness catches what Sam would have hit first
  - `saltzer-schroeder.md` — complete mediation across every publish + install
