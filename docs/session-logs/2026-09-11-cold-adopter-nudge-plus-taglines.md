---
date: 2026-09-11
title: Cold-adopter --help hint + 4 tagline proposals
goal: docs/iteration-bets/2026-09-11-zero-state-nudge-plus-straplines.md
in_flight_goal_closed: pending PR #56 merge
prs_opened: [56]
tickets_touched: [55]
authoring_luminaries:
  primary: [alan-cooper]
  supporting: [jerome-saltzer-and-michael-schroeder, john-ousterhout]
gates_fired:
  - /temperance (session)
  - /pre-mortem light (3 lenses × 3 risks)
  - /luminary (Cooper primary)
  - /verify (via full suite 227/227)
  - /loop (per-PR discipline; 1 iteration RED→GREEN first pass)
---

# 2026-09-11 — Cold-adopter `--help` hint + 4 tagline proposals

## Flash

Shipped a `Start here: bassclef init` line in `bassclef --help` for cold adopters. Reconciled ticket #55 scope against ADR-008 during Step 1 source-read. Drafted four tagline proposals for /riff /launch /build /howdoi. PR #56 open with 5 new tests + reconciled UC.

## What shipped

- **PR #56** — `feat(#55): first-run hint in bassclef --help for cold adopters` on branch `feat/55-zero-state-nudge`
  - `src/cli.ts` — one line added to USAGE string (`Start here: bassclef init (first-run verb...)`)
  - `tests/cli-init-nudge.test.ts` — 5 new Tier 0 tests (2 Beck RED→GREEN + 3 characterization pins)
  - `docs/use-cases/UC-cold-adopter-init-nudge.md` — brief-tier UC with reconciliation section
  - `docs/iteration-bets/2026-09-11-zero-state-nudge-plus-straplines.md` — goal doc + amended Steps + Acceptance
  - `docs/risk-ledgers/2026-09-11-zero-state-nudge-plus-straplines.md` — pre-mortem light
  - State markers — thread-walk + arc-walk + temperance + pre-mortem + luminary + ADR-deviation (ADR-honored)
- **Ticket #55 comment posted** — scope reconciliation summary explaining migrate no-manifest stays as Path B per ADR-008 D2
- **`docs/tagline-proposals/2026-09-11-brownfield-adopter-lens.md`** — four tagline drafts for /riff /launch /build /howdoi with brownfield-adopter framing + luminary rationale + ready for /promote filing

Full suite: **227/227 GREEN** (was 222; 5 new tests added).

## What did not ship

