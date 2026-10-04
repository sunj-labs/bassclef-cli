---
ticket: cli#348
ceremony: brief (Cockburn — adopter-facing workflow per `.claude/rules/oo-ad-entry-point.md`)
primary_luminary: michael-nygard
supporting:
  - michael-feathers
  - linus-torvalds
---

# UC-script-cli-348 — matrix cells skip missing tests on old tags

## Primary actor

CI runner on a smoke-matrix cell that checked out a tag predating the test file.

## Goal

The step exits 0 and logs `SKIP: <file> not present at <sha> — tag predates test`. The cell shows green in PR Checks. The operator reader can grep logs for `SKIP:` to count expected skips vs real passes.

## Preconditions

- Matrix cell has checked out a tag (not main).
- The tag ref does not have the test file at its expected path.

## Main success scenario

1. Step iterates the test file list.
2. For each file, step checks `[[ -f <file> ]]`.
3. File present: step runs `bash <file>` and reports its exit.
4. File absent: step echoes `SKIP: <file> not present at $(git rev-parse --short HEAD) — tag predates test` and continues.
5. Step exits 0.
6. PR Checks shows the cell green.
7. Nightly status reader counts SKIP lines to understand matrix coverage.

## Extensions

- 2a. File present on main but absent on tag: main cell runs; tag cell skips. Expected.
- 2b. File present on tag but absent on main: unexpected shape; operator sees unexpected SKIP on main (signal, not noise).
- 2c. Driver loop step: already uses `shopt -s nullglob` to skip absent globs. No change needed.

## Postconditions

- All matrix cells show green when their refs lack the expected tests.
- Overall workflow passes (unchanged — `continue-on-error: true` was already set at job level).
- Each SKIP is traceable: file path + short SHA logged.

## Why this is brief ceremony

Per `.claude/rules/oo-ad-entry-point.md` — adopter-facing script. Workflow edit, no new interface, one shape test. Fully-dressed would be drag.

## Pattern

Null Object / Fail-Safe (Nygard). Missing file acts as a null; the guard converts it to a visible SKIP log.
