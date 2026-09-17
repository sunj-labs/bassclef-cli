---
tier: project
id: RFC-0004
title: Council review — cli 1.1.1 init reporting design
date: 2026-09-17
stage: design (pre-code)
goal: 2026-09-17-cli-1.1.1-init-reporting
reviews:
  - docs/adrs/ADR-010-init-reporting-contract.md
  - docs/decompositions/2026-09-17-cli-1.1.1-init-reporting.md
  - docs/use-cases/UC-init.md
authoring_luminaries:
  - linus-torvalds
  - conventional-commits
  - tony-hoare
  - john-ousterhout
  - kent-beck
  - michael-feathers
  - alistair-cockburn
  - donald-norman
council:
  - hyrum-wright
  - michael-nygard
  - saltzer-schroeder
  - glenford-myers
  - frederick-brooks
---

# RFC-0004 — Council review of the cli 1.1.1 init reporting design

Five lenses, none of them in the authoring set, reading ADR-010 and the
decomposition before any code exists.

## Summary

Fourteen findings. Three are HIGH. One of them — the duplicate path key —
would have shipped a manifest that silently loses entries, and it comes
straight out of a feature this repo shipped last week.

| ID | Lens | Severity | Finding |
|---|---|---|---|
| S-1 | Saltzer & Schroeder | **HIGH** | Manifest entries keyed by path alone collide on dual-scope files |
| N-1 | Nygard | **HIGH** | `writeManifest` swallows every error, and D1 makes the manifest load-bearing |
| H-1 | Hyrum | **HIGH** | Removing `failed` breaks reader scripts silently rather than loudly |
| S-2 | Saltzer & Schroeder | MEDIUM | Under `--json`, real errors and routine chatter share stderr with no marker |
| H-2 | Hyrum | MEDIUM | ADR-010 claims an adopter count it never measured |
| M-1 | Myers | MEDIUM | No byte-exact assertion that stdout carries only the JSON |
| M-2 | Myers | MEDIUM | No near-miss tests for the family classifier |
| M-3 | Myers | MEDIUM | Dry run writing no manifest is a stated risk with no test |
| M-4 | Myers | MEDIUM | No test that a 1.1.0 manifest loads under 1.1.1 |
| N-2 | Nygard | MEDIUM | No size ceiling on the manifest |
| N-3 | Nygard | MEDIUM | Hash cost at write time is asserted to be free but never measured |
| B-1 | Brooks | MEDIUM | `source` is a third vocabulary next to `template` and `scope` |
| B-2 | Brooks | LOW | D9 renames a field unrelated to reporting; scope creep in the ADR |
| H-3 | Hyrum | LOW | `manifest.files.length` is observable and moves from 1 to 379 |

## S-1 — Duplicate path keys (HIGH)

**Finding.** The design says the manifest holds one entry per file. It
cannot. `src/lib/copy-substrate.ts:361-373` writes undeclared hook helpers
to both scopes, synthesizing a user decision and a project decision for
the same bundle path. `copyOne` at L424 pushes
`{ path: adopterRelPath, scope }` for each. Two entries share one `path`.

`src/commands/sync.ts:446` looks entries up with
`manifest.files.findIndex((f) => f.path === path)`. It finds the first and
never sees the second. Any later write against that path updates the user
entry and leaves the project entry stale, or the reverse — whichever
landed first.

Today this does not bite, because the manifest holds one config file and
no hooks. D1 puts every dual-written helper into the manifest and turns a
dormant defect into a live one.

