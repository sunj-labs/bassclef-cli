---
tier: upstream
ledger_id: 2026-09-22c-cli-217-drive-shape-pre-mortem
parent_goal: 2026-09-22c-cli-217-drive-shape-cure
ledger_mode: light (3 in-lens luminaries × 5-8 risks; 30 min per Klein)
authoring_luminaries: [michael-feathers, kent-beck, alan-cooper]
---

# Pre-mortem light — cli #217 drive-shape cure

## Sources read

- `docs/goals/2026-09-22c-cli-217-drive-shape-cure.md` — scope + acceptance
- `docs/use-cases/UC-hook-docker-smoke-drive-shape.md` — flow + extensions
- `docs/decompositions/2026-09-22c-cli-217-drive-shape-cure.md` — BCE + interfaces + prompt templates
- cli #212 chronicle (prior_operator_recap 2026-09-22b) — sister full-ceremony pattern

## Method

Klein pre-mortem light: "Imagine this cure has SHIPPED and DOES NOT WORK. What went wrong?"

Three lenses. Each lens surfaces 5-8 risks. Top 3 across lenses fold into the plan.

---

## Lens 1 — Michael Feathers (characterization)

**F1** — Natural-language prompt still doesn't dispatch the skill. LLM interprets the prompt as "explain what /temperance would do" not "actually run /temperance". Capture reads plausible; marker never lands. Positive-artifact check catches this class → GREEN cure.

**F2** — Prompt phrasing sensitive to LLM version. `run the /X skill` works on Sonnet 4.7 but returns explanation on Haiku. Docker container may run different model than local repro.

**F3** — Skill name in prompt is misinterpreted as URL path (LLM assumes `/temperance` is a route to visit). Fold: template says "the /X skill" not bare "/X".

**F4** — Existing tests characterize the WRONG shape (leading-slash) and my new tests won't run until I delete or update them. Full suite may fail on characterization tests baked into the old behavior.

**F5** — Positive-artifact assertion for `/luminary don-norman` matches false-positive when LLM merely mentions "Norman" in preamble ("You want the Don Norman lens? Here's the summary..."). Assertion fires PASS even without a real dispatch.

**F6** — Container caches an old bassclef-lite version; the fixed drives run against a stale substrate; skills that need substrate absent silently no-op.

**Top-fold:** F1 + F4 + F5.

---

## Lens 2 — Kent Beck (TDD RED-first)

**B1** — I write green tests first because "the fix is obvious", skip RED — fix is subtle and I ship a passing test suite that misses the core failure class.

**B2** — Tier 0 tests spawn `bash smoke-drive-skills.sh` but pass a mock `claude` binary that always echoes success. Test is a tautology. Cure: mock must be able to echo "Unknown command" too.

**B3** — Tests use `mkdtempSync` for isolated scratch dirs but the drive scripts write markers to `state/markers/temperance/` under CWD — not under scratch. Marker check must inspect the RIGHT dir.

**B4** — Test `describe` blocks share module-level state; parallel vitest runs step on each other's marker dirs. Non-deterministic RED/GREEN.

**B5** — I refactor smoke-assert.sh (Strategy extension) without a RED test for the refactor. Old check breaks; suite green because no test catches the regression.

**B6** — Ship the cure with test-mtime > source-mtime, satisfies `testing-tier-enforce.sh` mechanically, but test suite only covers new asserts — old checks lose their tests silently.

**Top-fold:** B1 + B2 + B3.

---

## Lens 3 — Alan Cooper (adopter mental model)

**C1** — Natural-language prompt does dispatch, but LLM asks clarifying questions instead of running the skill. Capture shape is "Which repo? What scope?" — no marker, no output. Sam or Louis in real container sees "Waiting for your input..." with no way to reply.

**C2** — Real adopter Sam types `/temperance` interactively and it works — my drive's natural-language prompt is a proxy that doesn't match Sam's actual workflow. Cure passes smoke but doesn't test the shape Sam uses.

**C3** — Positive-artifact for `/kiss words` says "contains 'rewritten' OR 'grade' OR 'words'". LLM output naturally contains "words" in almost any reply about rewriting. False-positive PASS.

**C4** — /luminary don-norman prompt "show me the lens summary" — LLM produces a summary from memory without reading the actual luminary file. Capture reads correct but no substrate touch happened; the skill body was never loaded.

**C5** — Container error message when Unknown command fires is not surfaced to a real Sam who types `/temperance` on the CLI — Sam sees "Unknown command" and thinks his install is broken. Cli-side skill-invocation error UX is a separate cure but the smoke should flag it.

**C6** — Adopter drive uses natural-language for smoke, but adopter's own onboarding docs teach `/temperance` (leading-slash interactive) — smoke and docs test different things. Adopter believes smoke covers their real path.

**Top-fold:** C1 + C4.

---

## Folded top-3

1. **F1 (Feathers)** — LLM interprets natural-language as "explain" not "run". CURE: positive-artifact check (marker file, not just phrase) is the load-bearing signal. Phrase-based checks stay as secondary; primary is filesystem artifact.

2. **B2 (Beck)** — Test mock `claude` binary must include an Unknown-command fixture that mimics the failure class. CURE: RED test fixture that reproduces the "Unknown command" no-op is the FIRST test written.

3. **C1 (Cooper)** — LLM asks clarifying questions with no reply channel. CURE: prompt template includes concrete scenario ("for the scope decision 'add a login button'") that fully specifies the input — no clarifying question possible.

## Non-folded but noted

- **F5 / C3** — phrase-based positive checks can false-positive. Where possible, prefer filesystem artifact over phrase match. Where phrase-based is unavoidable (`/luminary` doesn't touch disk), use ≥2 distinct phrases with AND semantics (e.g., "Norman" AND "lens").
- **B3** — marker checks must inspect the scratch's `state/markers/` subtree, not the harness's own.
- **C2 / C6** — real adopter uses leading-slash interactive; the drive is a proxy. Discovery for follow-on: build an interactive-proxy drive at some later point. Not this ticket.

## Refs

- `.claude/skills/pre-mortem/SKILL.md` light mode
- `.claude/luminaries/gary-klein.md` — pre-mortem method anchor
