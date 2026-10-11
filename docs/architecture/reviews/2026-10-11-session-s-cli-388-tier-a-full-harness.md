---
tier: standard
date: 2026-10-11
primary_lens: michael-feathers
supporting_lenses: [john-ousterhout, jerome-saltzer-and-michael-schroeder]
prior_review: docs/architecture/reviews/2026-10-10-session-p-cli-415-cross-repo-validator.md
coverage_marker: state/markers/architect-review/2026-10-11-session-s-cli-388.marker
scope: Session S Step 4 — architect-review on full Tier A harness (cli#388; deferred from Session L PR 8)
pr_reviewed: sweep (no single PR; see artifacts table below)
---

# Architect review — cli#388 Tier A full harness

## Verdict

**READY.** The 6-driver walking skeleton proves the Cooper 3-level + 3-fixture pattern. Fixture-driven characterization per Feathers works end-to-end. Chain helper earns its place for the 3 Jamie drivers that chain planning + build turns. Five Q1 findings filed as follow-on tickets; none block adopter use of the harness. The harness ships honest adopter signal today.

## Scope

11 artifacts covered. Line counts and top SHAs pinned per Feathers R2 risk mitigation (`docs/risk-ledgers/2026-10-11-session-s-go-c.md` L37).

| File | Lines | Last commit | Purpose |
|---|---|---|---|
| `scripts/lib/claude-chain.sh` | 161 | `d1de3cb` (cli#375 Session K PR 5) | multi-turn `claude -c` chain helper |
| `scripts/lib/persona-assert.sh` | 144 | `55445b1` (cli#375 Session I walking skeleton) | Cooper 3-level goal assertions |
| `scripts/tests/smoke-drive-flows-registry.sh` | 59 | `e6bf3fe` (cli v1.9.12) | ADR-011 D4 flow driver registry |
| `scripts/tests/smoke-drive-e2e-sprint-louis.test.sh` | 123 | `10dd546` (Session L real captures) | Louis × /sprint |
| `scripts/tests/smoke-drive-e2e-whereami-louis.test.sh` | 94 | `247bcd9` (Session J real captures) | Louis × /whereami |
| `scripts/tests/smoke-drive-e2e-onboard-repo-sam.test.sh` | 116 | `247bcd9` (Session J real captures) | Sam × /onboard-repo |
| `scripts/tests/smoke-drive-e2e-riff-jamie.test.sh` | 130 | `10dd546` (Session L real captures) | Jamie × /riff |
| `scripts/tests/smoke-drive-e2e-launch-jamie.test.sh` | 96 | `10dd546` (Session L real captures) | Jamie × /launch |
| `scripts/tests/smoke-drive-e2e-build-jamie.test.sh` | 105 | `c4fa54b` (Session M env-partial twin) | Jamie × /build |
| `.github/workflows/docker-smoke.yml` | 181 | `662cf83` (PR #414 Node + Ubuntu pin) | Linux CI complement to macOS OrbStack |
| `.github/workflows/lite-adopter-smoke.yml` | 173 | `a64b571` (cli#407 test family rename) | Matrix-last-3-releases regression gate |

Total: 1,382 lines across libs + 6 drivers + 2 workflows.

## Methodology

**Primary lens — @luminary michael-feathers.** Characterization tests pin shipped behavior. Each driver reads a captured fixture and asserts 3 Cooper goals against it. Fixture provenance (hand-crafted → docker-captured once cli#380 OAuth refresh lands) is the migration path per cli#388 scope angle 3.

**Supporting lens — @luminary john-ousterhout.** Deep module shape. `claude-chain.sh` and `persona-assert.sh` present narrow interfaces (2 functions + 3 functions respectively) that hide big internals (perl SIGALRM timeout, output-block extraction, exit-code preservation). Both libs cite their contracts in header comments.

**Supporting lens — @luminary jerome-saltzer-and-michael-schroeder.** Complete mediation. Every driver goes through the two libs; neither bypasses to call `claude` directly. The env-var contract (CLAUDE_BIN, CLAUDE_CHAIN_TIMEOUT_SEC, CLAUDE_PERMISSIONS) mediates every chain turn.

## cli#388 review angles — answers

Five angles named in cli#388 body. Each gets a direct answer below.

**Angle 1 — Interface shape across 6 drivers; is Cooper 3-level + 3-fixture the right abstraction, or does it drag at 7?** Still right at 6. Two drivers (Sam, Jamie-build) added a 4th case for shipped-behavior extension (prereq-missing, env-partial); the 4th case does not break the pattern — it extends it. Pattern survived cli#407 test family rename cleanly. See F-TierA-04 for the ADR note.

**Angle 2 — Chain helper vs direct `claude -p`; is the sourced helper earning its place in drivers that don't yet multi-turn?** Yes for Jamie (3 of 6); no for Louis + Sam (0 of 3). Clear persona split. Jamie's drivers chain planning turn + build turn; Louis + Sam work with a single first-touch capture. The split IS the design — not a defect. See F-TierA-06 (deferred) for the "will Louis/Sam ever chain?" question.

**Angle 3 — Fixture provenance plan; hand-crafted now, docker captures after OAuth refresh. Document the migration path.** Partially documented. 4 of 6 fixtures have a README; 2 don't. No central provenance doc. See F-TierA-03.

**Angle 4 — persona-assert lib boundaries; is `_persona_extract_output_block` still the right split with 6 drivers calling it?** Yes. The extractor hides the `=== output ===` ↔ `=== exit:` convention; drivers never touch that boundary directly. Narrow interface earns its place.

**Angle 5 — Test-sufficiency; are 3 Cooper goals sufficient, or does a 4th (performance / latency / token-count) earn its place?** 3 is sufficient. End + experience + life cover the lovability signal Cooper's framework targets. A 4th performance goal would tilt toward CI health, not adopter experience. See F-TierA-05 for the ADR-011 note.

## Q1 findings (capped at 5 per Session S pre-mortem OUST-R2)

### F-TierA-01 — Life ceiling drift across drivers; 4 values unratified

The scan-ceiling value passed to `persona_assert_life_goal` drifts across drivers.

- **40 lines**: dominant default — all whereami-louis cases; all launch-jamie cases; onboard-repo-sam T01/T02/T03/T04; build-jamie T01/T02/T03; riff-jamie T02/T03; sprint-louis T02/T03.
- **41 lines**: sprint-louis T01 golden (`scripts/tests/smoke-drive-e2e-sprint-louis.test.sh:69`) — documented at L59-65 as "trust-dialog harness overhead per cli#217 cure".
- **45 lines**: riff-jamie T01 golden (`scripts/tests/smoke-drive-e2e-riff-jamie.test.sh:83`) — no inline rationale.
- **46 lines**: build-jamie T04 env-partial golden (`scripts/tests/smoke-drive-e2e-build-jamie.test.sh:90`) — documented at L87 as "ratification pending if upstream ratifies > 40 as new Jamie bar".

**Severity**: medium. Tests pass but the per-persona scan-ceiling bar is not documented centrally. New drivers inherit "40 by default" without knowing when a bump is correct.

**Cure**: author a per-persona scan-ceiling table in `docs/plans/tier-a-driver-inventory-state.md` (or sister doc). Each persona names its ceiling + rationale for case-specific bumps. Driver comments cite the table.

### F-TierA-02 — persona-assert jargon list hardcoded + partial

`scripts/lib/persona-assert.sh` L85-95 hardcodes 9 jargon terms:

```
"operationalize", "load-bearing", "composer", "primitive",
"tier-preset", "blast radius", "compose-with", "scope-bounded",
"substrate primitive"
```

The authoritative list lives at `standards/bassclef-internal-jargon.md` and carries 50+ BLOCK terms. The hardcoded 9 are a subset frozen at Session I walking skeleton (2026-10-04 per last commit `55445b1`).

**Severity**: medium. Experience-goal assertion catches 9 terms but misses the other 40+. Dancing-bear jargon drift is less detected than it looks.

**Cure**: read the BLOCK terms from `standards/bassclef-internal-jargon.md` at test time (same shape as `turn-prose-kiss-check.sh` reads it). Signature already supports `jargon_file` override at L81; make the standards-file path the default when no override is passed.

### F-TierA-03 — Fixture provenance README inconsistent (4 of 6 present)

READMEs present:

- `scripts/tests/fixtures/jamie-build/README.md`
- `scripts/tests/fixtures/jamie-launch/README.md`
- `scripts/tests/fixtures/jamie-riff/README.md`
- `scripts/tests/fixtures/louis-sprint/README.md`

Missing:

- `scripts/tests/fixtures/louis-whereami/README.md`
- `scripts/tests/fixtures/sam-onboard-repo/README.md`

Each driver cites cli#380 / PR #381 in header comments. No central doc names the migration path (hand-crafted → docker-captured once OAuth refresh lands).

**Severity**: medium. cli#388 scope angle 3 explicitly asks for the migration path. Partial coverage leaves 2 fixtures undocumented.

**Cure**: write the 2 missing READMEs. Author `docs/plans/tier-a-fixture-provenance.md` (or extend the inventory doc) with the migration path. Each driver's header cites the central doc.

### F-TierA-04 — Workflow paths filter asymmetry (docker-smoke explicit; lite-adopter glob)

Two workflows trigger on the same driver family but filter paths differently:

- `.github/workflows/docker-smoke.yml` L19-34 — explicit list of each fixture dir + each driver file. New driver → manual paths update.
- `.github/workflows/lite-adopter-smoke.yml` L31-33 — glob `scripts/tests/smoke-drive-e2e-*.test.sh`. New driver → auto-catches.

**Severity**: low. docker-smoke works today. Fragile when a 7th driver lands.

**Cure**: converge docker-smoke on the glob pattern. One-line change. Reduces maintenance drag per @luminary ousterhout.

### F-TierA-05 — ADR-011 should note the "no 4th goal" answer

cli#388 scope angle 5 asks whether a 4th Cooper goal (performance / latency / token-count) earns its place. The 6-driver evidence answers "no" implicitly — no driver ships a 4th. The answer should land in ADR-011 so future reviewers know the question was asked and answered.

**Severity**: low. Current state works. Documentation gap only.

**Cure**: amend `docs/adrs/ADR-011-cli-side-cure-anchor-drivers-and-flow-layer.md` D1 or D3 section with a note: "3 Cooper goals (end + experience + life) sufficient per Session S cli#388 architect-review 2026-10-11; 4th performance goal rejected because it tilts toward CI health rather than adopter experience."

## Q2+ notes (not filed as tickets)

- **Chain helper adoption splits by persona.** Jamie uses `claude-chain.sh`; Louis and Sam don't. Design question, not defect. Revisit if Louis or Sam gets a multi-turn driver.
- **Fixture staleness check.** Characterization tests pin shipped behavior; shipped behavior drifts over time. No current driver carries a re-capture-after-N-months discipline. Consider in a future hygiene session.
- **V2i interactive lane advisory.** `docker-smoke.yml` L171-176 treats exit codes 30-34 as advisory per cli#276 (credentials seed requirement). Reasonable short-term; flips to failing once cli#276 ships.
- **`set -euo pipefail` vs `set -uo pipefail` deviation.** All 6 drivers + both libs deliberately omit `-e`. Documented per architect-review 2026-10-07 F3 in `scripts/lib/claude-chain.sh` L35-41. Consistent and intentional.

## Sources read

- `scripts/lib/claude-chain.sh` (full read; 161 lines)
- `scripts/lib/persona-assert.sh` (full read; 144 lines)
- `scripts/tests/smoke-drive-flows-registry.sh` (full read; 59 lines)
- `scripts/tests/smoke-drive-e2e-sprint-louis.test.sh` (full read; 123 lines)
- `scripts/tests/smoke-drive-e2e-onboard-repo-sam.test.sh` (full read; 116 lines)
- `scripts/tests/smoke-drive-e2e-build-jamie.test.sh` (full read; 105 lines)
- `scripts/tests/smoke-drive-e2e-whereami-louis.test.sh` (targeted scan; life ceiling + chain source + fixture count)
- `scripts/tests/smoke-drive-e2e-launch-jamie.test.sh` (targeted scan; life ceiling + chain source + fixture count)
- `scripts/tests/smoke-drive-e2e-riff-jamie.test.sh` (targeted scan; life ceiling + chain source + fixture count)
- `.github/workflows/docker-smoke.yml` (full read; 181 lines)
- `.github/workflows/lite-adopter-smoke.yml` (targeted scan; trigger paths section)
- `docs/adrs/ADR-011-cli-side-cure-anchor-drivers-and-flow-layer.md` (targeted scan; D1 + D3 decisions)
- cli#388 body via `gh issue view` (scope + 5 review angles)
- Prior review `docs/architecture/reviews/2026-10-10-session-p-cli-415-cross-repo-validator.md` (frontmatter + verdict pattern)

## Signatures

**Primary lens signoff — @luminary michael-feathers.**

Characterization per Feathers: the harness pins shipped adopter behavior via captured fixtures. Each driver reads a fixture and asserts 3 Cooper goals against it. The pattern survives shipped-behavior drift because fixtures are explicit; when shipped behavior changes, the fixture capture refreshes (manual today; docker-automated once cli#380 lands). No finding falsifies the pattern. 5 Q1 findings are refinement work.

**Supporting lens signoff — @luminary john-ousterhout.**

Deep modules: both libs present narrow interfaces. `claude-chain.sh` carries 2 user-facing functions over a perl SIGALRM invocation layer. `persona-assert.sh` carries 3 user-facing functions over a capture-parsing layer. No internal detail leaks to drivers. F-TierA-02 (hardcoded jargon) is the one interface-shape issue; cure keeps the narrow surface + reads the authoritative wordlist underneath.

**Supporting lens signoff — @luminary jerome-saltzer-and-michael-schroeder.**

Complete mediation: every driver mediates through `persona-assert.sh`. No driver reads a capture file directly. The env-var contract documented in `claude-chain.sh` L19-24 mediates every chain turn. F-TierA-04 (workflow paths asymmetry) is the one mediation leak at the CI boundary; cure converges on the glob pattern.

## Lead-lens signoff (per loop-discipline Step 5.5)

All 5 Q1 findings cleared for filing. Lead lens Feathers confirms: no finding falsifies the characterization-test pattern. Each finding is additive. Signoff marker landed at `state/markers/lead-lens-signoff/chore-session-s-cli-388-architect-review.marker`.
