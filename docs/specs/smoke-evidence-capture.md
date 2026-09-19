---
tier: project
title: Spec — cold-adopter smoke evidence capture
id: spec-smoke-evidence-capture
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture
status: draft
authoring_luminaries:
  primary: [michael-feathers, jerome-saltzer-and-michael-schroeder]
  supporting: [kent-beck, alistair-cockburn, donald-norman, john-ousterhout]
references:
  - path: docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md
    role: parent goal
  - path: docs/next-session-plan-2026-09-17-cli-pickup.md
    role: source plan
  - path: docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md
    role: existing manual plan the scripts fold into
---

# Spec — smoke evidence capture

## Sources read

- `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md` — full read; anchors scope, acceptance, and step list
- `docs/next-session-plan-2026-09-17-cli-pickup.md` L48-131 — Option e detail, four checks list, turn budget
- `docs/whereami.md` L41-49 + L60-77 — pickup pointer and cli#101-#108 findings
- `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` — full read; the manual plan Steps 5-7 fold into these scripts
- `.claude/rules/oo-ad-entry-point.md` — ceremony matrix
- `.claude/rules/artifact-ingestion.md` — Sources-read block discipline

## What I'm NOT reading (with reason)

- Fixture cure code for cli#101-#108 — out of scope; upstream work per bassclef-upstream#1728
- `scripts/smoke-reset.sh` internals beyond public flags — Step 7 authors the `--whole` extension; internals stay backward-compat

## Directive (per operator, 2026-09-18)

**Artifacts drive code.** This spec is not documentation of intent. It is
the source of truth that Step 1 onward reads before writing any script.
Every script must cite this spec plus UC-smoke-run plus the decomposition.

## What

A test system that runs on the cold-adopter Mac profile after a fresh
`bassclef init`, captures per-hook and per-skill output to files, asserts
four checks per surface, produces one markdown report, and posts that
report as a GitHub issue on `sunj-labs/bassclef-cli` with the `smoke-run`
label.

## Why

Today's cold-adopter smoke is manual. Steps 5-7 of the smoke plan are
eyeball work. On 2026-09-17 three tool blocks collapsed and nearly lost
cli#105 through #108. The next release ships with the same gap unless a
captured artifact survives.

## Actors

Two operator personas per RFC F2 (fold-in 2026-09-18):

| Actor | Role |
|---|---|
| **Operator-Release** | Runs the smoke on the cold profile before every release. Wants under 5 minutes end-to-end, pass/fail exit code, thumbs-up. Report body irrelevant beyond pass/fail. |
| **Operator-Diagnose** | A prior smoke was RED. Wants raw captures, per-check drill-down, ability to re-run one check via `--only <check-name>`. Reads the report body carefully. |
| Cold profile | Mac profile with fresh `~/.claude/` and no state from prior runs |
| GitHub as ferry | Public repo `sunj-labs/bassclef-cli` receives the run's report as an issue |
| Agent (me) | Reads the issue on demand and runs `/diagnose` on each RED row |

## Entities (V1 — Step 0c decompose refines)

| Entity | Role | Deliverable |
|---|---|---|
| SmokeCapture | Boundary — writes per-hook output to disk | one file per hook under `docs/smoke-captures/<date>/` |
| HookRunner | Control — fires wired SessionStart hooks | invokes the dispatcher against fresh init |
| SkillDriver | Boundary — fires skills via `claude -p` | one file per skill under `docs/smoke-captures/<date>/skills/` |
| AssertionSuite | Control — runs four checks per capture | pass/fail record per surface |
| Fixture | Entity — encodes a known defect from cli#101-#108 | test proof the check catches the real defect |
| ReportBuilder | Control — reads assertions, writes markdown summary | one file plus a union exit code |
| IssuePublisher | Boundary — posts to GitHub | issue on `sunj-labs/bassclef-cli` with `smoke-run` label |
| ResetHarness | Boundary — resets the whole environment | idempotent state cleanup |
| ScriptFetcher | Boundary — curls the ten smoke files from raw.githubusercontent.com; prints next-command block after fetch | files land under `$TARGET/scripts/` + `$TARGET/scripts/lib/` with the source-of-truth layout |

## Preconditions

- Cold profile has `gh` authenticated as `kingofrock` (verified per whereami L63)
- `@thebassclef/lite@<version>` installed globally via npm
- Test dir under `~/tmp/bassclef-smoke-test` exists and is `git init`-ed
- `bassclef init` has run in the test dir

## Postconditions

