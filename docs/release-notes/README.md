---
tier: upstream
type: reference
title: How to write release notes here
---

# How to write release notes here

One file per published version, named `v<version>.md`.

## Who reads these

Someone deciding whether to update. They do not work on bassclef. They
have a few minutes. They want to know two things: what changed for me,
and do I have to do anything.

They are not reading an audit trail. Ticket numbers, PR links, commit
hashes, and the names of the lenses we applied all belong in the
changelog and the session log, not here.

## The shape

```
# v<version> — <plain title, under 10 words>

**Released** <date> · **Bassclef substrate** <tag>

## What this means for you
2 to 4 plain sentences. Lead with the thing they will notice.

## What changed
Plain bullets. One per change a reader could observe.

## Do you need to do anything?
Usually "No." When it is yes, say exactly what.

## Notes
Optional. Anything honest that does not fit above.
```

## The language rule

Grade 8. Short sentences. Subject, verb, object.

Say what a reader would see, not what we did internally:

| Don't write | Write |
|---|---|
| "install-written-paths mediation" | "the check knows which files bassclef installed" |
| "cure" | "fix" |
| "the walker writes the manifest row" | "`bassclef init` records what it installed" |
| "O(N × M) rewritten to O(N + M)" | "a step that took two minutes now takes under a second" |
| "Luminary rotation — Linus Torvalds, supporting Tony Hoare" | leave it out |
| "per-finding RCA shape for downstream readers" | leave it out |

If a sentence only makes sense to someone who works on bassclef, it does
not belong in the file.

## Say so when a version was not published

A tagged version that never reached npm still gets a file. Say plainly
that it was never published and point at the version that replaced it.
Otherwise the next reader finds a gap in the changelog and wonders.

`v1.9.17.md` is the example.

## What enforces this

**Word level, enforced.** `.claude/hooks/release-notes-scrub-check.sh`
fires on every write to this directory and scans against the BLOCK-tier
terms in `standards/bassclef-internal-jargon.md`. Wired in
`.claude/settings.json`. Advisory for now; see
`.claude/rules/release-notes-scrub.md`.

**Shape level, not enforced.** Nothing checks the section order, the
audience, or whether a bullet describes something a reader could
observe. That gap is why the notes drifted in the first place — the word
scrub passes a file that is jargon-free and still written for us.

Worth a `/promote`: extend the scrub to check the four section headings
and flag a bullet that names a PR, a commit, or a luminary.

## History

Notes existed for `v1.2.1` and `v1.9.9`, then stopped for ten releases.
`v1.9.10` through `v1.9.19` were written back on 2026-10-26 from the
changelog. They are accurate but secondhand — written after the fact
rather than at release time. Write them at release time from now on.

`v1.9.9.md` predates this contract and reads as a worked example of what
not to do: it opens with a 500-character problem statement, cites risk
ledgers, and uses "per-finding RCA shape" in the second paragraph. Left
in place as a record.

## Refs

- `.claude/rules/release-notes-scrub.md` — the word-level rule
- `.claude/rules/plain-english-discipline.md` — grade 8 target
- `standards/bassclef-internal-jargon.md` — the term list
- `CHANGELOG.md` — the audit trail; ticket numbers live there
- cli#450 — bundle these into the package so downstream can read them
