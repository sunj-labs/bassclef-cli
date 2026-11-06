---
tier: lite
ticket: cli#477
level: brief
primary_actor: adopter reading the output of their first `bassclef init`
---

# UC-cli-477 — The install banner fits on one screen

## Primary actor

Adopter running `bassclef init` for the first time, reading the output in a
terminal. Secondary actor: a maintainer or a test that needs the full list of
files the run wrote.

## Preconditions

- Adopter installed `@thebassclef/lite` and is in a project directory.
- The bundle ships files across roughly fifteen directories.

## Main success scenario

1. Adopter runs `bassclef init`.
2. Init prints one line per directory it wrote into, with a file count.
3. Init prints one total: files installed, split into config and substrate.
4. Init prints how many hooks armed, out of how many the settings declare.
5. When init left a file alone because one already existed, it says how many
   and names the flag that changes it.
6. Init prints the mark and the ready block.
7. Adopter reads the whole thing without scrolling back.

## Alternate flow — the reader wants the detail

2a. Adopter runs `bassclef init --verbose`.
2b. Init prints the pre-change output: one line per path, the substrate count,
    the grand total, and the statusline paths.

## Alternate flow — a test wants the file set

2a. Test runs `bassclef init`, then reads `.bassclef/init.manifest.json`.
2b. The manifest names every file the run touched, each with an outcome, and a
    SHA-256 on every file it created. Refused and errored files are recorded
    too, per ADR-010 D4, so a partial run reads as partial.

## Postconditions

- Default stdout carries no line matching `^  <path>: <n> files copied$`.
- No directory summary key ends in a file extension.
- `--json` emits the same report shape as before: `schema_version` 3.
- `--dry-run` output is unchanged.

## Why the detail is not on the default path

The per-file list is a debug read, and stdout is the wrong place to keep it.
The manifest already holds more than the banner ever did — outcome and hash per
file — and it survives the run, so it is what a test should assert against.
