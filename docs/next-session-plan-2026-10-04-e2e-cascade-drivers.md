# Next session plan — E2E cascade drivers for Sam + Louis journey

## Why this plan fires

Cli#294 drivers 1-5 (merged this session, PRs #298-#302) anchor specific Kunal #2036 cures via file-level grep. They catch regression at the file surface. They do NOT exercise the full hook cascade that fires when a real adopter session invokes the skill.

Kunal's bugs lived in cascades the 21-skill generic drive catalog never observed:

- Trace-helper logged absolute paths because the SKILL firing the hook did not notice.
- zsh wiped PATH because `lib/state.sh` sourced under a shell no SIM covered.
- SKIP env never reached the hook because the hook ran in a subshell.
- /onboard-repo returned 403 with no fallback because the SIM mock was never under free-tier conditions.

The gap is **adopter-condition coverage**. This plan builds 5 end-to-end drivers for the skills Sam and Louis most graduate towards. Each driver scaffolds a scratch workdir, mocks binaries where needed, runs the SKILL body dispatch, observes the hook cascade firings, and asserts the full sequence.

Prototype work this session: `/onboard-repo` + `/build` drivers (operator ask 2026-10-03b). Next session continues per below.

## Candidate skills — Sam + Louis journey

Per `docs/personas/sam.md` (Saturday evaluator, 15-30 min, bounces on friction) and `docs/personas/2026-07-12-bet11c-louis.md` (context switcher, skims group headings):

| Rank | Persona | Skill | Cascade surface | Prior Kunal finding touched |
|---|---|---|---|---|
| 1 | Sam | `/onboard-repo` | gh api + .gitignore write + hook register | #9 |
| 2 | Sam | `/sprint` | state-spine read + lib/state.sh under zsh | #6 |
| 3 | Sam | `/temperance` | marker write + pre-build-gate read | — |
| 4 | Louis | `/longrun prep` | 10+ hook fires: whereami + plan + marker chain | — |
| 5 | Louis | `/build` | awk extractor + /verify compose | #2, #3 |

Prototype this session: #1 (/onboard-repo) + #5 (/build). Reasoning — Kunal landed on #1 first and left; #5 is the end of Louis's build cycle and the awk defect lived there.

## Shape per driver

Each driver follows the same template:

### Phase 1 — scaffold

- `mktemp -d` for scratch adopter workdir
- `git init -q` + git identity set
- `mkdir -p .claude` + optionally seed a dist/lite-shaped substrate layout
- `trap` cleanup on EXIT

### Phase 2 — mock

- Fake binaries on PATH where needed (fake_gh.sh, fake_claude.sh)
- Env vars (CLAUDE_PROJECT_DIR, BASSCLEF_DIR, etc.) set per adopter condition
- Deterministic clock stub if the SKILL reads time

### Phase 3 — observe

- Enable trace-log capture via trace-helper (if present) — logs land under docs/sdlc-traces/
- Snapshot state/markers/ before + after
- Capture stderr + stdout to log files

### Phase 4 — dispatch

- Source SKILL body sections OR run the hook sequence that mirrors a real session
- Example `/onboard-repo` cascade: SessionStart hooks → PreToolUse on gh api → PreToolUse on Edit of settings.json → PostToolUse

### Phase 5 — assert

- Marker diff — new markers landed per expected set
- Trace log — expected hook names fired in expected order
- Filesystem — expected files + content
- Shell state — PATH preserved, no absolute paths leaked

### Phase 6 — report

- `pass/fail` summary line per existing driver convention
- Fail messages name the cascade step that broke

## Fixtures to add

- `scripts/tests/fixtures/fake_gh.sh` — already exists; may need extension for 403 path
- `scripts/tests/fixtures/fake_claude.sh` — already exists
- `scripts/tests/fixtures/cascade_observer.sh` — new; wraps trace-helper + marker-diff
- `scripts/tests/fixtures/skill-fixtures/onboard-repo-mock-settings.json` — scratch seed

## CI integration

Bash drivers 1-5 currently run only locally; CI test+typecheck is vitest-only. Follow-on PR candidates (not blocking this session):

- **Option A** — `npm run test:drivers` script invokes `bash scripts/tests/*.test.sh`; `test` script chains both.
- **Option B** — docker-smoke CI job wiring to run bash drivers in container.
- **Option C** — vitest shell wrapper per driver using `child_process.execSync`.

Operator preference needed.

## Related tickets

- **bassclef-upstream#2049** (filed 2026-10-03b) — adopter-sim-test notification protocol when SKILL body changes. The notification layer this plan's drivers rely on long-term.
- **cli#294** (closed by PR #302) — parent 5-driver stack.
- **cli#294 follow-ons** — findings #7, #8, #10 at bassclef-upstream Slot 5/6.

## Time budget

- `/onboard-repo` E2E prototype: 30-50 turns (prototyped this session; shape set)
- `/build` E2E prototype: 25-40 turns (prototyped this session)
- `/sprint` E2E driver: 30-40 turns (next session)
- `/temperance` E2E driver: 20-30 turns (next session; smallest cascade)
- `/longrun prep` E2E driver: 50-80 turns (next session; biggest cascade — 10+ hook fires)

Full stack: 155-240 turns across 2-3 sessions.

## Luminary map

- Lead: `michael-feathers` — characterization at the cascade level.
- Supporting: `john-ousterhout` — each driver stays a narrow interface wrapping a scratch workdir.
- Supporting: `donald-norman` — report shape must surface which cascade step broke, not just "driver failed".
- Supporting: `alan-cooper` — each driver's top-of-file names the adopter journey being pinned, not just the SKILL being tested.
