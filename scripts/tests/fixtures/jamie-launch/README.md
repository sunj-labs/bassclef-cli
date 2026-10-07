# jamie-launch fixtures

**Provenance (2026-10-07):** `golden-capture.txt` is a real `claude -p` capture from the cold-adopter docker container running `@thebassclef/lite@1.9.11` in `/launch medium scratch mode`. Captured at Session L. Replaces the Session K scaffold.

Shape pattern mirrors `scripts/tests/fixtures/louis-whereami/` + `scripts/tests/fixtures/sam-onboard-repo/` (Session J real captures).

## Fixtures

- `golden-capture.txt` — REAL capture, 29 output lines. Lands within Jamie's 40-line ceiling. End-goal literal updated from "Variant A" (scaffold heading) to "variant-a" (real filename `variant-a-don-norman.html`). Luminary picker rotates lenses per adopter brief; filename pattern `variant-a-<slug>.html` stays stable.
- `bad-jargon-capture.txt` — SCAFFOLD. Fails experience goal with jargon in the variant headings.
- `bad-wall-capture.txt` — SCAFFOLD. Fails life goal — exceeds 40 lines.

## Shape notes

Scratch mode runs Phase 1 (interpret-input) + Phase 4 (riff-prototypes) only. Phases 5-9 (spec, GRASP, ux-migration) need `local` or `full` mode inside a real git repo. The real capture includes a `## Mode` block explaining this to Jamie plus a "Next step" line directing to `local` mode when ready to spec.

## Capture command

See `scripts/tests/fixtures/louis-sprint/README.md` for the pattern. For /launch, the prompt is:

```
use the /launch skill in medium size + scratch mode to produce a signup page for a weekly briefing newsletter about small-business tech. show me the gallery variants and the plan.
```

Hand-crafted negatives stay stable regardless of live-capture refreshes.
