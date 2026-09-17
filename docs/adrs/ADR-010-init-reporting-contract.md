---
tier: project
id: ADR-010
title: Init reporting contract — the manifest and the JSON report tell the truth
status: accepted
date: 2026-09-17
supersedes: []
superseded_by: []
amends:
  - ADR-002
luminaries:
  primary:
    - linus-torvalds
    - conventional-commits
  supporting:
    - tony-hoare
    - john-ousterhout
---

# ADR-010 — Init reporting contract

## Context

`bassclef init` writes files and then describes what it wrote. It
describes it twice: once in `.bassclef/init.manifest.json` for tools, and
once on the terminal for people. A third description appears when the
adopter passes `--json`.

At cli 1.1.0 all three disagree with each other and with the disk.

**The manifest records one file.** `src/commands/init.ts:583` calls
`writeManifest(targetDir, results)` with only the config-composer
results. The comment at L575-578 excludes walker files on purpose. A
fresh init writes 379 files and the manifest names one.

This is a regression, not a gap. `ADR-002` §Amendment 2026-09-13 L297-300
already decided the opposite: "The manifest continues to record path +
template + template version + outcome per file written. The file-count
grows to match the extended tree." `UC-init.md` L75 states the
postcondition plainly: "Each file has a SHA-256 content hash recorded in
`.bassclef/init.manifest.json`." The Phase 3 code did not implement the
amendment it shipped alongside.

**The JSON report goes to the wrong stream.** `init.ts:418` writes it to
stderr. `init.ts:585-591` then writes a folder reminder to stdout. An
adopter running `bassclef init --json 2>&1 | tail -1` gets the reminder.

**The JSON report describes one dimension of eleven.** `init.ts:411-417`
carries `copied / declared / failed / scope_counts / tier`, all about
hooks. `init.ts:330-370` already sorts every copied file into eleven
families to print the banner, then discards that work.

## Decision

### D1 — The manifest names every file init wrote

`.bassclef/init.manifest.json` lists one entry per file the run touched.
That includes files the walker copied from the bundle. This restores the
behavior `ADR-002` §Amendment 2026-09-13 already committed to.

**Entries are keyed by path and scope together, not by path alone.**
`src/lib/copy-substrate.ts:361-373` writes undeclared hook helpers to both
user scope and project scope, producing two entries that share one
bundle-relative path. Keying on path alone would let a reader find the
first and never see the second. `updateManifestEntry` in
`src/commands/sync.ts:446` matches on path today and is changed to match
on both. Recorded per RFC-0004 S-1.

### D2 — Each entry names its source, and sync ignores what it does not own

Every entry carries `source`, one of:

- `config-composer` — cli rendered this file from a template. Sync owns it.
- `bundle` — the walker copied this file from `dist/<tier>/`. Sync does
  not own it. `bassclef init --force` refreshes it.

The stored `source` value is the authority. It could be derived — an
entry whose `template` is absent from the sync TEMPLATES table came from
the bundle — but a derivation that depends on another module's lookup
table breaks the moment that table changes. Readers trust the field.
Recorded per RFC-0004 B-1.

Bundle entries carry a `template` value that is absent from the sync
TEMPLATES table. `src/commands/sync.ts:139-148` already handles an
unknown template by returning a no-op with a note. Bundle entries
therefore change no sync action. Grouped directory output at
`sync.ts:389-437` already exists for an extended manifest and renders the
larger list.

### D3 — Hashes are computed from what was written, at write time

`src/lib/copy-substrate.ts:409` holds the exact bytes in `outputContent`
immediately before `writeSafely`. The hash is taken there and travels on
`CopiedEntry`. Init does not re-read 378 files from disk to hash them.

A hash records what init wrote. It does not record what is on disk now.
That distinction is what lets a later reader detect an adopter edit.

### D4 — The manifest describes the run, not only its successes

Refused and errored files appear as entries with the matching `outcome`.
A partial init is visible in the manifest rather than looking complete.
This satisfies the failure postcondition already written at
`UC-init.md` L86.

### D5 — Shape version moves to 3; readers accept 2 and 3

`MANIFEST_SHAPE_VERSION` goes from 2 to 3. Writers emit 3. Readers accept
2 and 3, so a manifest written by 1.1.0 still loads under 1.1.1. Only a
shape above 3 is refused.

### D6 — With `--json`, stdout carries JSON and nothing else

When `--json` is set, the routine human lines are not printed at all, and
the JSON object is the entire content of stdout.
`bassclef init --json | python3 -m json.tool` parses with no pipeline
tricks.

An earlier draft redirected those lines to stderr. RFC-0004 S-2 rejected
that: error messages already use stderr, and mixing routine chatter into
the same stream leaves an adopter unable to tell a failure from a count.
The adopter asked for machine output. Errors still print to stderr, and
under `--json` they are the only thing there.