- **Ticket #55 in its literal spec** — the ticket asked for a uniform zero-state nudge on sync + migrate + bare `bassclef`. Reading source at Step 1 discovered sync already nudges correctly and migrate dispatches Path B per ADR-008 D2. Reconciled scope shipped the smaller `--help` polish instead. The comment on #55 explains the reconciliation. If operator wants the migrate behavior change, that is a follow-on ticket + ADR-008 amendment.
- **Actual /promote filings for the 4 taglines** — the drafts landed as a single artifact under `docs/tagline-proposals/`. Operator files at their pace via /promote (adopter-source + bassclef-evolution labels, per prior #37 + #38 shape).

## Gates fired

- `/temperance` — session marker at `state/markers/temperance/feat-55-zero-state-nudge.marker`. Scope: reconciled ticket #55 + strapline drafts. Drift trigger: pause if a step exceeded 1.5× budget.
- `/pre-mortem light` — 3 lenses × 3 risks (9 total); strongest R1 + R3 + R7 folded into Step 1 UC + Step 2 tests. Ledger at `docs/risk-ledgers/2026-09-11-...`.
- `/luminary` — Cooper primary; Saltzer-Schroeder + Ousterhout supporting.
- `/verify` — full suite 227/227 GREEN.
- `/loop` — one iteration; Beck RED (2 fails on missing `--help` hint) → GREEN (5 pass) after one-line source cure.

## What worked

- **Reading source at Step 1 caught the scope conflict early.** Ticket #55 body did not match shipped behavior. If I had gone straight to writing tests from the ticket, I would have shipped a behavior change (migrate no-manifest → nudge instead of Path B) that contradicts ADR-008 D2 without an ADR amendment. Reading `src/lib/manifest-io.ts` and `src/lib/migrate.ts` at Step 1 surfaced the conflict before code shipped. This is exactly the OOAD discipline the operator asked to keep active.
- **Characterization tests pin current behavior.** Three of the five new tests pin behavior that already worked (sync no-manifest nudge, migrate Path B opener, init happy path). A future refactor cannot silently drift these. Feathers-style safety net.
- **Small cure.** One line in `USAGE` closed the actual pain point (`--help` pre-run confusion per session log 2026-09-07 L48). No new module, no new interface, no ADR change.
- **Tagline drafts as one artifact.** Instead of filing 4 tickets inline, ship a single Markdown file with all four proposals + rationale. Operator files via /promote at their pace. Fewer permission dialogs; same content.

## What did not work

- **Multi-step ceremony ate turns for a one-line fix.** The `--help` hint is one line, but the session ran goal doc + risk ledger + UC + tests + PR + tagline artifact + this session log. Real work: maybe 15 turns of source + tests. Ceremony: the rest. For future one-line fixes on Tier 0 paths, `/quick-fix` may be a cleaner entry point than `/longrun`.
- **Hook cascade on first goal-doc write.** Two BLOCKs fired (parent-citation gate + thread-walk gate) before the goal doc landed. Cost 2-3 turns diagnosing which marker path the hook wanted. Both hooks resolved cleanly once the marker was in place. Note for next `/longrun`: touch thread-walk + arc-walk BOTH markers at Step 0 before the goal-doc write attempt.

## Discoveries

- **Ticket bodies can conflict with shipped ADRs.** Ticket #55 was written by a friend or from a cold-adopter observation. It described behavior the code did not have (sync nudge = already there) and asked for behavior the code deliberately does not have (migrate nudge = ADR-008 D2 says Path B). Reading the source at Step 1 was the check. `.claude/rules/oo-ad-entry-point.md` names this check but does not explicitly say "read the ADRs cited by the surface you are about to change." Consider proposing an amendment to name that.
- **Cockburn brief tier fits an extend-existing-code src/ change.** UC-cold-adopter-init-nudge.md at brief tier landed at ~90 lines including reconciliation section. Fully-dressed would have been 200+ lines with a full extensions table for a single-line change. Right tier match.

## Retro — one-line highlights

- **Biggest win** — reading source at Step 1 caught the ADR conflict before writing code
- **Biggest miss** — went too deep on prep ceremony for a one-line fix; would have been faster via `/quick-fix` for the `--help` polish and a separate mini-goal for tagline drafts
- **What compounds** — the 3 characterization tests protect current sync + migrate behavior forever; the tagline artifact is reusable input for future tagline audits
- **What to fix next** — file the four /promote tickets when operator has time; consider `/tagline-audit` skill proposal; consider follow-on ticket for interactive Path B prompt on cold adopters

## /promote audit

No missed /promote candidates surfaced this session beyond the four already drafted in the tagline artifact. One optional follow-on named in the tagline artifact tail: `/tagline-audit` skill. Operator's call whether to file.

## Next session

- Merge PR #56 (operator review; auto-merge disabled for security-adjacent guard per prior session pattern)
- File the four /promote tickets from `docs/tagline-proposals/2026-09-11-...` at bassclef-cli with bassclef-evolution + adopter-source labels
- Optional — file follow-on for interactive Path B prompt on cold adopters
- Return to open threads: trusted publisher config for lite, Cooper #1 silent-install hook (upstream), whereami schema drift folded into this session's whereami update

## Refs

- PR #56 (this session)
- Ticket #55 comment #issuecomment-5630319000 (reconciliation posted)
- ADR-002 (init safety contract; manifest path this reads)
- ADR-008 (migrate subcommand; Path B kept intact)
- Session log 2026-09-07 L48 (cold-adopter friend origin)
- Goal doc 2026-09-11-zero-state-nudge-plus-straplines.md
