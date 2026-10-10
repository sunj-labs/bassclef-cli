---
session: session-p
date: 2026-10-10
scope: cli#415 (ADR-059 CLI validator) then cli#328 (/build 14 gaps)
mode: /pre-mortem light — 3 lenses × 5-7 risks
authoring_luminaries:
  lead: jerome-saltzer-and-michael-schroeder
  supporting: [linus-torvalds, michael-feathers]
---

# Session P risk ledger — cli#415 then cli#328

Pre-mortem light fired BEFORE code work per `.claude/rules/loop-discipline.md` Step 0.5.

## Lens 1 — Saltzer-Schroeder (complete mediation)

- R1: cli validator uses `_tier` root-key; upstream uses `_tier: upstream`. CI reads a tier scheme that cli does not share. Caught at the first validator run; fold a cli-side tier adapter OR match upstream's scheme verbatim.
- R2: cli#415 vendor path drift — the 5 files land at paths matching upstream, but cli's state-spine shape may already carry a stale `install-written-paths.schema.json` from PR #403. Diff before overwrite.
- R3: CI job runs on `ubuntu-latest` per cli#415 body, but PR #414 just pinned cli workflows to `ubuntu-24.04`. Match the pin.
- R4: `ajv-cli` + `ajv-formats` install in CI; local developer run has no such step. Add a local-run README line in validator comments.
- R5: validator negative test (bad schema_ref) ships as part of acceptance — the test must land in the same PR or CI gate is unverified.

## Lens 2 — Linus Torvalds (adopter contract)

- R6: cli#328 touches `/build` SKILL.md body + Builder agent frontmatter + `/launch` SKILL body (stack-choice question). All three are adopter-observable surfaces per ADR-031. Compat shim discipline fires per `.claude/rules/we-dont-break-adopters.md`.
- R7: cli#328 Finding 7 names `Builder.md` model pin at `claude-sonnet-4-6` — stale. Updating to current Sonnet changes agent behavior. Smoke drivers may reproduce old behavior and go RED on the bump.
- R8: cli#328 Finding 13 adds a stack-choice question to `/launch`. Nine SKILL bodies today lean on Next.js examples. Dropping examples risks adopter orientation loss; keep examples with a visible "pick your stack" header.

## Lens 3 — Michael Feathers (characterization before change)

- R9: cli#328 Phases 4-7 have no smoke driver today — 5 /build drivers exist (phase-0, cascade, jamie, template, cli#326 regression) but none covers Phases 4-7 handoff. Each of the 14 findings needs a characterization test BEFORE the fix lands, or the acceptance stays untestable.
- R10: `/architect-review` intersperse means the review reads unmerged mid-session state. Characterization markers must land per-batch so the review has evidence to read.
- R11: cli#415 ships CI gate that observes `standards/cross-repo-contracts.json` edits. The first adopter PR touching that path IS the first live test. Dry-run the validator against the current registry (1 entry) in the same PR to lock the GREEN baseline.
- R12: cli#328 Finding 11 ("CI is green" stopping rule) means `/onboard-repo` should ship a minimal CI workflow. That is a new primitive — adopter-observable; bootstrap pair owed per `.claude/rules/bootstrap-pair-discipline.md`.

## Folded concerns

- R1-R3 shape cli#415 implementation order: diff before overwrite, match ubuntu pin, write negative test first.
- R6-R8 push cli#328 to a batched PR shape (A naming, B gates, C Builder, D goal+stack) with per-batch Reviewer + smoke-driver updates.
- R9-R10 give /architect-review intersperse real teeth: writes land per-batch, review reads evidence per-batch.
- R12 is a scope stretch — likely out-of-scope for Session P. Flag for Session Q plan doc.

## Anchor luminary slugs

- jerome-saltzer-and-michael-schroeder — complete mediation
- linus-torvalds — adopter contract
- michael-feathers — characterization before change
