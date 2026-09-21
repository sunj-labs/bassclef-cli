---
tier: lite
slug: 2026-09-21-pre-tag-version-sync-council
date: 2026-09-21
scope: Epic #194 Stories 1-3 — pre-tag version-sync guardrails
authoring_set: [michael-nygard, kent-beck, saltzer-schroeder]
council: [tony-hoare, david-parnas, frederick-brooks, alan-cooper, donald-norman]
disposition: Revised A — accept scope, cure MEDIUM findings inline, defer 2 LOW findings
preflight_skip: architect-review deferred to post-code closeout Step 7.5; nothing to review pre-code
references:
  - docs/specs/2026-09-21-pre-tag-version-sync.md
  - docs/use-cases/UC-version-sync-guardrails.md
  - docs/decompositions/2026-09-21-pre-tag-version-sync.md
  - docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md
---

# RFC — outside-luminary council review

## Sources read

- `docs/specs/2026-09-21-pre-tag-version-sync.md` — full spec authored this session
- `docs/use-cases/UC-version-sync-guardrails.md` — 4 scenarios
- `docs/decompositions/2026-09-21-pre-tag-version-sync.md` — BCE + GRASP + interfaces + patterns
- `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md` — 3-lens pre-mortem, top-5 folded

## What I'm NOT reading (with reason)

- No `/architect-review` marker exists — pre-code review has nothing to review; deferred to closeout Step 7.5. Bypass reason lands in this RFC frontmatter (`preflight_skip:`).

---

## Council

| Luminary | Lens role in this review |
|---|---|
| Tony Hoare | Pre / postcondition contracts on `readVersionSet` + `checkVersionSet` |
| David Parnas | Information hiding — is a single source of truth possible for the version string? |
| Fred Brooks | Conceptual integrity — does the new PR-CI workflow preserve the release-cycle shape? |
| Alan Cooper | Operator experience — friction of `npm run install-hooks` for cold contributors |
| Donald Norman | Signifier + feedback loop — hook message clarity + install-status affordance |

None appear in the authoring set (Nygard + Beck + Saltzer-Schroeder).

---

## Findings

### F1 [MEDIUM · Hoare] — `readVersionSet` behavior undefined when a marker regex fails

**Artifact:** `docs/decompositions/2026-09-21-pre-tag-version-sync.md` § Interface 1.

The decomposition names `readVersionSet(repoRoot): VersionSet` but does not state what happens when a source's marker cannot be read. Four failure modes:

- `package.json` missing the `.version` key.
- `src/index.ts` regex `/export const version = '([^']+)' as const;/` fails to match (someone refactored the constant to `let` or moved it).
- `README.md` missing the `<!-- version-start -->` marker (someone edited the README and dropped the delimiter).
- `CHANGELOG.md` missing a version heading below `## [Unreleased]` (first-release edge case, or the format shifted).

Hoare's rule: every function carries a precondition (input assumptions) and a postcondition (output guarantee). Silent-fail on unmatched regex breaks the postcondition contract — the returned VersionSet either has a `null` entry, an empty string, or an exception depending on how the reader is written.

**Cure inline (Revised A):** Amend the spec + decomp. `readVersionSet` throws a typed error (`class VersionMarkerNotFound extends Error`) when any regex or JSON key is absent. Callers see a clear failure. Tests cover each of the 4 not-found cases.

### F2 [MEDIUM · Brooks] — PR-CI scope unstated

**Artifact:** `docs/specs/2026-09-21-pre-tag-version-sync.md` § Acceptance list.

The spec says the new `.github/workflows/pr-checks.yml` runs `npm test` + `npm run typecheck`. That is more than a version-sync check but less than the existing `publish.yml` `checks` job (12 steps including tag validation, dist/lite/ bundling, andon scan, tier filter).

Brooks's conceptual integrity: the release cycle has three trigger phases — PR, tag, publish. Each phase's check surface should match the phase's concern. Running the full publish.yml `checks` at PR time is redundant (tag doesn't exist yet). Running only version-sync misses other classes the Tier 0 suite catches.

**Cure inline (Revised A):** The spec's `npm test` + `npm run typecheck` is the right scope. Add a design note explicit:

> PR-CI runs the Tier 0 test suite + typecheck. It does NOT run tag validation, dist/lite bundling, andon scan, or tier filter — those are release-only concerns per ADR-004 §Two-job shape. The version-sync assertion rides inside `npm test`.

### F3 [LOW · Parnas] — 4-file redundancy could be reduced to 1 source

