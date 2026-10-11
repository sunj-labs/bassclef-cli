---
date: 2026-10-11
session: S
scope: Option c — hygiene cluster + cli#388 Tier A architect-review
turn-budget: 100-130
lenses: [john-ousterhout, linus-torvalds, michael-feathers]
---

# Pre-mortem light — Session S (Option c)

Klein workshop shape — imagine Session S has failed. For each lens, name 5 specific causes.

## Lens 1 — @luminary john-ousterhout (deep modules; complexity is incremental)

- **OUST-R1** — Marker cleanup commits land one-per-marker; 10 commits bloat the log. Mitigation: single `chore: clean 10 stray session-N markers` commit.
- **OUST-R2** — Architect-review surfaces 10+ findings; overflow into Session T. Mitigation: cap at 5 Q1 findings; defer rest to filed tickets.
- **OUST-R3** — Whereami fix moves `last_updated:` but leaves the body copy. Mitigation: delete the body copy in the same edit; one source of truth.
- **OUST-R4** — Review doc enumerates each driver without stepping back to see system patterns. Mitigation: open with 3 cross-driver observations before per-driver findings.
- **OUST-R5** — Session hits 130 turns without closeout. Mitigation: fire /longrun checkpoint at step 50 and step 100.

## Lens 2 — @luminary linus-torvalds (we don't break adopters)

- **LINUS-R1** — Marker cleanup via `git rm` erases audit trail downstream sessions reference. Mitigation: `git add` + commit (track) over `git rm`. `git rm` only for schema-stale markers.
- **LINUS-R2** — Whereami frontmatter change breaks a hook that reads the body line. Mitigation: grep for `grep.*last_updated` across `.claude/hooks/` before edit; confirm readers use frontmatter path.
- **LINUS-R3** — Upstream ticket filed with wrong rationale; peer pushes back. Mitigation: cite SessionStart banner verbatim + path to the missing hook.
- **LINUS-R4** — Review surfaces findings that contradict adopter-visible claims in SKILL docs. Mitigation: lead-lens signoff checks adopter-contract per finding.
- **LINUS-R5** — Review doc rename/retire of a Tier A driver breaks adopter smoke tests. Mitigation: review doc produces tickets only; no file moves this session.

## Lens 3 — @luminary michael-feathers (characterization tests)

- **FEATH-R1** — Review doc claims coverage without listing each driver file. Mitigation: cite file path + top commit SHA per driver inline.
- **FEATH-R2** — Review observes patterns from memory; drivers moved since last session. Mitigation: `git log` each driver before reading; pin top SHA.
- **FEATH-R3** — Marker cleanup done without reading each marker's body first. Mitigation: `cat` each stray marker; include a 1-line gist per marker in the chore commit body.
- **FEATH-R4** — Whereami schema fix shipped without running schema validator. Mitigation: `ajv validate` against the whereami schema after edit; test must pass before commit.
- **FEATH-R5** — Upstream ticket body copies plan doc text; stale references. Mitigation: compose the ticket body from live SessionStart output + current hook state.

## Folded into plan (strongest)

Four risks reshape the sequence:

- **OUST-R2** — Cap at 5 Q1 findings this session. Follow-on tickets catch the rest.
- **LINUS-R1** — `git add` the stray markers (preserve history). `git rm` only when the marker schema is stale.
- **FEATH-R3** — Read each marker body before cleanup. Commit body carries 1-line gist per marker.
- **FEATH-R2** — Pin each driver's top commit SHA before architect-review reads it.
