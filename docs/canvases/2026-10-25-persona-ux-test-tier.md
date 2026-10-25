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

### WU-0 — prep · scope + personas pinned

- **Produces**: this canvas + personas enumerated (Sam cold-adopter + Louis daily operator + Jamie prototype loop).
- **Consumes**: session-start.
- **Risk**: 🟢 low — scope read + canvas author.
- **Time**: 10-20 turns.

### WU-1 — Prong B first (mechanical floor; cheapest)

- **Produces**: `.claude/hooks/pre-commit-naked-prompt-check.sh` + Tier 0 tests + settings.json wire.
- **Consumes**: WU-0 persona pins + `.claude/rules/plain-english-discipline.md` (grade-8 wordlist).
- **Risk**: 🟢 low — pre-commit hook with regex. BLOCK radius = adopter can commit; WARN never blocks shipping.
- **Why first**: closes the "naked Y/n" class in one commit. Mechanical floor compounds across every future SKILL edit.
- **Time**: 30-50 turns.
- **Luminary lead**: Kent Beck.

### WU-2 — Prong A second (reviewer gate; per-PR judgment)

- **Produces**: Reviewer agent amendment at `~/.claude/agents/reviewer.md` + checklist row + persona-context loader + marker contract (`state/markers/reviewer/<branch>.md` carries `persona_ux_review` field).
- **Consumes**: WU-1 pre-commit hook (so reviewer runs **after** mechanical floor is clean) + persona files at `docs/personas/`.
- **Risk**: 🟡 med — reviewer agent extension touches cross-cutting discipline. Needs loop-discipline iteration 1.
- **Why second**: builds on mechanical floor; adds judgment layer where tier-0 regex cannot reach.
- **Time**: 50-80 turns.
- **Luminary lead**: Alan Cooper + Donald Norman.

### WU-3 — Prong C third (persona-UX fixture tier; most expensive)

- **Produces**: `scripts/tests/persona-ux/` directory with 3 fixture scripts (one per persona) + runner at `scripts/run-persona-ux.sh` + README naming the review protocol.
- **Consumes**: WU-0 persona pins + bundled SKILL at `dist/lite/.claude/skills/onboard-repo/SKILL.md`.
- **Risk**: 🟡 med — fixture renders onboard flow; needs careful prompt capture + persona-context injection.
- **Why third**: covers the semantic class that regex + reviewer alone miss. Lives beside tier-06 (interactive flow) — same CI schedule, different output format.
- **Time**: 60-100 turns.
- **Luminary lead**: Michael Feathers (characterization) + Alan Cooper (persona).

### WU-4 — Backfill against the 4 Session U cures

- **Produces**: 4 persona-UX fixture outputs (one per cure) pinned at `state/persona-ux/baseline/`.
- **Consumes**: WU-3 fixture tier + the 4 shipped v1.11.1 cured prompts.
- **Risk**: 🟢 low — characterization run against known-good state.
- **Why**: establishes the baseline so WU-3 can detect drift in future releases. Closes the UX-quality column of the cure coverage matrix.
- **Time**: 30-50 turns.
- **Luminary lead**: Michael Feathers.

### WU-5 — Retire the stale regression

- **Produces**: `smoke-drive-regression-onboard-free-tier-403.test.sh` updated to match current prose (bassclef-upstream#2235 wording), OR retired with ticket citation.
- **Consumes**: WU-4 baseline (confirms the semantic coverage lives in Prong C now).
- **Risk**: 🟢 low — one test file.
- **Why last**: Session V surfaced that the regression's literals have drifted from the shipped SKILL prose. Fix the characterization pattern after Prong C can take over the semantic coverage.
- **Time**: 10-20 turns.
- **Luminary lead**: Michael Feathers.

## Open questions for next-session kickoff

1. **Does Prong C live as a shell script with Claude dispatch, or as a Node fixture?** Shell + Claude mirrors the existing smoke-drive-* pattern (familiar). Node fixture avoids Claude cost but asks a different question (what the SKILL body renders to, not what Claude says back).
2. **Does the Reviewer gate (Prong A) auto-dispatch on PR open, or require operator `/code-review` invocation?** Auto fires on every matching PR; operator invocation keeps cost explicit.
3. **Does WU-4 baseline capture happen inside this session chain, or get deferred until Prong C renders against each new release?** First path = canonical fixture snapshot; second = living characterization that updates per release.
4. **Prong C persona set — just Sam, or Sam + Louis + Jamie?** Sam-only covers the cold-adopter surface (highest value). Full three personas cover daily-operator + prototype prose changes too (full coverage).

## Entry state for next session

Session V closeout artifacts:
- v1.9.19 LIVE on npm; bundles bassclef v1.11.1.
- 4 upstream cold-adopter cures delivered (upstream#2253 shellcheck, #2255 oauth probe, #2256 Concise preamble, #2257 auto-save; plus housekeeping #2261).
- Full stack rerun: **49/50 PASS** in characterization mode (SMOKE_LIVE unset). 1 stale regression (free-tier-403) deferred to WU-5.
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
