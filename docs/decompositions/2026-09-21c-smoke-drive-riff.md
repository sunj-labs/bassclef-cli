---
tier: lite
slug: 2026-09-21c-smoke-drive-riff
date: 2026-09-21
scope: Epic #199 Story 1
method: objectory-decompose + GRASP
authoring_luminaries:
  primary: alistair-cockburn
  supporting: [andreas-zeller, michael-feathers]
references:
  - docs/specs/2026-09-21c-smoke-drive-riff.md
  - docs/use-cases/UC-smoke-drive-riff.md
  - docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md
---

# Decomposition — smoke-drive-riff

## Sources read

- `docs/specs/2026-09-21c-smoke-drive-riff.md` — acceptance list + assertion contract
- `docs/use-cases/UC-smoke-drive-riff.md` — 4 scenarios
- `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md` — top-5 folded (R1-R5)
- `scripts/smoke-drive-onboard-repo.sh` — proven template (142 lines)
- `harness/docker/entry.sh` L374-391 — V2 Step 6 wire-in shape to mirror

## What I'm NOT reading (with reason)

- Playwright MCP source — Playwright-in-Docker is a follow-on; this Story handles absence

---

## Part 1 — Objectory decomposition

### Domain nouns (entities)

- **ScratchDir.** Fresh directory where `/riff` runs — `$HOME/riff-test` or `$RIFF_SCRATCH`.
- **CaptureFile.** File under `$OUT_ROOT/riff.out` holding stdout+stderr from `claude -p`.
- **DriveInvocation.** One `bash smoke-drive-riff.sh` run.
- **ExitCode.** One of {0, 1, 3, 5, 6, 127}.
- **VariantHtml.** Static HTML file under `$SCRATCH_DIR/docs/prototypes/YYYY-MM-DD-riff-<slug>-variant-N/index.html`.
- **AssertionOutcome.** Either PASS or FAIL. FAIL has 4 sub-classes (assertion, timeout, environment, setup).
- **EnvironmentMissSignal.** A capture containing tokens like `Playwright|MCP|screenshot` indicating Playwright absence.

### Verb-subjects (actors)

- **Harness** — the Docker container's `entry.sh` V2 Step 7 caller.
- **Maintainer** — the human running the drive manually for debugging.
- **Drive** — `scripts/smoke-drive-riff.sh` itself.
- **Claude** — the `claude -p "/riff ..."` subprocess.
- **PerlAlarm** — the timeout wrapper.

### Verb-goal pairs (use case candidates)

| # | Actor | Verb | Goal |
|---|---|---|---|
| VG-1 | Harness | invoke Drive | receive AssertionOutcome + ExitCode |
| VG-2 | Drive | reset ScratchDir | fresh state per run |
| VG-3 | Drive | fire Claude with timeout | capture output OR observe timeout |
| VG-4 | Drive | assert VariantHtml exists + non-empty + has `<h2>` | emit PASS/FAIL |
| VG-5 | Drive | detect EnvironmentMissSignal | map to exit 6 (not 3) |
| VG-6 | Drive | teardown ScratchDir on any exit path | leave clean state |

### BCE classification (Jacobson)

| Class | Members |
|---|---|
| **Boundary** | argv parser, `claude -p` invocation, capture file writer, exit code emitter, harness wire-in in `entry.sh` |
| **Control** | The drive script's main sequence: reset → fire → assert → teardown |
| **Entity** | ScratchDir, CaptureFile, ExitCode, VariantHtml, AssertionOutcome, EnvironmentMissSignal |

---

## Part 2 — GRASP + interfaces + patterns

### GRASP role assignments

| Responsibility | Where it lives | GRASP principle |
|---|---|---|
| Reset ScratchDir (rm -rf + mkdir + git init + git config) | Drive setup block | **Creator** — Drive owns ScratchDir's lifecycle |
| Fire Claude with perl-alarm timeout | Drive drive block | **Controller** at the subprocess boundary |
| Assert VariantHtml file + size + `<h2>` content | Drive assert block | **Information Expert** — the file IS the source of truth |
| Detect EnvironmentMissSignal in capture | Drive `check_env_miss()` helper | **Pure Fabrication** — no domain entity owns this cross-cutting concern |
| Map ExitCode from `claude -p` return + assertion result + env-miss | Drive exit-code map | **Controller** — the drive owns the exit-code contract |
| Teardown ScratchDir on any exit path | Trap EXIT/INT/TERM | **Creator** — Drive that owns creation owns cleanup |
| Wire Drive into harness | `harness/docker/entry.sh` V2 Step 7 | **Controller** at the harness boundary |

### Interfaces identified

**Interface 1 — Drive invocation.**

