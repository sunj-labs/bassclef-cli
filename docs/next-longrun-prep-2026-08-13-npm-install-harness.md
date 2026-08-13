---
date: 2026-08-13
prepared_for: next /longrun session
goal_slug: 2026-08-13-npm-install-harness
tier: lite
parent_goal: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
---

# Next /longrun prep — npm install harness with full OOAD ceremony

## Problem (≤500 chars)

`@thebassclef/core@0.0.2` ships to npm, but no adopter-facing test verifies the published tarball installs cleanly and runs from a fresh fixture. Substrate defects — missing bin entry, wrong permission bits on `dist/cli.js`, broken shebang, dependency in `devDependencies` that should have been in `dependencies` — will surface at first adopter install, not in bassclef-cli's own tests. We need a harness that pulls the published tarball into a fresh temp dir and verifies `bassclef --version`, `bassclef init`, and `bassclef sync` all work end-to-end.

## Goal

Ship a first-class test harness for the published npm package with full OOAD discipline per operator direction:

> harness should get deep treatment with /objectory-decompose /use-case and /decompose as needed with /luminary on board with 1) ADR creation 2) Appropriate annotation - @pattern, @requirement, etc. 3) traceability mechanics wired in from the start

## /longrun prep proposal (options for operator to pick from)

### Option a — Minimum viable harness (~40-60 turns)

Scope:
- `/use-case` brief for "verify shipped tarball installs + runs"
- `harness/npm-install.test.ts` — fresh temp dir, `npm pack` then `npm install ./thebassclef-core-<version>.tgz`, run three verbs, assert exit codes + stdout
- `.github/workflows/harness.yml` — runs on release published event, gates on green
- ADR-006 pins the harness contract
- New requirement R-NPM-014 in registry
- `@requirement R-NPM-014` on source, `@verifies R-NPM-014` on harness

Trade-off: ships fast, misses fixture and decomposition discipline the operator asked for.

### Option b — Full OOAD ceremony (~120-180 turns) — RECOMMENDED

Scope per operator direction:

1. **/objectory-decompose on harness domain** — enumerate the objects (Fixture, TarballPack, InstallScope, CliInvocation, VerificationResult, HarnessRun). One paragraph per with responsibilities.
2. **/use-case UC-npm-install-harness.md** — fully-dressed use case per Cockburn. Actors: harness runner, adopter proxy. Preconditions, main success scenario, extensions, guarantees. Reads at fully-dressed depth because it drives the design.
3. **/decompose** — GRASP responsibility assignment for the six objects. Which class owns tarball creation? Which owns temp dir lifecycle? Which owns the run-verify loop?
4. **/luminary consult** — Feathers (characterization tests as adopter contract), Cockburn (walking skeleton first), Cooper (adopter as end user, not developer), Nygard (fail-safe defaults on cleanup). Additional lenses surface during design.
5. **ADR-006** — pins the harness contract:
   - Harness lives in `harness/` (separate from `tests/` because it exercises the built artifact, not the source)
   - Harness is git-tracked (not gitignored) per operator direction ("harness should get deep treatment")
   - Uses `npm pack` (not published tarball fetch) to run on unreleased commits too
   - Runs in CI on `release: published` AND on-demand via workflow_dispatch
   - Follows the tier-alignment discipline — harness stays in bassclef-cli, not published
6. **@pattern annotations** — mark the Fixture pattern (Fowler), the ScopedTempResource pattern, the Command Object pattern (GoF) if they appear
7. **@requirement R-NPM-014** on harness source; **@verifies R-NPM-014** on harness tests
8. **Traceability wired in from start** — R-NPM-014 registry row lands with satisfy + verify paths populated in the same PR that ships the harness
9. **Tier 0 strict TDD** — test list block on every harness test file per `.claude/rules/test-list-discipline.md`

Trade-off: 3-4x the time of option a, but earns the discipline the operator called out. Class-fix, not instance-fix.

### Option c — Full OOAD plus adopter-facing checklist (~200-280 turns)

Everything in option b, plus:
- `docs/adopter-first-install-checklist.md` — what an adopter should see, in order, when they `npm install -g @thebassclef/core && bassclef init`
- `harness/scenarios/` — one folder per adopter scenario (empty repo, existing repo, upgrade path)
- Bassclef-upstream cross-referenced tickets for the runbook + template gaps surfaced this session

Trade-off: closes more class-level substrate gaps but pulls scope wide. Consider splitting into option b + a follow-on if operator wants to protect scope.

## Recommended option

**Option b** — matches operator direction exactly. Deep OOAD ceremony with ADR-006, luminaries, `@pattern`/`@requirement`/`@verifies` annotations, and traceability wired in from the start.

