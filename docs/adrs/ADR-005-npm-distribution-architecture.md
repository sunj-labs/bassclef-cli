---
tier: standard
id: ADR-005
title: Split bassclef distribution into two roads — CLI + templates via npm, substrate content via user-scope sync hook
status: accepted
date: 2026-08-08
accepted: 2026-08-08
accepted_via: shipped across PRs #1, #3, #4, #5, #7. This ADR pins the arc-level shape those PRs implement.
supersedes: null
superseded_by: null
authoring_luminaries:
  primary: [john-ousterhout, linus-torvalds]
  supporting: [alan-cooper, saltzer-schroeder, vaughn-vernon]
lead_lens: john-ousterhout
---

# ADR-005 — Split bassclef distribution into two roads

## Context

Goal A ships bassclef via npm as `@thebassclef/core`. That's the trigger for this bet. But bassclef has two very different content types:

1. **CLI code + templates** — a Node package. Small. Versionable. Fits npm's shape.
2. **Substrate content** — skills, rules, hooks, luminaries, agents. Large. Fast-moving. Read by Claude Code at every session start.

Bundling both into one npm package would work. Adopters would install one thing. But it forces every substrate change to a full npm publish. It also blurs two contracts — the CLI's public API (what `bassclef init` writes) and the substrate's shape (what `.claude/skills/*/SKILL.md` looks like).

Prior distribution attempts (per CLAUDE.md L18-21) used a tarball URL fetched by a per-repo `.bassclef-source.json` hook. That path had zero adopters. This bet replaces it.

## Decision

Ship bassclef over **two distinct roads**:

**Road 1 — CLI + templates via npm.**

- Package name: `@thebassclef/core`
- Contents: compiled TypeScript in `dist/`, `README.md`, `LICENSE`. Nothing else.
- Package.json `files` field is an explicit whitelist (per ADR-001).
- Init templates are TypeScript string constants under `src/commands/init-templates/`, compiled INTO `dist/cli.js` at build time. No runtime disk read for templates.
- Adopter runs `npm install -g @thebassclef/core` once. Then `bassclef init` in each project.
- Version cadence: semver. Each bump is deliberate (WU-5 defines the bump policy).
- Publish gate: GitHub Actions workflow with trusted publisher, tag validator, andon scan, tier filter, operator approval (per ADR-004).

**Road 2 — Substrate content via user-scope sync hook.**

- Substrate content lives in the bassclef repo (separate GitHub repo).
- Adopter's `~/.claude/hooks/bassclef-sync.sh` fires at every SessionStart.
- The hook symlinks `.claude/skills/`, `.claude/rules/`, `.claude/hooks/`, `.claude/luminaries/`, `.claude/agents/` from the bassclef repo into the adopter's project directory.
- Version cadence: continuous. Substrate updates land as they ship in bassclef.
- No dependency on npm publish cycles.
- Setup lives outside bassclef-cli's scope. This bet does not build or ship the sync hook.

## Why split

**John Ousterhout — deep modules with clean interfaces.**

Road 1's interface is small: `npm install -g @thebassclef/core && bassclef init`. Two commands. The implementation hides package.json contract, files whitelist, template rendering, atomic writes, manifest tracking. Road 2's interface is also small: SessionStart fires; skills appear. Bundling the two roads collapses their interfaces into one giant surface. Splitting them keeps each interface honest to its own contract.

**Linus Torvalds — do not break adopters.**

Substrate content moves often. Bassclef ships new skills weekly. Bundling substrate into npm would mean every substrate change forces a package version bump. Adopters who pin `@thebassclef/core@0.1.0` would then miss substrate updates. That breaks the "always current substrate" promise. Road 2's continuous sync keeps that promise without disrupting Road 1's semver discipline.

**Alan Cooper — Sam's install path stays two commands.**

Sam runs two things: `npm install -g @thebassclef/core` and `bassclef init`. That is her whole surface. She does not think about substrate distribution. The bassclef-sync hook is a separate operator-time setup, not Sam's problem on first install. Splitting the roads keeps Sam's first-touch shape simple.

**Saltzer-Schroeder — least common mechanism.**

Two roads means two failure modes stay independent. A broken npm publish does not break substrate sync. A broken substrate change does not break the CLI. Blast surfaces are contained.

**Vaughn Vernon — anticorruption between contexts.**

The npm package's world (semver, versioned artifacts, provenance attestation) is distinct from bassclef's substrate world (session-time refresh, symlinks, tier filtering). The two-road split IS the anticorruption layer. Neither road's changes force reshapes on the other.

