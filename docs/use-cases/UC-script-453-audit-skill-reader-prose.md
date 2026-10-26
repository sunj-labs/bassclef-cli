---
tier: upstream
type: use-case
ceremony: brief
id: UC-script-453
title: Report wording in a skill that a first-time reader bounces on
closes_ticket: cli#453
scope_class: b
luminaries:
  primary: alan-cooper
  supporting: [michael-feathers, donald-norman]
---

# UC-script-453 — report wording a first-time reader bounces on

Brief ceremony per `.claude/rules/oo-ad-entry-point.md` — one script plus the
audit that defines its rules.

## Primary actor

Whoever is reading bassclef's skills on behalf of a first-time user. Today
that is the operator or an agent running the audit on cli#453.

## Stakeholders and interests

- **A first-time user** — never runs this, and is the reason it exists. Wants
  a skill that reads like someone talking to them.
- **Operator** — wants the 73 skills swept without reading 73 files.
- **bassclef** — wants the rule written down before a hook encodes it.

## Preconditions

- A directory of skills exists. Defaults to `dist/lite/.claude/skills`, the
  assembled package, which is what adopters receive.
- `python3` is on `PATH`.

## Main success scenario

1. Operator runs the script with no arguments.
2. Script finds every `SKILL.md` under the skills directory.
3. For each skill, the script locates the `## Details below the fold` heading
   that separates reader-facing prose from procedure.
4. Script strips code fences and inline backtick spans from the prose above
   that heading.
5. Script reports four patterns: a long skill with no boundary, a ticket
   reference, an order aimed at the model, a jargon term.
6. Script prints one line per finding, sorted worst first, with a count per
   pattern.
7. Script exits 1, because findings exist.

## Extensions

**1a — operator names specific skills.** Script reads only those.

**2a — the skills directory is absent.** Script says where the assembled
package comes from, names the environment variable for an override, and
exits 2.

**2b — no `SKILL.md` matched.** Script says so and exits 2.

**5a — a skill has no boundary heading.** Script reports it as the first
pattern when the file is longer than 300 lines, and then treats the whole
file as reader-facing. That inflates the other counts on purpose. A reader
has the same problem: with no boundary, there is no way to tell prose from
procedure. Hiding the inflation would hide the finding.

**7a — nothing found.** Script says every skill read clean and exits 0.

## Postconditions

- **Findings exist** — one line per finding on stdout, exit 1.
- **Clean** — one line saying so, exit 0.
- **Nothing to read** — the reason and the fix on stderr, exit 2.
- Nothing is written. The script only reads.

## Why it reads the assembled package

The package is what adopters receive. The source lives in bassclef-upstream
and can differ from the bundle, because `publish.yml:122` pins the substrate
to a release tag. Reading the package measures what shipped. Fixes still land
upstream, so the output names the skill and line to make the upstream path
easy to find.

## Refs

- cli#453 — the audit that defines the four patterns
- `docs/audits/2026-10-26-persona-coherence-first-touch.md` — the findings
- cli#454 — the run-based check; reads the same package
- upstream#2272 — the source-side check; P1 and P2 belong there
- @luminary alan-cooper — does the wording serve the person's goal
- @luminary michael-feathers — pin what it does before naming it
- @luminary donald-norman — the output names the fix, not just the fault
