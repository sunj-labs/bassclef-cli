---
rfc: 0002
title: Council review — cli 1.0.1 hook routing (pre-code OOAD)
authored: 2026-09-13
authored_by: agent
status: draft
review_type: outside-luminary council per .claude/rules/loop-discipline.md sub-step 2a
reviews: goal 2026-09-13d Steps 0-7 (pre-mortem + OOAD chain + spec + goal doc)
authoring_set: [michael-nygard, michael-feathers, jerome-saltzer-and-michael-schroeder, john-ousterhout, alan-cooper]
council: [linus-torvalds, hyrum-wright, frederick-brooks, don-norman, andy-hunt-and-dave-thomas]
council_rationale: 5 luminaries deliberately outside the authoring set. Nygard/Feathers/Saltzer-Schroeder covered fail-loud + characterization + mediation. Ousterhout covered deep modules. Cooper covered adopter agency. Council must find gaps those lenses cannot see — adopter contract stability (Torvalds), observable-behavior lock-in (Hyrum), conceptual integrity across a multi-scope walker (Brooks), signifier + feedback quality at the adopter surface (Norman), and orthogonality + DRY in the new class set (Hunt & Thomas).
---

# RFC-0002 — Council review of cli 1.0.1 hook routing

## Sources read

- `docs/iteration-bets/2026-09-13d-cli-1.0.1-hook-routing.md` — goal doc
- `docs/specs/2026-09-13d-cli-1.0.1-hook-routing.md` — spec with 14 acceptance rows
- `docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-domain.md` — 11 entities + 4 actors + BCE
- `docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-grasp.md` — 5 Control classes + pattern selection
- `docs/use-cases/UC-init-walker-hook-routing.md` — main + 12 extensions
- `docs/interaction-designs/2026-09-13d-cli-1-0-1-hook-routing.md` — 3 diagrams
- `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md` v1 — 18 risks + top-5 folds
- `.claude/luminaries/{linus-torvalds,hyrum-wright,frederick-brooks,don-norman,andy-hunt-and-dave-thomas}.md` (where available)

## What I'm NOT reading (with reason)

- Individual hook binary content — opaque to design decisions
- Full ADR-002 body — cited by reference in the spec

## Status

`draft` — findings await operator disposition. Ledger v2 (Step 9) folds accepted findings into engineering actions.

## Method

Each council lens is applied in sequence. For each lens: 3-5 findings, each with severity (HIGH/MEDIUM/LOW) + specific location in the artifacts + proposed disposition. Silence per lens is not the same as "no finding" — every lens gets at least 3 substantive reads.

---

## Lens 1 — Linus Torvalds (adopter contract; do not break userspace)

Concern class: cli 1.0.1 introduces user-scope writes for the first time. Every adopter installing cli 1.0.0 today has `~/.claude/hooks/` in some state — untouched, populated by another tool, or symlinked. Torvalds's rule bites when 1.0.1 changes any observable behavior an adopter depends on.

- **L1 (HIGH)** — Cli 1.0.0 wrote NOTHING to `~/.claude/hooks/`. Cli 1.0.1 does. Adopters running `bassclef init` a second time (upgrade path from 1.0.0 → 1.0.1) will suddenly find user-scope files landing where the tool never wrote before. Per Torvalds: an adopter's script that lists `~/.claude/hooks/` and expects a known content set will now see 2 unexpected files (`bassclef-sync.sh` + `session-reflection.sh`). Not a bug in intent, but a silent behavior change. Disposition options:
  a. Land as-is. Document in CHANGELOG as `**BREAKING for behavior-observers:**` clause; adopter counter is single-digit; risk is small in absolute terms.
  b. Add a preflight banner: "1.0.1 introduces user-scope hook installation at ~/.claude/hooks/. Continue? (y/N)". Blocks silent surprise; costs one interactive prompt on first run.
  c. Add a `--user-scope` flag defaulting to false. Adopters opt-in explicitly. Costs future adopters an extra step; matches Torvalds discipline strictly.