**Why the evidence supports the finding.** The dual-write is deliberate
and recent: the branch history at `94170e5` ("dry-run parity accounts for
dual-scope helpers") exists because dual-scope copies double the count.
The same doubling reaches the manifest under D1.

**Recommendation.** Key entries by `path` plus `scope`. Amend ADR-010 D1
to say so. Change `updateManifestEntry` to match on both. Add a test that
a dual-written helper produces two entries and that sync updates the
right one.

**Disposition options.** (a) Composite key, as above. (b) Store one entry
carrying a `scopes: ['user','project']` array. (c) Record project scope
only and drop user-scope entries from the manifest.

## N-1 — The manifest write swallows every error (HIGH)

**Finding.** `src/commands/init.ts:639-641` wraps the manifest write in a
bare `catch {}` with the comment "Best-effort; do not fail init on
manifest errors." That was defensible when the manifest was a courtesy
record of three files. D1 makes it the thing sync reads to know what
exists.

After this change, a full disk or a permission error produces an init
that prints success, exits 0, and leaves no manifest. The adopter has 379
files on disk and no record of them. The next `bassclef sync` reports
nothing to do.

**Recommendation.** Keep init from failing on a manifest error, because
the files did land and failing would be a lie in the other direction. But
print the failure to stderr with the path and the reason. Silence is the
only unacceptable option.

## H-1 — Removing `failed` fails quietly (HIGH)

**Finding.** D7 splits `failed` into `refused` and `errored`. A script
holding `if (report.failed > 0) { alert() }` does not crash when the field
disappears. It reads `undefined`, which is falsy, and stops alerting.
The script keeps running and keeps reporting success.

Hyrum's point is not that the split is wrong. It is that a field which
vanishes is worse than a field which changes meaning, because vanishing
is undetectable at the reader.

**Recommendation.** Keep `failed` for one release as the sum of `refused`
and `errored`, and say in the changelog that it retires at 1.2.0. This
contradicts D7's clean break, and the council thinks the clean break is
wrong here for exactly one release cycle.

**Disposition options.** (a) Keep `failed` as a sum, deprecate in the
changelog. (b) Clean break as D7 states, and accept silent reader
breakage. (c) Rename the whole object under a `schema_version` field so a
reader can branch — which the design already adds, and which makes (a)
cheap to carry.

## S-2 — Errors and chatter share stderr under `--json` (MEDIUM)

**Finding.** D6 sends every human line to stderr when `--json` is set.
Error messages already go to stderr. After the change, a genuine failure
and the routine "37 files created" line arrive on the same stream with
nothing to tell them apart. An adopter capturing stderr to diagnose a
failure gets both.

**Recommendation.** Under `--json`, suppress the routine lines rather than
redirect them. The adopter asked for machine output; they did not ask for
the human report on a different stream. Errors stay on stderr, alone, and
mean what they say.

## H-2 — The adopter count is asserted, not measured (MEDIUM)

**Finding.** ADR-010 §Consequences says "at the current adopter count,
ADR-031 says ship the change." No number appears. ADR-031's rule is a
threshold, so applying it without the count is applying it on faith.

**Recommendation.** Read the npm download count for `@thebassclef/lite`
and record it in the ADR, or state plainly that the count is unknown and
the decision rests on the package being days old.

## M-1 to M-4 — Coverage gaps (MEDIUM)

**M-1.** The decomposition's step 7 says "stdout-only JSON assertion." An
assertion that stdout *parses* as JSON passes even if a human line is
appended, because `JSON.parse` is not asked to consume the whole buffer
in most test styles. Assert the exact stdout buffer equals the serialized
object plus one newline.

**M-2.** `classifyEntry` needs near-miss cases. `.claude/skillsfoo/x.md`
must not count as a skill. The root-doc rule at `init.ts:366-370` tests
`/^[A-Z]/` on a path with no slash, so `gitignore` is excluded and
`README.md` is included — both need a test, because that rule is a guess
and guesses need pinning.

**M-3.** The pre-mortem names "dry run writes a manifest that claims files
landed" as risk H3. The decomposition's test order omits it.

**M-4.** D5 says readers accept shape 2 and 3. No test loads a shape-2
manifest under the new reader.

**Recommendation.** Add all four to the test list before step 3 begins.

## N-2, N-3 — Unmeasured claims (MEDIUM)

D3 asserts hashing is free because the bytes are in memory. That is true
of the read, not of the hash itself: 378 SHA-256 computations still cost
CPU. Measure it and record the number.

Nothing bounds the manifest size. Measure the written bytes in a test and
assert a ceiling, so a future tier that ships ten times the files fails
the test instead of an adopter's editor.

## B-1, B-2 — Conceptual integrity (MEDIUM, LOW)

**B-1.** An entry now carries `template`, `scope`, `source`, and
`outcome`. Three of those are close enough to confuse. `source` is
derivable: an entry whose `template` is in the sync TEMPLATES table is
config-composed, and one whose template is absent is from the bundle.
Storing it is defensible only if the stored value is the authority and
the derivation is not. The ADR should say which one is the authority.

**B-2.** D9 fixes `generated_by` naming a deprecated package. The fix is
right and it does not belong in a reporting-contract ADR. Either state
why it rides along or move it.

## Verdict

Do not start step 3 until S-1, N-1, and H-1 have a written disposition.
S-1 in particular changes the data shape, and discovering it after the
tests are written means rewriting them.

The design is sound in its central move. One report object feeding three
writers is the right shape, and it is what makes S-1 findable at all —
a design with three separate counters would have hidden the collision in
whichever counter nobody read.
