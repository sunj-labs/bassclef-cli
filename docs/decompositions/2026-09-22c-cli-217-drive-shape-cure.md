---
tier: upstream
decomp_id: 2026-09-22c-cli-217-drive-shape-cure
parent_uc: UC-hook-docker-smoke-drive-shape
authoring_luminaries:
  primary: michael-feathers
  supporting: [david-parnas, jerome-saltzer-and-michael-schroeder]
---

# Decomposition — cli #217 drive-shape cure

## Sources read

- `scripts/smoke-drive-skills.sh:1-146` — full script, especially L45-49 default skill list, L96-137 drive loop, L125-131 the perl+claude -p invocation
- `scripts/smoke-drive-riff.sh:1-259` — full script, especially L165-174 the perl+claude -p invocation, L189-197 env-miss detection, L201-232 positive-artifact assertion
- `scripts/smoke-drive-onboard-repo.sh:1-142` — full script, especially L107-117 invocation, L132-138 positive-artifact assertion
- `scripts/lib/smoke-assert.sh:1-205` — all 6 check functions; L34-46 check_no_not_found grep pattern; L160-204 timeout + crash checks; L21 Strategy pattern annotation
- `docs/next-session-plan-2026-09-23-cli-217-drive-shape-cure.md:1-118` — plan doc scope + 5-skill positive-artifact table L79-86 + step sequencing
- `docs/use-cases/UC-hook-docker-smoke-drive-shape.md:1-84` — the sibling UC (this session)
- Cli #217 body (gh issue view 217) — full trace of the invocation pattern + local repro
- `tests/harness/smoke-drive-riff.test.ts:1-80` — existing vitest test pattern (spawnSync + claude mock fixture)
- `tests/harness/fixtures/smoke-drive-riff/claude-happy.sh` — mock claude fixture pattern

## What I'm NOT reading (with reason)

- `scripts/smoke-assert-skills.sh` — will read at Step 5 when wiring new checks (not needed for design)
- `harness/docker/entry.sh` — not touched by this cure; already extended in cli #212

## Entity model (Jacobson BCE)

**Boundary** — shell scripts + LLM interface

- `smoke-drive-skills.sh` — reads skill list; fires 5 skills; writes captures
- `smoke-drive-riff.sh` — fires /riff; writes HTML variant assertion
- `smoke-drive-onboard-repo.sh` — fires /onboard-repo; writes settings.json assertion

**Control** — assertion orchestration

- `smoke-assert-skills.sh` — reads 5 captures; runs 6 assert functions per capture; emits PASS/FAIL rows
- `smoke-assert-hooks.sh` — sibling for hook captures

**Entity** — pure functions (library)

- `scripts/lib/smoke-assert.sh` — 6 check functions today; 2-6 new per-skill functions after cure
- `scripts/lib/smoke-schema.sh` — assertion row JSON schema

## GRASP role assignment

| Class | GRASP role | Rationale |
|---|---|---|
| smoke-drive-skills.sh | Controller (Fabricated) | Coordinates the drive-per-skill loop |
| smoke-drive-riff.sh | Controller | Single-skill drive with own assertion |
| smoke-drive-onboard-repo.sh | Controller | Same shape as riff |
| scripts/lib/smoke-assert.sh | Information Expert | Owns "does this capture pass?" |
| check_no_unknown_command (new) | Information Expert | Owns "did CLI slash-command dispatch fall through?" |
| check_temperance_marker (new) | Information Expert | Owns "did /temperance fire and touch its marker?" |
| check_output_contains (new generic) | Information Expert | Owns "does capture contain phrase X?" |

## Pattern annotations

`@pattern patterns/code/gof/strategy.md` — smoke-assert.sh already declares this. Each check function is a Strategy; caller swaps at will. Per-skill assertions extend the Strategy set.

`@pattern patterns/code/fowler/anticorruption-layer.md` — natural-language prompts sit at the anticorruption boundary between the harness (which wants to fire a named skill) and the LLM (which needs a natural request). The prompt template `run the /X skill with this input` is the translation layer.

## Cross-cutting audit

- **Timeout handling** — every drive wraps in `perl … alarm N`; 142 → distinct exit code (unchanged)
- **Env-degraded detection** — riff drive detects Playwright missing; other drives inherit pattern (unchanged)
- **Teardown** — trap EXIT INT TERM on scratch dirs (unchanged)
- **Stdin closure** — `< /dev/null` on perl call from 2026-09-20d cure (unchanged)

## Interfaces

Per-skill positive-artifact assertion signature (new):

```
check_<skill_slug>_artifact <capture_file> [<workdir>]
  Emits: <STATUS>|<check-name>|<message>  on stdout
  Returns: 0 on PASS, 1 on FAIL
```

Generic `check_no_unknown_command` signature:

```
check_no_unknown_command <capture_file>
  Emits: PASS|no-unknown-command|0 matches  OR  FAIL|no-unknown-command|N matches
  Returns: 0 on PASS, 1 on FAIL
```

Generic `check_output_contains` signature (for phrase-based positive checks):

```
check_output_contains <capture_file> <needle> [<label>]
  Emits: PASS|contains-<label>|<needle> found  OR  FAIL|contains-<label>|<needle> missing
  Returns: 0 on PASS, 1 on FAIL
```

## Prompt template

For each skill in the drive list, template the prompt:

```
run the /<skill-name> skill<optional args>. show me the output.
```

Concrete examples per plan doc L79-86:

- `/temperance` → `run the /temperance skill for the scope decision 'add a login button to a test app'. show me the output.`
- `/luminary don-norman` → `run the /luminary skill for don-norman and show me the lens summary.`
- `/kiss words --rewrite` → `use the /kiss skill in words mode to rewrite this verbose corporate text: "It has come to our attention that stakeholders would benefit from more granular reporting cadence". show me the output.`
- `/state-a-problem brief` → `use the /state-a-problem skill in brief mode to draft a problem statement for: 'session-start hooks fire twice on cold-adopter installs'. show me the output.`
- `/whats-the-plan` → `use the /whats-the-plan skill to declare a chain for shipping a login button to a test app. show me the output.`

## Positive-artifact assertion per skill

Per plan doc L79-86:

| Skill | Positive artifact |
|---|---|
| `/temperance` | `state/markers/temperance/*.marker` exists after drive (workdir-scoped) |
| `/luminary don-norman` | capture contains "Don Norman" OR "norman" (case-insensitive) |
| `/kiss words --rewrite` | capture contains "rewritten" OR "grade" OR "words" |
| `/state-a-problem brief` | capture contains "Problem:" OR "Who:" OR "What:" |
| `/whats-the-plan` | capture contains "Plan:" OR "Step" OR "chain" |

## What stays the same

- All 6 existing check functions stay — they catch orthogonal failure classes
- All 3 drives keep their teardown + stdin + timeout mechanics
- smoke-assert-hooks.sh unchanged — hook captures don't dispatch skills

## What changes

- 3 drive scripts: prompt shape swap only
- smoke-assert.sh: 1 new generic guard (`check_no_unknown_command`) + 1 new generic helper (`check_output_contains`) + 5 new per-skill checks
- smoke-assert-skills.sh: wire new per-skill checks into the assertion loop
- Test suite: Beck RED-first suite covering all changes

## Refs

- UC-hook-docker-smoke-drive-shape.md
- .claude/rules/pattern-annotation.md
- .claude/rules/oo-ad-entry-point.md