Without `--json`, every line prints exactly where it prints today.

### D7 — The JSON report names all eleven families and splits `failed`

The report gains a `catalog` block with a count per family, a `hooks`
block holding what the old flat fields carried, and separate `refused`
and `errored` counts. `failed` mixed two unrelated causes; a script could
not tell a refused overwrite from a read error.

**`failed` stays for one release as the sum of the two.** A reader
holding `if (report.failed > 0)` does not crash when the field is
removed. It reads `undefined`, which is falsy, and stops reporting
failures while appearing to work. A field that vanishes is worse than a
field that changes, because vanishing is undetectable at the reader. The
field retires at 1.2.0 and the changelog says so. Recorded per RFC-0004
H-1.

### D8 — One classifier, three readers

Sorting a path into a family lives in one function. The banner, the JSON
report, and the manifest all call it. Three copies of that logic would
drift, and the banner already carries the only copy today.

### D9 — `generated_by` names the package that actually generated it

`src/commands/init-templates/manifest-json.ts:16` hardcodes
`@thebassclef/core`. That package is deprecated; the shipping package is
`@thebassclef/lite`. The field reads the real package name.

RFC-0004 B-2 called this scope creep, and it is. It rides along because
this goal rewrites the manifest writer and bumps the shape version in the
same commit, so an adopter reading a 1.1.1 manifest meets the corrected
field at the same moment they meet the new shape. Splitting it would mean
two shape changes across two releases for one wrong string.

### D10 — A failed manifest write is reported, never silent

`src/commands/init.ts:639-641` catches every manifest write error and
discards it, on the grounds that the files did land and init should not
fail over its own bookkeeping. That reasoning still holds and init still
exits 0.

What changes is silence. Under D1 the manifest is what sync reads to know
what exists. An init that writes 379 files, fails to record them, and
prints success leaves the adopter with no way to notice. The catch block
now prints the path and the reason to stderr. Recorded per RFC-0004 N-1.

## Consequences

**Easier.** Sync, audit tools, and any adopter script can read one file
and know what init did. The eleven-family picture reaches tooling, not
just the terminal. A partial init is legible.

**Harder.** The manifest grows from roughly 1 KB to a measured 198 KB on
the lite tier — 499 entries. An earlier draft of this ADR estimated
roughly 100 KB; the measured figure is nearly double, which is why the
test now asserts a 1 MB ceiling rather than trusting the estimate. Sync
output on a fresh adopter repo grows from one line to a grouped
directory summary.

Hashing cost, which RFC-0004 N-3 asked to be measured rather than
asserted: a full init with 498 hashes completes in 114-122 ms across
three runs. The hash is taken from bytes already in memory, so it adds
no disk read, and the measured total is small enough that no adopter
will notice it.

**Breaks.** An adopter script that reads the `--json` object from stderr
stops seeing it there.

On adopter count: `@thebassclef/lite` first published 2026-09-02 and
recorded 244 downloads in the 30 days to 2026-09-11, 157 of them in the
final week. Downloads count machines, not people, and this project's own
smoke runs and CI installs are an unknown share of that number. So the
adopter count is unknown and it is not demonstrably zero. `ADR-031` puts
this below the threshold where a compat shim is owed, which is why the
stream move ships straight. It is also why `failed` survives one more
release under D7 rather than being cut today.

**Does not break.** Every run without `--json` prints what it printed
before. A 1.1.0 manifest still loads. Sync takes no new action on any
file it did not already manage.

## Alternatives considered

**Emit the JSON on both streams for one release.** Rejected. Two copies
of the same object on two streams is a worse contract than one move, and
it leaves the ambiguity in place for whoever reads it next.

**Record bundle files without hashes.** Rejected once D3 removed the cost.
The hash is free at write time, and `UC-init.md` L75 already promised it.

**Let sync manage bundle files.** Rejected. The verbatim-copy invariant in
`ADR-055` D1 belongs to the walker. `bassclef init --force` is the refresh
path. This ADR records the files; it does not hand them to sync.

## References

- `ADR-002` §Amendment 2026-09-13 — the file-list extension this ADR makes real
- `ADR-009` — manifest as the init contract source
- `ADR-057` — lite catalog destination paths, which the classifier mirrors
- `UC-init.md` §Success guarantee — the postconditions this ADR restores
- `docs/risk-ledgers/2026-09-17-cli-1.1.1-init-reporting.md` — 16 risks, 12 folded here
- sunj-labs/bassclef-cli#93, #94, #95

## Review

`docs/rfcs/RFC-0004-cli-1.1.1-init-reporting-design-council.md` — five
lenses outside the authoring set, fourteen findings. S-1, N-1, H-1, S-2,
H-2, B-1, and B-2 are dispositioned above. M-1 through M-4 and N-2, N-3
are folded into the test list and measured during construction.