- **L2 (MEDIUM)** — Existing adopters who ran `bassclef init` on 1.0.0 have a `.bassclef/init.manifest.json` file. Adding a `scope` field on 1.0.1 breaks any adopter tooling reading the manifest with strict schema validation. Disposition:
  a. Version the manifest schema (`schema_version: 2`); reader tolerates both v1 and v2. Old readers ignore new fields per JSON tolerance rule; adds one line to the manifest.
  b. Leave scope field out; separate user-scope entries into a sibling `.bassclef/init-user-scope.manifest.json` file. Preserves v1 manifest shape verbatim.

- **L3 (LOW)** — Cli 1.0.0's `bassclef sync` reads the manifest to detect adopter edits. Adding user-scope entries with `scope: user` means sync must either skip them (spec's choice — adopter owns them) or treat them like project-scope entries. Silent drift risk if sync's behavior differs from the spec's stated "sync ignores user-scope entries for edit-detection." Disposition:
  a. Ship a Tier 0 test asserting `bassclef sync` on a repo with mixed-scope manifest ignores user-scope edits. Small ticket; ~5 min work.

---

## Lens 2 — Hyrum Wright (observable behavior)

Concern class: with enough adopters, every observable behavior becomes something someone depends on. The walker's per-scope routing surface has never existed. Every observable — the target paths, the executable bits, the banner shape, the error messages, the manifest layout — locks in on ship day.

- **H1 (HIGH)** — Banner format change from cli 1.0.0's `"N hooks armed (lite tier)"` to a possible `"N of M hooks armed (lite tier)"` on failure paths is now Hyrum-locked. Any adopter parsing the banner (unlikely today, plausible tomorrow) sees an unstable shape. Disposition:
  a. Freeze the shape now — pick the two shapes deliberately and document them in a bassclef-cli standards doc so future changes to the wording surface as ADR-level decisions.
  b. Add a structured stderr line alongside the human banner (e.g., JSON `{copied: 24, declared: 24}` behind a `--json` flag) so parsers use the stable form, not the prose.

- **H2 (MEDIUM)** — `CopyResult.scope` field additions in the Tier 0 test surface. Any Tier 0 test in cli 1.0.0 that asserts against `CopyResult` shape will see a new required field. Fine for internal tests; matters if any downstream tool ever reads the walker return value. Disposition:
  a. Keep `scope` as an optional field in the `CopyResult` type (`scope?: 'user' | 'project'`), even though the walker always populates it. Downstream code that reads only existing fields keeps working; new code can rely on `scope`.

- **H3 (MEDIUM)** — New exit codes are NOT extended in the spec; the spec reuses exit 1 + exit 2 + exit 5 for the new failure kinds. Adopters reading exit codes (scripts wrapping `bassclef init`) will now see exit 1 or exit 2 fire on new conditions ($HOME unset, unknown prefix, path traversal). Per Hyrum: any script branching on exit codes now behaves differently. Disposition:
  a. Keep the spec (reuse existing codes). Document in CHANGELOG that exit 1 now covers additional refusal classes.
  b. Reserve NEW exit codes for the new classes (e.g., 6 for `EnvironmentIncomplete`, 7 for `UnknownScopePrefix`). Preserves existing script behavior; costs a small vocabulary expansion.

- **H4 (LOW)** — WriteError kinds — extending `AlreadyExists` and `SymlinkRefused` semantics to user-scope means adopter tooling that treats those messages as "project-scope only" now sees them fire for user-scope paths. Not a real risk today (no known tooling), but worth naming. Disposition: silent-accept; risk lives on `.claude/rules/we-dont-break-adopters.md` grace window.

---

## Lens 3 — Frederick Brooks (conceptual integrity)

Concern class: walker was a single-scope tool. Cli 1.0.1 makes it a two-scope router. The temptation is to bolt user-scope logic onto the existing project-scope path as an if/else branch. Brooks says: pick a coherent model and hold to it, even at some implementation cost. Two-scope routing must feel like ONE thing, not two.

