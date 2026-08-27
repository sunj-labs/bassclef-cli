---
tier: standard
name: npm install harness — Jacobson objectory-decompose (domain)
slug: npm-install-harness-domain
authored: 2026-08-27
authored_by: agent
bet: docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md
step: 1
prep_source: docs/next-longrun-prep-2026-08-13-npm-install-harness.md
luminaries:
  primary: sophia-prater
  supporting: [michael-feathers, alistair-cockburn, ivar-jacobson]
  rotation_reason: |
    Step 1 is OOUX object-model-first work per prep doc L40. Prater leads because
    the domain enumeration comes before actions; Feathers + Cockburn ride into
    Steps 2-3 (fully-dressed UC + walking skeleton) but Prater owns Step 1's
    object shape. Jacobson supports because this IS his method — the whole
    /objectory-decompose skill honors *Object-Oriented Software Engineering* (1992).
---

# npm install harness — Jacobson objectory-decompose (domain)

Step 1 output for iteration i. Objects enumerated, actors named, verb-goal pairs listed, BCE classification applied per Jacobson's boundary + control + entity model. Step 2 uses this to write a fully-dressed use case. Step 3 uses this plus the UC to assign GRASP responsibilities.

## Sources read

- `docs/next-longrun-prep-2026-08-13-npm-install-harness.md` L39-40 (Step 1 scope — 6 objects named)
- `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md` L36 (references list) + § "Luminary map"
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` L67-98 — init behavior the harness exercises
- `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` L99-151 — publish shape the harness rides after
- `docs/adrs/ADR-005-npm-distribution-architecture.md` L37-42 — Road 1 ship contract (dist/ + README + LICENSE)
- `docs/decompositions/wu-3-sync.md` L1-80 — decomposition file shape template
- `bassclef-upstream/.claude/luminaries/sophia-prater.md` (OOUX method — nouns before verbs)
- `bassclef-upstream/.claude/rules/pattern-annotation.md` — @pattern annotation contract for Step 8

## Domain narrative

The harness verifies that the shipped npm tarball installs cleanly on a fresh Node and runs three verbs — `bassclef --version`, `bassclef init`, `bassclef sync`. Two scenarios matter: local pack (working copy → `npm pack` → install → run) and published fetch (npm registry → install → run). Both scenarios use scoped temp directories and clean up after themselves per Nygard fail-safe defaults.

The domain has six objects. They collaborate through a linear pipeline — one produces, the next consumes. Cleanup runs in reverse order under any exit path (success or failure).

## Entities (nouns; 6 per prep doc L39)

### 1. Fixture

The isolated environment where one harness run happens. Owns a scoped temporary directory (`fs.mkdtempSync`), a scoped npm prefix (`--prefix $tempdir/.npm-global`), and a cleanup contract (`finally`-block `fs.rmSync`). Fixture is the outermost object — every other object lives inside a Fixture instance.

Responsibilities:
- Create the temp dir on setup
- Provide the npm prefix path to InstallScope
- Register cleanup callbacks
- Remove the temp dir on teardown (success or failure path)

Non-responsibilities:
- Does NOT execute install (delegates to InstallScope)
- Does NOT create the tarball (delegates to TarballPack)

### 2. TarballPack

The npm tarball artifact under test. Produces from either a local `npm pack` command (in the working copy) or a fetch from the npm registry (`npm pack @thebassclef/core@<version>`). Carries the tarball file path + the version string + the source (local vs published).

Responsibilities:
- Run `npm pack` in the correct directory
- Report the resulting `.tgz` path
- Report the version string extracted from the pack output
- Report the source (local vs published)

Non-responsibilities:
- Does NOT install (delegates to InstallScope)
- Does NOT clean up the tarball file (Fixture owns cleanup)

### 3. InstallScope

The scoped npm install operation. Given a TarballPack + a Fixture, runs `npm install --prefix <fixture.npmPrefix> <tarball.path>`. Isolates the install from the CI runner's global npm state. Reports install success + the installed CLI binary path.

Responsibilities:
- Execute `npm install --prefix ...`
- Verify the install succeeded (exit code + presence of `bin/bassclef`)
- Report the installed binary path
- Report install failure with the npm error text

Non-responsibilities:
- Does NOT invoke the CLI (delegates to CliInvocation)
- Does NOT own the prefix directory (Fixture owns)

### 4. CliInvocation

One command run against the installed CLI. Given the binary path + a command name (`--version`, `init`, `sync`) + args, runs the binary and captures exit code + stdout + stderr. Repeats per verb the harness needs to test.

Responsibilities:
- Execute the CLI binary with named arguments
- Capture exit code, stdout, stderr
- Report the captured triple back for verification
- Handle timeout if the command hangs

Non-responsibilities:
- Does NOT judge success or failure (delegates to VerificationResult)
- Does NOT own the binary (InstallScope reports it)

### 5. VerificationResult

The judgment on one CliInvocation. Given the captured exit code + stdout + stderr, decides pass or fail against expected shape (per ADR-002 for init, per ADR-003 for sync, per package.json version for --version). Carries the assertion text + the actual output snippet on failure.

Responsibilities:
- Apply the verification rule for the invoked verb
- Return pass / fail with structured detail
- Format failure text for reviewer visibility

Non-responsibilities:
- Does NOT execute anything (pure judgment)
- Does NOT own the source of truth (reads from ADR-002 + ADR-003 references)

### 6. HarnessRun

The top-level run for one scenario (local pack OR published fetch). Owns the Fixture, orchestrates TarballPack → InstallScope → CliInvocation × N verbs → VerificationResult × N. Reports the run outcome (pass / fail) + per-verb detail. Two HarnessRun instances per full harness invocation — one per scenario.

Responsibilities:
- Compose the pipeline in order
- Handle mid-pipeline failure (short-circuit; run cleanup)
- Report the run outcome
- Emit per-verb detail for the CI log

Non-responsibilities:
- Does NOT own multiple scenarios (the test file spins up two HarnessRun instances)
- Does NOT clean up (Fixture owns; HarnessRun delegates)

## Actors (verb subjects)

Per Jacobson, actors are agents outside the system that trigger use cases.

### Primary actors

- **CI Runner** — GitHub Actions job. Triggers the harness on `release: published` event OR `workflow_dispatch` manual dispatch. Reads the pass/fail outcome from the workflow exit code.
- **Operator (Sanjay)** — invokes the harness locally via `npm run harness:npm-install` during development OR reads harness output on the GitHub Actions run page after a release publish.

### Secondary actors

- **npm Registry** — the source of truth for the published scenario. Serves the published tarball on `npm pack @thebassclef/core@<version>`. Not a direct actor but a required external system.
- **Local Working Copy** — the source of truth for the local-pack scenario. Provides the pre-release build the harness verifies before publish.

### Non-actors (deliberately)

- **Sam (adopter persona)** — Sam does NOT invoke the harness. Sam invokes `bassclef init` after `npm install -g @thebassclef/core`. The harness verifies what Sam would see; the harness is not part of Sam's workflow. Cooper lens tracks Sam through VerificationResult's assertion rules but Sam does not appear in the actor list.

## Verb-goal pairs (use case candidates)

Per Cockburn's verb + goal-noun pattern. Each pair is a candidate use case Step 2 may flesh out.

| Actor | Verb + goal | Use case candidate |
|---|---|---|
| CI Runner | verify tarball installs and runs | UC-npm-install-harness (Step 2 authors this) |
| CI Runner | report harness outcome to release page | UC-harness-report (extension of primary UC; Step 2 folds in) |
| Operator | invoke harness locally during dev | UC-harness-local-dev (secondary UC; scope may defer to follow-on) |
| Operator | debug harness failure from CI log | UC-harness-failure-triage (extension; documented in ADR-006 rather than as UC) |
| HarnessRun | short-circuit on mid-pipeline failure | Extension of primary UC (Step 2 fleshes out) |
| Fixture | clean up on any exit path | System guarantee (Step 2 documents in postconditions) |

**Primary UC** for Step 2: `UC-npm-install-harness.md` — CI Runner verifies the tarball installs and runs correctly. Covers both scenarios (local pack + published fetch). Extensions cover mid-pipeline failure paths.

## BCE classification (Boundary / Control / Entity)

Per Jacobson's *Object-Oriented Software Engineering* (1992). Each object gets one primary classification. Some objects have a secondary role.

| Object | Primary | Secondary | Why |
|---|---|---|---|
| Fixture | **Boundary** | (Control) | Owns the boundary between the test process and the OS filesystem/npm state; cleans up at the edge. Secondary control role in cleanup ordering. |
| TarballPack | **Boundary** | (Entity) | Boundary to `npm pack` command + npm registry. Secondary entity role as the artifact-under-test carrier. |
| InstallScope | **Boundary** | — | Boundary to `npm install` command. Pure boundary object. |
| CliInvocation | **Boundary** | — | Boundary to the installed CLI process. Pure boundary object. |
| VerificationResult | **Entity** | — | Pure data + rule application; no external interaction. |
| HarnessRun | **Control** | — | Orchestrates the pipeline; owns sequencing and error propagation. No direct external interaction (delegates to boundary objects). |

Pattern reading — 4 boundary objects + 1 control + 1 entity. High boundary count matches the harness's job (verifying interaction with external systems: npm, filesystem, subprocess). Control-to-boundary ratio 1:4 is expected for characterization-test infrastructure per Feathers *Working Effectively with Legacy Code* Ch 13 (test seams).

## Candidate patterns for Step 3 (GRASP + GoF/Fowler)

Step 3 (`/decompose`) will assign GRASP responsibilities against these objects. Named candidate patterns for Step 8 annotation:

- **Fixture** — Fowler's Test Fixture pattern (see *xUnit Test Patterns*, 2007). Annotate at Step 8.
- **Fixture cleanup** — Nygard's stability pattern; RAII-style resource release via `finally`. Not a named GoF pattern but a documented idiom.
- **CliInvocation** — GoF Command pattern (Gamma et al., 1994) — one object encapsulates one CLI call with its args. Annotate at Step 8 if the code lands with a Command-shape wrapper.
- **HarnessRun** — GoF Template Method OR Pipeline pattern candidate. Step 3 GRASP will pick one based on which shape reads cleanest.

Patterns are candidates only — Step 3 GRASP assignment and Step 6 code shape will confirm or reject each.

## Composition — how Step 1 feeds Step 2

Step 2 (`/use-case UC-npm-install-harness.md`) reads:
- The 6 entities as the objects the UC's main success scenario references
- The actors (CI Runner primary; Operator secondary) as the UC's actors
- The verb-goal pair `CI Runner + verify tarball installs and runs` as the UC's goal
- The extensions (mid-pipeline failure) as the UC's extension section
- The system guarantees (Fixture cleanup) as postconditions

Step 3 (`/decompose` GRASP) reads:
- The 6 entities + BCE classification as the object set for responsibility assignment
- The UC's main success scenario as the interaction shape
- The candidate patterns list to seed pattern selection

## Refs

- Prep doc — `docs/next-longrun-prep-2026-08-13-npm-install-harness.md` L39-40, L88-101
- Goal doc — `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md`
- Jacobson, *Object-Oriented Software Engineering* (Addison-Wesley, 1992) — BCE method
- Cockburn, *Writing Effective Use Cases* (Addison-Wesley, 2001) — actor + verb-goal pattern
- Feathers, *Working Effectively with Legacy Code* (Prentice Hall, 2004) — characterization test framing
- Prater, *OOUX: A Foundation for Interaction Design* (2019 talk + subsequent method) — nouns before verbs
- Gamma et al., *Design Patterns* (Addison-Wesley, 1994) — Command + Template Method
- Fowler et al., *xUnit Test Patterns* (Addison-Wesley, 2007) — Test Fixture
- Nygard, *Release It!* (Pragmatic, 2018 2nd ed.) — stability patterns; RAII cleanup
