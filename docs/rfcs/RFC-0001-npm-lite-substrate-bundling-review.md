---
rfc: 0001
title: Council review — npm-lite substrate bundling (Steps 4-6 pre-code)
authored: 2026-08-29
authored_by: agent
status: under-review
review_type: /architect-review + fresh /pre-mortem
reviews: goal 2026-08-28d Steps 4-6 (tests + Phase 1 source + Phase 2 source)
authoring_set: [john-ousterhout, david-parnas, michael-nygard, michael-feathers, kent-beck, alan-cooper]
council: [linus-torvalds, hyrum-wright, frederick-brooks, saltzer-schroeder, don-norman]
council_rationale: 5 luminaries deliberately outside the authoring set. Pick catches design misses the authoring lenses cannot see.
rfc_template_source: https://medium.com/juans-and-zeroes/a-thorough-team-guide-to-rfcs-8aa14f8e757c (operator reference)
---

# RFC-0001 — Council review of npm-lite substrate bundling (Steps 4-6 pre-code)

## Status

`under-review` — waiting on operator disposition of council findings before Step 4 test writing resumes.

## Summary

Goal 2026-08-28d ships `@thebassclef/core@0.1.0` — bundles 146 substrate files inside the npm package and teaches `bassclef init` + `bassclef sync` to place and refresh them. Design landed across 3 docs (UC + decomp + ADR-007) authored by 6 luminaries. Step 4 preflight caught 2 misses (existing `write-safely.ts` + `manifest-io.ts` mislabeled as "new"). Operator asked for a fresh /pre-mortem with a council of luminaries outside the authoring set to catch the next class of miss BEFORE tests + source land.

This RFC is that review. 5 luminaries. Structured critique per luminary. Consolidated findings + proposed scope adjustments at the end.

## Motivation

Two forces made this review necessary:

**1. Preflight surfaced an authoring miss.** Step 2 decomp planned module names without running `ls src/lib/`. Design was confident; state check was skipped. The authoring set (Ousterhout deep modules + Parnas information hiding) drove design forward but did not include a "check what already ships" lens. A different set of eyes catches this class.

**2. Council reviews before commit are asymmetric wins.** Catching a design gap now costs ~40 turns of RFC + scope adjustment. Catching the same gap at Step 7 signoff costs ~150 turns of test rewrite + source rewrite + PR back-and-forth. The RFC template from juans-and-zeroes formalizes the review as a first-class artifact rather than ad-hoc "second pair of eyes".

## Design under review

Full artifacts:
- Goal doc — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md`
- Use case — `docs/use-cases/UC-npm-lite-substrate-bundling.md`
- Decomposition — `docs/decompositions/2026-08-28-npm-lite-bundling.md`
- ADR-007 — `docs/adrs/ADR-007-npm-lite-substrate-bundling.md`
- Risk ledger v2 — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md`

Design summary — what Steps 4-6 will ship:
1. `substrate/` directory inside npm package, populated at prepublish
2. `bassclef init` extended to copy 146 files after config files land
3. `bassclef sync` extended with legacy detection + Path A migration
4. Version bump to 0.1.0 minor
5. Strategy pattern for manifest source (sibling default + `BASSCLEF_MANIFEST_URL` env override)
6. 29 Tier 0 tests carrying `// @risk: R#` comments; commits carrying `[risk: R#]` trailers; Step 7 signoff runs grep audit

---

## Council critiques

### 1. Linus Torvalds — adopter contract (we don't break adopters)

**What Linus sees the design doing well:**

- Version bump to 0.1.0 minor is the right semver call. New capability; no breaking API change.
- Path A migration in `bassclef sync` preserves existing 3 config file hashes. Existing adopter state stays intact.
- ADR-007 D5 documents the upgrade path at `docs/migrations/0.1.0.md`.

**What Linus flags:**

**L1 (HIGH severity) — What about adopters on 0.0.1?** Whereami L96 says `@thebassclef/core@0.0.1` shipped as a name reservation on 2026-07-12. The package IS on npm. If any adopter installed 0.0.1 (unlikely but possible — anyone browsing npm could have run `npm install -g @thebassclef/core` before 0.0.2 shipped), running `bassclef sync` at 0.1.0 finds no manifest at all. Path A migration path only handles the 3-entry legacy case. What happens with no-manifest?

Cure: extend `detectLegacyManifest()` to return three cases (`current` / `legacy-3-entry` / `no-manifest`) and handle `no-manifest` as "run init instead of sync". OR at minimum, document + test the case.

