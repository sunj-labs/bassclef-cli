# Reviewer pass — 1.9.22 release

mode: sequential
reviewed_at: 2026-11-07T18:11:07Z
source_files_changed: 0
wu_id: cli#460
iteration_count: 1
lens_used: [jony-ive, michael-feathers]

## Checks
- spec acceptance criteria: PASS — #476 merged with its checks green.
- tests present + green: PASS — 63 files, 556 tests, 0 failed.
- test-after pattern check: NONE FOUND in this change. It carries a version
  bump and a changelog entry; the mark and its tests landed under #476.
- ADR compliance: N/A
- Designer sign-off: the operator picked the brass chip and the condensed
  figlet, and deferred the bass clef glyph to #475.
- architect-review: N/A

## Findings
- NOTE: 1.9.21 shipped the output collapse without the mark. That gap is what
  this release closes, and it should not have taken a second release.

acknowledged: true
