---
tier: project
title: Intent audit — smoke evidence design artifacts
id: intent-audit-smoke-evidence-design
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture
mode: agent-reasoned (stub; live extract-intent needs Voyage keys)
status: draft
references:
  - path: docs/specs/smoke-evidence-capture.md
    role: audit target
  - path: docs/use-cases/UC-smoke-run.md
    role: audit target
  - path: docs/decompositions/smoke-evidence-capture.md
    role: audit target
---

# Intent audit — smoke evidence design

## Sources read

- `docs/specs/smoke-evidence-capture.md` — full read
- `docs/use-cases/UC-smoke-run.md` — full read
- `docs/decompositions/smoke-evidence-capture.md` — full read (spec + BCE)
- `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md` — full read; carries the declared `authoring_luminaries` block

## What I'm NOT reading (with reason)

- Voyage embedding output — stub mode; live `/extract-intent` needs Voyage keys per the skill description
- Every luminary file body — I use catalog descriptions from `.claude/skills/luminary/SKILL.md` and the anchor patterns each luminary is known for

## Method

Not a machine-embedding score. I read each design artifact, name the disciplines it actually invokes, match those disciplines to luminaries in the bassclef catalog, then compare against the goal doc's declared `authoring_luminaries` list. Drift means a lens shows up in the work but is not on the list.

This is stub mode. Live mode would run Voyage + Anthropic on the same three files and produce confidence scores per luminary.

## Declared authoring set (from goal 2026-09-18a)

- **Primary:** michael-feathers, jerome-saltzer-and-michael-schroeder
- **Supporting:** kent-beck, alistair-cockburn, donald-norman, john-ousterhout, gary-klein

## Per-artifact intent match

### Spec (`docs/specs/smoke-evidence-capture.md`)

| Section | Discipline invoked | Luminary match |
|---|---|---|
| Entity table | Deep modules with narrow interface | john-ousterhout ✓ (declared) |
| Actors + Preconditions + Postconditions | Actor-driven Cockburn shape | alistair-cockburn ✓ (declared) |
| Preconditions + Postconditions | Pre/post contract triples | tony-hoare — **not declared** |
| Acceptance criteria (measurable, numbered) | Measurable acceptance / TDD | kent-beck ✓ (declared) |
| Four checks | Complete mediation | saltzer-schroeder ✓ (declared) |
| Interfaces (script contracts) | Command pattern, narrow interface | ousterhout ✓ + GoF Command |
| Success metrics | Measurable behavior | michael-feathers ✓ (declared) |
| Directive quote at top | Assert-only-after-verify | toulmin / popper — **not declared** but rule-level (assert-only-after-verify.md) |

Spec matches the declared set well. One implicit lens: **tony-hoare** (pre/postconditions). Not declared; not a load-bearing gap since bassclef ships Hoare-adjacent discipline in the state-schema-validation rule.

### Use case (`docs/use-cases/UC-smoke-run.md`)

| Section | Discipline invoked | Luminary match |
|---|---|---|
| Fully-dressed shape | Cockburn use-case template | alistair-cockburn ✓ (declared) |
| Stakeholders + interests | Persona-driven design | alistair-cockburn ✓ + alan-cooper (implicit) |
| Special requirements (under 5 min) | Usability threshold | donald-norman ✓ (declared) |
| Extension 11b — timeout kill | Stability pattern (bulkhead / circuit breaker) | michael-nygard — **not declared** |
| Extension 15a — publish gh auth fails | Fail-soft on external service | michael-nygard — **not declared** |
| Extension 18a — agent fallback to local report | Defensive fallback | michael-nygard — **not declared** |
| Extension 3a — registry lag false-positive | Empirical calibration | ash-maurya (riskiest-assumption) — **not declared** |

**Drift signal:** michael-nygard shows up in three of ten extension branches. Not declared in the authoring set. The stability discipline is real work, not decoration. Recommendation: add michael-nygard to `supporting`.

### Decomposition (`docs/decompositions/smoke-evidence-capture.md`)

