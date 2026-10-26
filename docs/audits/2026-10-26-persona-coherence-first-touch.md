---
tier: upstream
type: audit
date: 2026-10-26
ticket: cli#453
scope: 7 first-touch skills, read in the assembled package
read_from: dist/lite/.claude/skills/
fix_lands_in: sunj-labs/bassclef-upstream
luminaries:
  primary: alan-cooper
  supporting: [donald-norman, michael-feathers]
---

# Coherence audit — the 7 skills a new person meets first

## What this is

A read, not a test. The goal was to find out what confuses a first-time user
and write it down, so the checks in `upstream#2272` and `cli#454` encode a
real rule instead of a guess.

Read from `dist/lite/.claude/skills/` — the assembled package, which is what
adopters receive. All 7 are byte-identical to the source in bassclef-upstream
today, verified with `diff`. Fixes land upstream, so every finding below
names the upstream path.

## The six questions

1. Does any sentence use a word only a bassclef user knows?
2. Does a question say what happens if the person says yes?
3. Does a question say how to undo it?
4. When the skill tells the person to do something, does it name the path or
   command, or assume they know?
5. Does the voice stay the same from first screen to last?
6. Does the order make sense to someone who does not know the system?

Questions 1 to 4 come from the `bounces_on` list in the Sam persona. Questions
5 and 6 cover coherence, which no word-list check can reach.

## Headline

The word-list checks already work. The damage is elsewhere.

A scan of all 7 skills against the 64 BLOCK-tier terms in
`standards/bassclef-internal-jargon.md` returned **5 hits**. Question 1 is
close to solved, and the existing hooks did that.

Every remaining finding sits in questions 4, 5, and 6 — the three no machine
covers today.

## Findings

Severity: **high** = a new person is likely to stop reading or act wrongly.
**med** = they push through but lose trust. **low** = cosmetic.

| # | Skill | Line | Q | Sev | Finding |
|---|---|---|---|---|---|
| F1 | onboard-repo | — | 6 | **high** | No reader/detail boundary anywhere in 1910 lines. See below. |
| F2 | launch | — | 6 | **high** | Same — no boundary in 1032 lines. |
| F3 | onboard-repo | 645 | 2 | **high** | A question about production deploys with no explanation of what yes does. |
| F4 | whereami | 21 | 5 | med | A model instruction sits inside the reader-facing opening. |
| F5 | sprint | 25 | 5 | med | Same shape, same section. |
| F6 | launch | 106-107 | 1 | med | "Composer-preflight" in reader-facing prose. |
| F7 | launch | 69 | 1 | low | Table row labelled "Compose-with". |
| F8 | onboard-repo | 83 | 1 | low | "destroys 20+ hook wirings" — "wirings" is a BLOCK term. |
| F9 | onboard-repo | 1146 | 1 | low | "(operator-eyes design choices)". |

### F1 + F2 — the two longest skills have no reader/detail boundary

Five of the 7 skills split reader-facing prose from procedure with a
`## Details below the fold` heading. Two do not.

| Skill | Total lines | Boundary at |
|---|---|---|
| onboard-repo | 1910 | **none** |
| launch | 1032 | **none** |
| whereami | 307 | 109 |
| sprint | 439 | 97 |
| skills | 228 | 59 |
| howdoi | 105 | 55 |
| verify | 160 | 67 |

These are the two longest skills, and `onboard-repo` is the first thing a new
person runs. Sam has 15 to 30 minutes and "skims first, digs second, bails
third" (`docs/personas/sam.md`). Without a boundary there is no signal where
skimming ends. The reader either reads 1910 lines of procedure or guesses.

Highest-value fix in this audit, and the cheapest — it is one heading placed
in the right spot.

### F3 — the production-deploy question

`.claude/skills/onboard-repo/SKILL.md:645`:

```bash
# Prompt operator: "Does this repo deploy to prod? [y/N]"
```

