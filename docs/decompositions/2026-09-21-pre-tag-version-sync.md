---
tier: lite
slug: 2026-09-21-pre-tag-version-sync
date: 2026-09-21
scope: Epic #194 Stories 1-3
method: objectory-decompose + GRASP
references:
  - docs/specs/2026-09-21-pre-tag-version-sync.md
  - docs/use-cases/UC-version-sync-guardrails.md
  - docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md
authoring_luminaries:
  primary: michael-nygard
  supporting: [kent-beck, saltzer-schroeder, john-ousterhout]
---

# Decomposition — pre-tag version-sync guardrails

## Sources read

- `docs/specs/2026-09-21-pre-tag-version-sync.md` — full acceptance list + design notes
- `docs/use-cases/UC-version-sync-guardrails.md` — 4 scenarios (happy path + 3 alternatives)
- `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md` — top-5 risks + folded mitigations
- `tests/version-sync.test.ts` L14-32 — existing structure (regex + describe/it shape)
- `scripts/bump-version.mjs` L1-80 — existing entry point (`npm run bump`)
- `.github/workflows/publish.yml` L34-45 — trigger surface (`release: published` only)
- `.claude/rules/test-sufficiency.md` — 12-criterion rubric for hook tests

## What I'm NOT reading (with reason)

- Full CHANGELOG history — only the top heading + Unreleased shape matter for the extension
- Existing husky patterns in other repos — no husky adoption planned this session

Two-part decomposition. `/objectory-decompose` names entities, actors, verb-goal pairs, and BCE classification. `/decompose` assigns GRASP roles + identifies interfaces + selects patterns.

---

## Part 1 — Objectory decomposition

### Domain nouns (entities)

- **VersionMarker.** A string of shape `X.Y.Z` written into one of four files.
- **VersionSource.** One of the four files: `package.json`, `src/index.ts`, `README.md`, `CHANGELOG.md`.
- **VersionSet.** The tuple of four VersionMarker values read from the four VersionSources at a point in time. Agrees or disagrees.
- **BumpEvent.** The operator action that changes a VersionSet. Two kinds: script-driven (`npm run bump`) or hand-edit.
- **CommitBoundary.** The `git commit` event where staged files land in history.
- **PRBoundary.** The `pull_request` event where changes reach the shared branch.
- **TagBoundary.** The `git tag` event where a version reaches the release surface.
- **DriftFinding.** A structured result: which VersionSources disagree, what values each carries.

### Verb-subjects (actors)

- **Maintainer** — a person with commit rights.
- **BumpScript** — `scripts/bump-version.mjs`, existing.
- **PreCommitHook** — new, fires at CommitBoundary.
- **PRCIWorkflow** — new, fires at PRBoundary.
- **PublishWorkflow** — existing, fires at TagBoundary via `release: published`.

### Verb-goal pairs (use case candidates)

Each pair reads as "Actor does Verb to reach Goal."

| # | Actor | Verb | Goal |
|---|---|---|---|
| VG-1 | Maintainer | bump version | new VersionSet agrees |
| VG-2 | Maintainer | commit change | drift blocked locally |
| VG-3 | Maintainer | open PR | drift blocked at merge gate |
| VG-4 | PreCommitHook | read + compare VersionSet | emit DriftFinding OR pass |
| VG-5 | PRCIWorkflow | run version-sync test | emit DriftFinding OR pass |
| VG-6 | BumpScript | write four VersionSources | leave VersionSet in agreement |

VG-1 through VG-3 are Maintainer goals. VG-4 through VG-6 are system responsibilities that support them.

### BCE classification (Jacobson)

| Class | Members |
|---|---|
| **Boundary** | PreCommitHook (git → agent), PRCIWorkflow (GitHub → runner), CLI messages emitted on drift |
| **Control** | The version-sync assertion function — reads four VersionSources, computes DriftFinding |
| **Entity** | VersionMarker, VersionSource, VersionSet, DriftFinding |

The Control class is the single point where the check runs. Boundary classes fire it. Entity classes hold the data.