```bash
scripts/smoke-drive-riff.sh [--out DIR] [--claude BIN] [--timeout SEC] [--scratch DIR] [--keep-scratch] [--help]
```

Same argv shape as onboard-repo template.

**Interface 2 — Environment variables.**

```
CLAUDE_BIN            override binary (default: claude)
RIFF_SCRATCH          override scratch (default: $HOME/riff-test)
RIFF_TIMEOUT_SEC      override timeout (default: 300)
OUT_ROOT              output dir (default: docs/smoke-captures/<date>/riff)
```

**Interface 3 — Exit codes (contract with harness).**

```
0    /riff fired + variant HTML landed + content check passed
3    /riff fired but assertion failed (no HTML, empty HTML, or no <h2>)
5    /riff exceeded RIFF_TIMEOUT_SEC (mapped from 142)
6    Environment-degraded — Playwright/MCP absent detected in capture
127  claude binary missing
1    other setup failure (perl / git missing, unwritable HOME, etc.)
```

**Interface 4 — Environment-miss detection.**

```bash
check_env_miss() {
  # Returns 0 if the capture contains any Playwright/MCP token.
  # Returns 1 otherwise.
  grep -qiE 'playwright|mcp not enabled|cannot screenshot' "$1"
}
```

Case-insensitive on purpose — capture may quote error messages in different casings.

### Cross-cutting concerns

| Concern | Handling |
|---|---|
| No PR-open (SKILL L96 says MUST) | Scratch dir has no remote. Drive does not push. Story 6 verifies against a real repo. |
| Playwright BLOCK vs graceful degrade ambiguity | Drive treats BOTH as observable behavior. If HTML lands, pass. If no HTML + env-miss signal → exit 6. |
| Timeout tuning (R5) | Default 300s; env override; note in header. |
| Fixture isolation for Tier 0 test | Test spawns drive against 3 fixture scratch dirs; mocks `claude` via a stub script on PATH. |

### Patterns applied

- **@pattern patterns/code/gof/template-method.md** — drive's setup → fire → assert → teardown mirrors onboard-repo template's shape.
- **@pattern patterns/code/gof/strategy.md** — exit-code map is a strategy per outcome (pass / assertion / timeout / env / claude-missing / setup).
- **@pattern patterns/code/fowler/pure-function.md** — `check_env_miss()` is pure over the capture file contents.

### File map

| New / extended | Path | Owner interface |
|---|---|---|
| New | `scripts/smoke-drive-riff.sh` | Interfaces 1-4 |
| New | `tests/harness/smoke-drive-riff.test.ts` | Characterization coverage |
| New | `tests/harness/fixtures/smoke-drive-riff/claude-happy.sh` | Mock claude writing HTML |
| New | `tests/harness/fixtures/smoke-drive-riff/claude-playwright-block.sh` | Mock claude with env-miss signal |
| New | `tests/harness/fixtures/smoke-drive-riff/claude-empty.sh` | Mock claude producing no HTML |
| Extended | `harness/docker/entry.sh` V2 Step 7 | Wire-in |

### Test coverage per Tier 0

Per `.claude/rules/test-sufficiency.md` criteria:

1. Happy path — fixture claude writes valid HTML → drive exits 0
2. Assertion fail — fixture claude exits 0 with no HTML → drive exits 3
3. Timeout — fixture claude sleeps past timeout → drive exits 5
4. Env-miss (Playwright) — fixture claude writes stderr Playwright message → drive exits 6
5. claude binary missing — CLAUDE_BIN=`/nonexistent/claude` → drive exits 127
6. Teardown — after any exit path, `$SCRATCH_DIR` does not exist

## Sequencing (Beck TDD RED → GREEN)

1. Beck RED — write `tests/harness/smoke-drive-riff.test.ts` with 6 tests + 3 fixture scripts. Drive script does not exist yet → tests fail to spawn.
2. Beck GREEN — author `scripts/smoke-drive-riff.sh` modeled on onboard-repo. Tests pass.
3. Wire into `harness/docker/entry.sh` V2 Step 7.
4. Verify: run drive against Real Docker container (deferred to Story 6 or manual).
5. `/architect-review` — dispatch after code lands + before PR merge.
6. Ship — PR + merge within scope.

## Refs

- Spec: `docs/specs/2026-09-21c-smoke-drive-riff.md`
- Use case: `docs/use-cases/UC-smoke-drive-riff.md`
- Risk ledger: `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md`
- @luminary alistair-cockburn — walking skeleton
- @luminary andreas-zeller — hypothesis testing
- @luminary michael-feathers — characterization
- Jacobson, I. (1992). *Object-Oriented Software Engineering* — BCE.
- Larman, C. (2004). *Applying UML and Patterns* — GRASP.