Ten words of prose sit above it. Compare the other two questions in the same
skill, which both carry real explanation:

| Line | Words of prose directly above |
|---|---|
| 645 | **10** |
| 1344 | 17 |
| 1757 | 19 |

Two things make this the worst of the three. It governs production deploys.
And it is written as an instruction to the model rather than as prose, so the
sentence the person reads is generated at runtime — which means no check that
reads source files can see what they were actually asked.

### F4 + F5 — model instructions inside reader-facing prose

`whereami` opens with "What you get", then two paragraphs in:

> **Tier gate (bassclef#740 Task 1.8).** `/whats-the-plan` ships at
> `tier: standard`. Lite adopters skip it. Print skip note. Resolve tier via
> `lib/tier-check.sh`.

Three problems in four sentences. "Print skip note" and "Resolve tier via
`lib/tier-check.sh`" are orders to the model, not information for the reader.
"bassclef#740 Task 1.8" means nothing to anyone outside the project. And
"Lite adopters skip it" tells the reader they are missing something without
saying which tier they are on or how to find out.

`sprint` carries the same block in the same position.

Counts across the 5 skills that have a boundary, measured on reader-facing
lines only, code blocks stripped:

| Skill | Reader lines | Model instructions | Ticket refs | Internal paths |
|---|---|---|---|---|
| whereami | 104 | 2 | 3 | 3 |
| sprint | 97 | 4 | 2 | 3 |
| verify | 67 | 4 | 0 | 2 |
| skills | 59 | 0 | 2 | 1 |
| howdoi | 55 | 0 | 0 | 1 |

`howdoi` is the clean one. Zero instructions, zero ticket references, one path.
It reads start to finish as one voice talking to a person. It is the model the
other six should follow.

## What the script reports, and why two numbers look wrong

The scans are saved at `scripts/audit-skill-reader-prose.sh`. Run on the 7:

```
By pattern: P1 x2 · P2 x84 · P3 x38 · P4 x5
Total: 129 findings across 6 skills
```

Those P2 and P3 totals are inflated, and the reason matters.

The script treats everything above the `## Details below the fold` heading as
prose a reader sees. `onboard-repo` and `launch` have no such heading, so the
script reads all 1910 and 1032 lines as reader-facing. Most of those lines are
procedure nobody but the model reads.

So **the script cannot tell prose from procedure in those two files. Neither
can a reader.** The inflated count is the same blindness F1 and F2 describe,
measured a second way.

Split the numbers and both halves read true:

| | P1 | P2 | P3 | P4 |
|---|---|---|---|---|
| **The 5 skills with a boundary** | 0 | 7 | 9 | 0 |
| **The 2 without** | 2 | 77 | 29 | 5 |

Measured by running the script on each group, not by subtraction.

The left column is the real rate of this problem when a skill is structured:
roughly 3 findings per skill, all medium. The right column is what happens
without the boundary.

Fix F1 and F2 first and the right column shrinks to whatever sits above the
new heading. That is the whole argument for doing P1 before anything else.

## Patterns worth encoding

This is the deliverable. Ranked by how much a machine can catch.

**P1 — a long skill with no reader/detail boundary.** Fully mechanical. Flag
any skill over roughly 300 lines with no `## Details below the fold`. Two hits
in seven, both high severity. Cheapest rule in the set, and it catches the
worst finding.

**P2 — a ticket reference in reader-facing prose.** Fully mechanical. Match
`bassclef#NNN`, `Task N`, `ADR-NNN` above the boundary. 7 hits across the 5
skills that have a boundary. 77 more in the two that do not, which P1 fixes
first.

**P3 — an imperative aimed at the model in reader-facing prose.** Mostly
mechanical. A small verb list — Print, Dispatch, Resolve tier, Touch, Emit,
Fire — above the boundary. 9 hits in the 5 structured skills, 29 more in the
two without a boundary. Some hits will be false, because a few of those verbs
legitimately address the reader. Ship it as a warning, not a block.

**P4 — a yes/no question with less than two sentences above it.** Mechanical
on text written word for word, blind to anything the model generates. This is
the rule `upstream#2272` was filed for. One hit, and it is the one the rule
would miss, because line 645 lives inside a code comment.

**P5 — an internal file path in reader-facing prose.** Mechanical but noisy.
10 hits. Some are useful to the reader (`docs/whereami.md`); some are not
(`lib/tier-check.sh`). Needs a judgment call per path, so this one belongs
with a person, not a regex.

**P6 — voice drift.** Not mechanical. The `whereami` block reads like a
different author than the paragraph above it. Only a person or a model reading
the whole flow catches this.

## What this changes about the two open tickets

**`upstream#2272` is scoped too narrowly.** It was filed for P4 alone — one
finding, low severity, and the rule as written cannot see the one instance
that matters. P1 and P2 are cheaper to build, catch more, and catch worse.
Recommend widening it, with P1 first.

**`cli#454` is confirmed as the important half.** P6 needs a reading of the
whole flow, and F3 needs the generated wording. Neither is reachable from a
source scan.

**Open question 4 in the canvas now has an answer.** Every finding here is a
Sam finding — first-touch confusion. Nothing surfaced that only affects a
daily operator. Scope the run-based check to Sam first.

## Honest limits

- **7 of 73 skills.** Not a sample — a judgment call about which a new person
  meets first, taken from the Sam persona's documented path. No usage data
  exists to check it against.
- **One reader.** I read these as a model. Sam is a person on a Saturday with
  coffee. The findings skew toward what is countable.
- **Questions 2 and 3 are nearly untested.** Only 4 skills ask anything, so
  the sample is tiny.
- **One finding was wrong and got dropped.** Three descriptions carry a
  `—` escape in frontmatter. I expected the reader to see it literally.
  A YAML parse shows the escape decodes to an em-dash. No defect. Noted
  because the next reader may suspect the same thing.
- **The script counts the unfolded skills wrongly, on purpose.** See the
  section above. Treating the fix as "tune the regex" would hide F1.
- **Nothing here is measured against a run.** Every finding comes from
  reading files. The generated half is still unseen, which is the whole case
  for `cli#454`.

## Reusable output

`scripts/audit-skill-reader-prose.sh` reports P1 to P4 over any directory of
skills. Defaults to the assembled package. Takes skill names as arguments, or
runs the lot. Exit 1 on findings, 0 clean, 2 when there is nothing to read.

```bash
bash scripts/audit-skill-reader-prose.sh                  # all 73
bash scripts/audit-skill-reader-prose.sh whereami sprint  # named
```

That makes the sweep of the other 59 skills a single command plus a read of
the output, which is why the estimate below is far under the one on cli#453.

## Rate, for sizing the rest

7 skills took roughly 14 turns, including two mechanical scans that are now
reusable. Call it 2 turns per skill at depth once the scans exist.

So the 7 recurring skills are 15-20 turns. A shallow sweep of the other 59 —
P1 and P2 only, both fully mechanical — is 5-10 turns total, because it is one
script run and a read of the output. That is much cheaper than the 40-70 turns
estimated on `cli#453`, and the "why only 14" framing was wrong: with P1 and
P2 mechanized, all 73 are affordable in one pass.

## Refs

- cli#453 — this audit
- cli#448 — the parent request
- cli#454 — the run-based check; P6 and F3 need it
- upstream#2272 — the source-side check; recommend widening to P1 + P2
- `docs/canvases/2026-10-25-persona-ux-test-tier.md` Amendment 2 — this is Step 1
- `docs/personas/README.md` — where the persona files live
- `standards/bassclef-internal-jargon.md` — the 64 BLOCK terms scanned
- @luminary alan-cooper — does the wording serve the person's goal
- @luminary donald-norman — does it tell them what happens next
- @luminary michael-feathers — read what it actually does before naming it
