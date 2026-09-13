---
tier: lite
slug: 2026-09-13d-cli-1-0-1-hook-routing-grasp
type: grasp-decomposition
input_artifact: 2026-09-13d-cli-1-0-1-hook-routing
sister_decomposition: 2026-09-13d-cli-1-0-1-hook-routing-domain
created_at: 2026-09-13T21:45:00Z
references:
  - { type: input-artifact, id: 2026-09-13d-cli-1-0-1-hook-routing }
  - { type: decomposition, id: 2026-09-13d-cli-1-0-1-hook-routing-domain }
  - { type: iteration-bet, id: 2026-09-13d-cli-1.0.1-hook-routing }
phase: larman-grasp
---

# GRASP decomposition — cli 1.0.1 hook routing

Larman GRASP responsibility assignment on the sequence diagrams in `docs/interaction-designs/2026-09-13d-cli-1-0-1-hook-routing.md`. Assigns Information Expert, Controller, Creator, Low Coupling, High Cohesion to each Control class the domain decomposition surfaced. Selects patterns from GoF + Fowler + stack idioms. Audits cross-cutting concerns.

## Sources read

- `docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-domain.md` — 11 entities + 4 actors + BCE matrix; Control classes emerged (ScopeRouter, ExecutableBitEnforcer, SymlinkRefuser)
- `docs/interaction-designs/2026-09-13d-cli-1-0-1-hook-routing.md` — 3 diagrams; message-send patterns drive GRASP assignment
- `docs/use-cases/UC-init-walker-hook-routing.md` — 12 extensions; each maps to a responsibility that must land on some class
- `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md` — top-5 folds shape the -ility audit
- `src/lib/copy-substrate.ts` at commit c974f33 — existing walker shape; new Control classes fit inside existing structure
- `src/lib/write-safely.ts` (by reference) — existing SymlinkRefuser + AlreadyExists patterns to extend
- Larman — *Applying UML and Patterns* — GRASP source
- @luminary john-ousterhout — deep modules; every new class must have API narrower than implementation
- @luminary martin-fowler — refactoring patterns for the extension
- GoF — Strategy, Chain of Responsibility, Command, Value Object

## What I'm NOT reading (with reason)

- Vernon *Implementing Domain-Driven Design* — aggregate roots do not apply at this altitude (walker is a technical extraction pipeline, not a domain model)
- Nygard *Release It!* — Nygard's stability patterns fed the pre-mortem (Step 0); GRASP focuses on class placement, not runtime failure modes
- Individual hook binary content — opaque to walker; not relevant to class assignment

## GRASP responsibility assignment per class

### InitDispatcher (existing — extended)

- **Pattern**: **Controller** (Larman GRASP)
- **Role**: receives the system event `bassclef init`; orchestrates safety gates + walker dispatch + reporting + manifest write.
- **Why Controller and not Coordinator**: Larman prescribes Controller for the class that first receives an external system event. `bassclef init` is that event; InitDispatcher is the first class to touch it.
- **Cohesion**: high — one concern (init lifecycle orchestration).
- **Coupling**: low — depends on InitWalker via an interface (typed `copySubstrate` function), on writeSafely for its own manifest write, on filesystem for exit codes.
- **Extension in this iteration**: adds `compareHookCounts(copied, declared)` responsibility (per UC Ext 8a); no new class needed.

### InitWalker (existing — extended)

- **Pattern**: **Coordinator** (Larman GRASP) + **Iterator** (GoF)
- **Role**: coordinates per-file classify + route + write + chmod inside `copySubstrate`. Iterates `walkDistTree` output.
- **Why Coordinator not Information Expert**: walker does not own the classification rule (ScopeRouter does) or the executable-bit rule (ExecutableBitEnforcer does) or the symlink rule (writeSafely does). Walker's job is to compose these three.
- **Cohesion**: high — one concern (walk-and-copy loop).
- **Coupling**: low after extraction — depends on the three new/existing Control classes via interfaces.
- **Extension in this iteration**: delegates classification to ScopeRouter (extracted); delegates chmod to ExecutableBitEnforcer (extracted). Walker code shrinks by ~30 lines despite the new routing capability. Per @luminary john-ousterhout — deeper module with narrower interface.

### ScopeRouter (NEW)

