---
date: 2026-09-11
authored_by: agent
authoring_lens: extract-intent + luminary chain (Cooper primary; Norman + Ousterhout supporting)
adopter_source: sunj-labs/bassclef-cli
target_repo: sunj-labs/bassclef-upstream
skills_covered: [riff, launch, build, howdoi]
---

# Tagline proposals — 4 skills through the brownfield-adopter lens

## Context

Bassclef-cli ships `@thebassclef/lite` to npm. It is a brownfield adopter of bassclef substrate — real repo, real adopters, real npm SKU. The four skills below were reviewed through bassclef-cli's lens as a brownfield adopter would experience them.

The current descriptions are already grade-8 plain English. Each proposed tagline aims to be even tighter and more distinctive vs adjacent skills. The taglines could replace the `description:` field, or ride alongside as marketing copy.

## Sources read

- `.claude/skills/riff/SKILL.md` — current description + problem + value
- `.claude/skills/launch/SKILL.md` — current description + problem + value + composes_baseline
- `.claude/skills/build/SKILL.md` — current description + problem + value
- `.claude/skills/howdoi/SKILL.md` — current description + problem + value + modes
- `docs/whereami.md` — bassclef-cli adopter role + open threads
- `docs/session-logs/2026-09-07-lite-rename-sync-publish-shipped.md` — recent adopter session shape
- `.claude/luminaries/alan-cooper.md`, `.claude/luminaries/donald-norman.md`, `.claude/luminaries/john-ousterhout.md`

## /promote — 4 draft issue bodies

Each block below is ready to file at bassclef-cli as `bassclef-evolution` + `adopter-source` per the /promote skill. bassclef-upstream operator triages via `/triage-public`.

---

### 1. /riff

**Proposed tagline:** *See three futures for one screen — pick before you build.*

**Current description** (280 chars max):
> Produce 2-3 clickable mock alternatives for a UI surface. Each mock uses a different luminary lens. Louis picks a marketing variant. Sam picks a direction before building. Combines /interpret-input + /luminary + /stage + /visual-review.

**Proposed rewrite** (140 chars):
> See three futures for one screen — pick before you build. Each mock rides a different luminary lens. Sam picks direction; Louis picks marketing.

**Brownfield lens (bassclef-cli):** A brownfield adopter typing `/riff` on a new CLI verb or install-flow surface gets three concrete futures side-by-side. Faster than reading three docs; safer than committing to code.

**Luminary rationale:**
- **Cooper** — Sam sees the direction she is picking, not a text description. Zero-imagination-tax.
- **Norman** — three mocks give feedback + affordance signals side-by-side; picking is a comparison, not a leap.

**Why file:** Current description packs 4 chained skills into the sentence. The reader learns HOW /riff works before WHAT it delivers. The proposed line puts outcome first.

---

### 2. /launch

**Proposed tagline:** *From napkin sketch to ready-to-ship plan — mocks included.*

**Current description** (280 chars max):
> Turn an idea into a buildable plan. Ships a clickable mock gallery plus the spec, user stories, decomposition, and migration plan. Two sizes: medium and full. Two deploy modes: extended (subdomain) and --local (localhost).

**Proposed rewrite** (145 chars):
> From napkin sketch to ready-to-ship plan — mocks included. Ships a clickable gallery plus spec plus stories plus decomposition. Sizes: medium, full.

**Brownfield lens (bassclef-cli):** A brownfield adopter with a rough ticket (like #55) types `/launch` and gets a clickable gallery + spec + stories + decomposition. Instead of jumping straight to code (as bassclef-cli did tonight for #55), the plan lands first. Fewer scope-conflict discoveries at Step 1.

**Luminary rationale:**
- **Cooper** — Sam sees the shape before writing code. No surprise at Step 1.
- **Ousterhout** — one command hides four artifacts. Deep-module interface.

**Why file:** Current description mentions "medium and full" without saying why. Proposed line leads with the transformation (sketch → plan), which is what an adopter wants to know before running.

---

### 3. /build

**Proposed tagline:** *Ship the plan you already wrote — one PR per user story.*

**Current description** (280 chars max):
> Take a buildable plan and ship it. Reads a spec from /launch. Dispatches a builder per user story. Runs /verify. Opens PRs. Gates prod deploy on a human. Refuses auth, schema, security, and tenant work. --explain narrates first.

**Proposed rewrite** (145 chars):
> Ship the plan you already wrote — one PR per user story. Reads a /launch spec; opens PRs; runs verify; gates prod on a human. Refuses auth + schema + security.

**Brownfield lens (bassclef-cli):** For bassclef-cli, /build would fit the "ship a mid-size feature with proper decomposition" case — e.g., a new CLI verb with UC + spec + stories. Current session used /longrun (lighter ceremony) because #55 was a one-line fix. /build's value clarifies against /longrun by scale — plan-first, story-per-PR.

**Luminary rationale:**
- **Ousterhout** — one command hides the whole build cycle. Adopter watches, does not type.
- **Cooper** — the hard-ceiling list (auth + schema + security) is a safety affordance; adopter sees the guardrails before running.

**Why file:** Current description packs 6 verbs (reads / dispatches / runs / opens / gates / refuses) into one sentence. Proposed line leads with the transformation (plan → PRs) and moves guardrails to a second clause.

---

### 4. /howdoi

**Proposed tagline:** *Ask "how do I" — get the skill (and the reason it fits).*

**Current description** (280 chars max):
> Search bassclef skills and rules for an adopter goal — LLM-assisted. Two modes — search (top matches) and compose (matches plus suggested chains). Ranks by semantic fit and cites what each match does.

**Proposed rewrite** (128 chars):
> Ask "how do I" — get the skill (and the reason it fits). Two modes: search (top matches) and compose (matches plus chains).

**Brownfield lens (bassclef-cli):** A brownfield adopter mid-session (like tonight) types `/howdoi "how do I add a new CLI verb?"` and gets top-3 skill matches with one-line reasons. Especially useful for cross-session recall — a repo like bassclef-cli inherits 99 skills; no operator remembers all 99.

**Luminary rationale:**
- **Cooper** — Sam asks in her own words. No skill-name memorization.
- **Norman** — the "why it fits" line is the feedback signal that turns a match into a decision.

**Why file:** Current description names two modes but the reader has to parse "LLM-assisted" + "semantic fit" as tech marketing. Proposed line leads with the interaction (ask a question in plain words).

---

## Optional follow-on

Consider a bassclef-upstream sister ticket: an audit skill (`/tagline-audit`) that reviews every skill's `description:` field against a rubric — verb-first, outcome-first, ≤180 chars for the tagline half, mode names inline (per `.claude/rules/skill-description-clarity.md`), no chained-skill dumps at the front. The four proposals above would characterize the audit's target shape.

## What did NOT change

- Skill behavior — every proposed rewrite is a description-only change
- Frontmatter `problem:` and `value:` fields — already grade-10; kept intact
- Composes-with declarations — unchanged; the how still lives in the SKILL body