- **B1 (HIGH)** — Spec calls for ScopeRouter as a new class, but the walker's caller convention (`copySubstrate(targetDir, opts)`) takes ONLY project-scope `targetDir`. User-scope target is implicit (from `$HOME`). The interface leaks the historical single-scope shape. A conceptually-integral shape passes BOTH scopes as arguments: `copySubstrate({ projectDir, userScope: {homeDir, allowRoot} }, opts)`. Disposition:
  a. Refactor the entry-point signature. Larger diff; cleaner conceptual shape. Per Brooks: pay the cost now, not later.
  b. Keep the current signature; document that user-scope resolution happens inside via ScopeRouter. Faster to ship; leaves an integrity debt.

- **B2 (MEDIUM)** — Two failure kind vocabularies exist post-1.0.1: `WriteError` (from `writeSafely`) and `CopyFailure` (from `copy-substrate.ts`). ScopeRouter throws `CopyFailure`. Symlink refusal throws `WriteError`. Adopter reading stderr sees inconsistent tags. Disposition:
  a. Unify — either every failure is a `CopyFailure` kind or every failure is a `WriteError` kind. Pick one lexicon. Small refactor; large integrity win.
  b. Document the split ("CopyFailure for routing/discovery; WriteError for filesystem mediation") and hold. Less code churn; leaves cognitive load on the reader.

- **B3 (MEDIUM)** — GRASP decomposition names 5 Control classes. Two are new (ScopeRouter, ExecutableBitEnforcer), three extend or exist (InitDispatcher, InitWalker, PlaceholderTransform + SymlinkRefuser as writeSafely extension). Class count doubles from cli 1.0.0. Brooks warns: complexity grows superlinearly with class count unless the interfaces stay narrow AND the composition rule is uniform. Disposition:
  a. Ship as-is. Cross-cutting audit in the GRASP decomp already accounts for this. Every class has one method; test surface is manageable.
  b. Consider collapsing `ExecutableBitEnforcer` into a `writeSafely` option (a `mode: 0o755` parameter). Reduces class count by 1. Trade-off: `writeSafely` API widens.

---

## Lens 4 — Don Norman (signifier + feedback)

Concern class: the adopter sees three surfaces — the banner, the stderr on failure, the resulting filesystem state. Every surface must SIGNIFY what happened (past tense, unambiguous) and give feedback the adopter can act on. Norman's affordance test: could a cold adopter, reading only the surface, know exactly what to do next?

- **N1 (MEDIUM)** — Banner text `"N of M hooks armed (lite tier)"` on the failure path (Ext 8a). "Armed" is a jargon signifier. What does "armed" mean to a cold adopter? Compare: `"Installed 22 of 24 hooks. 2 hooks failed to install (see errors above)."` The second version signifies action taken + gap + next-step affordance. Disposition:
  a. Rewrite the banner shape to Norman standard. Preserves count clarity; adds affordance. Small text edit.
  b. Keep "armed" (matches prior cli 1.0.0 banner). Norman finding stands; take as documented drift.

- **N2 (MEDIUM)** — Error message for Ext 6a (`SymlinkRefused` at user-scope): spec says "delete or move the symlink at `~/.claude/hooks/<name>.sh` and rerun". Good. But NORMAN test — a cold adopter who didn't create the symlink doesn't know what it points to or why it exists. Adding `"Symlink target: <resolved-path>"` to the error message helps the adopter decide (delete vs preserve). Disposition:
  a. Include symlink target in the error message. Requires reading `readlink(target)` before the throw; one line.

- **N3 (MEDIUM)** — First-run banner does NOT explain the two-scope model. Adopter sees `"24 hooks armed (lite tier)"` and doesn't know that 22 landed in the repo + 2 in the user home. When something goes wrong later ("why is `bassclef-sync.sh` at ~/.claude/hooks/?"), the connection is opaque. Disposition:
  a. Extend the banner to a two-line form: `"24 hooks armed (lite tier). 22 in <repo>/.claude/hooks/, 2 in ~/.claude/hooks/."`. Explicit surface for the two-scope shape.
  b. Add a one-time first-run hint: `"cli 1.0.1 installs some hooks to your home dir. See docs/user-scope.md."` Costs a doc file.