---

## Part 2 — GRASP + interfaces + patterns

### GRASP role assignments

| Responsibility | Where it lives | GRASP principle |
|---|---|---|
| Read a VersionSource's marker | Per-source reader function inside `tests/version-sync.test.ts` (or extracted to `src/lib/version-markers.ts` if the test bloats) | **Information Expert** — the file itself is the source of truth |
| Compute DriftFinding across a VersionSet | `checkVersionSet(sources: VersionSource[]): DriftFinding` — pure function, no I/O | **Pure Fabrication** — no domain entity naturally owns cross-file agreement |
| Emit the failure message on drift | The shell hook AND the vitest test both call the same message formatter | **Low Coupling** — one message string, two consumers |
| Fire the check on CommitBoundary | `scripts/git-hooks/pre-commit-version-sync.sh` | **Controller** at the git boundary |
| Fire the check on PRBoundary | `.github/workflows/pr-checks.yml` | **Controller** at the GitHub boundary |
| Install the local hook | `scripts/install-git-hooks.mjs` | **Creator** — owns the `.git/hooks/pre-commit` file |

### Interfaces identified

**Interface 1 — `readVersionSet(repoRoot): VersionSet`.**

```typescript
type VersionSource = 'package.json' | 'src/index.ts' | 'README.md' | 'CHANGELOG.md';
type VersionSet = Record<VersionSource, string>;

class VersionMarkerNotFound extends Error {
  constructor(public readonly source: VersionSource, message: string) { super(message); }
}

// Throws VersionMarkerNotFound when any source's marker cannot be read.
function readVersionSet(repoRoot: string): VersionSet;
```

Reads each source. Applies the per-source regex or JSON parse. Returns the tuple.

**Error contract (RFC F1 · Hoare).** `readVersionSet` throws a typed error when any of the four markers is absent. Callers do NOT see `null`, empty string, or `undefined`. The error's `source` field names the failing file. This closes the silent-failure class where a marker deletion goes unnoticed until release.

**Interface 2 — `checkVersionSet(set: VersionSet): DriftFinding`.**

```typescript
type DriftFinding =
  | { drift: false }
  | { drift: true; disagreements: Array<{ source: VersionSource; value: string }> };
function checkVersionSet(set: VersionSet): DriftFinding;
```

Pure function. Takes the tuple. Returns a discriminated union.

**Interface 3 — `formatDriftMessage(finding: DriftFinding): string`.**

Formats the message the hook + CI emit. Single source of truth for the operator-facing string.

**Interface 4 — Shell wrapper for the pre-commit hook.**

```bash
# scripts/git-hooks/pre-commit-version-sync.sh
# 1. Check `jq` is present. Exit 2 with remediation if not.
# 2. Check if any of the four files is staged. Skip if none.
# 3. Run `node scripts/check-version-set.mjs` (thin wrapper over interface 2).
# 4. Exit 2 with the formatted message on drift. Exit 0 otherwise.
```

**Interface 5 — Installer.**

```javascript
// scripts/install-git-hooks.mjs
// Reads .git/hooks/pre-commit. Appends the version-sync line if not present.
// Idempotent. Preserves prior content.
```

### Cross-cutting concerns

| Concern | Handling |
|---|---|
| `jq` missing on the machine | Shell hook checks first. Uses `node -e` fallback (Node is always present in this repo). Per pre-mortem R4. |
| `--no-verify` bypass | Accept it. PR-CI is the safety net. Per pre-mortem R5. |
| GUI client that skips `.git/hooks/pre-commit` | Same — PR-CI is the safety net. Per pre-mortem Nygard R1. |
| Legitimate `npm run bump` intermediate state | Never observed. The commit fires after the script writes all four. Bump script is atomic from the hook's perspective. |

### Patterns applied

