---
tier: standard
id: ADR-001
title: Pin build toolchain for @thebassclef/core — Vite (library mode) + TypeScript + Vitest
status: proposed
date: 2026-08-06
supersedes: null
superseded_by: null
---

# ADR-001 — Pin build toolchain for @thebassclef/core — Vite (library mode) + TypeScript + Vitest

## Context

Goal A bet `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
(L121) names "TypeScript + Vite build" as the WU-1 scaffold. This ADR
records that decision plus the sibling picks (test runner, type
checking, dts emission) it forces, so future contributors can see the
whole build stack in one place.

Forces at play:

- **Bet direction.** The bet is authored and reviewed; Vite was
  chosen there. Deviating requires an amendment to the bet, not a
  quiet swap in package.json.
- **CLI-package idiom drift.** Most modern npm CLI packages use
  `tsup` (esbuild-based, CLI-native), `unbuild`, or plain `tsc`. Vite
  is web-first with a library mode. The library mode is production-
  ready but underused for pure-CLI packages.
- **Test-runner co-locality.** Vitest ships from the same team as
  Vite, shares the config file, and reuses the resolver. Picking Vite
  effectively picks Vitest unless we accept two configs.
- **Node 20 floor** (per handoff). Node 20 lands `.js` extension
  requirements in ESM, native fetch, native test runner. All three
  choices (Vite, Vitest, TypeScript 5.5) support Node 20 cleanly.
- **Dual module (ESM + CJS).** The bet L94 requires both `main`
  (CJS) and `module` (ESM). Vite library mode emits both from one
  config; tsup and unbuild also do; `tsc` alone does not.
- **Sam's install path** (Cooper lens). Sam does not see any of
  this — she runs `npm install -g @thebassclef/core`. The build
  toolchain is invisible to her. This makes the trade-off
  developer-facing only.
- **CLI cold-start latency.** Vite output for a CLI can carry more
  runtime overhead than tsup's raw esbuild bundle. WU-1 does not
  measure this; if the smoke test in WU-8 shows cold-start over
  ~200ms on a fresh macOS install, the tsup swap is a candidate
  refactor.

## Decision

Adopt for WU-1:

- **Bundler** — Vite `^5.4.0` in library mode. Two entrypoints:
  `src/cli.ts` (produces `dist/cli.js`) and `src/index.ts` (produces
  `dist/index.js` + `dist/index.cjs`). Externalize Node built-ins.
- **Compiler** — TypeScript `^5.5.0`. `noEmit: true` on the config
  used for typechecking; emission happens via Vite's build.
- **Type declarations** — `vite-plugin-dts` `^4.0.0` to emit
  `dist/index.d.ts`.
- **Test runner** — Vitest `^2.0.0`. One config for build + test.

Rationale for accepting Vite over the CLI-idiom alternative (tsup):

1. **The bet named it.** Overriding a written bet decision inside WU-1
   without an amendment breaks the bet-as-source-of-truth discipline.
2. **Vitest co-locality** simplifies contributor onboarding — one
   config file, one resolver, one plugin ecosystem.
3. **Library mode is production.** Vite library mode powers many
   published packages (including several in the Vite ecosystem
   itself). Underused-for-CLI is not the same as unsuited-for-CLI.
4. **Escape hatch is cheap.** If the WU-8 Sam demo surfaces
   cold-start latency, swapping to tsup is a config-file change plus
   removing `vite-plugin-dts`. No source code churn.

## Status

`proposed` — WU-1 lands this ADR alongside the scaffold PR; operator
review flips to `accepted` (or requests amendment to `superseded_by:
ADR-NNN` if we swap to tsup at review time).

## Consequences

**Easier:**

- Vitest shares Vite's config, so one file drives both build and
  test.
- Adding future entrypoints (e.g., a `sync` command that also ships
  as `bassclef-sync` binary) is a `lib.entry` array edit.
- Dual-format emission (ESM + CJS) is a one-line change in the config.

**Harder:**

- Vite's docs are web-first. CLI-specific gotchas (shebang preservation,
  `node:` scheme externalization, tree-shaking Node builtins) require
  reading library-mode docs plus GitHub issues.
- Cold-start latency on a Node CLI is not Vite's design target. If
  it becomes a problem, we swap toolchains.

**Enables:**

- WU-4 publish pipeline can rely on `dist/` being self-contained
  (assets copied by Vite, source not shipped per bet L99).
- WU-5 semver methodology can trust that a version bump plus rebuild
  yields identical bit-for-bit output when source is unchanged
  (Vite is deterministic given pinned deps).

**Blocks (until reconsidered):**

- Switching to a monorepo layout (e.g., `packages/core` +
  `packages/init`) — Vite library mode supports it but adds a config
  layer.

**Invariants established:**

- No `prepublishOnly` script that auto-builds. Publish and build are
  separate steps (bet L98; Evil Martians 2026 guide).
- No source shipped to npm. Only `dist`, `README.md`, `LICENSE`
  (package.json `files` whitelist).
- Node 20 floor pinned in `engines`; refuse install below.

## References

- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L121 (WU-1 scope naming Vite), L92-94 (package.json shape), L98
  (no prepublishOnly), L99 (no source shipped)
- Decomposition: `docs/decompositions/wu-1-repo-shape.md` (Q1 flags
  the Vite-vs-tsup question for pattern-review — this ADR answers it
  with "Vite for now")
- ADR template: `standards/adr-template.md` (bassclef substrate)
- Vite library mode docs: https://vitejs.dev/guide/build.html#library-mode
- Vitest: https://vitest.dev/
- vite-plugin-dts: https://github.com/qmhc/vite-plugin-dts
- Alternative considered: tsup (https://tsup.egoist.dev/) — CLI-native,
  esbuild-based, smaller bundles; deferred pending WU-8 latency data.