**L2 (MEDIUM severity) — CLI verb shape drift.** Existing `bassclef sync` output shape (per UC-sync) reports one summary line per file. Extended sync at 149 files means adopter sees 149 output lines by default. Sam bounces. UC-npm-lite-substrate-bundling § Boundary objects L46 says "per-directory summary" but doesn't spec what happens to per-file verbose output. Any adopter who scripted against `bassclef sync` output format breaks silently.

Cure: pin the output shape in ADR-007 D5. Default: per-directory summary + total. `--verbose`: per-file. This mirrors ADR-002 D8 (init output shape).

**L3 (LOW severity) — Version constraint on `@thebassclef/core` peer deps.** Not applicable now (no peer deps) but ADR-007 sets a precedent that "0.1.0 is a minor bump". If a future adopter takes a peer dep on `@thebassclef/core`, they need to know the semver contract. ADR-007 D6 is clear on this internally; adopter changelog should state it externally.

Cure: land 0.1.0 CHANGELOG entry that names the "adopter migration ships as MINOR" contract explicitly.

**Linus verdict:** L1 is a required scope add before Steps 4-6. L2 is a required ADR amendment. L3 is a documentation add.

---

### 2. Hyrum Wright — observable behavior contracts (Hyrum's Law)

**What Hyrum sees the design doing well:**

- Extended manifest schema is a proper interface per Parnas (R4).
- 149-entry init manifest carries hashes for every file — enables `bassclef sync` to detect adopter edits + user-visible drift.
- Path constants module (R6) means adopters who script against `.claude/hooks/` paths keep working.

**What Hyrum flags:**

**H1 (HIGH severity) — Init manifest schema is now an observable adopter API.** As of 0.0.2, `.bassclef/init.manifest.json` on disk has a specific shape (per `src/lib/manifest-types.ts`). Adopters have not been promised this shape is stable. But with 0.1.0 shipping a schema extension AND a migration path that rewrites the file, we implicitly promise the extended shape is stable going forward. Any adopter reading their own init manifest (tooling, scripts, backup tools) will bind to whichever shape they see.

Cure: pin the init manifest schema version + shape in ADR-007 as a semver-locked invariant. Add a "schema evolution" section describing how to add fields without breaking older readers (add-only, never remove).

**H2 (MEDIUM severity) — File count 146 becomes observable.** Every count-related assertion (test at Step 4 saying "146 files added", ADR-007 saying "146 files", ledger row R7 saying "146 source files") locks the count. Any adopter who scripts `bassclef sync | grep '146'` binds to that number. When bassclef-upstream's lite-manifest grows to 147 files (inevitable), everything downstream that assumed 146 breaks.

Cure: parameterize the count everywhere. Tests should assert "count matches manifest.entries.length", not "count = 146". ADR-007 D3 postflight check says "count = manifest.entries.length" — good. But decomp § Test list line 306 says "146 files" as a literal. Fix.

**H3 (MEDIUM severity) — Bundle path convention `substrate/<path>` becomes observable.** Bundle layout matches source tree — good for Parnas but observable. Any adopter who scripts `find $(npm root -g)/@thebassclef/core/substrate/` will bind to that path. Rearranging the bundle layout in a future version breaks them.

Cure: document `substrate/<path>` as semver-locked in ADR-007 D1. Additive changes OK; rearrangements are MAJOR.

**Hyrum verdict:** H1 blocks Step 3.5 v3 amendment before Step 4. H2 is a test-authoring correction at Step 4. H3 is an ADR-007 addition.

---

### 3. Frederick Brooks — conceptual integrity + second-system effect

**What Brooks sees the design doing well:**

