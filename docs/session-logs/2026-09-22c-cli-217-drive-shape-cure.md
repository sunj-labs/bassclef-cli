---
tier: upstream
session_id: 2026-09-22c
session_started: 2026-09-22T21:44:00Z
title: cli #217 drive-shape cure — natural-language prompts + positive-artifact asserts
authoring_luminaries:
  primary: michael-feathers
  supporting: [kent-beck, alan-cooper]
gates_fired:
  - /temperance (branch open)
  - /luminary consult
  - /pre-mortem light (3 lenses × 5-8 risks)
  - /rfc adversarial (4 outside lenses)
  - Beck TDD RED → GREEN (1 iteration)
  - /architect-review (4-lens READY)
  - /loop discipline signoff
sources_read:
  - docs/whereami.md
  - docs/next-session-plan-2026-09-23-cli-217-drive-shape-cure.md
  - scripts/smoke-drive-skills.sh
  - scripts/smoke-drive-riff.sh
  - scripts/smoke-drive-onboard-repo.sh
  - scripts/lib/smoke-assert.sh
  - scripts/smoke-assert-skills.sh
  - tests/harness/smoke-drive-riff.test.ts
  - cli #217 body (gh issue view)
---

# Session log — cli #217 drive-shape cure

## Sources read

Full plan doc + all 3 drive scripts + smoke-assert lib + one existing test file (as template). See frontmatter for the enumerated list.

## Gate evidence

| Gate | Status | Evidence |
|---|---|---|
| /temperance | fired | `state/markers/temperance/feat-cli-217-drive-shape-cure.marker` |
| /luminary consult | fired | `state/markers/luminary/feat-cli-217-drive-shape-cure.marker` — lead michael-feathers; supporting kent-beck + alan-cooper |
| /pre-mortem light | fired | `state/markers/pre-mortem/feat-cli-217-drive-shape-cure.marker` — 3 lenses × 5-8 risks; top-3 folded (F1 + B2 + C1) |
| /rfc adversarial | fired | `docs/rfcs/RFC-cli-217-drive-shape-council.md` — 4 outside lenses; 7 of 8 findings folded pre-code |
| adr-deviation | fired | `state/markers/adr-deviation/feat-cli-217-drive-shape-cure.marker` — outcome ADR-honored |
| /decompose | fired | `state/markers/decompose/feat-cli-217-drive-shape-cure.marker` + `docs/decompositions/2026-09-22c-cli-217-drive-shape-cure.md` |
| Beck RED | confirmed | state/events/test-runs/2026-09-22T21-52-29-780Z.json — 3 vitest fails + bash 26/26 exit 127 |
| Beck GREEN | confirmed | state/events/test-runs/2026-09-22T21-56-05-079Z.json — 489/489 vitest + bash 26/26 PASS |
| /architect-review | READY | `docs/architecture/reviews/2026-09-22c-cli-217-drive-shape.md` |
| /loop | iteration 1 GREEN | `state/markers/loop/feat-cli-217-drive-shape-cure.marker` |
| lead-lens sign-off | signed | `state/markers/lead-lens-signoff/feat-cli-217-drive-shape-cure.marker` |
| Reviewer | PASS | `state/markers/reviewer/feat-cli-217-drive-shape-cure.md` |

## Work done

**Phase 1 — Discovery + design (Feathers characterization).** Read 3 drive scripts + smoke-assert lib fully. Discovered the failure class: `check_no_not_found` grep pattern `(not found|No such file or directory)` cannot match `Unknown command:`. Smoke-drive-riff.sh + smoke-drive-onboard-repo.sh already ship positive-artifact assertions but both use `-p "/skill"` shape at invocation.

**Phase 2 — Ceremony.** Wrote brief Cockburn UC (`docs/use-cases/UC-hook-docker-smoke-drive-shape.md`), decomposition (Jacobson BCE + GRASP + Strategy pattern for per-skill assertions), risk ledger (Feathers + Beck + Cooper × 5-8 risks each — 18 total), RFC council (Hyrum + Linus + Saltzer-Schroeder + Norman — 8 findings, 7 folded).