- **@pattern patterns/code/gof/strategy.md** — the per-source reader (`readVersionSet`) uses a strategy per file type. `package.json` reads via `JSON.parse`. Others use regex. Same interface.
- **@pattern patterns/code/gof/template-method.md** — the shell hook + the vitest test both follow the same three-step template: read the set, check it, format on drift.
- **@pattern patterns/code/fowler/pure-function.md** — `checkVersionSet` is pure. Trivially unit-testable.

The Strategy + Template Method combination puts the boundary variance (shell vs vitest) at the outer layer and keeps the Control class pure.

### File map

| New / extended | Path | Owner interface |
|---|---|---|
| Extended | `tests/version-sync.test.ts` | Interfaces 1-3 (may extract to a lib if the test bloats past 100 lines) |
| Optional new | `src/lib/version-markers.ts` | Interfaces 1-3 if extracted |
| New | `scripts/check-version-set.mjs` | Thin Node CLI wrapper — Interface 2 + 3 for the shell hook |
| New | `scripts/git-hooks/pre-commit-version-sync.sh` | Interface 4 |
| New | `scripts/install-git-hooks.mjs` | Interface 5 |
| New | `.github/workflows/pr-checks.yml` | PR-CI Controller |
| New | `CONTRIBUTING.md` | Operator prose — points at `npm run bump` |
| Extended | `package.json` scripts | Add `install-hooks` script that calls the installer |

### Test coverage per Tier 0

Per `.claude/rules/test-sufficiency.md` criterion set. New scripts land under Tier 0 per `.claude/rules/testing-tier-config.md` substrate-path table (`scripts/*.sh` is Tier 1; adopter-facing scripts + the shell hook fall under `scripts/*.sh` Tier 1 test-with discipline).

Tests to write:

1. `tests/version-set-check.test.ts` — pure function. All 4 files agree → drift=false. Each single-file disagreement → drift=true with correct value. Four not-found cases per RFC F1 — each throws `VersionMarkerNotFound` with the correct `source` field: missing `.version` key in `package.json`, `src/index.ts` regex miss, `README.md` marker gone, `CHANGELOG.md` no non-Unreleased heading.
2. `tests/git-hook-install.test.ts` — installer is idempotent. Preserves prior content. Correct executable bit.
3. `tests/version-sync.test.ts` — extend existing. Cover README + CHANGELOG readers. Characterization fixture pins the v1.5.0 shape from commit `12d7153`.

Shell hook test coverage lives in the same vitest suite via a spawn-based test — runs the actual `.sh` file against a fixture repo.

---

## Sequencing

Beck TDD RED → GREEN, one step per WU:

1. Extend `tests/version-sync.test.ts` to cover README + CHANGELOG (RED first — fixture pins the v1.5.0 shape from commit `12d7153`).
2. Extract `readVersionSet` + `checkVersionSet` + `formatDriftMessage` — either in `tests/` or `src/lib/version-markers.ts` if the test bloats.
3. Ship `scripts/check-version-set.mjs` (Node CLI wrapper).
4. Ship `scripts/git-hooks/pre-commit-version-sync.sh` (shell hook).
5. Ship `scripts/install-git-hooks.mjs` (installer) + `npm run install-hooks` npm script.
6. Ship `.github/workflows/pr-checks.yml` (PR-CI workflow).
7. Ship `CONTRIBUTING.md` with the version-bump section.
8. Verify: run `npm run bump patch --allow-dirty --date 2026-09-22` as a dry test bump; confirm hook + PR-CI both pass; revert the bump.

## Refs

- Spec: `docs/specs/2026-09-21-pre-tag-version-sync.md`
- Use case: `docs/use-cases/UC-version-sync-guardrails.md`
- Risk ledger: `docs/risk-ledgers/2026-09-21-pre-tag-version-sync.md`
- @luminary michael-nygard — fail loud earlier (lead lens)
- @luminary kent-beck — TDD rhythm
- @luminary saltzer-schroeder — complete mediation across all four files
- @luminary john-ousterhout — deep modules (single Control class serves shell + vitest)
- Jacobson, I. (1992). *Object-Oriented Software Engineering* — BCE method.
- Larman, C. (2004). *Applying UML and Patterns* — GRASP roles.
