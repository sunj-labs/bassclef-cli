---
tier: standard
name: npm install harness — GRASP responsibility assignment
slug: npm-install-harness-grasp
authored: 2026-08-27
authored_by: agent
bet: docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md
step: 3
prep_source: docs/next-longrun-prep-2026-08-13-npm-install-harness.md
extends: docs/decompositions/npm-install-harness-domain.md
governs_source:
  - harness/npm-install.test.ts
  - harness/lib/*.ts
luminaries:
  primary: john-ousterhout
  supporting: [craig-larman, michael-feathers, alistair-cockburn]
  rotation_reason: |
    Step 3 is GRASP assignment — Ousterhout leads because "deep modules with
    narrow interfaces" IS the GRASP shape once responsibilities are placed.
    Larman supports because GRASP is his method (Applying UML and Patterns,
    3rd ed. 2004). Feathers + Cockburn ride from Step 2's UC into the
    interaction shape GRASP formalizes.
---

# npm install harness — GRASP responsibility assignment

Step 3 output. Domain decomposition from Step 1 plus fully-dressed UC from Step 2 → GRASP-assigned responsibilities per class. Each of the 6 objects gets a primary GRASP pattern plus interface signature. Steps 4-6 use this to shape ADR-006 + R-NPM-014 + the test code.

## Sources read

- `docs/decompositions/npm-install-harness-domain.md` — Step 1 output; 6 entities + actors + BCE
- `docs/use-cases/UC-npm-install-harness.md` — Step 2 output; main success + 11 extensions
- `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md` — parent goal
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` L67-98 — init behavior VerificationResult judges
- `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` — publish shape
- Larman, *Applying UML and Patterns* (Prentice Hall, 3rd ed. 2004) ch 17 — 9 GRASP patterns
- Ousterhout, *A Philosophy of Software Design* (2nd ed. 2021) ch 4-6 — deep modules
- Feathers, *Working Effectively with Legacy Code* (Prentice Hall, 2004) ch 13 — test seams

## GRASP patterns applied

Larman names 9 patterns — Information Expert, Creator, Controller, Low Coupling, High Cohesion, Polymorphism, Pure Fabrication, Indirection, Protected Variations. Six objects → primary + supporting patterns per object.

## Responsibility matrix

| Object | Primary GRASP | Supporting GRASP | Interface size (methods) | Implementation size (est. LoC) | Depth ratio (impl/interface) |
|---|---|---|---|---|---|
| Fixture | Creator | Pure Fabrication + Protected Variations | 3 | 60-100 | ~25× (deep) |
| TarballPack | Information Expert | Low Coupling | 2 | 40-60 | ~25× (deep) |
| InstallScope | Controller (subordinate) | Low Coupling | 2 | 30-50 | ~20× (deep) |
| CliInvocation | Information Expert | Low Coupling + Indirection | 2 | 40-60 | ~25× (deep) |
| VerificationResult | Information Expert | High Cohesion | 3 | 50-80 | ~20× (deep) |
| HarnessRun | Controller | Low Coupling + Protected Variations | 2 | 80-120 | ~50× (deep) |

Ousterhout deep-module check — every object ships thin interface + rich implementation. Depth ratios above 20× per Ousterhout's guideline. No shallow module exposed.

## Per-object rationale

### Fixture — Creator + Pure Fabrication + Protected Variations

**Why Creator.** Fixture creates the temp dir + npm prefix — the pair that scopes every downstream object. Creator applies when a class Contains or Aggregates the created objects (Larman GRASP L474). Fixture contains the temp dir path plus every scoped resource that lives inside it.

**Why Pure Fabrication.** Nothing in the domain says "Fixture" — it is a designed object, not a real-world entity. Pure Fabrication (Larman GRASP L486) applies when High Cohesion + Low Coupling demand a class that does not represent a domain noun. Fixture exists to bundle setup + cleanup + resource scoping in one place.

**Why Protected Variations.** Fixture hides the OS temp-dir API behind a stable interface. Node's `fs.mkdtempSync` semantics could change across major Node versions; Fixture's interface stays stable. Protected Variations (Larman GRASP L492) applies.

**Interface (3 methods):**
```typescript
class Fixture {
  create(): Promise<void>   // mkdtemp + prefix setup + register cleanup
  npmPrefix(): string       // return path for InstallScope to use
  cleanup(): Promise<void>  // rmSync; safe to call twice
}
```

Cleanup runs via a `try / finally` inside `HarnessRun.run()` — Fixture does not need lifecycle hooks. Test framework (Vitest) may also register cleanup at `afterEach` as a belt-and-suspenders check.

### TarballPack — Information Expert + Low Coupling

**Why Information Expert.** TarballPack owns everything about the tarball — path, version, source (local vs published). Information Expert (Larman GRASP L459) assigns behavior to the class with the data.

**Why Low Coupling.** TarballPack does not touch Fixture, InstallScope, or downstream objects. It runs `npm pack` and reports back. Low Coupling (Larman GRASP L470) minimizes ripple when TarballPack changes.

**Interface (2 methods):**
```typescript
class TarballPack {
  static local(workingDir: string): Promise<TarballPack>       // npm pack in cwd
  static published(scope: string, version: string): Promise<TarballPack>  // npm pack @scope/name@version
  readonly path: string      // .tgz file path
  readonly version: string   // extracted from pack output
  readonly source: 'local' | 'published'
}
```

Two factory methods for the two scenarios. Instance is read-only after creation. Retry logic for published-fetch flakes (Extension 3b in UC) lives inside `TarballPack.published()`.

### InstallScope — Controller (subordinate) + Low Coupling

**Why Controller (subordinate).** InstallScope is the subordinate controller for the npm-install operation. HarnessRun is the primary controller; InstallScope handles one specific coordination — running `npm install --prefix` and reporting the installed binary path. Larman GRASP L462 allows subordinate controllers when a specific operation is complex enough to deserve its own coordinator.

**Why Low Coupling.** InstallScope depends only on Fixture (for the prefix path) + TarballPack (for the tarball path). Nothing else touches it.

**Interface (2 methods):**
```typescript
class InstallScope {
  constructor(fixture: Fixture, tarball: TarballPack)
  install(): Promise<InstalledBinary>   // runs npm install --prefix; returns {binPath: string}
}

type InstalledBinary = { binPath: string }
```

`install()` throws on non-zero npm exit with the npm error text — HarnessRun catches. No retry (install failures are usually deterministic; retry would mask the defect).

### CliInvocation — Information Expert + Low Coupling + Indirection

**Why Information Expert.** CliInvocation owns everything about one CLI run — binary path, args, timeout, captured output. It runs the process and reports.

**Why Low Coupling.** Depends only on the InstalledBinary path. Does not know about Fixture or TarballPack.

**Why Indirection.** CliInvocation shields the rest of the code from Node's `child_process` API (which has subtle sync/async + stdio buffering quirks). Indirection (Larman GRASP L495) applies.

**Interface (2 methods):**
```typescript
class CliInvocation {
  constructor(binPath: string, verb: string, args: string[])
  run(opts?: { timeoutMs?: number, cwd?: string }): Promise<CliCaptured>
}

type CliCaptured = {
  exitCode: number
  stdout: string
  stderr: string
  timedOut: boolean
}
```

Timeout default 30 seconds. Captured triple is plain data — no interpretation.

### VerificationResult — Information Expert + High Cohesion

**Why Information Expert.** Owns the pass/fail judgment. Given a CliCaptured + a verification rule, produces a structured result.

**Why High Cohesion.** VerificationResult does one thing — applies the rule for one verb. Separate rule set per verb keeps each verification tight. Larman GRASP L468 (High Cohesion).

**Interface (3 methods):**
```typescript
class VerificationResult {
  static forVersion(captured: CliCaptured, expected: string): VerificationResult
  static forInit(captured: CliCaptured, initDir: string): VerificationResult
  static forSyncDryRun(captured: CliCaptured): VerificationResult
  readonly ok: boolean
  readonly detail: string   // human-readable pass/fail explanation
}
```

Three factory methods — one per verb. Adding a fourth verb (e.g., `bassclef status`) is one static method + one call site in HarnessRun. Protected Variations achieved via factory-per-verb pattern.

### HarnessRun — Controller + Low Coupling + Protected Variations

**Why Controller.** HarnessRun is the primary controller (Larman GRASP L462). It sequences TarballPack → InstallScope → CliInvocation × N → VerificationResult × N. Owns error propagation + fail-fast policy.

**Why Low Coupling.** HarnessRun depends on the 5 other objects but they do not depend on it. Ripple flows one way.

**Why Protected Variations.** HarnessRun's `run()` returns a structured outcome. Test file consumes the outcome. Adding a new scenario (Node 18 in the future) means one more HarnessRun instance + one more assertion — no reshape of the test file's interpretation code.

**Interface (2 methods):**
```typescript
class HarnessRun {
  constructor(scenario: 'local' | 'published', opts: HarnessOpts)
  run(): Promise<HarnessOutcome>
}

type HarnessOpts = {
  workingDir?: string        // for local scenario
  scope?: string             // '@thebassclef'
  packageName?: string       // 'core'
  version?: string           // for published scenario
  timeoutMs?: number         // per-verb timeout
  failFast?: boolean         // default true
}

type HarnessOutcome = {
  scenario: 'local' | 'published'
  ok: boolean
  verbs: Array<{ verb: string, result: VerificationResult }>
  fixtureCleanupError?: string  // warn-only
}
```

## Interaction diagram (UC → objects)

Text-only sequence for the main success scenario (Step 5 mermaid diagram may formalize later):

```
CI Runner
  → npm run harness:npm-install
    → new HarnessRun('local', {...})
      → HarnessRun.run()
        → new Fixture() ; fixture.create()
        → TarballPack.local(workingDir)  ← npm pack subprocess
        → new InstallScope(fixture, tarball) ; installScope.install()  ← npm install subprocess
        → new CliInvocation(bin, '--version', []).run()  ← subprocess
        → VerificationResult.forVersion(captured, tarball.version)
        → new CliInvocation(bin, 'init', []).run({cwd: initDir})  ← subprocess
        → VerificationResult.forInit(captured, initDir)
        → new CliInvocation(bin, 'sync', ['--dry-run']).run({cwd: initDir})  ← subprocess
        → VerificationResult.forSyncDryRun(captured)
        → return HarnessOutcome
      → fixture.cleanup() [in finally]
    → new HarnessRun('published', {...})
      → (same shape as above; TarballPack.published(...) instead)
    → assert outcome1.ok && outcome2.ok
```

## Pattern annotations for Step 8

Per `.claude/rules/pattern-annotation.md`. Step 8 annotates source with `@pattern` when a class embodies a named catalog pattern.

| Object | Named pattern | Catalog path (if bassclef-upstream carries it) |
|---|---|---|
| Fixture | Test Fixture (Fowler *xUnit Test Patterns*, 2007) | `bassclef-upstream/patterns/code/fowler/test-fixture.md` — check existence at Step 8; file if missing per pattern-annotation.md L46 |
| Fixture cleanup | RAII / Scoped Resource | Not a GoF pattern; bassclef-upstream may not have a catalog entry — skip annotation if catalog missing |
| CliInvocation | Command (Gamma et al., 1994) | `bassclef-upstream/patterns/code/gof/command.md` — check at Step 8 |
| VerificationResult | Strategy (Gamma et al., 1994) via factory-per-verb | `bassclef-upstream/patterns/code/gof/strategy.md` — arguably; more naturally the factory-per-verb IS the Strategy shape |
| HarnessRun | Template Method OR Pipeline | Deferred — Step 6 code shape will confirm which pattern the implementation reads as |

Step 8 grep + annotate + verify catalog paths exist.

## What Step 3 defers to Step 4 (ADR-006)

- Directory placement — `harness/` at repo root (out of `tests/` because it exercises the built artifact, not source)
- Git-tracked (not `.gitignore`'d) per operator direction at prep doc L44
- Local `npm pack` vs published fetch scenario split
- CI trigger shape (`release: published` + `workflow_dispatch`)
- Tier alignment — harness stays in cli, does NOT ship in the npm tarball (`files` field in `package.json` excludes)
- Exit code mapping — Extensions 2a-9a in UC define 7 exit codes; ADR-006 formalizes the mapping

## What Step 3 defers to Step 6 (harness code)

- Concrete TypeScript file paths under `harness/lib/`
- Test framework choice (Vitest most likely, matching cli's existing test setup at `tests/`)
- Test-list block content (Beck test-list per `.claude/rules/test-list-discipline.md`)
- Fail-fast toggle default
- Retry timing for TarballPack.published() flakes

## Refs

- Larman, *Applying UML and Patterns* (Prentice Hall, 3rd ed. 2004) ch 17 — 9 GRASP patterns L455-500
- Ousterhout, *A Philosophy of Software Design* (2nd ed. 2021) — deep modules
- Gamma, Helm, Johnson, Vlissides, *Design Patterns* (Addison-Wesley, 1994) — Command, Strategy, Template Method
- Fowler et al., *xUnit Test Patterns* (Addison-Wesley, 2007) — Test Fixture
- Meszaros, *xUnit Test Patterns* (2007) — Fresh Fixture + Shared Fixture patterns
- Step 1 domain — `docs/decompositions/npm-install-harness-domain.md`
- Step 2 UC — `docs/use-cases/UC-npm-install-harness.md`
- Goal doc — `docs/iteration-bets/2026-08-27-iteration-i-npm-install-harness.md`