- **N4 (LOW)** — First-run adopter who runs `bassclef init` and gets a `SudoBypassRefused` (Ext 1c) needs to know WHY sudo bypass is refused. Current message: "routing user-scope hooks to /root breaks adopter maintenance model." That's the correct explanation. Norman check passes.

---

## Lens 5 — Andy Hunt & Dave Thomas (Pragmatic Programmer — DRY + orthogonality)

Concern class: two new classes + one extended class + one shared enum + one extended failure type. DRY (Don't Repeat Yourself) risk if scope-routing logic appears in more than one place. Orthogonality risk if two classes both need to know about $HOME resolution.

- **P1 (HIGH)** — Executable-bit rule appears TWICE in the proposed design:
  1. `ExecutableBitEnforcer.setExecutable(path)` sets mode 0755 after each hook copy.
  2. Test assertion `statSync(path).mode & 0o111 !== 0` verifies it in the Tier 0 harness.
  The MODE VALUE (0o755, 0o111) is the shared knowledge. If either changes, the other must too. DRY violation. Disposition:
  a. Extract a shared constant `HOOK_EXECUTABLE_MODE = 0o755` and `HOOK_EXECUTABLE_MASK = 0o111` in a small module that both the enforcer + tests import.
  b. Accept the duplication — it's small AND clearly named. DRY at this scale is over-engineered.

- **P2 (MEDIUM)** — $HOME resolution logic appears in TWO places:
  1. ScopeRouter's classification path (checks env, checks sudo bypass, resolves to `~/.claude/hooks/`).
  2. UC-init's existing `--allow-any-dir` gate (via `resolveTargetDir`, which also touches $HOME implicitly for containment check).
  These two paths might diverge on edge cases (e.g., $HOME symlinked to /var/home). Orthogonality violation — two classes with overlapping knowledge. Disposition:
  a. Extract a shared `resolveHome(opts)` helper that both consumers call. Returns the canonical home path or throws the right typed failure.
  b. Document that the two resolvers can differ, and pin the delta with a test. Acceptable if the differences are named.

- **P3 (MEDIUM)** — CopyResult carries both flat `copied: string[]` (paths) AND the walker will populate `scope` per entry. Consumers must join the two data lists to know per-file scope. DRY violation waiting to happen — someone will add a `copiedByScope: { user: string[], project: string[] }` field for convenience, and then TWO representations exist. Disposition:
  a. Change `CopyResult.copied` shape from `string[]` to `Array<{path: string, scope: 'user' | 'project'}>`. One representation. Downstream code adapts.
  b. Keep the flat shape + add `scope` as a parallel array indexed the same way. Two lists means two things to keep in sync — Pragmatic warning stands.

- **P4 (LOW)** — Extension IDs in UC-init-walker-hook-routing use numbers per Cockburn (1a, 1c, 3a, 5b, 6a-e, 8a, 10a). Tests will need to name the extensions somehow (test name, comment, or ID). If naming is inconsistent between UC + tests, the traceability rots. Disposition:
  a. Ship a naming convention in the Tier 0 harness: `test('UC-init-walker-hook-routing Ext 6a — symlink at user-scope target refuses', ...)`. Pins the traceability.

---

## Summary — findings by severity

| Severity | Count | Findings |
|---|---|---|
| HIGH | 3 | L1 (adopter behavior change), H1 (banner shape lock-in), B1 (interface signature leaks single-scope shape), P1 (executable-bit constant duplication) — wait, P1 also HIGH per Hunt-Thomas rating |
| MEDIUM | 8 | L2, L3, H2, H3, B2, B3, N1, N2, N3, P2, P3 |
| LOW | 3 | H4, N4, P4 |

Total findings: 14.

## Proposed disposition table (for Step 9 ledger v2 fold)

Each row names the finding + a proposed engineering action. Ledger v2 in Step 9 folds accepted rows.

| Finding | Severity | Proposed action | Engineering fold shape |
|---|---|---|---|
| L1 adopter behavior change | HIGH | Accept b — preflight banner on first-run 1.0.1 install detecting cli 1.0.0 manifest present | New check in InitDispatcher: read old manifest; if present + no user-scope entries, print advisory + confirm; adds 1 Tier 0 test |
| L2 manifest schema addition | HIGH | Accept a — version bump on manifest schema (schema_version: 2) | Extend `ManifestEntry` type + `manifestTemplate`; reader tolerates both; 1 Tier 0 test |
| L3 sync tolerance | LOW | Accept a — Tier 0 test asserts sync ignores user-scope edits | 1 Tier 0 test |
| H1 banner shape lock-in | HIGH | Accept b — add `--json` flag emitting stable structured output; keep prose banner | Extends init argv + new output branch; 2 Tier 0 tests |
| H2 CopyResult additive field | MEDIUM | Accept a — `scope` optional in type | Type change only; existing tests unaffected |
| H3 exit codes reused | MEDIUM | Accept a — reuse existing codes; document in CHANGELOG | No engineering; CHANGELOG line |
| H4 WriteError semantics | LOW | Silent-accept | None |
| B1 interface signature | HIGH | Accept b — keep current signature; document ScopeRouter as the resolver | Documentation-only in spec; NO code change |
| B2 unified failure lexicon | MEDIUM | Accept b — document the CopyFailure vs WriteError split | Documentation-only in spec; NO code change |
| B3 class count | MEDIUM | Accept a — ship 5 Control classes as-is | None |
| N1 banner jargon | MEDIUM | Accept a — rewrite banner to Norman standard ("Installed 22 of 24 hooks. 2 failed — see errors above.") | Text edit in InitDispatcher + update Tier 0 tests |
| N2 symlink error message | MEDIUM | Accept a — include readlink target in error | 1 line in writeSafely error path + 1 test |
| N3 two-scope banner | MEDIUM | Accept a — two-line banner ("24 hooks armed (lite tier). 22 in <repo>, 2 in ~/") | Text extend in InitDispatcher + 1 test |
| N4 sudo bypass message | LOW | Silent-accept | None |
| P1 executable-bit constants | HIGH | Accept a — extract HOOK_EXECUTABLE_MODE + HOOK_EXECUTABLE_MASK to shared module | Small refactor; adds 1 shared module import in tests |
| P2 $HOME resolution | MEDIUM | Accept a — extract resolveHome() helper | New file `src/lib/resolve-home.ts` + tests |
| P3 CopyResult shape | MEDIUM | Accept a — change `copied` to `Array<{path, scope}>` | Breaking type change; internal only; 3 Tier 0 tests update |
| P4 UC ID traceability | LOW | Accept a — Tier 0 test name convention | Convention documented in Step 10 harness |

## Council recommendation

**Adopt all HIGH findings** (5 total: L1, L2, H1, B1, P1). Every HIGH fold has a specific engineering action with bounded scope. Rejecting any HIGH leaves an adopter-visible risk on ship day.

**Adopt MEDIUM findings selectively** based on time budget: L3, H2, N1, N2, N3, P2, P3 all add small increments to the Tier 0 harness. B2 + B3 + H3 are documentation-only. Total additional Tier 0 test count: ~12 tests beyond the spec's core acceptance set.

**Accept LOW findings silently.** H4, N4, P4 are named for the record but need no engineering.

## Next step

Operator reviews this RFC. Step 9 (risk ledger v2) folds ACCEPTED findings into the ledger with explicit engineering owner + Tier 0 test count. Step 10 (RED harness) uses the folded ledger as its authoritative source.

## References

- Goal doc: `docs/iteration-bets/2026-09-13d-cli-1.0.1-hook-routing.md`
- Spec: `docs/specs/2026-09-13d-cli-1.0.1-hook-routing.md`
- Risk ledger v1: `docs/risk-ledgers/2026-09-13d-cli-1.0.1-hook-routing.md`
- Sister RFC (scope-b1): `docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md`
