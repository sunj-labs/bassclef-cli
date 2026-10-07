# jamie-build fixtures

**Provenance (2026-10-07):** Two REAL captures from `claude -p` output. Both capture `@thebassclef/lite@1.9.11` cold-adopter docker container behavior.

Shape pattern mirrors `scripts/tests/fixtures/sam-onboard-repo/` (Session J twin-fixture pattern — happy + prereq-missing).

## Fixtures

- `golden-capture.txt` — REAL (Session L). 16 output lines. Cold adopter runs `/build` without a plan. /build refuses with structured 3-paths-forward ("pick one") guidance. End-goal literal `pick one`.
- `golden-capture-env-partial.txt` — REAL (Session M). 45 output lines. Cold adopter has plan + spec + git init, but no `gh` CLI. /build reads 6 ADRs, runs environment check, refuses before touching Phase 0's hard floor. End-goal literal `gh`. Driver life-ceiling 46 to match shipped body size.
- `bad-jargon-capture.txt` — SCAFFOLD. Fails experience goal (jargon in story headings).
- `bad-wall-capture.txt` — SCAFFOLD. Fails life goal (exceeds 40 lines).

## Shape notes

Current /build on cold adopter has two failure shapes before the (yet-to-ship-live) happy path:

1. **No plan** → "pick one" refusal (3 paths forward)
2. **Plan + partial env** → "/build: environment does not support the full chain" refusal with checklist of missing prerequisites

Both are correct safety-floor behavior per /build Phase 0 + prerequisite guard. Neither is a bug.

A true happy path (code shipped + PR opened) requires the docker image to carry `gh` CLI + a seeded auth token + Playwright MCP. That's substantial container surgery deferred to a later session. Note — bassclef-upstream#2130-2132 (3 cures routed from cli Session M scope a) may land Phase 4-7 LIVE path in a future release that changes this shape.

## Capture command

See `scripts/tests/fixtures/louis-sprint/README.md` for the base pattern. The env-partial fixture extends it:

```bash
# inside container, after bassclef init:
git init -b main
git config user.email ...
git add . && git commit -m 'scaffold'
mkdir -p docs/iteration-bets docs/specs
# seed plan at docs/iteration-bets/signup-page.md with Steps enumerated
# seed spec at docs/specs/signup-page.md with Steps enumerated
git add docs/ && git commit -m 'plan + spec'
claude --dangerously-skip-permissions -p "use the /build skill to construct the signup-page feature. the plan is at docs/iteration-bets/signup-page.md. show me the output."
```

Hand-crafted negatives (bad-jargon, bad-wall) stay stable regardless of live-capture refreshes.