## Compounding value per option

| Axis | Option a | Option b (rec) | Option c |
|---|---|---|---|
| Where the payoff shows up | first release under harness | every future release + every adopter | every release + every adopter + upstream runbook |
| How often it fires | per-release | per-release + per-adopter session | per-release + per-adopter + per-upstream-goal |
| What must be true first | 0.0.2 on npm (done) | 0.0.2 + operator on OOAD ceremony | option b + upstream capacity |
| Does this teach a shape later work reuses | limited | yes — decomposition + luminary map + ADR reusable across every install-flow harness | yes plus adopter-first framing generalizes |
| What breaks if we ship this half-done | first adopter hits raw failure | class not fully closed; some drift possible | scope creep + partial upstream artifacts |

## Adopter benefit per option

| Axis | Option a | Option b (rec) | Option c |
|---|---|---|---|
| Mechanism | binary go/no-go on release | reproducible install scenario + visible use case | option b + written checklist |
| Visibility | CI badge | ADR + registry + harness in the repo | ADR + registry + harness + checklist |
| Action | operator reads CI status | operator + future contributor reads the use case to extend the harness | operator + adopter reads the checklist |

## Step sequencing for option b (recommended)

| Step | Produces | Consumes (from prior step) | Risk |
|---|---|---|---|
| **0** prep | goal doc + temperance marker + luminary map + parent goal walk read | session-start | low |
| **1** /objectory-decompose | 6-object domain enumeration in docs/decompositions/npm-install-harness.md | prep luminary map | low |
| **2** /use-case UC-npm-install-harness | fully-dressed UC in docs/use-cases/ | Step 1 objects | low |
| **3** /decompose (GRASP) | responsibility assignment matrix inside the decomposition doc | Step 1 objects + Step 2 UC | low |
| **4** ADR-006 | pins harness contract, 5 decision points | Step 2 UC + Step 3 GRASP | medium |
| **5** R-NPM-014 registry row | requirement diagram + registry line added | Step 4 ADR | low |
| **6** harness/npm-install.test.ts + fixtures | Tier 0 tests with `@verifies R-NPM-014` + test-list block | Steps 1-5 as spec | medium |
| **7** .github/workflows/harness.yml | CI job wired on release + workflow_dispatch | Step 6 test file | low |
| **8** annotations pass | `@requirement R-NPM-014` on harness source, `@pattern` on any embodied patterns | Step 6 code | low |
| **9** integration verify | full workflow fires green on a synthetic release | Steps 6-8 | medium |
| **10** session close | session log + whereami + PR | Steps 0-9 | low |

## Per-step compounding for option b

Each step's produces feeds the next. No parallel-safe steps except step 8 which could ride any prior. Chain shape is a straight line — canvas → spec → design → test → CI → verify → close.

## Time budget grounding

Cite: bet 2026-08-06b (WU-1 through WU-5, roughly 350 turns across 6 sessions) — average ~60 turns per WU with heavy test setup. This harness is bigger (crosses filesystem, tarball, install, CLI invocation) but the OOAD ceremony front-loads the design decisions. Similar shape to WU-3 sync command (~90 turns, deep decomposition + fixture-heavy). Range: 120-180 turns for option b, high end covers characterization-test discovery per Feathers.

## Luminary map for option b

- Primary: **Michael Feathers** — characterization tests pin the actual adopter contract; the harness IS the characterization test at the adopter boundary
- Primary: **Alistair Cockburn** — walking skeleton first (thin end-to-end path); fully-dressed use case
- Supporting: **Alan Cooper** — adopter is not a developer; harness reads the same UX the adopter sees
- Supporting: **Michael Nygard** — fail-safe defaults on cleanup (temp dirs, background processes)
- Supporting: **Sophia Prater (OOUX)** — object model before actions in step 1
- Supporting: **John Ousterhout** — deep modules for the harness helpers (thin wrapper over rich fixture logic)

## References this session's work

- ADR-005 (npm distribution architecture) — parent decision the harness verifies
- R-NPM-006, R-NPM-011 (trusted publisher + first tagged release) — cured this session
- `docs/session-logs/2026-08-13-iteration-e-plus-npm11-cure.md` — the release-arc session that closed iteration e
- `.claude/rules/oo-ad-entry-point.md` — the discipline this /longrun honors
- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD applies (harness IS substrate-adjacent)

## Ready for /longrun prep dispatch

Operator confirms option → next session opens with `/longrun prep` and this doc as the parent context. Steps 0 through 10 above are the step table Step 1.7 of the prep will render.