- **Pattern**: **Information Expert** (Larman GRASP) + **Strategy** (GoF)
- **Role**: sole owner of the mapping from `HookCommand.ScopePrefix` to a filesystem target directory. Throws on unknown prefix + on env-incomplete + on sudo-bypass + on path traversal.
- **Why Information Expert**: ScopeRouter owns the scope-prefix knowledge (`$HOME`, `$CLAUDE_PROJECT_DIR`). Any class that needed the mapping would ask this class.
- **Why Strategy pattern**: per-prefix routing rule is a strategy family. Adding a third prefix (per risk N6) becomes adding a new strategy, not editing the router core.
- **Cohesion**: high — one concern (prefix → target resolution).
- **Coupling**: low — depends on `process.env.HOME`, `os.homedir()`, `path.resolve`; no dependency on the walker or dispatcher.
- **Public interface** (narrow per Ousterhout):
  ```typescript
  interface ScopeRouter {
    classify(command: HookCommand, targetDir: string): ScopeDecision;
  }
  type ScopeDecision =
    | { scope: 'user'; targetPath: string }
    | { scope: 'project'; targetPath: string };
  // Throws: CopyFailure with kind
  //   'UnknownScopePrefix' | 'EnvironmentIncomplete'
  //   | 'SudoBypassRefused' | 'PathTraversalRefused'
  ```
- **Implementation depth** (behind the interface): prefix inspection, HOME resolution + sudo check, targetDir resolution, path.resolve normalization, containment check per scope. All the S1 + S4 + N2 + N6 risk folds land here.

### ExecutableBitEnforcer (NEW)

- **Pattern**: **Information Expert** (Larman GRASP)
- **Role**: sole owner of the executable-bit rule for `.sh` files. Handles the non-POSIX skip (Windows).
- **Why Information Expert**: chmod semantics + platform check + mode-0755 policy — all one concern.
- **Cohesion**: high.
- **Coupling**: low — depends on `fs.chmodSync` + `process.platform` only.
- **Public interface**:
  ```typescript
  interface ExecutableBitEnforcer {
    setExecutable(targetPath: string): void;
    // Throws on POSIX chmod failure; no-op with INFO stderr on win32.
  }
  ```
- **Risk fold**: S3 lands here.

### SymlinkRefuser (extends existing writeSafely)

- **Pattern**: **Information Expert** (Larman GRASP) — extension of existing `writeSafely`
- **Role**: refuses symlink writes on both project-scope and user-scope. Existing project-scope path preserves ADR-002 discipline; new user-scope path adds same refusal.
- **Why extension not new class**: symlink refusal is one rule with two callsites. One class per rule (High Cohesion). Extension surface is a new option on `writeSafely` or a sibling function `writeSafelyUserScope` — Step 6 spec picks.
- **Risk fold**: S2 lands here.
- **Existing interface** (extended):
  ```typescript
  interface WriteSafely {
    // Existing project-scope shape:
    (target: string, content: string, opts: { force: boolean }): void;
    // User-scope extension — same guarantees; different default policy:
    // - AlreadyExists refusal same
    // - SymlinkRefused same
    // - No HOME containment check here — ScopeRouter did that
  }
  ```

### PlaceholderTransform (existing — negative extension)

- **Pattern**: **Information Expert** (Larman) — for placeholder shapes
- **Role**: unchanged — substitutes canonical placeholders in `PLACEHOLDER_FILES` set only. Never touches hooks.
- **Negative characterization test in Step 10** — asserts a hook filename never matches `PLACEHOLDER_FILES`. F3 fold.

## Pattern selection table

| Pattern | Applied to | Rationale | Cost if wrong |
|---|---|---|---|
| **GRASP Controller** | InitDispatcher | Larman standard for the class receiving external system events | Wrong: init lifecycle concerns leak into walker → high coupling |
| **GRASP Coordinator** | InitWalker | Class composes three specialists (Router + Chmod + WS) without owning any rule itself | Wrong: walker becomes a god class carrying all rules |
| **GRASP Information Expert** | ScopeRouter, ExecutableBitEnforcer, SymlinkRefuser, PlaceholderTransform | Each class owns exactly one rule's knowledge | Wrong: rules scatter across classes → drift + duplication |
| **GoF Strategy** | ScopePrefix mapping inside ScopeRouter | Per-prefix routing rule is a strategy family; extensible via new strategy, not core edit | Wrong: adding a third prefix (N6 risk) requires router core edit |
| **GoF Chain of Responsibility** | ScopeRouter validation chain (prefix → env → containment) | Each check runs before the next; any check may throw | Wrong: mixing validation with routing in one function → hard to test each check independently |
| **GoF Value Object** | HookCommand, ScopePrefix, ScopeDecision, CopyResult | Immutable, equality-by-value, no identity | Wrong: mutable objects → race conditions in the walker loop; test fixtures harder |
| **GoF Command** | Not selected | No undo/redo requirement; no queueing; no reified operation | Wrong: over-abstracts the copy operation for zero benefit |
| **Fowler Registry** | WiringManifest read | Global-in-scope reference; single lookup point per walker run | Wrong: reading manifest per-file → performance hit + inconsistent view if manifest changes mid-run |
| **Fowler Special Case** | UnknownScopePrefix → CopyFailure kind | Named failure type carries remediation string; not null | Wrong: null returns from Router → NPE downstream |
| **Fowler Guard Clause** | Every check in ScopeRouter chain | Early return with typed failure; no nested conditionals | Wrong: nested if/else → hard to read + harder to add new checks |

