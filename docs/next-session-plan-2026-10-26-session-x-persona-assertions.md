---
session_id: 2026-10-26-session-x
project: bassclef-cli
status: planned
tags: [cli-425, cli-454, cli-453, persona-ux, jargon-reader, coherence-audit]
---

# Next-session plan — Session X: persona assertions plus the audit sweep

## Context

Session W shipped the `cli#444` fix, a coherence audit of the 7 first-touch skills, and a canvas amendment that moved the plan from "build a check" to "read first, then build". Three PRs merged: #452, #455, #456.

Two things reshaped the work. First, the persona test tier already exists in this repo — `scripts/lib/persona-assert.sh` with three Cooper-level assertions, `claude-chain.sh`, 20 drivers, 7 fixtures. So #454 is three missing assertions, not a new tier. Second, the jargon word list enforces about a third of itself across nine upstream hooks, which is now `upstream#2277`.

No release this cycle. A fix is still heading upstream.

## Recommended session sequence

### Thread 1 — cli#425, source the bundled jargon reader

`persona_assert_experience_goal` checks adopter output against 9 hardcoded words. The standard has 64. All 19 call sites take the default, so 56 terms are unreachable — including the two the audit found in `onboard-repo`, the skill that Sam's own driver passes.

The bundle already ships a reader: `load_block_terms` at `dist/lite/lib/code-comment-discipline.sh:34`, with a `CCD_WORDLIST` path override. So this is a source line, not a parser.

**Scope class:** b (script extension).

- **Steps:** brief use case + `/luminary consult` (lead + 1) + `/pre-mortem light` + Beck RED-first + impl + `/verify` + PR.
- **Produces:** `scripts/lib/persona-assert.sh` sourcing the bundled reader + Tier 0 test for the swap.
- **Consumes:** the three corrections on cli#425; `upstream#2277` for the term-cleaning that follows.
- **Risk:** 🟡 med — the terms get stricter, so drivers that pass today may start failing. That is the point, but it arrives as a wave. Ship advisory first.
- **Time:** 25-40 turns.
- **Lead luminary:** John Ousterhout — one reader, many consumers. The defect is the copy, not the parse.
- **Supporting:** Michael Nygard — fail loudly when the bundle is absent. A silent fallback to a short list rebuilds the exact defect.

**One design decision to make first.** `dist/` is gitignored and only exists after the bundling script runs. `pr-checks.yml:82` and `publish.yml:153` both run it. So decide: fail hard when the bundle is missing, or skip the assertion with a loud note. Recommend fail hard — a quiet skip is how the 9-term default survived.

### Thread 2 — cli#454, the three missing assertions

The existing three assertions ask whether the chain finished, whether the output is jargon-free, and whether it is short. None asks whether a person could decide anything.

| New function | What it checks | Audit finding it pins |
|---|---|---|
| `persona_assert_informed_consent` | every question says what yes does and names a way to undo it | F3 — `onboard-repo:645` |
| `persona_assert_one_voice` | the output never tells the model what to do, and cites no ticket numbers | F4, F5 |
| `persona_assert_next_step` | when the output asks the reader to act, it names the path or command | audit question 4 |

**Scope class:** c (new building block) — three functions in a Tier 0 library.

- **Steps:** fully-dressed use case + `/decompose` + `/luminary consult` (lead + 2) + `/pre-mortem light` + Beck RED-first + impl + `/verify` + PR.
- **Produces:** three functions in `scripts/lib/persona-assert.sh` + Tier 0 tests + fixtures built from the audit findings.
- **Consumes:** Thread 1's reader swap; `docs/audits/2026-10-26-persona-coherence-first-touch.md` for the failing shapes.
- **Risk:** 🟢 low — additions. The 19 existing call sites are untouched.
- **Time:** 50-80 turns.
- **Lead luminary:** Alan Cooper — the three goal levels the library is built on, and the one it is missing.
- **Supporting:** Michael Feathers (pin the real failing shape first) + Donald Norman (a question should tell the reader what happens next).

**Ship `persona_assert_one_voice` as a warning.** The verb list will catch prose that legitimately addresses the reader. The audit saw that with "Print" and "Fire".

### Thread 3 — the audit sweep

Two passes, both cheap because `scripts/audit-skill-reader-prose.sh` exists.

