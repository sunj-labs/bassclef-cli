# src/pipeline/ — reserved for WU-4

This directory is a boundary reservation, not code.

WU-4 (publish pipeline per iteration bet 2026-08-06b L124) will land the
anticorruption layer between the bassclef tier manifest
(`lite-manifest.json` in the sibling bassclef repo, per ticket #1143) and
this package's publish workflow. Vernon's anticorruption pattern: the
pipeline reads a stable manifest shape, not raw bassclef frontmatter.

Reserving this folder in WU-1 makes the boundary visible from day one so
WU-4's first commit lands the code inside a folder that already exists in
the repo layout. See `docs/decompositions/wu-1-repo-shape.md` — the
open-question section (Q1 for architect-review) recommended this
reservation.

Do not put unrelated code here. If WU-2 or WU-3 needs a shared module,
create `src/lib/` or the appropriate named folder — not `src/pipeline/`.
