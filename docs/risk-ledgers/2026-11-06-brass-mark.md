---
tier: lite
---

# Pre-mortem — brass chip and condensed figlet

Three lenses, light mode. Premise: it is three months on and the new mark
has embarrassed us. What happened?

## Jony Ive — material honesty

1. **A non-ASCII character crept in during an edit.** Someone fixed a
   letterform by pasting from a figlet generator and brought a Unicode
   dash with it. Nobody noticed because it renders on the author's
   machine. → Assert the character set mechanically in a test, not by
   reading the source.
2. **Rows drifted to uneven widths.** A later edit padded one row and not
   its neighbours, so the right edge went ragged. → Assert every row has
   identical length.
3. **The chip was used where colour never arrives** — a log file, a CI
   capture — and printed as a bare word with odd spacing. → That is the
   intended degrade, but test it rather than assume it.

## Michael Nygard — stability and visible state

4. **The caller stopped passing a width.** `process.stdout.columns` is
   `undefined` when piped, and the old code treated that as "full mark".
   A refactor could turn it into "narrow". → Keep the undefined case
   explicit and tested.
5. **A narrow terminal clipped the figlet mid-letter.** Worse than no
   mark, because it reads as corruption. → Keep the old fallback: below
   the minimum, print text alone.
6. **The version drifted from package.json.** The mark takes a version
   argument for exactly this reason; a later edit could hardcode it. →
   The caller passes it; a test pins that the argument is interpolated.

## Michael Feathers — characterization

7. **The old tests pinned the old mark and were deleted wholesale.** The
   three grid tests exist because the grid is data that corrupts
   silently. Deleting rather than rewriting them loses that protection.
   → Rewrite each one against the new contract. Same intent, new numbers.
8. **The chip has no test at all** because it looks too simple to break.
   Padding and case are the whole design. → Pin them.
9. **Nothing proves the mark is narrower than the one it replaces.**
   That was the justification for the change. → Assert it.

## Folded before the first line

- Mechanical ASCII assertion over the whole figlet.
- Every row the same width, asserted.
- Chip tested with colour off as well as on.
- Narrow and undefined width paths both kept and tested.
- Old grid tests rewritten, not dropped.
- A test asserting the new mark is smaller than 53 columns.
