# jamie-build fixtures

**Provenance (2026-10-07):** `golden-capture.txt` is a real `claude -p` capture from the cold-adopter docker container running `@thebassclef/lite@1.9.11`. Captured at Session L. Replaces the Session K scaffold.

Shape pattern mirrors `scripts/tests/fixtures/louis-whereami/` + `scripts/tests/fixtures/sam-onboard-repo/` (Session J real captures).

## Fixtures

- `golden-capture.txt` — REAL capture, 16 output lines. Jamie's first-touch /build on a cold adopter (no git, no plan) produces a structured refusal with three paths forward ("pick one"). Driver end-goal literal updated from "Story 1" (scaffold's aspirational post-plan shape) to "pick one" (real refusal signifier).
- `bad-jargon-capture.txt` — SCAFFOLD. Fails experience goal with jargon in the story headings.
- `bad-wall-capture.txt` — SCAFFOLD. Fails life goal — exceeds 40 lines.

## Shape notes

Real /build on cold adopter without a plan correctly refuses: it names the missing plan file, cites `ls` evidence, and offers three paths (point at the actual plan, run `/canvas` or `/spec` first, confirm wrong directory). This is correct safety-floor behavior per the /build Phase 0 hard-refusal gate — not a bug. The scaffold's "Story 1" shape assumes a plan already exists; it's the next-step happy path post-/launch or post-/canvas, not the cold-adopter first touch.

A future fixture pair (future session) could capture /build's happy path by: (1) `bassclef init ~/test`, (2) write a fake iteration-bet to `docs/iteration-bets/signup-page.md`, (3) `git init` + first commit, (4) run `/build signup-page`. Out of scope for Session L.

## Capture command

See `scripts/tests/fixtures/louis-sprint/README.md` for the pattern. For /build, the prompt is:

```
use the /build skill to construct the signup-page feature from the plan at docs/iteration-bets/signup-page.md. show me the output.
```

Hand-crafted negatives stay stable regardless of live-capture refreshes.
