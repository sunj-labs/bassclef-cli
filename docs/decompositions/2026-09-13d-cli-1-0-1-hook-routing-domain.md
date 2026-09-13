---
tier: lite
slug: 2026-09-13d-cli-1-0-1-hook-routing-domain
type: domain-decomposition
input_artifact: 2026-09-13d-cli-1-0-1-hook-routing
created_at: 2026-09-13T21:15:00Z
references:
  - { type: input-artifact, id: 2026-09-13d-cli-1-0-1-hook-routing }
  - { type: iteration-bet, id: 2026-09-13d-cli-1.0.1-hook-routing }
entity_count: 11
actor_count: 4
phase: jacobson
---

# Domain decomposition — cli 1.0.1 hook routing

Jacobson analysis on the InputArtifact at `docs/input-artifacts/2026-09-13d-cli-1.0.1-hook-routing.json`. Extracts entities + actors + verb-goal pairs + BCE matrix. Feeds Step 3 (`/use-case` fully-dressed) + Step 5 (`/decompose` GRASP + patterns).

## Sources read

- `docs/input-artifacts/2026-09-13d-cli-1.0.1-hook-routing.json` — normalized intent + entities + actors + boundary objects; the main input for this decomposition
- `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md` — 18 risks across 3 lenses; N5/N6/F3/S2/S3 shape the ScopeRouter + ExecutableBitEnforcer + SymlinkRefuser class emergence
- `src/lib/copy-substrate.ts` (cli 1.0.0 walker at commit c974f33) — current walker shape; L131 readHookCount, L275-277 project-scope AlreadyExists refusal, L316-325 top-directory grouping
- `src/commands/init.ts` (cli 1.0.0 dispatcher at commit c974f33) — L88-94 root refusal, L253-268 placeholder transform, L418 writeManifest
- Public bassclef v0.40.0 `dist/lite/.claude/settings.json` — 6 event types + 2 command prefixes ($HOME + $CLAUDE_PROJECT_DIR)
- bassclef-upstream ADR-055 D1 — verbatim-copy contract; cli does not compose settings.json

## What I'm NOT reading (with reason)

- `src/lib/write-safely.ts` — implementation detail of SymlinkRefuser Control class; Step 5 (`/decompose` GRASP) reads this
- Full 24 hook binary contents — content is opaque to the walker; only path + executable bit matter at this altitude
- ADR-002 §Amendment 2026-09-13 exit code table — Step 3 use case reads this for extension paths

## Entities

Domain nouns the cli tracks or moves through the routing pipeline.

- **HookBinary** — a shell script file at `dist/lite/.claude/hooks/<name>.sh` in the bundle. Carries executable bit (git mode `100755`). 24 instances at v0.40.0.
- **ScopePrefix** — the string prefix on a settings.json command that names where the hook lives at runtime. Two values today: `$HOME` (user home) and `$CLAUDE_PROJECT_DIR` (adopter repo root).
- **HookCommand** — a full `command` string from settings.json (e.g., `$CLAUDE_PROJECT_DIR/.claude/hooks/plain-english-steering.sh`). Composes ScopePrefix + relative path.
- **EventBlock** — one of six Claude Code hook events (PostToolUse, PreToolUse, SessionStart, Stop, UserPromptExpansion, UserPromptSubmit) that binds a set of HookCommands.
- **WiringManifest** — the bundled `standards/bassclef-wiring-manifest.json` file. Declares schema version (currently `2.0.0`). Guards reader-side compatibility.
- **BundleRoot** — the resolved on-disk directory the walker reads from (`dist/lite/` inside the installed npm package).
- **AdopterRepo** — the on-disk directory the adopter ran `bassclef init` inside. Written as the project scope.
- **UserHome** — the resolved `$HOME` on the adopter machine. Written as the user scope.
- **InitManifest** — the `.bassclef/init.manifest.json` file the cli writes to record what init did. Sync reads it to detect adopter edits.
- **CopyResult** — the in-process value the walker returns: copied paths, refused paths, errored paths, wiring version, hook count.
- **HookCountReport** — the operator-visible banner value ("N hooks armed (<tier> tier)"). One number per init run.

## Actors

- **ColdAdopter** — a human running `npm install @thebassclef/lite && bassclef init` for the first time. Never seen the substrate before. Reads the banner + expects Claude Code session-start to succeed.
- **InitDispatcher** — the outer cli process in `src/commands/init.ts`. Parses argv, checks safety gates, dispatches the walker, writes the manifest, prints the banner.
- **InitWalker** — the inner walk-and-copy process in `src/lib/copy-substrate.ts`. Reads BundleRoot, per-file transforms + writes to per-scope target, returns CopyResult.
- **ClaudeCodeSession** — the Claude Code harness that reads `.claude/settings.json` after `bassclef init` and invokes each hook at its declared command path.

## Verb-goal pairs

