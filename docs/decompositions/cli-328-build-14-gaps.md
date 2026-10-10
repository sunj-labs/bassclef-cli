---
date: 2026-10-10
ticket: cli#328
primary_luminary: alan-cooper
supporting_luminaries: [john-ousterhout, michael-feathers, kent-beck]
scope: 14 /build Phase 4-7 gaps found by operator supervised-run 2026-10-03
state: 2  # Epic/defect — reverse-engineer from current SKILL state + ticket findings
---

# cli#328 decomposition — 14 /build gaps

## Sources read

- `gh issue view 328 --json body` — the 14 numbered findings + 5 asks + "## How the run went" context section
- `gh issue view 332 --json state` — CLOSED (Finding 14 lite deploy drops)
- `gh issue view 307 --json title,body` — CLOSED sister ticket (Step-N parsing; NOT in cli#328's 14 numbered findings)
- `gh issue view 327 --json title` — CLOSED sister ticket (zero-step spec; NOT in cli#328's 14)
- `gh issue view 199 --json state` — OPEN Epic parent
- `gh pr view 346 --json title,state,mergedAt` — MERGED 2026-10-04 (Finding 6 characterization driver only; SKILL fix pending)
- `.claude/agents/Builder.md` L1-15 — frontmatter + model pin `claude-sonnet-4-6` (Finding 7)
- `.claude/skills/temperance/SKILL.md` L85-102 — current `git add` of gitignored marker (Finding 6)
- `.claude/skills/build/SKILL.md` L21-38 + L560-571 — Phase 4-7 STUB declaration (Findings 3, 12)
- `.claude/skills/launch/SKILL.md` — grep returned no "stack choice" / "tech_stack" lines (Finding 13 confirmed open)
- `docs/risk-ledgers/2026-10-10-session-p-cli-415-then-328.md` — parent ledger; R6-R10 + R12 folded into batch shapes

## What I'm NOT reading (with reason)

- Full `/pre-mortem` SKILL body — only need the operator-write-down step shape; defer to Batch B impl
- Full `/onboard-repo` SKILL body — only need the CI-workflow absence; defer to Batch D impl (may stretch to Session Q)
- `.claude/skills/autonomous/SKILL.md` — Finding 3 flags `--from-spec --wu` nonexistence; out-of-scope stretch

## Context

cli#328 was filed 2026-10-03T20:35Z by the operator after one supervised run of `/build` Phases 4-7 against a real adopter goal — recipe data + types + build-time validator — on bassclef lite `v1.6.6`. Part of cli#199 Epic (cold-adopter smoke drive for `/riff → /launch → /build`).

The ticket body carries 14 numbered findings AND a shorter "## Asks" section with 5 bullets. The asks map to fixable scope; the findings carry the diagnosis.

## Shipped-state check per finding

Walked each of 14 findings against current SKILL + agent + ticket state.

| # | Finding | Current state | Verdict |
|---|---|---|---|
| 1 | Branch name 3 shapes (`-stack-N-wu-slug` vs `-stack-N`) | `.claude/skills/build/SKILL.md` + `/launch` SKILL still carry both shapes | **OPEN** |
| 2 | No issue per branch | `/launch --local` creates no issue; `/build` never checks | **OPEN** |
| 3 | Phase 4 target `/autonomous start --from-spec --wu` doesn't exist | `/build` SKILL L560 declares Phase 4-7 STUB | **OUT OF SCOPE** — full Phase 4-7 live mode is a separate goal |
| 4 | Pre-mortem needs operator write-down | `/pre-mortem` SKILL has no operator-write-down step | **OPEN** |
| 5 | Pre-mortem marker not checked by /build | `/build` SKILL has no step reading `state/markers/pre-mortem/` | **OPEN** |
| 6 | `/temperance` says `git add` a marker `.gitignore` blocks | `/temperance` SKILL L99 still says `git add`; PR #346 shipped the characterization driver only | **OPEN (SKILL fix pending)** |
| 7 | Builder.md model pin `claude-sonnet-4-6` | `.claude/agents/Builder.md` L6 unchanged | **OPEN** |
| 8 | Builder asks for `/pattern-review` first | `.claude/agents/Builder.md` references pattern-review as mandatory | **OPEN** |
| 9 | Builder didn't report friction mid-run | `.claude/agents/Builder.md` has no friction-report step | **OPEN** |
| 10 | "Done was not done" — Phase 5 needs review step, not just /verify | `/build` Phase 5 is `VerifyOrchestrator` only | **OPEN** |
| 11 | "CI is green" stopping rule unreachable (no onboard-produced workflow) | `/onboard-repo` has no `.github/workflows/` step | **OPEN** |
| 12 | Nothing opens base PR | `/launch` + `/build` have no base-PR-open step | **OUT OF SCOPE** — needs Phase 4-7 live mode |
| 13 | Stack picked silently (`/launch` writes "Next.js" with no reason) | `/launch` SKILL does not prompt for stack choice | **OPEN** |
| 14 | No deploy path on lite | cli#332 CLOSED (routed to a separate cure) | **CLOSED — DROP** |

**Scope summary:** 14 diagnostic findings → **10 fixable now** + **2 stretch (Phase 4-7 live)** + **1 shipped partial (Finding 6 driver)** + **1 closed (Finding 14)**.

## Batch grouping (per Session P plan step 9)

### Batch A — Naming + handoff (2 findings; Finding 3 deferred as stretch)

| # | Scope | File(s) | Driver shape |
|---|---|---|---|
| 1 | Unify branch slug shape in `/build` + `/launch` SKILLs | `.claude/skills/build/SKILL.md`, `.claude/skills/launch/SKILL.md` | Characterize current drift; fix matches `/launch` write to the slug `/build` reads |
| 2 | Issue-per-branch decision (require? skip for `--local`?) | `.claude/skills/launch/SKILL.md` + `.claude/rules/branching.md` | Characterize `/launch --local` no-issue; decide policy; add check or exempt |

**Estimate:** 20-30 turns. Primary lens Cooper (operator surface clarity).

### Batch B — Gates (3 findings)

| # | Scope | File(s) | Driver shape |
|---|---|---|---|
| 4 | `/pre-mortem` operator write-down step | `.claude/skills/pre-mortem/SKILL.md` | Characterize current (agent-only); add operator-write-down step |
| 5 | `/build` reads pre-mortem marker | `.claude/skills/build/SKILL.md` | Characterize no-check; add Phase 0.5 marker-read |
| 6 | `/temperance` SKILL body `git add` fix | `.claude/skills/temperance/SKILL.md` L99 | PR #346 shipped driver; fix SKILL text; align with gitignore reality |

**Estimate:** 20-30 turns. Primary lens Feathers (characterize-before-fix per PR #346 pattern).

### Batch C — Builder agent (3 findings)

| # | Scope | File(s) | Driver shape |
|---|---|---|---|
| 7 | Builder.md model pin bump | `.claude/agents/Builder.md` L6 | Characterize current pin; bump to current Sonnet |
| 8 | Builder /pattern-review precondition | `.claude/agents/Builder.md` | Characterize + add "skip when no catalog" clause |
| 9 | Builder friction report | `.claude/agents/Builder.md` | Add friction-report step before "done" |

**Estimate:** 20-30 turns. Primary lens Cooper (Builder is operator-facing-via-agent).

### Batch D — Phase 5 review + goal + stack (3 findings; Finding 12 deferred as stretch)

| # | Scope | File(s) | Driver shape |
|---|---|---|---|
| 10 | Phase 5 adds review step (not just /verify) | `.claude/skills/build/SKILL.md` Phase 5 | Characterize current /verify-only; add Reviewer dispatch step |
| 11 | `/onboard-repo` offers minimal CI workflow (R12 stretch) | `.claude/skills/onboard-repo/SKILL.md` + templates | Big — may defer to Session Q |
| 13 | `/launch` stack-choice question | `.claude/skills/launch/SKILL.md` | Characterize silent pick; add stack-choice prompt + spec rationale field |

**Estimate:** 30-50 turns. Primary lens Ousterhout (deep-module edits on /onboard-repo + /launch); R12 (Finding 11) may defer to Session Q per `.claude/rules/wu-sequencing-compounds.md`.

### New flow driver (per step plan #14)

`smoke-drive-e2e-build-phases-3-7-<persona>.test.sh` — pins any Phases 3-7 behavior cli#328 ships. Deferred until the SKILL fixes land per batch; the driver pins the fixed shape.

## Impl order

1. Batch A (naming + handoff) — self-contained; low impact
2. Batch B (gates) — SKILL text + marker wiring; shares shape with Batch A
3. Batch C (Builder agent) — single-file edits; after gates lands
4. Batch D (Phase 5 review + goal + stack) — biggest; may need Session Q split
5. New flow driver — after batches land

## /verify + Reviewer + /architect-review intersperse

Per Session P plan:
- Each batch runs its own `/verify` + Reviewer pass
- `/architect-review` fires once after all batches land (Step 15 of plan)
- Operator merges each batch PR individually (per `.claude/rules/pr-strategy.md` stacked default)

## Risks folded from parent ledger

- R6 (3 SKILL body touches; compat shim) — per `.claude/rules/we-dont-break-adopters.md`, SKILL body changes stay plain-English grade 8; grace window on prior vocabulary preserves
- R7 (Builder model bump) — may change agent behavior; characterization test MUST pin pre-bump behavior; post-bump test confirms new behavior
- R8 (/launch stack-choice; Next.js examples) — keep Next.js examples with visible "pick your stack" header per the ledger
- R9 (Phases 4-7 no driver today) — new flow driver addresses this
- R10 (architect-review evidence per-batch) — Reviewer markers per batch land per `.claude/rules/reviewer-dispatch.md`
- R12 (/onboard-repo CI stretch) — Finding 11 may defer to Session Q

## Refs

- cli#328 (OPEN, operator-filed 2026-10-03)
- cli#199 (OPEN Epic — cold-adopter smoke drive)
- cli#307 (CLOSED — Step-N parsing; sister ticket, NOT in cli#328's 14)
- cli#327 (CLOSED — zero-step spec; sister ticket, NOT in cli#328's 14)
- cli#332 (CLOSED — Finding 14 lite deploy; drops from scope)
- PR #346 (MERGED 2026-10-04 — Finding 6 characterization driver; SKILL fix pending)
- `docs/risk-ledgers/2026-10-10-session-p-cli-415-then-328.md`
- `state/markers/adr-deviation/feat-cli-328-build-14-gaps.marker` — outcome ADR-honored (ADR-031 + ADR-040)
