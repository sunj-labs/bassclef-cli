---
tier: project
id: RFC-0005
title: Council review — cli 1.1.1 init reporting, shipped code
date: 2026-09-17
stage: code (post-implementation, pre-release)
goal: 2026-09-17-cli-1.1.1-init-reporting
reviews:
  - src/lib/catalog-classify.ts
  - src/lib/init-report.ts
  - src/commands/init.ts
  - src/lib/copy-substrate.ts
  - src/commands/sync.ts
  - tests/init-report.test.ts
  - tests/init-manifest-authoritative.test.ts
  - tests/init-reporting-characterization.test.ts
council:
  - glenford-myers
  - michael-nygard
  - hyrum-wright
  - frederick-brooks
sibling: RFC-0004
---

# RFC-0005 — Council review of the shipped code

RFC-0004 read the design. This reads the diff. Same discipline, later
stage: the lenses look at what landed, not at what was planned.

## Summary

Three findings, two of them defects in code written earlier in this same
session. Both were verified by running the built cli, not by reading it.
Both are fixed in commit that follows this document.

The pattern worth naming: the goal set out to close a class where two
counters disagree, and the first implementation reintroduced that exact
class in a new place. A design being right does not make its
implementation right.

| ID | Lens | Severity | Finding | State |
|---|---|---|---|---|
| A-1 | Myers | **HIGH** | `totals.files` and the manifest disagreed on any run with refusals | fixed |
| A-2 | Brooks | **MEDIUM** | `hooks.declared` and `hooks.copied` carried different units | fixed |
| A-3 | Nygard | MEDIUM | A dry run discarded real read errors from its report | fixed |
| A-4 | Hyrum | LOW | `totals.files` changed meaning between two commits in one session | noted |

## A-1 — The report and the manifest disagreed (HIGH)

**Finding.** `buildInitReport` set `totals.files = configs.length +
entries.length`. `writeManifest` recorded configs, copied entries, AND
refused and errored entries per ADR-010 D4. On any run with a refusal the
two numbers differed by exactly the refused count.

**Evidence.** Ran the built cli twice against one home directory, so the
second run refused the user-scope files the first had written:

```
report.totals.files  434
manifest.files.length 499
report.refused         65
```

434 + 65 = 499. The gap is the refusals, exactly.

**Why this matters more than the arithmetic.** The decomposition's stated
postcondition is that the three writers "cannot disagree about the
numbers," and the whole reason for one report object was to make that
true. The first implementation satisfied it only for runs where nothing
was refused — which is every fresh install and no re-install.

**How the tests missed it.** `tests/init-manifest-authoritative.test.ts`
asserted `manifest.files.length === report.totals.files` on a fresh
init. Refused was 0, so the assertion could not tell a correct report
from one counting successes only. The test passed for the wrong reason.

**Fix.** `totals.files` now counts everything the run touched, matching
what the manifest records. `totals.written` carries the narrower number
for readers that want successes only. A new test performs a second init
into a populated home and asserts the equality holds when `refused > 0`.

## A-2 — Two different units in one block (MEDIUM)

**Finding.** The report emitted `hooks: { declared: 24, copied: 85 }`.
`declared` counted hook commands named in settings.json. `copied`
counted hook FILES, which includes the helpers and fragments that ship
alongside declared commands. A reader subtracting one from the other
concludes 61 unexpected hooks arrived.

The terminal banner, meanwhile, prints "Installed 22 of 24 hooks" — a
third number, from a filtered count that the JSON did not use.

**Why the lens caught it.** Brooks's conceptual integrity asks whether
the parts of a design say the same thing in the same language. Ticket #95
exists because the old `failed` field mixed two causes. Pairing a command
count with a file count under one heading is that same mistake, moved.

**Fix.** `hooks.copied` now counts declared commands that landed, using
the same filter the banner uses, so `declared` and `copied` share a unit.
Hook files get their own field, `hooks.files`. Verified on the built cli:
`{ declared: 24, copied: 22, files: 85 }`, where 22 of 24 matches the
banner exactly.

## A-3 — A dry run hid its own failures (MEDIUM)

**Finding.** The dry-run branch built its report with `refused: []` and
`errored: []` hard-coded. A dry run does not write, but it does read
every source file, and `copyOne` records a read failure in
`result.errored` even in dry-run mode. Those failures never reached the
JSON.

**Why this is a Nygard finding.** The point of a dry run is to learn what
a real run would do. A dry run that cannot report a broken bundle is
worse than no dry run, because it answers the question confidently and
wrongly.

**Fix.** The dry-run report passes through the walker's actual refused
and errored lists.

## A-4 — A field changed meaning mid-session (LOW, noted not fixed)

`totals.files` meant "files written" in one commit and "files touched" in
the next. Both commits are in this session and neither has been released,
so no reader outside this repo ever saw the first meaning. Hyrum's Law
applies to shipped behavior; nothing shipped.

Noted here because the fix landed by changing what an existing field
means rather than by adding a new one. That was the right call before
release and would be the wrong call after it.

## What the council did not find

No finding against `catalog-classify.ts`. It is a pure function with one
rule, tested against every family plus three near-misses. The near-miss
tests were added because RFC-0004 M-2 asked for them at the design stage.

No finding against the characterization tests. They pinned the non-JSON
path before any change and stayed green through every commit, which is
what they were for.

## Verdict

Ship. The two defects the council found are fixed and each carries a test
that fails if it returns. The suite went from 303 tests at session start
to 345.

One process note for the retrospective: RFC-0004 reviewed a design and
found a data-shape defect before any test existed, which saved rewriting
the tests. RFC-0005 reviewed code and found two defects that the tests as
written could not catch. The two reviews caught different classes. Running
only one of them would have shipped a defect either way.
