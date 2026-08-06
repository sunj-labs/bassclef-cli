---
tier: standard
name: WU-1 repo shape — @thebassclef/core scaffold decomposition
slug: wu-1-repo-shape
authored: 2026-08-06
authored_by: agent
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
wu: 1
luminaries:
  primary: alan-cooper
  supporting: [john-ousterhout, saltzer-schroeder]
---

# WU-1 repo shape — @thebassclef/core scaffold decomposition

Bassclef bet 2026-08-06b WU-1 asks for a bootstrapped npm package repo.
This doc splits the work by responsibility BEFORE any code lands. Per
the bet's discipline touchpoints (L136), WU-1 opens with a decomposition
that names boundary + entity + control surfaces.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L121 (WU-1 scope), L136 (discipline touchpoint), L90-100 (npm best
  practices), L59-67 (three luminary framings)
- `HANDOFF.md` L11-19 (Turn 1 sequence + tech_stack answers)
- `.claude/bassclef-configs.jsonc` tech_stack block (lang=typescript,
  runtime=node20, pkg_manager=npm)
- `.claude/luminaries/alan-cooper.md` L36-48 (goal-directed design,
  personas as design tools) + L129-152 (worked example)
- `.claude/luminaries/john-ousterhout.md` L50-63 (deep modules,
  complexity is incremental, define errors out of existence)
- `.claude/luminaries/saltzer-schroeder.md` L69-88 (fail-safe defaults
  + complete mediation), L59-67 (economy of mechanism)
- Web (via bet doc refs, not re-fetched this session):
  https://medium.com/@ddylanlinn/npm-package-development-guide-...
  and https://evilmartians.com/chronicles/the-secure-way-to-release-an-npm-package
  for npm package.json shape norms.

## Boundary objects — what adopters touch

These are the surfaces Sam sees. Cooper's lens: what is her goal on
first contact, and does each surface serve it?

| Boundary | WU-1 responsibility | WU-2+ responsibility |
|---|---|---|
| `bassclef` CLI binary | dispatches `--version`, `--help`; stubs `init` and `sync` with "not yet — WU-2/3" message | `init` writes settings.json + kilo.json + substrate.config.md; `sync` upgrades in place |
| `@thebassclef/core` npm metadata | package.json with name, description, keywords, homepage, repository, license — shown on npmjs.com search results | version bumps on publish (WU-5) |
| README.md | Sam's first-touch; two commands + what she gets in ≤5 min | expanded with example configs, tier ladder, adopter FAQ (post-launch) |
| LICENSE | Apache-2.0 (per handoff memory `project-tarball-distribution-deprecated` cross-ref confirms Apache-2.0) | — |
| Programmatic API (`import ... from '@thebassclef/core'`) | minimal — a stub `version` export so consumers can inspect | fills as commands land |

## Entity objects — domain state

State the package holds or references. Ousterhout: each entity should
belong to exactly one deep module.

| Entity | Owner | Shape at WU-1 |
|---|---|---|
| Package version | package.json + built-in constant | Hardcoded `"0.0.1"`; WU-5 automates the bump |
| Node runtime constraint | package.json `engines` | `"node": ">=20"` per handoff answer |
| Substrate assets | (not yet — WU-2 consumes bassclef repo files) | none in WU-1 |
| Tier manifest | (not yet — WU-4 reads lite-manifest.json) | none in WU-1 |

## Control objects — application logic

Where routing and orchestration live. Ousterhout: deep modules;
Saltzer-Schroeder: complete mediation.

| Control | WU-1 shape | Grows into (later WU) |
|---|---|---|
| CLI dispatcher (`src/cli.ts`) | Parses `argv[2]`; switch on `init` / `sync` / `--version` / `--help`; unknown → error + usage | Same shell; command modules load lazily |
| Build (Vite lib mode) | Two entrypoints (`cli` + `index`); ESM + CJS; Node 20 target; externalizes Node built-ins | May switch to tsup if Vite proves overkill for a pure CLI — flag for pattern-review (Q1) |
| Publish (GH Actions) | Not built in WU-1 | WU-4: trusted publisher + tier filter + andon scan + provenance |

## Deep vs shallow module analysis (Ousterhout)

- **CLI dispatcher** SHOULD be deep — interface is `bassclef <cmd>`
  (small); implementation grows to include argv parsing + command
  loading + error handling + tier filter (large). WU-1 ships the shell
  only; depth accretes in later WUs.
- **package.json** is a DECLARATION not a module — depth doesn't
  apply. Ousterhout's comments-as-design lens still applies to any
  inline comments the format supports (it does not; jsonc extends
  json but package.json is strict json). Comments-as-design goes into
  README instead.
