---
tier: lite
slug: UC-smoke-drive-riff
ceremony: brief
date: 2026-09-21
actors: [harness, maintainer]
scope: Epic #199 Story 1
references:
  - docs/specs/2026-09-21c-smoke-drive-riff.md
  - docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md
---

# UC — smoke-drive-riff (brief tier)

## Sources read

- `docs/specs/2026-09-21c-smoke-drive-riff.md` — acceptance + design notes
- `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md` — 3-lens pre-mortem
- `scripts/smoke-drive-onboard-repo.sh` — reference actor behavior

**Actor.** Harness (bass Docker container's `entry.sh` V2 Step 7) OR Maintainer (manual invocation for debugging).

**Scope.** Fire `/riff` in a fresh scratch dir. Verify HTML variants land. Report pass/fail/timeout/environment-degraded to the harness.

**Level.** Subfunction.

**Primary actor goal.** Know if a published tarball's `/riff` still dispatches cleanly and authors mock variants.

## Primary scenario — happy path

1. Harness invokes `bash scripts/smoke-drive-riff.sh --out $OUT_ROOT`.
2. Drive checks preconditions: `claude`, `perl`, `git` all on PATH.
3. Drive resolves scratch dir at `$RIFF_SCRATCH` or `$HOME/riff-test`. Removes prior state.
4. Drive `git init -q` + `git config` in scratch. `cd` into it.
5. Drive fires `claude -p "/riff riff a marketing landing hero"` with a 300s perl-alarm timeout. Captures stdout+stderr to `$OUT_ROOT/riff.out`.
6. `/riff` dispatches. Runs its 5 internal steps. Writes HTML variants at `docs/prototypes/YYYY-MM-DD-riff-<slug>-variant-N/index.html`.
7. Drive asserts: `find docs/prototypes -name '*.html' -size +100c | head -1` returns a path AND the file contains `<h2>`.
8. Drive echoes PASS + capture path. Exits 0. Trap fires teardown: removes scratch dir.

## Alternative — timeout

1. Steps 1-5 as above.
2. `/riff` runs longer than 300s. Perl-alarm fires SIGALRM. `claude -p` exits 142.
3. Drive maps 142 → 5. Echoes "TIMEOUT — /riff exceeded 300s" + capture path. Exit 5.
4. Teardown removes scratch.

## Alternative — Playwright/MCP absent (environment-degraded)

1. Steps 1-5 as above.
2. `/riff` dispatches but `/visual-review` sub-step BLOCKs on missing Playwright MCP. Stderr: "Playwright MCP not enabled — cannot screenshot variants".
3. `claude -p` exits non-zero. No HTML files landed under `docs/prototypes/`.
4. Drive checks HTML files → empty. Greps capture for `Playwright|MCP|screenshot` (case-insensitive) → match.
5. Drive echoes "ENVIRONMENT-DEGRADED — /riff blocked on missing MCP" + capture. Exit 6.
6. Teardown removes scratch. Harness reports Step 7 as environment-degraded, not skill-regression.

## Alternative — assertion fail (real regression)

1. Steps 1-5 as above.
2. `/riff` exits 0 but writes no HTML (or writes empty file).
3. Drive checks HTML files → empty (or empty file). Greps capture for Playwright tokens → no match.
4. Drive echoes "ASSERTION FAIL — no HTML variants landed after /riff" + capture + scratch dir listing. Exit 3.
5. Teardown removes scratch. Harness reports Step 7 as skill-regression.

## Preconditions

- `claude` binary on PATH (else exit 127)
- `perl` on PATH (else exit 1)
- `git` on PATH (else exit 1)
- Writable `$HOME` or `$RIFF_SCRATCH`

## Postconditions (success)

- HTML variant file exists in scratch under `docs/prototypes/*-riff-*/*.html` at size >100 bytes with `<h2>` heading
- Capture file at `$OUT_ROOT/riff.out` with stdout+stderr from the drive
- Scratch dir removed (unless `--keep-scratch` was passed)

## Postconditions (failure paths)

- Exit 3: skill regression. Capture at `$OUT_ROOT/riff.out`. Scratch removed.
- Exit 5: timeout. Capture at `$OUT_ROOT/riff.out`. Scratch removed.
- Exit 6: environment-degraded (Playwright/MCP). Capture at `$OUT_ROOT/riff.out`. Scratch removed.
- Exit 127: claude missing. No capture. No scratch.
- Exit 1: other setup failure. No capture. Scratch may or may not exist.

## Refs

- Spec: `docs/specs/2026-09-21c-smoke-drive-riff.md`
- Risk ledger: `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md`
- `~/.claude/skills/riff/SKILL.md` — skill under test
- `scripts/smoke-drive-onboard-repo.sh` — sibling pattern