## What Road 1 explicitly does NOT ship

- Skills (`.claude/skills/*/SKILL.md`)
- Rules (`.claude/rules/*.md`)
- Hooks (`.claude/hooks/*.sh`)
- Luminaries (`.claude/luminaries/*.md`)
- Agents (`.claude/agents/*.md`)
- The `bassclef-sync.sh` script itself
- `.bassclef-source.json` per-repo config (deprecated; memory `project-tarball-distribution-deprecated`)

The `files` field in package.json enforces this whitelist. The tier-filter script in the publish pipeline (per ADR-004) catches any file whose frontmatter carries `tier: upstream` and refuses to publish it.

## Consequences

**Easier:**

- Semver on the CLI stays clean. Only Road 1 changes bump the version.
- Substrate updates ship without publish ceremony.
- Two teams (or one operator wearing two hats) can move Road 1 and Road 2 on independent cadences.
- Rollback is per-road. A bad npm publish rolls back via `npm deprecate` without touching substrate. A bad substrate change rolls back by reverting the bassclef repo commit.

**Harder:**

- Adopter setup is two steps, not one. First `npm install -g @thebassclef/core`. Then the operator installs the user-scope `bassclef-sync` hook separately.
- Discovery: an adopter who installs from npm but never sets up the sync hook gets a working CLI with no substrate. That is a failure mode WU-9 acceptance testing must catch (Sam demo per bet L128).
- Two version stories: npm package version + bassclef substrate release tag. Adopters who ask "what version am I on?" get two answers. Documented in the CLI's `--version` output as a follow-on.

**Enables:**

- Future substrate bundling (opt-in) via a new `@thebassclef/lite` package if adopters ask for the one-command shape.
- Future tier packages (`@thebassclef/standard`, `@thebassclef/ultra`) each with different bundled substrate slices per bet #1143.
- Kilo runtime port (Phase 2 per bet L168) can consume Road 1 as-is without depending on Road 2.

### Namespace reservation

The three future package names (`@thebassclef/lite`,
`@thebassclef/standard`, `@thebassclef/ultra`) sit inside the
`@thebassclef` npm scope, which the maintainer already owns via
`@thebassclef/core`. Anyone with a free npm account can register a
package name inside a scope they do not own only if the scope's owner
has not claimed it. The reservation shape:

1. Publish an empty `0.0.1` scaffold under each name via manual
   `npm login` + `npm publish --access public`. Same one-time step as
   `@thebassclef/core@0.0.1` per `docs/publish-setup.md` L21-31.
2. Package pages carry a README that says "reserved for future
   bundled variant per ADR-005; do not install."
3. When the actual variant ships, the version bump goes through the
   workflow at `.github/workflows/publish.yml` per ADR-004.

Namespace reservation is operator work; the CLI cannot log into
npmjs.com. Tracked as a follow-on operator ticket. See the bassclef-cli
issue tagged `namespace-reservation`.

**Blocks:**

- One-command install with substrate baked in. Adopters who want that either wait for a future `@thebassclef/lite` package or do the two-step setup.

## Relationship to sibling ADRs

This ADR is the arc-level shape. The 4 sibling ADRs pin WU-level contracts:

- **ADR-001** pins the build toolchain that produces Road 1's `dist/` output.
- **ADR-002** pins the safety contract for `bassclef init` — Road 1's first-touch surface.
- **ADR-003** pins the safety contract for `bassclef sync` — Road 1's upgrade surface.
- **ADR-004** pins the safety contract for the publish pipeline — Road 1's ship path.

No sibling ADR covers Road 2 yet because Road 2 is out of scope for this bet.

## What this ADR does NOT cover

- The exact shape of the user-scope `bassclef-sync` hook (lives in bassclef repo; separate governance).
- Which specific substrate items ship in the future `@thebassclef/lite` bundled variant.
- The Kilo runtime port shape.
- MCP server integration.
- Standard-tier and ultra-tier npm packages (deferred per bet L172).

## References

- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- Sibling ADRs: ADR-001, ADR-002, ADR-003, ADR-004
- CLAUDE.md L18-21 — deprecation of the per-repo tarball path
- Bassclef substrate discipline: `.claude/rules/we-dont-break-adopters.md` (Linus anchor)
- Bassclef upstream ticket #1143 — tier manifest as contract across tiers
- Memory: `project-tarball-distribution-deprecated`