## Cross-cutting concerns audit

Per @luminary john-ousterhout — cross-cutting concerns must resolve as decorators wrapping interfaces, not bolted into implementations.

| Concern | Owner | Resolution shape |
|---|---|---|
| **Logging** | InitDispatcher | Existing `process.stderr.write` per named error class. No new logger abstraction needed at this scope (single-process CLI). |
| **Observability** | InitDispatcher | `CopyResult` shape carries copied/refused/errored per scope. Banner surfaces the count. Manifest records per-hook scope. Sufficient signal for cold-adopter smoke tests. |
| **Testability** | InitWalker | Existing `bundleRoot` option allows test override. New classes each get their own Tier 0 test file per `.claude/rules/testing-tier-config.md` — SymlinkRefuser user-scope extension, ScopeRouter every branch, ExecutableBitEnforcer platform variations. |
| **Security posture (path traversal, symlink attacks, sudo bypass)** | ScopeRouter + SymlinkRefuser | Both classes throw typed failures on adversarial input. No silent fall-through. Per @luminary saltzer-schroeder — complete mediation on file writes. |
| **Cross-platform** | ExecutableBitEnforcer | Owns the Windows chmod skip decision. Other classes stay platform-agnostic. |
| **Backward compatibility** | InitWalker | Existing behavior for project-scope files unchanged. New user-scope path is additive. Per `.claude/rules/we-dont-break-adopters.md` — cli 1.0.0 adopters running `bassclef init` again on 1.0.1 get more hooks landed, not different behavior for the existing set. |
| **Error message quality** | Every class throwing `CopyFailure` or `WriteError` | Each throw carries a `kind` + a remediation sentence per @luminary cooper — plain-English cure the adopter can act on. |

## Interface catalog

Per Ousterhout — every module's API surface documented explicitly. Total new + extended interfaces:

1. `ScopeRouter.classify(command, targetDir)` — new
2. `ExecutableBitEnforcer.setExecutable(targetPath)` — new
3. `writeSafely` — extended to accept user-scope targets with same guarantees
4. `CopyResult` — extended with per-entry `scope` field
5. `CopyFailure.kind` — extended enum: `UnknownScopePrefix | EnvironmentIncomplete | SudoBypassRefused | PathTraversalRefused` (additions)
6. `InitManifest` schema — extended with `scope: user | project` field per entry
7. `InitDispatcher.printBanner(copied, declared)` — extended shape: `"N of M hooks armed"` on mismatch

## Notes

- **Walker code should shrink after this iteration.** Per Ousterhout deep-module principle — narrower interface + deeper implementation. Extraction of ScopeRouter + ExecutableBitEnforcer moves ~30 lines of inline decisions into two focused classes. Walker becomes a composition point.
- **No god classes.** Every new class owns one rule. ScopeRouter has one method. ExecutableBitEnforcer has one method. Their internal implementations can grow; their APIs stay narrow.
- **Pattern selection is defensible.** Strategy fits the prefix routing because the enum is open (per N6 risk). Chain of Responsibility fits the validation because each check may throw and short-circuit. Value Object fits every immutable data carrier. Command explicitly rejected because there is no undo/redo/queue requirement.
- **Every -ility concern has a named owner.** No cross-cutting concern floats. Logging → InitDispatcher. Observability → CopyResult shape. Security → ScopeRouter + SymlinkRefuser. Testability → each class ships its own Tier 0 test. Cross-platform → ExecutableBitEnforcer. Error message quality → typed failures with remediation strings.

## References

- Domain decomposition: `docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-domain.md`
- Interaction design: `docs/interaction-designs/2026-09-13d-cli-1-0-1-hook-routing.md`
- Use case: `docs/use-cases/UC-init-walker-hook-routing.md`
- Risk ledger v1: `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md`
- Downstream: Step 6 spec, Step 8 RFC, Step 9 risk ledger v2, Step 10 Tier 0 RED harness