- Conceptual integrity — the CLI shape stays 2 commands (`init` + `sync`). Sam's mental model doesn't grow.
- Deep modules per Ousterhout preserve the invariant that adopters see one thing, we own the depth.
- Risk ledger + build wiring pattern (R#) is a coherent shape reused across every ship.

**What Brooks flags:**

**B1 (HIGH severity) — Second-system effect on `bassclef sync`.** Sync at 0.0.2 handles 3 files with a simple classifier. Sync at 0.1.0 handles 149 files with a classifier + migration path + hash preservation + legacy detection + per-directory reporting. This is the classic "add every feature you dreamed of on the first version" trap. The migration path is essential; per-directory reporting is essential. But `detectLegacyManifest` + `computeConfigHashes` + rewriting the manifest to 149-entry shape all in one PR is one of Brooks's canonical failure modes.

Cure: split. Ship "sync walks 149-entry manifest" this PR. Ship "sync handles legacy migration" as a follow-on 0.1.1 patch OR make Path A a `bassclef migrate` subcommand instead of overloading sync. Rationale: adopters on 0.0.2 who see 0.1.0 shipped have a clear choice — `bassclef init --force` OR wait for migration path. Overloading sync with migration hides that choice.

**B2 (MEDIUM severity) — Test count 27 → 29 is small but the pattern is second-system.** Every risk gets a test. Every test gets a `// @risk:` comment. Every commit gets a `[risk:]` trailer. Every ledger row must round-trip through the grep audit at Step 7. This is a LOT of ceremony for 10 risks. Ceremony is fine when it's proven; this one is Brooks-shaped (first-time invention).

Cure: dogfood the pattern this goal AS AN EXPERIMENT. Do not codify the round-trip audit as a bassclef-wide requirement until 2-3 more goals prove it out. Update the /promote ticket (bassclef-upstream#1420) to name this as "pattern candidate — needs 3 dogfoods before promotion".

**B3 (LOW severity) — Strategy pattern for manifest source is elegant but might be premature.** Two strategies (sibling + remote). Both used today? Sibling always used. Remote never used yet. Second-system: build the Strategy before the second concrete strategy is needed.

Cure: ship sibling-only for 0.1.0. Add remote as a follow-on when CI actually needs it. Reduces surface + defers a 2-test file spec until it's real.

**Brooks verdict:** B1 is a scope trim recommendation — ships 0.1.0 lighter. B2 is a discipline calibration — don't over-promote. B3 is a YAGNI check.

---

### 4. Saltzer & Schroeder — complete mediation (review mode, not authoring)

**What S&S see the design doing well:**

- Every write goes through `writeSafely()` per ADR-002 (D4 preserves envelope end-to-end).
- Bundle hash verification before write (R7 fallback) means bit-rot corruption caught at copy time.
- Prepublish fail-fast per D3 (3 checks) is textbook bulkhead + fail-fast.

**What S&S flag:**

**S1 (HIGH severity) — Remote fetch Strategy has no signature or integrity verification.** ADR-007 D2 opens `BASSCLEF_MANIFEST_URL` for CI use. Remote content from `raw.githubusercontent.com` OR anywhere the env points can inject an arbitrary manifest. Prepublish then bundles the files that manifest points to. In a compromised CI (attacker plants env var), attacker controls what ships in the tarball.

Cure: add manifest signature verification when using RemoteFetchStrategy. Options: (a) require SHA-256 of manifest to be pinned in an env var alongside URL (`BASSCLEF_MANIFEST_URL_SHA256=abc123`), (b) require GPG-signed manifest, (c) simplest — only allow remote URLs pointing at bassclef-upstream repo tags (validate URL matches `raw.githubusercontent.com/sunj-labs/bassclef-upstream/refs/tags/v*/lite-manifest.json`). Pick (c) — narrowest attack surface.

**S2 (MEDIUM severity) — `require.resolve('@thebassclef/core/package.json')` inside `copySubstrate` runs code from the installed package.** If an attacker managed to poison the installed package (via compromised npm registry, MITM), `require.resolve` executes package.json exports resolution — could be leveraged. Small; not likely; but complete-mediation says check.

Cure: use `import.meta.url` + relative path resolution instead. Avoids the resolution algorithm entirely. More brittle to package layout changes; but package layout is our contract per ADR-007 D1.

**S3 (LOW severity) — R7 fallback (hash verification before write) doesn't specify what "abort that file" means for the rest of the copy.** UC extension 9a says "Sam gets partial init; manifest reflects what landed successfully." But what if only 1 of 146 files fails hash? Continue copying the other 145, or halt entire copy? Currently ambiguous.

Cure: pin in ADR-007 D4. Recommend: continue on per-file hash mismatch; report `errored` count at end; adopter can rerun `bassclef init --force` to retry. Same pattern as UC-init 7b/7c.

**S&S verdict:** S1 is a required security add before Step 4 test spec. S2 is a design refinement in decomp § Control objects. S3 is an ADR clarification.

---

### 5. Don Norman — user mental model vs system model

**What Norman sees the design doing well:**

- 2 commands. Sam runs `npm install -g @thebassclef/core && bassclef init`. Mental model matches system model.
- Per-directory summary at end of init (Cooper — not dancing bear) — matches Sam's need to see the shape without every file.
- `--dry-run` support for both init AND the new copy step — trust signal.
- Migration doc at `docs/migrations/0.1.0.md` — explicit path for upgrade.

**What Norman flags:**

**N1 (HIGH severity) — Sam's mental model of "init" changed. She doesn't know.** At 0.0.2, `bassclef init` writes 3 files. Fast. Sam expects it to stay fast. At 0.1.0, `bassclef init` writes 149 files. Slower. Sam runs it, waits, wonders if it hung. No progress indicator; no mid-stream signal that "copying substrate: 47 of 146".

Cure: add progress output during copy. Options: (a) per-directory line as each directory completes ("hooks: 25 files ✓"), (b) dots (`....`) as each file lands, (c) percent progress. Pick (a) — matches Cooper's "not dancing bear" — one line per meaningful unit.

**N2 (HIGH severity) — Error messages during copy have no mapping to Sam's mental model.** Ledger R7 fallback (hash mismatch) triggers `errored` state for that file. Error message today (per S&S S3): specific hash mismatch. Sam sees "SHA256 mismatch for .claude/hooks/foo.sh" — she doesn't know what to do. Restart? Reinstall the package? File a bug?

Cure: error messages name the FIX, not the CAUSE. Bad: "SHA256 mismatch". Good: "Bundle corruption detected. Rerun `npm install -g @thebassclef/core --force && bassclef init --force` to fix." Per ADR-002 D8 (init messages already do this).

**N3 (MEDIUM severity) — `bassclef sync` after Path A migration reports a summary Sam won't parse.** ADR-007 D5 says report `146 files added; 3 files preserved with computed hashes; <N> refused (already present)`. "Preserved with computed hashes" is system-model language. Sam doesn't know or care what "computed hashes" means.

Cure: rewrite as "146 new files added. Your 3 existing files unchanged. <N> files skipped (already present — pass --force to update)." Same information; adopter's model.

**N4 (LOW severity) — `substrate/` folder inside `.claude/` after init — is that folder visible in Sam's tree browser as a giant blob?** After init at 0.1.0, Sam's file tree grows by ~146 files. `.claude/hooks/`, `.claude/skills/`, etc. All under `.claude/` which is hidden on Unix but visible in most editors. Sam opens VS Code; sees 146 new files; wonders if she should git-commit them.

Cure: `bassclef init` prints one line at the end: "Your project now has bassclef installed. The `.claude/` directory holds the substrate — commit it or gitignore it per your project's convention. See docs/migrations/0.1.0.md for guidance."

**Norman verdict:** N1 + N2 are required UX adds before Step 6 (progress + error messages). N3 is a Step 6 output-string edit. N4 is a Step 6 init.ts output addition.

---

## Consolidated findings by severity

### HIGH (must resolve before Step 4 tests land)

| ID | Finding | Cure | Where |
|---|---|---|---|
| **L1** | 0.0.1 adopters have no manifest; Path A doesn't handle no-manifest case | Extend `detectLegacyManifest` to 3-way; handle no-manifest as init dispatch | ADR-007 D5 amendment + Step 4 test + Step 6 code |
| **L2** | Sync output shape drift on 149 files breaks scripts binding to 0.0.2 shape | Pin output shape in ADR-007 D5 (per-directory default; `--verbose` for per-file) | ADR-007 D5 amendment + Step 6 code |
| **H1** | Init manifest schema is an observable adopter API — needs semver lock + evolution rule | Add "manifest schema evolution" section to ADR-007 | ADR-007 amendment |
| **B1** | Second-system trap on `bassclef sync` — 5 concerns in one PR | Split — ship 149-entry walk this PR; migration Path A as follow-on 0.1.1 OR `bassclef migrate` subcommand | Scope adjustment + ledger v3 |
| **S1** | Remote fetch Strategy has no integrity verification — CI attack surface | Restrict remote URLs to bassclef-upstream repo tags only | ADR-007 D2 amendment + Step 5 code |
| **N1** | Init at 149 files feels hung to Sam — no progress signal | Per-directory line as each completes | Step 6 code + UC amendment |
| **N2** | Copy error messages are system-model, not user-model | Error messages name the fix, not the cause | Step 6 code |

### MEDIUM (should resolve before Step 6 source)

| ID | Finding | Cure | Where |
|---|---|---|---|
| **H2** | Hard-coded "146" in tests + ADR + ledger binds adopters to the count | Parameterize — use `manifest.entries.length` everywhere | Test list correction + ADR-007 D3 refinement + ledger v3 |
| **H3** | Bundle layout `substrate/<path>` becomes observable — future rearrangement breaks adopters | Document as semver-locked in ADR-007 D1 | ADR-007 amendment |
| **B2** | Round-trip risk audit is ceremony-heavy for first-time pattern | Dogfood as experiment; don't promote to bassclef-wide until 2-3 dogfoods | Update /promote #1420 |
| **S2** | `require.resolve` inside `copySubstrate` runs package resolution code | Use `import.meta.url` + relative path | Decomp § Control objects + Step 6 |
| **N3** | Sync output "preserved with computed hashes" is system-model | "Your 3 existing files unchanged" — adopter language | Step 6 code |

### LOW (nice-to-have; can ship in 0.1.1)

| ID | Finding | Cure |
|---|---|---|
| **L3** | 0.1.0 CHANGELOG should name the MINOR-for-adopter-migration precedent | CHANGELOG entry |
| **B3** | RemoteFetchStrategy is premature — no second real user | Ship sibling-only for 0.1.0; add remote when CI needs it |
| **S3** | Per-file hash mismatch doesn't specify continue-vs-halt behavior | Pin in ADR-007 D4 (continue on mismatch; report errored count) |
| **N4** | Sam sees 146 new files; doesn't know to gitignore or commit | Init output line about `.claude/` |

## Proposed scope adjustment

The council surfaced 16 findings. Most are additive; 1 is a scope trim (B1 — split sync).

**Recommendation A — Absorb all HIGH findings before Step 4 resumes.**

Estimated cost: ~40-60 turns for ADR-007 amendment + decomp corrections + ledger v3 + scope re-plan. Steps 4-6 then proceed with the amended design.

Total revised time budget: 495 (original) + ~50 (this RFC) + ~50 (HIGH-finding cures) = ~600 turns. Above the 500-turn ceiling per plan doc L58. Would need re-confirmation.

**Recommendation B — Split the goal per B1.**

Ship goal 2026-08-28d as scope-b1 (Phase 1 + Phase 2 without migration path). Migration ships as sibling goal 2026-08-28e later (0.1.1 patch OR `bassclef migrate` subcommand). Absorbs L1 + H1 + B1 + S1 + N1 + N2 in scope-b1; L2 + others in scope-e.

Estimated cost per goal: ~350 turns for scope-b1; ~200 turns for scope-e. Both within budget.

**Recommendation C — Absorb HIGH only, defer MEDIUM + LOW to follow-on.**

Land HIGH cures (~40 turns of doc amendments), continue Steps 4-6 with amended design. MEDIUM + LOW ship as follow-on goals or as amendments during 0.1.x cycle.

Estimated cost: ~40 turns HIGH cures + Steps 4-8 as planned = ~470 turns total. Fits under ceiling.

## Operator decision points

1. **Which recommendation — A, B, or C?**
2. **For any HIGH finding you want to defer OR accept-as-is, name it explicitly.** Silence = absorb per recommendation picked.
3. **B1 (scope split) is the biggest structural change** — does the migration path stay in scope for goal 2026-08-28d, or move to a follow-on?
4. **B2 (dogfood the risk-audit pattern before promoting)** — should the /promote ticket bassclef-upstream#1420 add a "needs 3 dogfoods before promotion" note NOW?

## Council selection rationale

Deliberately outside the authoring set. Each luminary catches a class the authoring lenses cannot:

- **Ousterhout + Parnas + Nygard + Feathers + Beck + Cooper** (authoring) — design-forward, code-quality-forward
- **Linus** (council) — adopter compat; existing installs
- **Hyrum** (council) — observable behavior; scripts binding to output shape
- **Brooks** (council) — second-system effect; scope discipline
- **Saltzer-Schroeder** (council, review mode) — complete mediation on the NEW attack surface (remote fetch)
- **Norman** (council) — Sam's mental model when the install grows from 3 to 149 files

Not in the council but considered:
- Alexander (pattern language) — mostly covered by the authoring set's pattern annotations
- Tufte (data-ink) — UX-shape; covered by Norman
- Karpathy (context engineering) — meta-level; not scope-shaping for this specific goal

## References

- Reviewed artifacts (per § Design under review above)
- RFC template shape — juans-and-zeroes reference (operator-supplied)
- Luminaries: `.claude/luminaries/linus-torvalds.md`, `.claude/luminaries/hyrum-wright.md`, `.claude/luminaries/frederick-brooks.md`, `.claude/luminaries/saltzer-schroeder.md`, `.claude/luminaries/don-norman.md`
- Sister ticket — sunj-labs/bassclef-upstream#1420 (pre-mortem-to-compensator mapping — this RFC pattern is a candidate promotion too if it proves out)