- Every wired SessionStart hook has one capture file with its stdout plus stderr
- Every driven skill has one capture file with its full response
- Every check has a pass/fail row in the report
- Every RED row links to its raw capture
- The report's exit code is 0 when all pass, non-zero when any fails
- When `--publish` is set, one issue exists on `sunj-labs/bassclef-cli` with a version-stamped label `smoke-run-<version>` (e.g. `smoke-run-1.2.0`) and the report body. Script auto-creates the label on first publish per release.
- **Report body shape is versioned** in the report frontmatter (`report_shape_version: 1`), not the label. Breaking body-shape changes bump the frontmatter version with a grace window per ADR-031. Agents parse the frontmatter to pick shape. (Prior design carried shape version in the label as `smoke-run-v1`; retired 2026-09-19 per PR #141 — label now groups by release version, not body-shape version.)
- **Publish is idempotent per version-and-date**: when an open `smoke-run-<version>` issue exists for the same `<version>` on the same `<date>`, `--publish` updates that issue's body instead of creating a new one. `--publish --new` forces a fresh issue.
- **Reset snapshots before it clears** (RFC F6 fold): `--whole` copies affected dirs to `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/` before clearing. `--restore <ISO-timestamp>` restores. Backups auto-expire after 7 days.

## Acceptance criteria (measurable)

1. `bash scripts/smoke-capture.sh` writes ≥1 capture file per wired hook found in `.claude/settings.json`
2. `bash scripts/smoke-assert-hooks.sh` returns exit 0 on a clean 1.1.1 baseline and exit ≥1 when any of the four checks fails
3. Each fixture for cli#101 through #108 causes exactly one assertion to fail; removing the defect makes the fixture pass
4. `bash scripts/smoke-drive-skills.sh` fires exactly five skills (`/temperance`, `/luminary don-norman`, `/kiss words <sample>`, `/state-a-problem brief <sample>`, `/whats-the-plan`) via `claude -p` and captures each response
5. `bash scripts/smoke-assert-skills.sh` runs the same four checks per skill capture
6. `bash scripts/smoke-report.sh` writes `docs/smoke-captures/<date>/report.md` with a pass/fail table; exits with the union code
7. `bash scripts/smoke-report.sh --publish --version-tag <ver>` posts the report as an issue on `sunj-labs/bassclef-cli` with the `smoke-run-<ver>` label (auto-created on first publish per release) and returns the issue number. When an open `smoke-run-<ver>` issue exists for the same version on the same date, `--publish` updates the existing body. `--publish --new` forces a fresh issue. `--publish` without `--version-tag` exits 1.
8. `bash scripts/smoke-reset.sh --whole` clears npm global cache plus `~/.claude/projects/<repo>/` plus `~/tmp/bassclef-smoke-test`; idempotent; `--dry-run` flag preserved. Before clearing, snapshots each target dir to `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/`. `--restore <ISO-timestamp>` restores from the snapshot. Backups auto-expire after 7 days.
9. `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md` Steps 5-7 name the new scripts
10. **Per-check re-run** (RFC F2 fold): `bash scripts/smoke-assert-hooks.sh --only <check-name>` runs a single check across all hook captures. Same flag on `smoke-assert-skills.sh`. Serves Operator-Diagnose after a RED smoke.

## Four checks (per surface)

Same four checks apply to per-hook capture (Step 2) and per-skill capture (Step 5):

| Check | Reads | Passes when |
|---|---|---|
| no-not-found | full capture | zero `not found` and zero `No such file or directory` lines |
| no-silent-skip | full capture | zero `skip —` lines (a fragment reporting doing nothing) |
| no-unexpected-blocked | full capture | zero `BLOCKED` blocks except those declared in a per-check allowlist |
| paths-exist | full capture | every filesystem path the surface names actually exists on disk |

## Interfaces (script contracts)

Each script must honor these preconditions and postconditions. Step 1 onward implements against this table.

### `scripts/smoke-capture.sh`

- **Precondition:** `bassclef init` has run in the test dir; hooks are wired
- **Reads:** `.claude/settings.json` to enumerate wired SessionStart hooks
- **Writes:** `docs/smoke-captures/<ISO-date>/hooks/<hook-basename>.out` per hook
- **Exit:** 0 on capture complete; non-zero when no hooks found

### `scripts/smoke-assert-hooks.sh`

- **Precondition:** capture dir exists with ≥1 hook file
- **Reads:** `docs/smoke-captures/<date>/hooks/*.out`
- **Writes:** `docs/smoke-captures/<date>/hooks-assertions.json` — one object per hook with four pass/fail rows
- **Exit:** 0 when all pass; non-zero when any fails

### `scripts/smoke-drive-skills.sh`

- **Precondition:** `claude` CLI on PATH; global lite install present
- **Reads:** hardcoded skill list (five skills named above)
- **Writes:** `docs/smoke-captures/<date>/skills/<skill-slug>.out` per skill call
- **Exit:** 0 on drive complete; non-zero when any skill call fails to return

### `scripts/smoke-assert-skills.sh`

- **Precondition:** skill capture dir exists
- **Reads:** `docs/smoke-captures/<date>/skills/*.out`
- **Writes:** `docs/smoke-captures/<date>/skills-assertions.json` — same four-check shape per skill
- **Exit:** 0 when all pass; non-zero when any fails

### `scripts/smoke-report.sh`

- **Precondition:** both assertion JSON files exist
- **Reads:** `hooks-assertions.json` plus `skills-assertions.json`
- **Writes:** `docs/smoke-captures/<date>/report.md` with pass/fail matrix
- **Optional:** `--publish` flag posts issue to `sunj-labs/bassclef-cli` with `smoke-run-<version>` label (derived from `--version-tag`; auto-created via `gh label create --force` on first run per release). Returns issue number to stdout. Same-day-same-version idempotent — updates the open issue body when one already exists. `--publish --new` forces a fresh issue. `--publish` without `--version-tag` exits 1.
- **Exit:** union of both assertion exit codes

### `scripts/smoke-assert-hooks.sh` and `smoke-assert-skills.sh` — `--only <check-name>` flag (RFC F2 fold)

Both scripts accept `--only <check-name>` where `<check-name>` is one of `no-not-found`, `no-silent-skip`, `no-unexpected-blocked`, `paths-exist`. Runs that single check across all captures. Serves Operator-Diagnose after a RED smoke.

### `scripts/smoke-bootstrap.sh` (post-merge addition — 2026-09-18)

- **Precondition:** `curl` on PATH
- **Reads:** hardcoded list of 10 smoke files from `raw.githubusercontent.com/sunj-labs/bassclef-cli/<ref>/scripts/...`
- **Writes:** each file into `$TARGET_DIR/scripts/...` or `$TARGET_DIR/scripts/lib/...` preserving layout so scripts source each other
- **Flags:** `--target DIR` (default `~/tmp/bassclef-smoke`), `--ref REF` (default `main`), `--dry-run`
- **Feedback:** on both dry-run and real fetch, prints a "next commands" block to stderr — reset (with destructive warning), version-fetch, and the runbook one-liner
- **Exit:** 0 all fetched; 1 usage error; 2 one or more curl failures

### `scripts/smoke-reset.sh --whole` (extension of existing script)

- **Precondition:** operator confirmation via existing `--cold` gate
- **Reads:** existing reset targets plus new whole-env targets
- **Writes:** cleared state at npm global cache plus `~/.claude/projects/<repo>/` plus `~/tmp/bassclef-smoke-test`
- **Flags preserved:** `--dry-run` (no side effects, prints plan)
- **Snapshot before clear:** copies each target dir to `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/`. Backups auto-expire after 7 days.
- **Restore flag:** `bash scripts/smoke-reset.sh --restore <ISO-timestamp>` restores from a snapshot dir.
- **Exit:** 0 on reset complete; non-zero on partial clear

## Out of scope

Named in the parent goal doc; not repeated here. Highlights:
- Building the mock app (Layer 2)
- Skills that read a target app (Layer 3)
- CI wiring for the smoke
- Fixing cli#101 through #108 (fixture pins only)

## Terminal feedback (post-merge addition — 2026-09-18)

Every smoke script prints a bookend banner to stderr — `>>> <name> starting` at the top, `<<< <name> done (exit N)` at the end. The end banner fires from `trap ... EXIT` so it prints on any exit path including errors.

When the runbook one-liner chains six scripts, the operator sees clear boundaries between steps. No more interleaved output where you cannot tell which step is running.

Norman signifier: the boundary IS the feedback. Cooper flow: operator sees each step start plus end, so a slow step never looks hung.

## Success metrics

- **Time to signal**: from cold reset to report issue posted — target under 5 min
- **Coverage growth**: Layer 1 covers ≥24 wired hooks plus 5 skills; Layers 2+3 extend the skill list
- **False-positive rate**: fewer than 1 per 10 runs on a clean baseline
- **Fixture proof**: 8 of 8 pinned defects fail correctly; 0 of 8 pass with defect absent

## References

- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Source plan: `docs/next-session-plan-2026-09-17-cli-pickup.md`
- Existing plan to fold into: `docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md`
- Existing sibling scripts: `scripts/smoke-reset.sh`, `scripts/smoke-preflight.sh`
- Fixture pins: cli#101 through #108
- Coordination ticket: bassclef-upstream#1728