| Section | Discipline invoked | Luminary match |
|---|---|---|
| Entity model | Entity-relationship + Larman GRASP | GRASP roles cited directly (Larman is not a bassclef luminary; discipline is bassclef-native via GRASP) |
| GRASP role assignment | Larman GRASP (Information Expert, Controller, Creator, Low Coupling, Polymorphism, Pure Fabrication, Indirection, Protected Variations, High Cohesion) | Ancestor discipline; no direct luminary in bassclef catalog for Larman |
| Pattern catalog (Command, Strategy, Template Method, Composite, Adapter) | GoF | GoF catalog present in bassclef via `patterns/code/gof/` |
| Fixture Object | Fowler xUnit | martin-fowler — **not declared** |
| Fail-Fast | Nygard stability | michael-nygard — **not declared** (again) |
| Cross-cutting concerns table | Anticorruption layer + information hiding | david-parnas (info hiding) + vaughn-vernon (ACL) — **neither declared** |
| Sequence diagram (main flow) | UML sequence — Booch/Rumbaugh/Jacobson lineage | ivar-jacobson (BCE anchor) — **not declared** |
| "What NOT to build" | Conceptual integrity — cut features that add coupling | frederick-brooks + john-ousterhout ✓ (Ousterhout declared) — brooks **not declared** |
| BCE classification (Step 0d) | Jacobson OOSE | ivar-jacobson — **not declared** |
| BCE split rationale | Information hiding + one-responsibility | david-parnas — **not declared** |

**Drift signals:** ivar-jacobson (BCE anchor, unavoidable for Step 0d), michael-nygard (Fail-Fast), david-parnas (info hiding audit in split rationale), frederick-brooks (conceptual integrity in "What NOT to build"), martin-fowler (Fixture Object pattern), vaughn-vernon (ACL cross-cutting).

## Aggregated drift

| Luminary | Declared? | Where it shows up | Recommendation |
|---|---|---|---|
| **michael-nygard** | No | UC extensions 11b + 15a + 18a; Decompose Fail-Fast; Decompose cross-cutting | **Add to supporting.** Stability discipline pervasive. |
| **ivar-jacobson** | No | Decompose sequence diagram; Step 0d BCE section entirely | **Add to supporting.** Load-bearing for Step 0d. |
| **david-parnas** | No | Decompose cross-cutting (info hiding); Decompose BCE split rationale | **Consider adding to supporting.** Not load-bearing but present. |
| **frederick-brooks** | No | Decompose "What NOT to build" (conceptual integrity) | **Optional add.** One-off invocation. |
| **martin-fowler** | No | Decompose Fixture Object pattern | **Optional add.** One pattern reference. |
| **tony-hoare** | No | Spec pre/postconditions | **Optional add.** Bassclef rule ships Hoare discipline separately; may not need explicit lens. |
| **vaughn-vernon** | No | Decompose cross-cutting (ACL implied) | **Skip.** Weak implicit; not central. |
| **ash-maurya** | No | UC extension 3a (registry lag false-positive) | **Skip.** One implicit invocation. |

## Comparison to declared set

Declared primary set (feathers + saltzer-schroeder) — CONFIRMED. Both anchor real work. Feathers via characterization tests (fixtures for cli#101-#108). Saltzer-Schroeder via complete mediation (four checks per surface).

Declared supporting set (kent-beck + cockburn + norman + ousterhout + klein) — CONFIRMED. All present.

- kent-beck: measurable acceptance in spec, Tier 0 tests implied on scripts
- cockburn: fully-dressed UC-smoke-run
- norman: usability threshold in UC special requirements; report as signifier
- ousterhout: deep-module + narrow-interface language throughout decompose
- klein: pre-mortem light at Step 2a (deferred to Step 1 boundary)

## Recommendations (before code lands)

**Add to `authoring_luminaries.supporting` in the goal doc frontmatter:**

1. **michael-nygard** — load-bearing (three extension branches plus Fail-Fast plus cross-cutting)
2. **ivar-jacobson** — load-bearing (BCE section is entirely his lens)

**Optional adds:**

3. david-parnas — makes the info-hiding audit explicit
4. frederick-brooks — makes the "What NOT to build" scope discipline explicit

**Skip:** martin-fowler, tony-hoare, vaughn-vernon, ash-maurya — implicit invocations that don't need declaration.

## Verdict

Design honors the declared lens set. Two undeclared lenses (nygard, jacobson) do real load-bearing work; add them before Step 1 fires. Two optional adds (parnas, brooks) sharpen but do not change the design.

The RFC adversarial pass (next artifact) picks lenses **outside** this augmented set to catch what the authoring set — declared plus surfaced — misses.

## References

- Spec: `docs/specs/smoke-evidence-capture.md`
- Use case: `docs/use-cases/UC-smoke-run.md`
- Decomposition: `docs/decompositions/smoke-evidence-capture.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Skill catalog: `.claude/skills/luminary/SKILL.md`
- Extract-intent skill: `.claude/skills/extract-intent/SKILL.md`