**Artifact:** `docs/decompositions/2026-09-21-pre-tag-version-sync.md` § Domain nouns (VersionSource).

Parnas would ask: why does the version string live in 4 files? A single source of truth (say, `package.json`) could feed the other 3 at build time:

- `src/index.ts` could `import { version } from '../package.json' with { type: 'json' }`.
- `README.md`'s marker could be rewritten by a build step.
- `CHANGELOG.md` version headings could be generated from git tags.

Trade-off: static-readable files serve consumers who don't run npm (GitHub browsers reading the README, humans skimming the CHANGELOG). Generating them adds a build step + risks CI-only truth.

**Disposition:** DEFER. The 4-file design is intentional per ADR-004 + `standards/npm-versioning-and-changelog.md`. The check IS the mediation layer. Follow-on ticket candidate: audit whether `src/index.ts` could import from `package.json` (removes 1 of 4 sources). File as bassclef-cli follow-on after this ships.

### F4 [LOW · Cooper] — `install-hooks` friction for cold contributors

**Artifact:** `docs/use-cases/UC-version-sync-guardrails.md` § Alternative — cold-adopter machine.

Cooper would flag: cold contributor clones repo, runs `npm install`, makes a change, commits — the hook never fired because they never ran `npm run install-hooks`. First feedback is a red PR-CI check ~5 minutes later.

Three cures possible:

- (a) `postinstall` script auto-installs the hook. Bad — surprises the adopter with a git hook.
- (b) `prepare` script (npm's dev-only lifecycle). Idiomatic (husky uses this).
- (c) Keep opt-in. Cover in CONTRIBUTING first-time-setup section.

**Cure inline (Revised A):** Path (c). Add a "First-time setup" section to `CONTRIBUTING.md` that names `npm run install-hooks` as the second step after `npm install`. Do NOT wire `postinstall` per Cooper "don't surprise the user."

### F5 [LOW · Norman] — no signifier when hook is uninstalled

**Artifact:** `docs/decompositions/2026-09-21-pre-tag-version-sync.md` § Interface 5 (installer).

Norman would flag: a developer without the hook installed has no in-terminal signal that they're missing local coverage. They discover it at PR time. A one-time note on first commit ("hook not installed; run `npm run install-hooks`") would close the gap.

Trade-off: adding a first-commit banner requires state (was this printed already?) and cross-cuts every commit — scope creep.

**Disposition:** DEFER. File as a follow-on ticket. CONTRIBUTING coverage per F4 is enough for now.

---

## Disposition — Revised A

Accept the scope. Cure MEDIUM findings inline. Defer 2 LOW findings to follow-on tickets.

**Inline cures (this session):**

- F1 (Hoare): amend spec + decomp with typed error contract for `readVersionSet`. Tests cover 4 not-found cases.
- F2 (Brooks): amend spec design notes with the PR-CI scope clarification.
- F4 (Cooper): CONTRIBUTING covers `npm run install-hooks` in first-time setup (already in acceptance list; this RFC confirms the shape).

**Deferrals (follow-on tickets to file at closeout):**

- F3 (Parnas): audit whether `src/index.ts` can import version from `package.json`. Would reduce 4 sources to 3.
- F5 (Norman): first-commit signifier when hook is uninstalled. Cross-cuts every commit; needs its own scope.

---

## Amendments to source artifacts

The following inline edits ship in the same PR as this RFC:

1. **`docs/specs/2026-09-21-pre-tag-version-sync.md`** — add a "PR-CI scope" design note per F2. Add a "readVersionSet error contract" design note per F1.
2. **`docs/decompositions/2026-09-21-pre-tag-version-sync.md`** — Interface 1 signature adds throws clause. Test coverage list adds 4 not-found cases.
3. **`docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md`** — add "RFC council absorbed:" note referencing this file.

---

## Refs

- Spec: `docs/specs/2026-09-21-pre-tag-version-sync.md`
- Use case: `docs/use-cases/UC-version-sync-guardrails.md`
- Decomposition: `docs/decompositions/2026-09-21-pre-tag-version-sync.md`
- Risk ledger: `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md`
- ADR-004 (publish pipeline safety contract) — invariants this cure honors
- `standards/npm-versioning-and-changelog.md` — the discipline this reinforces
- @luminary tony-hoare — precondition/postcondition contracts
- @luminary david-parnas — information hiding
- @luminary frederick-brooks — conceptual integrity
- @luminary alan-cooper — operator experience
- @luminary donald-norman — signifier + feedback loop
