---
date: 2026-09-11
goal: 2026-09-11-zero-state-nudge-plus-straplines
lenses:
  primary: alan-cooper
  supporting: [jerome-saltzer-and-michael-schroeder, john-ousterhout]
shape: pre-mortem-light
---

# Pre-mortem light — zero-state nudge + strapline promotes

3 lenses × 3 risks. 30-minute Klein workshop shape. Strongest concerns fold into acceptance criteria.

## Cooper (adopter UX)

- **R1** Nudge string names the wrong verb; the reader gets pointed at a verb that does not fix their state. Cure — pin the nudge string in a constant. Add a test that asserts the constant matches `bassclef is not set up here yet — run \`bassclef init\` first`. Folded into Step 2.
- **R2** Future verbs miss the preflight check because it lives at each verb's dispatch site. Cure — put the detector call in a small preflight function; document the extension point in the source comment. Folded into Step 3.
- **R3** Exit 1 breaks a shell script that wraps `bassclef sync` in a loop. Cure — call this out in the ticket #55 out-of-scope section; document exit code in `bassclef --help` sync help output. Folded into Step 3.

## Saltzer-Schroeder (mediation)

- **R4** Detector fails on a read-only directory or a directory the process cannot stat. Cure — the detector reads `.bassclef/init.manifest.json`; a read error is treated the same as absence (nudge fires). One test covers the read-error path via chmod.
- **R5** Nudge fires before flag parsing; `bassclef sync --help` might not print. Cure — the existing dispatcher already checks `--help` before `runSync`. My preflight fires after the `--help` check. Verified by reading `src/cli.ts` L58-67 before writing.
- **R6** Detector logic runs on every invocation. Cure — read the file once per run; no cache needed at this scale. Fine.

## Ousterhout (deep modules)

- **R7** Detector couples to `.bassclef/init.manifest.json` path. An ADR-002 change would drift the check. Cure — reuse the existing manifest loader if one exists; otherwise document the path constant in one place and cite ADR-002.
- **R8** Preflight pattern needs a clear extension point for future verbs. Cure — a small `requireInit(verb: string)` helper; call from each verb entry point. Documented in the source.
- **R9** Temp-dir fixtures in tests may slow the suite. Cure — use `mkdtemp` per test, clean up in afterEach. No shared state.

## Strongest concerns

R1 + R3 + R7. All fold into Steps 2-3.

## Refs

- Ticket #55 body (open on bassclef-cli)
- `src/cli.ts` L58-67 — existing verb dispatch reads
- ADR-002 (bassclef init safety contract) — manifest path convention
- `.claude/rules/loop-discipline.md` Step 0.5 — pre-mortem light discipline