**Phase 3 — Beck TDD RED.** Wrote 2 test files first:
- `scripts/tests/smoke-assert-check-no-unknown-command.test.sh` — 18 tests × 26 assertions covering all 8 new lib functions. RED confirmed: exit 127 for all (functions not yet in lib).
- `tests/harness/smoke-drive-skills.test.ts` — 6 characterization tests + 3 claude-mock fixtures (happy-all + unknown-command + clarifying-question). RED: 3 fails at source-grep asserts.

**Phase 4 — Cure.** Extended smoke-assert.sh with 8 new Strategy functions (check_no_unknown_command + check_output_contains + 5 per-skill positive-artifact checks + check_temperance_marker with fail-safe on missing dir per RFC S1). Rewrote invocation site in all 3 drives to use natural-language prompt templates (per-skill map for smoke-drive-skills.sh; inline template for riff + onboard-repo). Wired `no-unknown-command` into smoke-assert-skills.sh default check list; per-skill checks fire when `SMOKE_PER_SKILL_CHECKS=1`.

**Phase 5 — Beck GREEN.** All tests pass. Full suite: 489/489 (up from 483). Typecheck clean.

**Phase 6 — Architect review.** 4-lens review READY. All HIGH + MEDIUM findings folded. Two LOW deferred (N1 → cli #215; C4 → post-merge smoke).

**Phase 7 — PR + merge.** PR #218 opened, CI in flight.

## Ceremony chain audit

Per `.claude/rules/oo-ad-entry-point.md` matrix — script extension = brief UC + /decompose. Plus /pre-mortem light + /rfc adversarial + /architect-review because substrate/Tier 0 code. All fired. All markers landed.

## What worked

- **Feathers characterization first.** Reading the full source before touching anything surfaced that riff + onboard-repo already have positive-artifact assertions — only the prompt shape needed cure at those two. Only smoke-drive-skills.sh needed the deeper per-skill assertion extension.
- **RED-first TDD.** Bash test exit-127 output was unambiguous — "function does not exist" is the clearest RED signal. Vitest source-grep asserts pinned the exact strings the cure had to introduce.
- **RFC council caught H1 + L1** (backward compat). Kept DEFAULT_SKILLS list unchanged even though the new prompt shape doesn't need it — protects downstream consumers hardcoding the list.
- **Pre-mortem C1 fold** (prompt fully specifies input) — every prompt template includes a concrete scenario so LLM cannot ask clarifying questions.
- **Opt-in per-skill checks** — kept existing smoke-assert-skills tests green by gating on `SMOKE_PER_SKILL_CHECKS=1`. Cure is additive, not disruptive.

## What did not work

- Initially wrote per-skill checks as always-on in smoke-assert-skills.sh. Broke 2 existing tests (row-count expectation 6 not 7). Fixed by gating behind opt-in env var + updating the count-expectation test (6 → 7 for the always-on no-unknown-command check).
- adr-deviation-challenge hook fired on first Write of the UC because I ran the marker touch + Write in parallel. Retry after marker landed worked. Would have been cleaner to touch marker first, then Write.

## Deferred to next session

- **S12 — post-merge cold smoke on v1.7.0 npm** (fires after PR merges + docker-smoke workflow_dispatch runs)
- **S13 — /kiss + /feynman findings report** (depends on S12)
- **S14 — /promote upstream tickets for Sam/Louis first-5-min friction** (depends on S13)

## Sibling coordination

None this session. Peer bassclef-upstream-c2 sessions remain independent per prior coordination — cli #208 flood claim already posted; cli side owed no follow-on work at prep time. This cure is cli-side only; no upstream substrate change needed.

## Turn count

Prep + full ceremony chain + cure + PR: ~85 turns as of PR open. Post-merge smoke + report + upstream promotes will add ~30-50.

## Refs

- Goal doc: `docs/goals/2026-09-22c-cli-217-drive-shape-cure.md`
- PR: #218
- Closes cli #217
