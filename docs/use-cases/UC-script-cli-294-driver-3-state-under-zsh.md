---
tier: lite
date: 2026-10-03
goal: cli#294 Step 5
code-class: new adopter-facing script (brief UC per .claude/rules/oo-ad-entry-point.md matrix row 7)
---

# UC-script-cli-294-driver-3 — state-under-zsh

## Primary actor

Smoke harness (CI docker-smoke OR local `bash scripts/tests/*.test.sh`).

## Goal

Assert that NO lib file in the bundled substrate carries a `local X=` declaration where `X` is one of the four zsh-magic linked variables (`path`, `cdpath`, `fpath`, `manpath`). Under zsh, these lowercase names tie to their uppercase forms (`PATH`, `CDPATH`, `FPATH`, `MANPATH`). A `local path="..."` inside a function wipes PATH for that function scope silently.

## Main success scenario

1. Harness enumerates every `*.sh` file under `dist/lite/lib/` (bundled view)
2. Harness enumerates every `*.sh` file under the sibling `lib/` as cross-check
3. For each file, harness greps for the four patterns: `local path=`, `local cdpath=`, `local fpath=`, `local manpath=`
4. Harness asserts total match count across all files == 0
5. Exit 0

## Extensions

- 4a. Any match in bundled or sibling lib → exit 1 listing the file + line + offending pattern
- Lib dir missing → SKIP (exit 77) with reason

## Preconditions

- Bundled lib reachable at `dist/lite/lib/` OR via `BASSCLEF_SIBLING_ROOT` OR via `~/src/sunj-labs/bassclef/lib/`
- Bash 3.2+ with grep

## Postconditions

- Current main: driver exits 0 (sweep held post-v1.7.0)
- Pre-cure commit (parent of upstream PR #2043): driver exits 1 (7 `local path=` matches in `lib/state.sh` alone)

## Pattern

Characterization test per @luminary michael-feathers. Pre-cure characterization: at the parent commit of upstream PR #2043, `grep -c "local path=" lib/state.sh` returns 7. Upstream PR #2045 extended the sweep to 10 more lib files + 24 more occurrences. Current cured state: zero matches across the lib tree.

## Covers

- Kunal #2036 finding #6 (zsh PATH kill — any state-reading skill failed silently when `lib/state.sh` sourced from zsh)

Adopter was trying to: run any bassclef skill that reads project state (`/sprint`, `/whereami`, `/temperance`, `/verify`) from their zsh shell without the first state call wiping PATH and breaking every subsequent subprocess.
