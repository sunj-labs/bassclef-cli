---
tier: project
title: Decomposition — cold-adopter smoke evidence capture
id: decomp-smoke-evidence-capture
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture
status: draft
references:
  - path: docs/specs/smoke-evidence-capture.md
    role: spec
  - path: docs/use-cases/UC-smoke-run.md
    role: use case
---

# Decomposition — smoke evidence capture

## Sources read

- `docs/specs/smoke-evidence-capture.md` — full read; entity table and script interfaces
- `docs/use-cases/UC-smoke-run.md` — full read; main flow and extension branches drive control flow
- `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md` — full read
- `.claude/rules/pattern-annotation.md` — annotation format for pattern references

## What I'm NOT reading (with reason)

- Existing script internals (`smoke-reset.sh`, `smoke-preflight.sh`) — Step 7 extends `smoke-reset.sh` per its public flag contract; internals stay backward-compat

## Directive (per operator)

**Artifacts drive code.** Every class or module Step 1 onward creates MUST cite this decomposition. The GRASP role assignment plus pattern annotations tell the implementer what shape to write.

## Entity model

Seven entities plus two support types. Each entity's role, primary data, and collaborators named below.

| Entity | Primary data | Collaborates with |
|---|---|---|
| SmokeCapture | capture-dir path, per-hook filenames | HookRunner, filesystem |
| HookRunner | wired hook list from `.claude/settings.json`, dispatcher path | Claude Code dispatcher, SmokeCapture |
| SkillDriver | skill list (five names), per-skill filenames | `claude -p`, SmokeCapture |
| AssertionSuite | check list (4 checks), capture paths | Capture files, allowlist |
| Fixture | fixture-id (cli#101-#108), known-bad shape, expected fail | AssertionSuite, capture files |
| ReportBuilder | assertion JSON paths, report path | AssertionSuite, filesystem |
| IssuePublisher | report body, repo name, label | GitHub API via `gh`, ReportBuilder |
| ResetHarness | reset targets list, dry-run flag | filesystem, npm, `~/.claude/` |

Support types:

- **AssertionResult** — value object: `{check, hook_or_skill, status, message, capture_path}`
- **Allowlist** — value object per check type: list of shapes that should NOT fail

## GRASP role assignment

Per Larman GRASP patterns:

| GRASP role | Assigned to | Why |
|---|---|---|
| Information Expert (owns the data, does the work on it) | AssertionSuite runs checks on capture files | AssertionSuite is the only entity that reads capture bytes and knows the check semantics |
| Controller (coordinates a use case) | ReportBuilder | Reads both assertion JSONs, orchestrates report shape, hands off to IssuePublisher |
| Creator (creates instances) | SmokeCapture creates per-hook capture files; SkillDriver creates per-skill capture files | Each Boundary object writes its own artifacts |
| Low Coupling (minimize dependencies) | AssertionSuite reads capture files only; does not know how they were produced | Decouples capture from assertion; Fixture reuses the same suite |
| Polymorphism (variation by type) | AssertionSuite runs same four checks whether capture came from HookRunner or SkillDriver | One assertion shape, two sources |
| Pure Fabrication (invented type to lower coupling) | AssertionResult value object | Decouples check output from downstream consumers |
| Indirection (extra layer) | IssuePublisher shields ReportBuilder from `gh` CLI specifics | Swap publisher backend without touching the report builder |
| Protected Variations (interface hides variation) | ResetHarness `--whole` flag stable across future target additions | Add new reset targets without changing the caller contract |
| High Cohesion (each class one purpose) | Every entity does one job named in its role column | See table |

## Patterns applied

Per `.claude/rules/pattern-annotation.md`, each pattern gets a `@pattern` annotation in the source file that carries it.

| Pattern | Where | Why |
|---|---|---|
| **Command** (GoF) | Each script (`smoke-capture.sh`, `smoke-assert-hooks.sh`, `smoke-drive-skills.sh`, `smoke-assert-skills.sh`, `smoke-report.sh`) | CLI verbs with preconditions plus postconditions plus exit codes; operator invokes; script encapsulates one task |
| **Strategy** (GoF) | Four check functions inside AssertionSuite (no-not-found, no-silent-skip, no-unexpected-blocked, paths-exist) | Same signature `(capture_path, allowlist) → AssertionResult`; swap or add without touching the loop |
| **Template Method** (GoF) | AssertionSuite loop: fixed shape (enumerate captures → run each check → collect result) with per-check body varying | Loop shape same for hooks and skills; only the check bodies vary |
| **Composite** (GoF) | Report body composes per-surface tables from per-check rows | ReportBuilder aggregates AssertionResults into per-surface groups without knowing check specifics |
| **Adapter** (GoF) | IssuePublisher wraps `gh issue create` for the ReportBuilder | ReportBuilder posts issues via a plain method; `gh` specifics hidden |
| **Fixture Object** (Fowler xUnit) | Each cli#101-#108 fixture pins one defect shape | Test-double for the check; proves assertions catch real defects |
| **Fail-Fast** (Nygard) | `bassclef init` exits 4/5 per ADR-002; scripts exit non-zero on first hard failure | Failure is loud; report captures it as INIT-FAILED row |

## Cross-cutting concerns

Concerns that touch more than one entity. Each concern gets one owner to prevent scatter.

| Concern | Owner | Interface |
|---|---|---|
| Capture-file naming | SmokeCapture + SkillDriver | Both use `docs/smoke-captures/<ISO-date>/<subdir>/<slug>.out`. Extract to a shared `capture_path()` helper in `lib/smoke-paths.sh` if either script needs to reason about the other's paths. |
| Exit code propagation | ReportBuilder | Union of both assertion exit codes; surfaces to smoke-report caller |
| Dry-run mode | Every script that has side effects | `--dry-run` flag preserved; no writes to disk or network |
| GitHub API auth | IssuePublisher only | Scripts other than `smoke-report` never touch `gh`; auth failure isolated |
| Allowlist per check | AssertionSuite | Per-check allowlist file under `.claude/hooks/tests/fixtures/smoke-allowlist/<check>.txt`; empty when no exceptions |
| Timeout on skill drive | SkillDriver | 30 second `timeout` per `claude -p` call; kill returns TIMEOUT capture |
| Terminal feedback boundaries (post-merge 2026-09-18) | Every smoke script | `>>> <name> starting` at top + `<<< <name> done (exit N)` at exit via `trap ... EXIT`; makes chain boundaries visible when the one-liner runs |

## Sequence — main flow (per UC-smoke-run steps 7-16)

```
Operator                SmokeCapture   HookRunner    Filesystem   AssertionSuite   SkillDriver   ReportBuilder   IssuePublisher   GitHub
   |                          |             |             |             |               |               |               |             |
   |—bash smoke-capture.sh—→  |             |             |             |               |               |               |             |
   |                          |—enumerate—→ |             |             |               |               |               |             |
   |                          |             |—read .claude/settings.json→|              |               |               |             |
   |                          |             |—fire each hook (fresh session)—————→      |               |               |             |
   |                          |—write per-hook out file—→|              |               |               |               |             |
   |                          |             |             |             |               |               |               |             |
   |—bash smoke-assert-hooks.sh—→                        |—read captures—→              |               |               |             |
   |                          |             |             |             |—run 4 checks per hook—       |               |             |
   |                          |             |             |—write hooks-assertions.json—|               |               |             |
   |                          |             |             |             |               |               |               |             |
   |—bash smoke-drive-skills.sh—→                        |             |               |               |               |             |
   |                          |             |             |             |               |—claude -p per skill—         |             |
   |                          |             |             |—write per-skill out file—                   |               |             |
   |                          |             |             |             |               |               |               |             |
   |—bash smoke-assert-skills.sh—→                       |—read captures—→              |               |               |             |
   |                          |             |             |             |—run 4 checks per skill—      |               |             |
   |                          |             |             |—write skills-assertions.json—|              |               |             |
   |                          |             |             |             |               |               |               |             |
   |—bash smoke-report.sh --publish—→                    |—read both JSONs—→            |—compose report md—→          |             |
   |                          |             |             |—write report.md—|          |               |—post issue—→ |             |
   |                          |             |             |             |               |               |               |—POST /issues|→
   |                          |             |             |             |               |               |               |←issue #N—   |
   |←issue #N to stdout———————|             |             |             |               |               |               |             |
```

## Extension flows (per UC-smoke-run extensions)

Each extension branch in UC-smoke-run maps to one guarded code path. Implementation cites the branch by number.

| UC branch | Code path |
|---|---|
| 3a — npm install fails | Not owned here; operator diagnoses; report skips if bassclef init did not run |
| 5a — bassclef init exits 4/5 | ReportBuilder writes INIT-FAILED row from stderr capture; skips hook and skill sections |
| 7a — no wired hooks found | SmokeCapture exits with "no hooks wired"; ReportBuilder marks HOOKS-SECTION-SKIPPED; skill drive still fires |
| 9a — empty hook capture | AssertionSuite writes EMPTY-CAPTURE result; fail unless on empty-allowlist |
| 11a — claude -p non-zero | SkillDriver capture records exit; AssertionSuite writes NO-RETURN result (fail) |
| 11b — claude -p hangs | SkillDriver `timeout 30` kills; capture records TIMEOUT; AssertionSuite writes TIMEOUT result (fail) |
| 15a — publish gh auth fails | IssuePublisher exits non-zero; report on disk; operator publishes manually |
| 15b — publish returns odd status | IssuePublisher exits non-zero; report on disk |
| 18a — agent cannot access issue | Agent falls back to `docs/smoke-captures/<date>/report.md` via git pull |

## What NOT to build

Naming what would be tempting to add but violates scope:

- **Central smoke orchestrator script.** Each script stands alone; the operator invokes six commands in sequence. A wrapper adds coupling and hides failures. If a wrapper appears later, it lives in a follow-on goal.
- **Retry logic on skill drive.** One shot per skill; TIMEOUT is a real signal, not a transient to retry.
- **Rich report format.** Markdown table with links only. HTML or JSON pretty-print belongs in Layer 3 or later.
- **Slack notification.** Out of scope. GitHub is the ferry per pickup plan.

## References

- Spec: `docs/specs/smoke-evidence-capture.md`
- Use case: `docs/use-cases/UC-smoke-run.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Pattern rule: `.claude/rules/pattern-annotation.md`

## Jacobson BCE classification (Step 0d — /objectory-decompose)

Per Jacobson's Object-Oriented Software Engineering (1992). Every entity gets one primary class — Boundary, Control, or Entity. Classes with two responsibilities split.

### Boundary objects (interfaces to actors)

Adapters to the world outside the use case. Each Boundary type wraps one external interface.

| Boundary type | Wraps | Actor |
|---|---|---|
| **DispatcherInvoker** | `bash .claude/hooks/session-reflection.sh <event>` | Claude Code dispatcher |
| **ClaudeInvoker** | `claude -p "<skill>"` with `timeout 30` | Claude CLI |
| **FilesystemWriter** | `printf` / `tee` write to capture path under `docs/smoke-captures/<date>/` | Filesystem |
| **GhInvoker** | `gh issue create --repo sunj-labs/bassclef-cli --label smoke-run --body-file <path>` | GitHub API |
| **NpmInvoker** | `npm install -g @thebassclef/lite@<version>` | npm registry |
| **StderrReader** | reads stderr streams into capture files | subprocess stderr |
| **CurlFetcher** (post-merge 2026-09-18) | `curl -sfL <url> -o <dest>` for the 10 smoke files | raw.githubusercontent.com |

### Control objects (coordinate use case per step)

One Control per multi-step coordination inside the use case. Each fires its Boundary objects in sequence and writes to Entity objects.

| Control type | Fires | Writes to |
|---|---|---|
| **HookRunner** | DispatcherInvoker (per hook) + StderrReader + FilesystemWriter | CaptureFile (per hook) |
| **SkillDriver** | ClaudeInvoker (per skill) + StderrReader + FilesystemWriter | CaptureFile (per skill) |
| **AssertionSuite** | Four Strategy check functions per CaptureFile | AssertionResult (per check per surface) |
| **ReportBuilder** | reads AssertionResult set + writes Report | Report (markdown file) |
| **PublisherController** | GhInvoker for label ensure (auto-create `smoke-run-<version>` via `gh label create --force`) + GhInvoker for issue list (search open `smoke-run-<version>` with matching version + date) + GhInvoker for create-or-update + report body versioning marker | Issue (external — GitHub state); labeled `smoke-run-<version>` |
| **ResetController** | FilesystemWriter (many targets) + NpmInvoker (uninstall) + FilesystemWriter for snapshot dirs + FilesystemWriter for restore | ResetLog (idempotency record); Snapshot (per-timestamp backup dir under `~/tmp/bassclef-smoke-reset-backups/`) |
| **BootstrapController** (post-merge 2026-09-18) | CurlFetcher (10 files) + FilesystemWriter (target-dir layout) + stderr next-command block | fetched scripts under `$TARGET/scripts/` with `scripts/lib/` layout preserved |

### Entity objects (persistent or per-use-case data)

Nouns that carry data across steps.

| Entity type | Persistence | Owned by |
|---|---|---|
| **CaptureFile** | on disk under `docs/smoke-captures/<date>/hooks/*.out` and `.../skills/*.out` | HookRunner + SkillDriver create; AssertionSuite reads |
| **AssertionResult** | on disk as `hooks-assertions.json` and `skills-assertions.json`; per-check variant `<check-name>-only.json` when `--only` fires | AssertionSuite creates; ReportBuilder reads |
| **Fixture** | on disk under `.claude/hooks/tests/fixtures/2026-09-18-smoke-findings/cli-<N>/` | Committed to repo; AssertionSuite reads at fixture-test time |
| **Report** | on disk as `docs/smoke-captures/<date>/report.md`; body carries a version marker in the frontmatter (`report_shape_version: 1`); label carries the release version, not the body-shape version (see F1 note below) | ReportBuilder creates; PublisherController reads |
| **Allowlist** | on disk as `.claude/hooks/tests/fixtures/smoke-allowlist/<check>.txt` | Committed to repo; AssertionSuite reads |
| **Issue** | external — GitHub; labeled `smoke-run-<version>` (e.g. `smoke-run-1.2.0`); body follows Report's versioned shape | PublisherController creates or updates via GhInvoker |
| **Snapshot** | on disk under `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/` (RFC F6 fold); mirrors target dirs; auto-expires after 7 days | ResetController writes on `--whole`; reads on `--restore` |
| **ResetLog** | on disk as `docs/smoke-captures/<date>/reset.log` | ResetController writes; operator reads |

### BCE call sequence (main flow)

```
Operator → HookRunner (Control)
  HookRunner → DispatcherInvoker (Boundary) — fires dispatcher per hook
  HookRunner → StderrReader (Boundary) — reads stderr streams
  HookRunner → FilesystemWriter (Boundary) — writes CaptureFile (Entity)

Operator → AssertionSuite (Control)
  AssertionSuite → CaptureFile (Entity) — reads
  AssertionSuite → [Strategy check × 4 per capture]
  AssertionSuite → FilesystemWriter (Boundary) — writes AssertionResult (Entity)

Operator → SkillDriver (Control)
  SkillDriver → ClaudeInvoker (Boundary) — fires claude -p per skill
  SkillDriver → StderrReader (Boundary) — reads stderr
  SkillDriver → FilesystemWriter (Boundary) — writes CaptureFile (Entity)

Operator → AssertionSuite (Control) — same shape, reads skill captures

Operator → ReportBuilder (Control)
  ReportBuilder → AssertionResult (Entity) — reads both
  ReportBuilder → FilesystemWriter (Boundary) — writes Report (Entity)

Operator → PublisherController (Control) [when --publish]
  PublisherController → Report (Entity) — reads
  PublisherController → GhInvoker (Boundary) — POST to GitHub
  GhInvoker → Issue (Entity, external) — created
```

### Why the split matters

Two classes carried temptation to blur. Named here so the implementer keeps them apart:

- **HookRunner is Control, not Boundary.** It coordinates enumerate → invoke → capture. The invocation itself belongs to DispatcherInvoker (Boundary). Blur risk: putting the `bash <dispatcher>` call inline in HookRunner ties the coordinator to the external process shape. Keeping DispatcherInvoker separate lets Layer 2 or 3 swap invocation shapes without touching the coordinator.
- **AssertionSuite is Control, not Entity.** Assertions produce AssertionResult objects (Entities), but the coordination — enumerate captures, apply four checks, collect results — is Control. Blur risk: putting the check logic on the AssertionResult object couples data to check semantics.

## Post-merge additions (2026-09-18, after PR #110)

Three additions surfaced between PR #110 merge and the cold-profile smoke run:

- **BootstrapController (Boundary + Control) + CurlFetcher (Boundary).** New `scripts/smoke-bootstrap.sh` fetches all 10 smoke files from `raw.githubusercontent.com` via curl. Cold-adopter no longer needs `git clone`. Bootstrap prints a next-command block on stderr after fetch — Norman signifier, Cooper flow. Ships in PR #112. See spec § Interfaces § `scripts/smoke-bootstrap.sh`.
- **Terminal feedback (cross-cutting concern).** Every smoke script prints `>>> <name> starting` at top, `<<< <name> done (exit N)` at exit via `trap ... EXIT`. Makes chain boundaries visible in the operator's terminal. Ships in PR #112.
- **Gitignore un-ignore for `scripts/lib/`.** `.gitignore` bare `lib` pattern was matching `scripts/lib/` too. `smoke-schema.sh` got silently ignored on the PR #110 squash. Fix landed as PR #111 — added `!scripts/lib` + `!scripts/lib/**` un-ignore lines mirroring the src/lib pattern.

## RFC F1 + F2 + F4 + F6 folds (2026-09-18)

Design deltas from `docs/rfc/RFC-smoke-evidence-adversarial.md`:

- **F1 — Report shape versioned.** Report entity gains `report_shape_version: 1` frontmatter. Future breaking body-shape changes bump the frontmatter version per ADR-031 grace. Agents parse the frontmatter to pick shape. (Original F1 fold put the shape version in the label as `smoke-run-v1`; retired 2026-09-19 per PR #141 after cold-adopter-1 smoke exposed the label-hardcoding trap. Label now derives from the release version — `smoke-run-<version>` — and auto-creates on first publish per release.)
- **F2 — Two personas.** Operator-Release + Operator-Diagnose. `smoke-assert-hooks.sh --only <check-name>` and `smoke-assert-skills.sh --only <check-name>` serve Operator-Diagnose. New AssertionResult variant `<check-name>-only.json`.
- **F4 — Publish idempotent.** PublisherController now runs a label-ensure step (`gh label create smoke-run-<version> --force`) plus a search-first step: `gh issue list --label smoke-run-<version> --state open --search "<version>"`. When open issue exists on same date, updates body via `gh issue edit` instead of creating. `--new` flag forces fresh create.
- **F6 — Reset snapshotted.** New Snapshot entity under `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/`. ResetController writes snapshot before clear; `--restore <ISO-timestamp>` reads snapshot. Auto-expires after 7 days.

## References

- Jacobson, *Object-Oriented Software Engineering* (1992) — BCE classification
- Larman, *Applying UML and Patterns* — GRASP roles
- Spec: `docs/specs/smoke-evidence-capture.md`
- Use case: `docs/use-cases/UC-smoke-run.md`
- RFC folds: `docs/rfc/RFC-smoke-evidence-adversarial.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Pattern rule: `.claude/rules/pattern-annotation.md`