- **Vite config** SHOULD be small (economy of mechanism). Standard
  library-mode config; no plugins beyond what TypeScript needs. If it
  grows past 30 lines that's a signal to reconsider.

## Fail-safe defaults audit (Saltzer-Schroeder principle 2)

| Decision | Whitelist (fail-safe) | Blacklist (permissive) | Choice |
|---|---|---|---|
| What ships to npm | package.json `files` array (explicit list) | `.npmignore` (implicit deny-list) | **files whitelist** per bet L92 |
| Which Node versions can install | `engines.node: ">=20"` (deny <20) | absent field (any version tries) | **engines pinned** per handoff |
| Auto-run scripts on install | none | `postinstall` running arbitrary code | **no postinstall** |
| Auto-build on publish | separate build step | `prepublishOnly: "npm run build"` | **no `prepublishOnly`** per Evil Martians 2026 guide (bet L98) |

Every decision above is a fail-safe default. A future contributor who
adds a permissive shape has to argue against a written baseline.

## Cooper README pass — plain-language check

Bet L63: "If she hits jargon in the first 60 seconds, she bounces."
Ban words for the first paragraph of README:

- BLOCK: substrate, adopter, workunit, WU, telemetry, dispatcher,
  andon, tier filter, provenance, tarball, luminary
- ALLOW: install, run, works, minutes, plain English

The first paragraph must answer Sam's question: what is this and
what will happen if I run the two commands? Later paragraphs can
carry the terms of art.

## Open questions for /pattern-review

1. **Vite vs tsup for a CLI package.** The bet says "TypeScript +
   Vite build" (L121). Vite is web-tooling-primary; tsup is
   CLI-native. WU-1 uses Vite as-directed but flags this for review
   — if the WU-1 build feels heavier than it needs to be, tsup is
   the natural swap.
2. **Command module lazy-loading.** Should `src/cli.ts` dynamically
   import command modules (better cold-start, worse type-check
   surface), or eagerly import (simpler, all-loaded up-front)? WU-1
   ships eager; WU-2/3 may switch when the modules gain weight.
3. **Programmatic API surface.** Do we expose the command implementations
   as library exports (so consumers can call `import { init } from
   '@thebassclef/core'` and drive it programmatically), or keep the
   package CLI-only? WU-1 leaves `index.ts` a stub with only `version`;
   revisit at WU-4 when the publish pipeline knows what to include.

## Open questions for /architect-review

1. **Repo-boundary anticorruption layer.** Bet L124 names Vernon's
   anticorruption pattern between the tier manifest (bassclef repo)
   and this package's publish pipeline. WU-1 doesn't build the layer
   but should the CODE ORGANIZATION anticipate it? Proposal: reserve
   `src/pipeline/` folder for WU-4 so the boundary is visible from
   day one.
2. **Node 20 minimum vs Node LTS floor drift.** Node 20 goes to
   maintenance April 2026 and end-of-life April 2028. If we launch
   in Q3 2026, the pin is defensible. Post-launch reviewer question:
   do we bump the floor to 22 when 20 hits maintenance, and does that
   break adopters per ADR-031?

## What WU-1 must produce

- [ ] `README.md` — Cooper-lens first-touch signal
- [ ] `LICENSE` — Apache-2.0 verbatim
- [ ] `package.json` — bin, files whitelist, exports, main+module+types, engines
- [ ] `tsconfig.json` — Node 20 target, strict mode
- [ ] `vite.config.ts` — library mode, two entries (cli + index)
- [ ] `src/cli.ts` — shebang, argv dispatch, `--version` + `--help` implemented
- [ ] `src/index.ts` — programmatic entry with `version` export only
- [ ] `src/commands/init.ts` — stub that prints "WU-2 will land init"
- [ ] `src/commands/sync.ts` — stub that prints "WU-3 will land sync"
- [ ] `tests/cli.test.ts` — Vitest: `bassclef --version` prints the pinned version
- [ ] `.vitest/` or root vitest config
- [ ] Build succeeds (`npm run build` produces `dist/cli.js` + `dist/index.js`)
- [ ] Test passes (`npm test`)

## What WU-1 does NOT ship

- `bassclef init` real logic (WU-2)
- `bassclef sync` real logic (WU-3)
- Publish pipeline (WU-4)
- Versioning discipline doc (WU-5)
- Cold-adopter harness updates (WU-6)
- Security PRs (WU-7)
- Sam demo evidence (WU-8)

Everything above is out of scope. WU-1 lands the shell.
