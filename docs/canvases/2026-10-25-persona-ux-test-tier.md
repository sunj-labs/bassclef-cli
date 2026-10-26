---
canvas_id: 2026-10-25-persona-ux-test-tier
project: bassclef-cli
status: draft
authors: [personal]
verification_status: draft
luminaries:
  primary: alan-cooper
  supporting: [donald-norman, michael-feathers, kent-beck]
tags: [cli-448, persona-ux, test-tier, cold-adopter, onboarding-prose]
closes_ticket: cli#448
---

# Persona-UX test tier — close the UX-quality coverage gap

## Thesis

Behavioral tests ask: **did the prompt fire?**
Persona-UX tests ask: **can a fresh adopter answer this prompt with informed consent?**

Both are needed. We have only the first. The 2026-10-18 cold-adopter smoke on `giveisusfree` surfaced 5 upstream defects. Four were behavioral (upstream#2253 shellcheck, #2255 oauth probe, #2257 auto-save, #2261 housekeeping). One — upstream#2256, Concise opt-in prompt without explanation or unwind hint — was a UX-quality defect that **slipped every tier of our 7-tier local stack and all 4 CI tiers**. Every tier asserts shape, not reader experience.

Session V (2026-10-18) shipped the fix via bundle refresh v1.11.1. But the class remains open. Any future prompt change in `.claude/skills/onboard-repo/` carries the same risk.

**The claim:** add a dedicated UX-quality tier so prose changes on cold-adopter surfaces cannot slip without a persona-weighted read.

**Evidence:** v1.9.19 shipped 4 upstream cold-adopter cures bundled from bassclef v1.11.1 (release_sha 3b0203d5). 3 of the 4 cures have zero UX-quality coverage in the current stack — see cure matrix at `test-topology.html` artifact. upstream#2256 was reported by cold adopter directly as "not enough hint around the concise mode in initial flow."

**Why this evidence supports the claim:** Three cures today ride on behavioral tests only. The fourth was authored under human review. Any future prose change on the same surface can slip the same way unless a tier reads prose as adopters read it.

## Shape

cli#448 proposes three insertion points. They **ride together** — each covers a defect class the others miss.

### Prong A — PR Reviewer gate · pre-tier (persona-context SKILL diff review)

- **Where**: PR open on any file matching `.claude/skills/onboard-repo/**` body prose. Fires before any test tier runs.
- **Who**: Reviewer agent, with cold-adopter persona context loaded (Sam persona at `docs/personas/sam.md`).
- **What**: Reads the SKILL diff. Scores each changed prompt against informed-consent criteria:
  1. Does the prompt explain what will happen if the adopter says yes?
  2. Does the prompt explain what will happen if the adopter says no?
  3. Does the prompt name an unwind path?
  4. Does the body prose read at grade 8 per `.claude/rules/plain-english-discipline.md`?
- **Why**: Catches tone + framing drift. The only tier that can judge "would Sam understand this."
- **Cost**: ~2 min per PR touching the matcher.
- **Luminary**: Alan Cooper (goal-directed design) + Donald Norman (signifier + feedback loop).

### Prong B — Pre-commit WARN · tier-0 mechanical floor (regex for naked Y/n)

- **Where**: Pre-commit hook on staged SKILL diff. Mechanical regex check.
- **What**: Fire WARN (not BLOCK) when a Y/n prompt lands without ≥2 sentences of body prose above it. Pattern: `[Yy]/[Nn]` within 3 lines of a non-prose line (blank line or heading).
- **Why**: Catches the **shape** fast. Does not catch the **quality** of the body prose when present. Cheap floor.
- **Cost**: adds <100ms to pre-commit for any SKILL edit.
- **Luminary**: Kent Beck (test the structural invariant mechanically).

### Prong C — Persona-UX fixture tier · new sibling to tier 06 (fixture rendering)

- **Where**: New tier between interactive flow (tier 06) and e2e flow drivers (tier 07) in the test topology. Lives at `scripts/tests/persona-ux-*.test.sh`.
- **What**: Script renders the onboard flow against a persona context, captures prose output as plain text, writes to `state/persona-ux/<persona>-<date>.md`. Operator reviews offline.
- **Why**: The only tier that reads prose **as adopters will read it**. Catches semantic drift the regex and reviewer gates miss when the diff is small but the shipped prose has shifted elsewhere.
- **Cost**: ~5-10 min per persona per release cycle.
- **Luminary**: Michael Feathers (characterization — pin the actual rendered output).

## Build sequence

Steps compound. Each produces an artifact the next consumes.

### Step 0 — prep · scope + personas pinned

- **Produces**: this canvas + personas enumerated (Sam cold-adopter + Louis daily operator + Jamie prototype loop).
- **Consumes**: session-start.
- **Risk**: 🟢 low — scope read + canvas author.
- **Time**: 10-20 turns.

### Step 1 — Prong B first (mechanical floor; cheapest)

- **Produces**: `.claude/hooks/pre-commit-naked-prompt-check.sh` + Tier 0 tests + settings.json wire.
- **Consumes**: Step 0 persona pins + `.claude/rules/plain-english-discipline.md` (grade-8 wordlist).
- **Risk**: 🟢 low — pre-commit hook with regex. BLOCK radius = adopter can commit; WARN never blocks shipping.
- **Why first**: closes the "naked Y/n" class in one commit. Mechanical floor compounds across every future SKILL edit.
- **Time**: 30-50 turns.
- **Luminary lead**: Kent Beck.

### Step 2 — Prong A second (reviewer gate; per-PR judgment)

- **Produces**: Reviewer agent amendment at `~/.claude/agents/reviewer.md` + checklist row + persona-context loader + marker contract (`state/markers/reviewer/<branch>.md` carries `persona_ux_review` field).
- **Consumes**: Step 1 pre-commit hook (so reviewer runs **after** mechanical floor is clean) + persona files at `docs/personas/`.
- **Risk**: 🟡 med — reviewer agent extension touches cross-cutting discipline. Needs loop-discipline iteration 1.
- **Why second**: builds on mechanical floor; adds judgment layer where tier-0 regex cannot reach.
- **Time**: 50-80 turns.
- **Luminary lead**: Alan Cooper + Donald Norman.

### Step 3 — Prong C third (persona-UX fixture tier; most expensive)

- **Produces**: `scripts/tests/persona-ux/` directory with 3 fixture scripts (one per persona) + runner at `scripts/run-persona-ux.sh` + README naming the review protocol.
- **Consumes**: Step 0 persona pins + bundled SKILL at `dist/lite/.claude/skills/onboard-repo/SKILL.md`.
- **Risk**: 🟡 med — fixture renders onboard flow; needs careful prompt capture + persona-context injection.
- **Why third**: covers the semantic class that regex + reviewer alone miss. Lives beside tier-06 (interactive flow) — same CI schedule, different output format.
- **Time**: 60-100 turns.
- **Luminary lead**: Michael Feathers (characterization) + Alan Cooper (persona).

### Step 4 — Backfill against the 4 Session U cures

- **Produces**: 4 persona-UX fixture outputs (one per cure) pinned at `state/persona-ux/baseline/`.
- **Consumes**: Step 3 fixture tier + the 4 shipped v1.11.1 cured prompts.
- **Risk**: 🟢 low — characterization run against known-good state.
- **Why**: establishes the baseline so Step 3 can detect drift in future releases. Closes the UX-quality column of the cure coverage matrix.
- **Time**: 30-50 turns.
- **Luminary lead**: Michael Feathers.

### Step 5 — Retire the stale regression

- **Produces**: `smoke-drive-regression-onboard-free-tier-403.test.sh` updated to match current prose (bassclef-upstream#2235 wording), OR retired with ticket citation.
- **Consumes**: Step 4 baseline (confirms the semantic coverage lives in Prong C now).
- **Risk**: 🟢 low — one test file.
- **Why last**: Session V surfaced that the regression's literals have drifted from the shipped SKILL prose. Fix the characterization pattern after Prong C can take over the semantic coverage.
- **Time**: 10-20 turns.
- **Luminary lead**: Michael Feathers.

## Amendment 1 — 2026-10-26 · what the first build attempt found

Session W tried to build Prong B and stopped. Three findings reshape the
canvas. The Shape and Build sequence sections above are kept as written;
this amendment supersedes them where the two disagree.

### Finding 1 — Prong B cannot run in bassclef-cli

A pre-commit check in this repo that scans staged onboarding SKILL diffs
can never fire. The file is never staged here.

- `.gitignore:76` ignores `.claude/skills/`. `git ls-files .claude/skills`
  returns 0 files.
- `.gitignore:20` ignores `dist/`. `git ls-files dist/lite` returns 0 files.
- `scripts/prepublish-bundle-substrate.mjs:86` resolves the substrate source
  to `../bassclef-upstream`. The bundle is copied in at publish time.
- `.claude/skills/onboard-repo/SKILL.md` is tracked in bassclef-upstream only.

The canvas names hook paths but never names which repo each prong lives in.
That omission is what let the plan read as local work.

### Finding 2 — Prong B is not a new hook upstream

Two upstream hooks already match the exact path and already read the file.
The work is a new section in each, not a new file plus a new wire.

- `substrate-clarity-gate.sh:64` matches `*/.claude/skills/*/SKILL.md` and
  runs before an edit lands. Wired at `.claude/settings.json:230`.
- `pre-commit-gate.sh:360` already scans `git diff --cached` for
  `.claude/skills/*/SKILL.md` for the reserved-name check.

### Finding 3 — the text comes in two kinds, and a source scan sees one

Read in context, the three onboarding prompts are not alike.

**Written out word for word.** Lines 1344 and 1757 of the onboarding SKILL
are verbatim blocks the model renders as-is. A machine reading the file can
check these.

**Written as an instruction.** Line 645 reads
`# Prompt operator: "Does this repo deploy to prod? [y/N]"` — a note telling
the model to ask something. The model writes the sentence the adopter reads.
A machine reading the file sees the instruction, not the wording. This one
carries no explanation at all, and it governs production deploys.

So the concern is wider than yes/no prompts. Coherence covers headers, status
lines, error text, the order things appear in, and whether the whole flow
sounds like one voice. None of that matches a yes/no pattern, and a machine
reading source cannot see generated wording at all.

This flips the weight of the three prongs.

| Prong | What it reads | What it catches | What it cannot see |
|---|---|---|---|
| **B** — machine, source | the file as written | a verbatim block missing its explanation | generated wording · coherence · tone · ordering |
| **A** — person, proposed change | the diff, with a persona in mind | tone and framing on changed lines | wording that drifted elsewhere · the flow as a whole |
| **C** — the run | everything the adopter actually sees | generated wording · coherence · voice · ordering | nothing — this is the real view |

Prong C is the answer to cli#448. Prong B is a cheap floor over part of the
surface. Prong A sits between them.

### Repo placement — corrected

| Prong | Repo | Why there |
|---|---|---|
| B — machine, source | bassclef-upstream | the only place the file is open for editing |
| A — person, proposed change | bassclef-upstream | changes to the text are proposed there |
| C — the run | bassclef-cli | only the assembled package holds the real shipped skill to run |

Two of three stay here. Prong B moves, and only its machine half.

### Why the cli-side check is not redundant with the upstream ones

`publish.yml:122` pins the substrate to a release tag. So this repo can
assemble and publish wording written before any upstream check existed. At
that moment nobody is typing and nobody is committing. A check reading the
assembled package is the only one looking. Same moment as the pre-publish
gate proposed in PR #449 (ADR-012), so it joins that gate rather than
inventing a second one.

---

## Amendment 2 — 2026-10-26 · Step 1 replaced by a read, not a build

The cheapest first step needs no machinery. Before any hook ships, read the
skills a first-time user actually meets and write down what confuses them.
Nothing can be automated well until we know what we are looking for, and six
yes/no prompts were never the real target.

### Step 1 (new) — coherence audit of the first-touch skills

- **Produces**: `docs/audits/2026-MM-DD-persona-coherence-first-touch.md` —
  one row per skill per finding, each row naming the persona that bounces and
  the line that causes it. Plus a short list of the patterns that recur, which
  becomes the rule the later checks enforce.
- **Consumes**: `docs/personas/README.md` (this repo's pointer to the persona
  files, which live upstream and carry `tier: upstream`) + the assembled
  package at `dist/lite/.claude/skills/`.
- **Risk**: 🟢 low — a read and a document. Changes no shipped behavior.
- **Why first**: it tells us what the machine rule should say. Writing the
  hook first guesses the rule.
- **Time**: 40-70 turns for 14 skills.
- **Luminary lead**: Alan Cooper (does this serve the person's goal) with
  Donald Norman (does the wording tell them what happens next).

**Scope — 14 skills.** 73 skills carry `tier: lite`, which is too many for a
first pass. The shortlist below is a judgment call, grounded in Sam's
documented 15-30 minute path (`docs/personas/sam.md` Tasks + Approach) and
Louis's recurring loop across several surfaces. It is not derived from usage
data, because we have none.

First touch — what Sam meets inside 30 minutes:

`onboard-repo` · `whereami` · `sprint` · `skills` · `howdoi` · `launch` · `verify`

Recurring — what Louis runs every week:

`longrun` · `session-end` · `session-log` · `kiss` · `temperance` · `diagnose` · `promote`

Second wave, if the first pass is cheap: `riff` · `stage` · `build` ·
`value-prop` · `state-a-problem`.

**What each read checks.** Six questions, taken from Sam's `bounces_on` list
plus the coherence concern in Amendment 1.

1. Does any sentence use a word only a bassclef user knows?
2. Does a question say what happens if the person says yes?
3. Does a question say how to undo it?
4. When the skill tells the person to do something, does it name the path or
   command, or assume they know?
5. Does the voice stay the same from first screen to last, or does it read
   like a different author mid-flow?
6. Does the order make sense to someone who does not already know the system?

**Why the audit reads the assembled package, not the source.** The source
lives upstream and this repo cannot edit it. The assembled package is what
adopters receive, and it is what the later run-based check will read, so the
audit and the check look at the same thing.

### The later steps, renumbered

Prior Step 1 (Prong B) becomes Step 2 and moves upstream. Prior Step 2
(Prong A) becomes Step 3 and stays upstream. Prior Step 3 (Prong C) becomes
Step 4 and stays here. Steps 4 and 5 become Steps 5 and 6. Each still
consumes what the one before it produces, and each now names its repo.

### Tickets filed 2026-10-26

| Ticket | Repo | Prong | What it is |
|---|---|---|---|
| #453 | bassclef-cli | — | Read the 14 first-touch skills. Produces the pattern list the checks encode. Do this first. |
| upstream#2272 | bassclef-upstream | B | Machine check on text written word for word. Two sections in two hooks that already exist. |
| #454 | bassclef-cli | C | Run the flow against the assembled package and read it as a conversation. Joins the gate in PR #449. |

Prong A — the human review on proposed changes — is not yet filed. It needs
the pattern list from #453 to have a rubric worth reviewing against.

### Open question answered

Open question 4 above asks whether Prong C covers Sam only or all three
personas. The audit answers it with data instead of a guess: if the findings
cluster on one persona, scope the run-based check to that persona first.

---

## Open questions for next-session kickoff

1. **Does Prong C live as a shell script with Claude dispatch, or as a Node fixture?** Shell + Claude mirrors the existing smoke-drive-* pattern (familiar). Node fixture avoids Claude cost but asks a different question (what the SKILL body renders to, not what Claude says back).
2. **Does the Reviewer gate (Prong A) auto-dispatch on PR open, or require operator `/code-review` invocation?** Auto fires on every matching PR; operator invocation keeps cost explicit.
3. **Does Step 4 baseline capture happen inside this session chain, or get deferred until Prong C renders against each new release?** First path = canonical fixture snapshot; second = living characterization that updates per release.
4. **Prong C persona set — just Sam, or Sam + Louis + Jamie?** Sam-only covers the cold-adopter surface (highest value). Full three personas cover daily-operator + prototype prose changes too (full coverage).

## Entry state for next session

Session V closeout artifacts:
- v1.9.19 LIVE on npm; bundles bassclef v1.11.1.
- 4 upstream cold-adopter cures delivered (upstream#2253 shellcheck, #2255 oauth probe, #2256 Concise preamble, #2257 auto-save; plus housekeeping #2261).
- Full stack rerun: **49/50 PASS** in characterization mode (SMOKE_LIVE unset). 1 stale regression (free-tier-403) deferred to Step 5.
- Open ticket: cli#448 (persona-driven UX review) — THIS canvas closes it.

## Refs

- cli#448 — `feat(reviewer): persona-driven UX review on onboarding SKILL prose changes` (OPEN).
- upstream#2256 — the Concise opt-in defect that motivated cli#448.
- Session V chronicle — `docs/chronicle/2026-10-18-session-v-v1-9-19-republish.md`.
- Session U chronicle — `docs/chronicle/2026-10-18-session-u-v1-9-18-release-cold-adopter-defects.md`.
- Test topology artifact — `test-topology.html` (private artifact, Session V diagram).
- `.claude/rules/plain-english-discipline.md` — grade-8 target for prose checks.
- `.claude/rules/writing-craft-discipline.md` — Ogilvy six-tests for Prong A rubric.
- `.claude/rules/operator-facing-prose.md` — gloss discipline for naked-prompt detection.
- `docs/personas/sam.md` — cold-adopter persona (primary Prong C fixture target).
- `docs/personas/README.md` — pointer to the persona files; they live in
  bassclef-upstream and carry `tier: upstream`, so they never sync here.
- PR #452 — `cli#444` fix; the session that produced Amendment 1.
- PR #449 — ADR-012, pre-publish gate; sibling moment for the cli-side check.
- `scripts/prepublish-bundle-substrate.mjs` — assembles `dist/lite/`, the
  surface the audit and the run-based check both read.
- #453 — the coherence audit; new Step 1
- #454 — the run-based check; Prong C
- upstream#2272 — the machine check on source text; Prong B
