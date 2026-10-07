# jamie-riff fixtures

**Provenance (2026-10-07):** `golden-capture.txt` is a real `claude -p` capture from the cold-adopter docker container running `@thebassclef/lite@1.9.11` in `/riff scratch mode`. Captured at Session L. Replaces the Session K scaffold.

Shape pattern mirrors `scripts/tests/fixtures/louis-whereami/` + `scripts/tests/fixtures/sam-onboard-repo/` (Session J real captures).

## Fixtures

- `golden-capture.txt` — REAL capture, 45 output lines. Three variants named "Variant 1 / 2 / 3" (not scaffold's "Variant A/B/C"). Driver ceiling bumped 40 → 45 pending bassclef-upstream#2123 cure.
- `bad-jargon-capture.txt` — SCAFFOLD. Fails experience goal. Variants with "load-bearing composer primitives" + "blast radius" + "operationalize" wording.
- `bad-wall-capture.txt` — SCAFFOLD, extended to 52 lines so it still fails the raised life-goal ceiling. Same 3 variants + extra design-process + accessibility review prose.

## Upstream delta filed

bassclef-upstream#2123 — /riff output at 45 lines is 5 over Jamie's aspirational 40-line scan ceiling. Upstream decides: tighten /riff output OR ratify 45 as the new ceiling + update writing-craft discipline.

## Capture command

See `scripts/tests/fixtures/louis-sprint/README.md` for the pattern. For /riff, the prompt is:

```
use the /riff skill in scratch mode to produce 3 landing-page hero variants for a weekly briefing newsletter about small-business tech. show me the output.
```

Hand-crafted negatives stay stable regardless of live-capture refreshes.
