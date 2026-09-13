---
tier: lite
id: UC-init-walker-hook-routing
name: Route bundled hook binaries to user and project scopes at init time
level: subfunction
extends: UC-init
primary_actor: ColdAdopter
scope: bassclef-cli — the walker inside `bassclef init` (extends UC-init postcondition #1)
authored: 2026-09-13
authored_by: agent
cockburn_ceremony: fully-dressed
bet: docs/iteration-bets/2026-09-13d-cli-1.0.1-hook-routing.md
governs_source:
  - src/lib/copy-substrate.ts
  - src/lib/write-safely.ts
  - src/commands/init.ts
references_adr:
  - ADR-002-bassclef-init-safety-contract.md
  - ADR-055 (bassclef-upstream — reader contract)
references_input_artifact: docs/input-artifacts/2026-09-13d-cli-1.0.1-hook-routing.json
references_decomposition: docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-domain.md
references_risk_ledger: docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md
---

# UC-init-walker-hook-routing — Route bundled hook binaries to user and project scopes at init time

## Sources read

- `docs/use-cases/UC-init.md` — parent use case; this UC extends postcondition #1 (walker copies dist/<tier>/ tree) with per-scope routing for hook binaries
- `docs/input-artifacts/2026-09-13d-cli-1.0.1-hook-routing.json` — normalized intent; source of the two-prefix routing decision
- `docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-domain.md` — 11 entities + 4 actors + BCE matrix; ScopeRouter + ExecutableBitEnforcer emerge as Control classes
- `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md` — 18 risks; extensions below cover the top-5 folded risks
- `src/lib/copy-substrate.ts` at commit c974f33 — current walker shape the extension modifies
- Public bassclef v0.40.0 `dist/lite/.claude/settings.json` — 6 event blocks + 2 command prefixes ($HOME, $CLAUDE_PROJECT_DIR)
- ADR-002 §Amendment 2026-09-13 — exit codes 4 + 5 (wiring manifest failures)
- bassclef-upstream ADR-055 D1 — verbatim-copy contract; walker does not compose settings.json

## What I'm NOT reading (with reason)

- `src/lib/write-safely.ts` full body — Step 5 GRASP decomposition reads this; here I cite the extension shape (add user-scope symlink refuser) at UC altitude
- Full 24 hook binary contents — opaque to the walker; only path + executable bit matter for this UC

## Scope

The walker extension inside `bassclef init` that copies hook binary files from `dist/<tier>/.claude/hooks/*.sh` to the correct filesystem target based on the command prefix each hook uses in the bundled `settings.json`. Extends UC-init postcondition #1 with two-scope routing. Ships in cli 1.0.1.

## Level

Subfunction — one step inside the UC-init main scenario (specifically, the copySubstrate walker dispatch at UC-init main step 6).

## Primary actor

**ColdAdopter** — a human running `npm install @thebassclef/lite@1.0.1 && bassclef init` for the first time. Attention budget: reads the banner + expects Claude Code session-start to work.

## Stakeholders and interests

| Stakeholder | Interest |
|---|---|
| ColdAdopter | Wants zero hook-not-found errors on Claude Code session-start after init. Wants the banner to honestly report what landed. |
| Maintainer (bassclef-cli operator) | Wants every user-scope write auditable + refuse-on-symlink same as project-scope. Wants the executable bit preserved so hooks actually run. |
| Bassclef-upstream author | Wants cli to copy the bundle verbatim per ADR-055 D1 — no cli-side composition of settings.json. |
| Adopter machine security posture | Wants no path traversal outside `~/.claude/hooks/` or `<repo>/.claude/hooks/`. Wants no follow-through of adversarial symlinks on either scope. |
| Future prefix additions | Wants the walker to fail loud (exit 2) rather than silent-drop when upstream adds a third scope prefix. |

## Preconditions

Inherits every UC-init precondition, plus:

1. Bundled `dist/<tier>/.claude/settings.json` uses exactly the two known command prefixes: `$HOME` and `$CLAUDE_PROJECT_DIR`. Any third prefix triggers extension 3a.
2. Bundled `dist/<tier>/.claude/hooks/*.sh` files exist for every command declared in settings.json (bundle-side invariant enforced by bassclef-upstream release step; cli fails loud in extension 5a if violated).
3. `$HOME` environment variable is set. Any unset state triggers extension 1a.

## Success guarantee (postconditions)

1. Every hook binary referenced by a `$HOME/...` command in settings.json has been copied to `~/.claude/hooks/<same-relative-path>`.
2. Every hook binary referenced by a `$CLAUDE_PROJECT_DIR/...` command in settings.json has been copied to `<adopter-repo>/.claude/hooks/<same-relative-path>`.
3. Every copied hook file has mode `0755` (executable bit set for owner + group + other read + execute).
4. Neither scope target followed a symlink at write time.
5. The banner reports `N hooks armed (<tier> tier)` where N equals the copied-hook-file-count AND equals the declared-hook-count in settings.json.
6. `.bassclef/init.manifest.json` records both scopes with a `scope: user | project` field per hook entry.
7. Exit code 0.

## Failure guarantee (minimal postconditions on failure)

- No adopter file has been silently overwritten.
- Every failed write left a stderr line naming the file + reason.
- Exit code is 1 (policy refusal), 2 (write-time safety fail), 4 (manifest missing), or 5 (schema incompatible) per ADR-002 §Amendment 2026-09-13. Zero for the new class: banner-count-mismatch surfaces as exit 2 per postcondition #5.

## Main success scenario

1. **ColdAdopter runs `bassclef init`.** InitDispatcher parses argv + resolves target dir + checks root refusal + checks manifest existence (all per UC-init main steps 1-4).
2. **InitDispatcher dispatches copySubstrate walker.** Walker resolves BundleRoot from installed package path.
3. **Walker reads WiringManifest.** Schema major version checked against `EXPECTED_WIRING_SCHEMA_MAJOR`. Version 2.0.0 passes.
4. **Walker walks the BundleRoot tree.** Enumerates every file under `dist/<tier>/` recursively, sorted for determinism.
5. **Walker classifies each hook file by scope.** For every file matching `.claude/hooks/*.sh`, walker consults settings.json's command list. Command starting `$HOME/` → user scope. Command starting `$CLAUDE_PROJECT_DIR/` → project scope. Non-hook files (settings.json itself, CLAUDE.md, whereami.md, etc.) → project scope per UC-init.
6. **Walker copies each hook via writeSafely.** For each hook:
   - Target path resolves: `${HOME}/.claude/hooks/<name>.sh` (user) OR `<targetDir>/.claude/hooks/<name>.sh` (project).
   - writeSafely refuses symlinks on both scopes.
   - Walker sets mode `0755` on the copied file.
   - CopyResult accumulates the target path with a `scope` tag.
7. **Walker returns CopyResult.** Includes copied paths, refused paths, errored paths, and the copied-hook count.
8. **InitDispatcher counts declared hooks in copied settings.json.** Compares copied-hook count vs declared-hook count.
9. **InitDispatcher prints hook-count banner.** Format: `N hooks armed (<tier> tier)` where N equals both counts.
10. **InitDispatcher writes InitManifest.** Includes both scopes with `scope` field per entry.
11. **ColdAdopter reads the banner + opens Claude Code.** Session-start hooks fire from `~/.claude/hooks/`. UserPromptSubmit hooks fire from `<repo>/.claude/hooks/`. Zero hook-not-found errors.
12. Exit code 0.

## Extensions

Numbered per Cockburn shape. Each extension names the trigger, the alternative flow, and the exit outcome. Extension IDs match main scenario step numbers.

- **1a. `$HOME` environment variable unset.**
   1. Walker detects `$HOME` empty or missing at step 5 classification.
   2. Walker throws `CopyFailure` with kind `EnvironmentIncomplete` naming `$HOME` and remediation ("set HOME before running init").
   3. InitDispatcher prints stderr line and exits 1.
   4. No user-scope files written. Project-scope writes from prior iterations of the loop stay in place (no rollback — same as UC-init partial-success shape).

- **1b. Cli invoked as root without `--allow-root`.**
   1. Root refusal fires at UC-init step 1 (existing gate). Walker never reaches step 2.
   2. Exit 1.
   3. Note — even with `--allow-root`, the walker path resolves `$HOME` to `/root` and writes user-scope hooks to `/root/.claude/hooks/`. Extension 1c covers this class.

- **1c. `--allow-root` passed AND user-scope target lands under `/root`.**
   1. Walker detects `$HOME == /root` at step 5.
   2. Walker treats this as extension 1a (`EnvironmentIncomplete` variant with kind `SudoBypassRefused`) and refuses the write.
   3. Exit 1. Rationale: routing user-scope hooks to root-owned dirs breaks the adopter maintenance model; complete-mediation gap per S1 in the risk ledger.

- **3a. WiringManifest schema major version differs from cli expectation.**
   1. Walker throws `CopyFailure` kind `SchemaIncompatible` per ADR-055 D4.
   2. InitDispatcher exits 5. (Existing behavior; unchanged.)

- **3b. WiringManifest missing from bundle.**
   1. Walker throws `CopyFailure` kind `ManifestMissing`.
   2. InitDispatcher exits 4. (Existing behavior; unchanged.)

- **5a. Hook file referenced in settings.json is missing from bundle.**
   1. Walker classifies the missing hook at step 5 (from settings.json command list) but readFileSync fails at step 6.
   2. Walker adds the hook to `CopyResult.errored` with a stderr message naming the missing file + remediation ("reinstall @thebassclef/<tier>").
   3. Walker continues with remaining hooks.
   4. InitDispatcher exits 2 at postcondition #5 check because copied count is less than declared count.

- **5b. Third scope prefix appears in settings.json (unknown to walker).**
   1. Walker's ScopeRouter throws `CopyFailure` kind `UnknownScopePrefix` naming the prefix + remediation ("upgrade cli to a version that supports this prefix").
   2. InitDispatcher exits 5. Rationale: silent-drop of an unknown prefix reproduces the exact class of failure this UC exists to close (per N6 in risk ledger).

- **6a. Symlink present at user-scope target.**
   1. writeSafely throws `WriteError.SymlinkRefused` for user-scope target (existing project-scope behavior extended to user-scope per S2 in risk ledger).
   2. Walker adds the target to `CopyResult.refused` (not `errored`) — refusal is by-design.
   3. InitDispatcher continues with remaining hooks + exits 2 with a stderr message naming the symlink target + remediation ("delete or move the symlink at `~/.claude/hooks/<name>.sh` and rerun").

- **6b. Symlink present at project-scope target.**
   1. writeSafely throws `WriteError.SymlinkRefused` (existing behavior).
   2. Walker adds the target to `CopyResult.refused`.
   3. InitDispatcher exits 2 with stderr line.

- **6c. Existing non-symlink file at user-scope target without `--force`.**
   1. writeSafely throws `WriteError.AlreadyExists` for user-scope (new — extends project-scope path per N4 in risk ledger).
   2. Walker adds the target to `CopyResult.refused`.
   3. InitDispatcher prints stderr line naming the file + remediation ("pass --force to overwrite or delete the file first").
   4. Continues with remaining hooks. Exits 2 unless every hook that was owed landed.

- **6d. chmod fails on copied hook (non-POSIX filesystem, permission error).**
   1. Walker's ExecutableBitEnforcer catches the chmod error.
   2. If OS is Windows, walker skips chmod silently and emits an INFO-level stderr note ("executable bit not applicable on this OS"). Continues.
   3. If OS is POSIX and chmod fails for another reason, walker adds the hook to `CopyResult.errored`. Exits 2.

- **6e. Path traversal in a hook command (defensive — should be impossible at bundle level).**
   1. Walker's ScopeRouter normalizes the resolved target via `path.resolve` at step 6.
   2. Resolved target is checked for containment under `homedir()` (user scope) or `targetDir` (project scope).
   3. If containment fails, walker throws `CopyFailure` kind `PathTraversalRefused` naming the path + remediation ("report the bundle content to bassclef-upstream — this is a bundle-side defect").
   4. Exits 2. Rationale: complete-mediation on read-side per S4 in risk ledger.

- **8a. Copied hook count does not equal declared hook count.**
   1. Postcondition #5 check fails at step 8.
   2. Banner reads `N of M hooks armed (<tier> tier)` where N is copied, M is declared.
   3. InitDispatcher exits 2. Rationale: honest signal per N5 in risk ledger.

- **10a. Second `bassclef init` run without `--force`.**
   1. Every user-scope target hits extension 6c (`AlreadyExists`).
   2. Every project-scope target hits UC-init's existing `AlreadyExists` refusal.
   3. Exit 2 unless `--force` supplied.
   4. Rationale: idempotency per S5 in risk ledger; adopter edits from first run are not silently clobbered.

## Special requirements

- **Determinism** — the walker sorts file entries before iterating, so failure messages are stable across runs. Per ADR-055 D3.
- **Fail-loud** — every classified failure surfaces a stderr line + a non-zero exit code. Silent skip is not acceptable. Per @luminary michael-nygard.
- **Complete mediation** — every filesystem write goes through writeSafely (or its user-scope sibling). No direct fs.writeFileSync anywhere in the walker path. Per @luminary saltzer-schroeder.
- **Executable-bit preservation** — every `.sh` file lands mode `0755` after copy. Per S3 in risk ledger.

## Technology and data variations

- **Non-POSIX filesystems** — Windows filesystems ignore Unix executable bits. Walker detects `process.platform === 'win32'` and skips chmod with an INFO stderr note (extension 6d.2). Hooks land readable; Claude Code on Windows handles execute permission differently.
- **`$HOME` shape** — POSIX `$HOME` is expected. On Windows, walker uses `os.homedir()` (Node's canonical resolver) which returns `%USERPROFILE%`. Same routing applies.
- **Tier variation** — cli 1.0.1 ships lite tier. Standard + ultra tiers ship the same walker with different bundle contents (more hooks). Walker code is tier-agnostic; the bundle drives the count.

## Frequency of occurrence

Per cold-adopter machine: once per fresh install. Per `bassclef init --force`: same walker runs but with overwrite enabled. Per session: never (walker only fires at init).

## Open issues

- **User-scope manifest scope-field shape** — Step 6 spec decides whether user-scope entries in `.bassclef/init.manifest.json` carry a `scope: user` field OR a distinct top-level `user_scope_files:` array. Decomposition (Step 5) reads the trade-off.
- **Second-adopter migration** — first cold adopter on a fresh machine gets clean writes. A machine where another adopter previously installed bassclef will hit extension 6c on every user-scope hook. Behavior is correct (refuse-and-report), but adopter UX may need a `--refresh-user-hooks` flag in a future cli release. Not in scope for 1.0.1.

## References

- Parent UC: `docs/use-cases/UC-init.md`
- Input: `docs/input-artifacts/2026-09-13d-cli-1.0.1-hook-routing.json`
- Domain decomposition: `docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-domain.md`
- Risk ledger v1: `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md`
- Downstream: Step 4 interaction design, Step 5 GRASP decomposition, Step 6 spec, Step 7 goal doc, Step 8 RFC, Step 9 risk ledger v2, Step 10 Tier 0 RED harness
- bassclef-cli#79 (v0.40.0 handoff)
- bassclef-upstream#1619 (parent cure ticket)
- bassclef-upstream#1623 (regression report + cure PR #1624)