- **The 7 recurring skills** — `longrun`, `session-end`, `session-log`, `kiss`, `temperance`, `diagnose`, `promote`. 15-20 turns at depth.
- **A sweep of the other 59** — one command plus a read of the output. 5-10 turns. This answers how big the problem really is.

- **Produces:** a second audit document, or an appendix to the first.
- **Consumes:** the script and the six questions from Session W.
- **Risk:** 🟢 low — a read.
- **Time:** 20-30 turns combined.
- **Lead luminary:** Alan Cooper, with Michael Feathers on the counts.

### Order plus decision

Thread 1 first — smallest, and Thread 2 builds on the same library. Thread 3 can slot anywhere; it touches nothing the others touch.

**Decision queued for the operator at prep:**

- **Option a** — Threads 1 and 2 only. Two PRs. Leaves the audit sweep for later.
- **Option b** — all three. Three PRs. Longer, but the sweep sizes the remaining work.
- **Option c** — Thread 1 plus Thread 3. Ships the reader fix and finishes the measuring, defers the new assertions.

Recommend **b** if the budget allows, **c** if not. The sweep is the cheapest information in the set, and the "why only 14 skills" question from Session W is still unanswered with data.

## Upstream state — read before scoping

- **`upstream#2277`** — promote the jargon reader to its own lib, clean the term at extraction. Thread 1 lands fine without it and gets the cleaner terms free on the next bundle refresh.
- **`upstream#2272`** — the source-side prompt check. **Filed too narrow.** The audit recommends widening it to the boundary and ticket-reference rules before anyone builds it. Worth a comment before it gets picked up as written.
- **`upstream#1780`** — hook consolidation. Session W posted the nine-readers finding there and messaged `bassclef-upstream-c7`.
- **`upstream#2267-#2270`** — held by `bassclef-upstream-d2`, which was mid-`/eisenhower` at Session W close. Check whether that landed before assuming anything about the next bundle.

## Fix tickets the audit earned, not yet filed

All land in bassclef-upstream.

- **F1 plus F2 (high)** — `onboard-repo` and `launch` have no `## Details below the fold` heading. One heading each. Highest value and cheapest fix in the audit.
- **F3 (high)** — `onboard-repo:645`, the production-deploy question, with 10 words of prose above it.
- **F4 plus F5 (med)** — model instructions inside the reader-facing opening of `whereami:21` and `sprint:25`.
- **F6 to F9 (med/low)** — four jargon terms in `launch` and `onboard-repo`.

Worth filing F1 and F2 as one ticket early. Two headings, and they fix the worst reader problem found.

## Time budget

Thread 1 plus 2: 75-120 turns. All three: 95-150.

Grounded in Session W actuals: the `cli#444` fix ran about 25 turns for a class-b script change with 16 new assertions, and the audit ran about 14 turns for 7 skills including two reusable scans. Thread 2 is class c with three functions, so it carries the heavier ceremony.

Session W overran its own 55-95 estimate at about 100 turns. The overrun came from the jargon thread, which was out of scope and worth following. Budget for one such detour.

## Entry state

- Branch: `main` at the Session W closeout commit
- Open cli tickets: #425 (Thread 1), #454 (Thread 2), #453 (Thread 3 parent), #448 (epic parent), #441, #445-#447, #450, plus the Tier A set #424-#428, #431, #434-#436
- Open cli PRs: #449 (ADR-012 pre-publish gate, proposed — the cli-side wording check belongs here), #423 (Dependabot node 25-slim — triage)
- `@thebassclef/lite@1.9.19` LIVE on npm as `latest`
- No release pending until the upstream fix lands

## Reference artifacts

- Session W chronicle: `docs/chronicle/2026-10-26-session-w-cli-444-plus-persona-ux-audit.md`
- The audit: `docs/audits/2026-10-26-persona-coherence-first-touch.md`
- The scan script: `scripts/audit-skill-reader-prose.sh`
- Canvas: `docs/canvases/2026-10-25-persona-ux-test-tier.md` — read Amendments 1 and 2
- Persona pointer: `docs/personas/README.md` — the files live upstream and carry `tier: upstream`
- Risk ledgers: `docs/risk-ledgers/2026-10-25-cli-444-*`, `2026-10-26-cli-453-*`