Each `<actor> <verb> <object>` triple. Feeds Cockburn use-case formalization in Step 3.

- ColdAdopter runs `bassclef init`
- ColdAdopter reads the hook-count banner
- InitDispatcher checks safety gates (root refusal, HOME containment, manifest existence)
- InitDispatcher dispatches InitWalker
- InitWalker reads WiringManifest
- InitWalker validates schema major version
- InitWalker resolves BundleRoot
- InitWalker walks the BundleRoot tree
- InitWalker classifies each file by ScopePrefix
- InitWalker copies HookBinary to per-scope target
- InitWalker preserves executable bit on copied HookBinary
- InitWalker refuses symlink at either scope target
- InitWalker returns CopyResult
- InitDispatcher counts hooks in copied settings.json
- InitDispatcher compares copied count vs declared count
- InitDispatcher prints HookCountReport
- InitDispatcher writes InitManifest
- ClaudeCodeSession reads settings.json at session start
- ClaudeCodeSession invokes each HookCommand at its resolved path

## BCE matrix (Jacobson classification)

Every domain noun classified per Jacobson's Boundary / Control / Entity model.

| Noun | Classification | Rationale |
|---|---|---|
| `bassclef init` CLI command | Boundary | The surface the ColdAdopter touches |
| Settings.json (bundle input) | Boundary | The externally-authored contract the walker reads |
| Hook binaries (bundle input) | Boundary | External artifacts the walker consumes |
| Wiring manifest (bundle input) | Boundary | External contract the reader validates against |
| Hook-count banner (output) | Boundary | Operator-visible signal after the run |
| User-scope hooks (output at `~/.claude/hooks/`) | Boundary | Externally-observable artifact after the run |
| Project-scope hooks (output at `<repo>/.claude/hooks/`) | Boundary | Externally-observable artifact after the run |
| Init manifest (output) | Boundary | Audit trail readable by sync |
| InitDispatcher | Control | Orchestrates safety gates + walker dispatch + reporting |
| InitWalker | Control | Coordinates per-file read + classify + route + write |
| PlaceholderTransform | Control | Coordinates per-file content substitution |
| ScopeRouter (new — emerges from decomposition) | Control | Maps HookCommand.ScopePrefix to a filesystem target directory |
| ExecutableBitEnforcer (new — emerges from decomposition) | Control | Sets mode `0755` after copy on `.sh` files |
| SymlinkRefuser (existing writeSafely + user-scope extension) | Control | Refuses symlink writes on both scopes |
| HookBinary | Entity | Persistent domain state — the file itself is the value being moved |
| WiringManifest | Entity | Persistent contract — schema version + declared hook count |
| CopyResult | Entity | In-memory value object — copied + refused + errored + count |
| InitManifest (data) | Entity | Persistent audit record |
| HookCommand | Entity | Value object parsed from settings.json — prefix + relative path |
| ScopePrefix | Entity | Enum value: `$HOME` or `$CLAUDE_PROJECT_DIR` (extensible) |
| EventBlock | Entity | Value object grouping HookCommands by Claude Code event type |

## Notes

- **Two Control classes emerge from the walker rewrite** — `ScopeRouter` (maps prefix → target dir) and `ExecutableBitEnforcer` (guarantees mode `0755` on `.sh` files). Both are new deep modules; each maps to a GRASP responsibility in Step 5.
- **SymlinkRefuser extends existing `writeSafely`** — project-scope already refuses symlinks (`src/lib/write-safely.ts` `WriteError.SymlinkRefused`). User-scope needs the same guard. One interface with two callsites, not two separate refusers.
- **ScopePrefix is an open enum** — today the two values cover the wiring manifest, but risk N6 in the ledger v1 names the class where upstream adds a third prefix. The ScopeRouter throws `UnknownPrefix` on unrecognized values rather than silent-drop.
- **HookCountReport is a Boundary emitted from a Control class** — the operator-visible banner comes from `InitDispatcher.printBanner`. Risk N5 in the ledger names the class where declared and copied counts diverge silently. The banner value composes both numbers and returns non-zero on mismatch.
- **PlaceholderTransform must NOT touch hook files** — F3 in the ledger names the class. The current `PLACEHOLDER_FILES` set explicitly lists CLAUDE.md, whereami.md, .bassclef-source.json. Hook filenames stay outside the set. A negative characterization test in Step 10 pins the invariant.
- **The four actors form a chain** — ColdAdopter → InitDispatcher → InitWalker → ClaudeCodeSession. Failure at any hop must surface at the ColdAdopter boundary; silent failure between InitDispatcher and ClaudeCodeSession is the exact 1.0.0 regression this ticket cures.

## References

- Input: `docs/input-artifacts/2026-09-13d-cli-1.0.1-hook-routing.json`
- Risk ledger v1: `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md`
- Downstream: Step 3 (`docs/use-cases/UC-init-walker-hook-routing.md`), Step 5 (`docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-grasp.md`)
