---
tier: lite
date: 2026-10-03
goal: cli#294 Step 6
code-class: new adopter-facing script (brief UC per .claude/rules/oo-ad-entry-point.md matrix row 7)
---

# UC-script-cli-294-driver-4 — env-reach-override

## Primary actor

Smoke harness (CI docker-smoke OR local `bash scripts/tests/*.test.sh`).

## Goal

Assert that `lib/skip-env-inline-check.sh` exists in bundled substrate AND its `skip_var_set` function correctly reads the inline-prefix form (`SKIP_FOO=1 cmd...`) that adopters paste from BLOCK banners.

## Main success scenario

1. Harness locates `lib/skip-env-inline-check.sh` in bundled `dist/lite/lib/` or sibling
2. Harness sources the lib in a subshell
3. Harness calls `skip_var_set "SKIP_FOO" "SKIP_FOO=1 git commit -m test"` → asserts return 0 (inline prefix detected)
4. Harness calls `skip_var_set "SKIP_FOO" "git commit -m test"` with env `SKIP_FOO=` unset → asserts return 1 (no inline, no env)
5. Harness calls `skip_var_set "SKIP_FOO" "git commit -m test"` with env `SKIP_FOO=1` set → asserts return 0 (env fallback)
6. Exit 0

## Extensions

- 3a. Inline detection returns non-zero → exit 1 naming the pattern that failed
- 4a. Neither-source returns 0 → exit 1 naming the false-positive
- 5a. Env fallback returns non-zero → exit 1 naming the fallback regression
- Lib missing → exit 1 (not SKIP — this cure is a mandatory file)

## Preconditions

- Bundled or sibling lib dir reachable
- Bash 3.2+ with grep

## Postconditions

- Current main: driver exits 0 (lib shipped + 3 inputs behave per contract)
- Pre-cure commit (parent of upstream PR #2042): driver exits 1 (lib file does not exist)

## Pattern

Characterization test per @luminary michael-feathers + narrow-interface check per @luminary john-ousterhout. The driver exercises the shipped helper's contract at 3 inputs covering the two signal sources (inline prefix + process env).

## Covers

- Kunal #2036 finding #4 (SKIP_* env-reach override recipes did not bypass hooks because inline prefix set the var in git's subshell, not the hook's env; new helper parses the command string for the pattern + falls back to process env)

Adopter was trying to: paste the `SKIP_FOO=1 git commit -m "..."` recipe from a BLOCK banner, have the hook actually honor the override, and move past the gate without having to export the var at shell level.
