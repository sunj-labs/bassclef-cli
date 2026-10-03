---
tier: lite
date: 2026-10-03
goal: cli#294 Step 1
code-class: new adopter-facing script (brief UC per .claude/rules/oo-ad-entry-point.md matrix row 7)
---

# UC-script-cli-294-driver-1 — trace-log-privacy

## Primary actor

Smoke harness (CI docker-smoke OR local `bash scripts/tests/*.test.sh`).

## Goal

Assert that a fresh adopter install of `@thebassclef/lite` does not leak absolute home paths into trace logs, into staged git content, or into pushed branches.

## Main success scenario

1. Harness sources the bundled trace-helper.sh at `dist/lite/.claude/hooks/trace-helper.sh`
2. Harness fires `trace_log "fake-hook" "fake-trigger"` from a scratch workdir simulating `/Users/<name>/some-repo`
3. Harness reads the written log at `docs/sdlc-traces/<today>.log`
4. Harness asserts the log line contains NO literal `/Users/` AND NO literal `/home/` substring
5. Harness reads `dist/lite/presence/dist-templates/.gitignore` (if present at a shipped-template path)
6. Harness asserts `docs/sdlc-traces/` is present in the shipped adopter `.gitignore`
7. Exit 0

## Extensions

- 4a. Log line contains `/Users/` → exit 1 with failure message naming the leak class
- 6a. Shipped `.gitignore` missing `docs/sdlc-traces/` → exit 1 naming the gitignore gap
- Any required file missing → exit 2 with "fixture setup failed"

## Preconditions

- `dist/lite/.claude/hooks/trace-helper.sh` exists in the cli repo (bundled substrate)
- Bash 3.2+ (macOS default) OR bash 5+ (CI Debian)

## Postconditions

- Current main: driver exits 0 (cure held)
- Pre-cure commit (parent of upstream PR #2041): driver exits 1 (cure not present)

## Pattern

Characterization test per @luminary michael-feathers. RED-first evidence: `git checkout <pre-cure-SHA> && bash scripts/tests/smoke-drive-adopter-trace-log-privacy.test.sh` returns exit 1. GREEN on current main: exit 0.

## Covers

- Kunal #2036 finding #1 (trace-log absolute paths)
- Kunal #2036 finding #5 (CCF-3 blocks adopter's own shipped file; related — gitignore cure prevents the trace log reaching staged content in the first place)

Adopter was trying to: start a fresh session in their new project, have trace logs stay local, keep machine username out of git history.
