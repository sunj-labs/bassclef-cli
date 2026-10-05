---
id: next-session-plan-2026-10-05-session-j-dynamic-driver-integration
status: converged
primary_lenses:
  - alistair-cockburn
  - michael-feathers
supporting:
  - alan-cooper
  - kent-beck
---

# /longrun prep — Session J: dynamic driver integration bridge

## Problem (via /state-a-problem brief)

Session I PRs #376 + #377 shipped the persona-assertion library and 2 fixture-driven unit tests, but the fixtures are hand-crafted mocks. Cockburn's walking skeleton forbids mocks at any layer. The 2 drivers do not spawn `claude -p` against `@thebassclef/lite@1.9.10` in the cold-adopter container. The adopter contract — "drive the skill against current released lite" — is not yet honored. Session J's job is to close the gap: capture REAL `claude -p` output from docker-smoke against current lite, replace the mock fixtures with those captures, and re-run the persona-assert chain over them so the walking skeleton walks end-to-end at every layer.

## Value prop (via /value-prop tweet)

Honest adopter simulation starts here. Session J replaces 6 mock fixtures with real captures from docker-smoke against @thebassclef/lite@1.9.10. The next 4 Tier A drivers then ride a proven real-capture path.

## Evidence

- PR #376 + #377 ship `scripts/lib/persona-assert.sh` + unit tests against fixtures I wrote by hand
- `scripts/smoke-drive-onboard-repo.sh` L14 writes captures to `$OUT_ROOT/onboard-repo.out`
- Last docker-smoke run: 2026-10-03 (`gh run list --workflow docker-smoke.yml`). PRs #376 + #377 did NOT trigger it (path filter excludes scripts/tests/)
- Docker available locally per `command -v docker` + `harness/docker/Dockerfile.cold-adopter`

## Whereami read

Session I closed 2 of 7 Tier A PRs. Next 5 pending per `docs/plans/tier-a-dynamic-driver-roadmap.md`. Integration gap discovered this turn by operator.

## Shipped-state check (per /longrun Step 0.75)

- `scripts/lib/persona-assert.sh` → EXTENDS (shipped; needs no edit; just needs real captures to run on)
- `scripts/tests/fixtures/sam-onboard-repo/golden-capture.txt` → MOCK (needs replacement with real capture)
- `scripts/tests/fixtures/louis-whereami/golden-capture.txt` → MOCK (same)
- `.github/workflows/docker-smoke.yml` path filter → EXTENDS (needs `scripts/tests/**` added so PRs touching drivers trigger integration CI)

## Preset: converged

Operator confirmed path. No shape exploration needed.

### Deliverable

Real captures replace mock fixtures. docker-smoke runs on every PR touching `scripts/tests/**`. The 2 shipped drivers run against real claude output + current lite release. The remaining 4 Tier A drivers then ride the proven real-capture path.

### Recommend: Option a — Integration bridge (one PR)

- **Value**: Honors the adopter contract. Sam and Louis assertions run against REAL `claude -p "/onboard-repo"` and `claude -p "/whereami"` output from current `@thebassclef/lite@1.9.10` in cold-adopter container. Fixture directory shifts from mocks to committed real captures. If next cli release regresses the chain, docker-smoke catches it; if next upstream substrate ships a defect, persona-assert catches it.
- **Turns**: 40-60. Local docker-smoke run (~15 min); capture 2 real outputs; commit as new fixtures; verify PR 1 + 2 drivers still PASS; add `scripts/tests/**` to docker-smoke path filter.
- **Risk**: 🟡 med — docker run against real OAuth may hit auth friction; cli@latest may produce output shape persona-assert does not yet handle (that's the point — we discover it); cure cycle may be 2-3 iterations.
- **Priority**: P1 — blocks the remaining 4 Tier A drivers (they should ride real captures from day one).

### Other options

```
  b. Full integration + remaining 4 Tier A      200-300t  🔴 high  P2
  c. Just CI path filter (defer real captures)    30-40t  🟢 low   P3
```

- **b**: Option a plus /sprint, /riff, /launch, /build real-capture drivers. Scope too wide for one session; ship a then revisit for /sprint + beyond.
- **c**: Add `scripts/tests/**` to docker-smoke path filter so PRs trigger it, but keep mocks until a real capture lands. Lowest risk. Leaves the mock gap intact. Only valuable if Option a is deferred for another reason.

Ask "step plan" for Option a sequencing.
Ask "see b" or "see c" for detail.

## Luminary map (per /luminary + /extract-intent)

- Primary: @luminary alistair-cockburn — the walking skeleton must walk at every layer, mocks forbidden
- Primary: @luminary michael-feathers — real captures are the characterization; fixtures become reference points pinned to a real build
- Supporting: @luminary alan-cooper — persona assertions still frame what counts as pass/fail
- Supporting: @luminary kent-beck — RED first; the real capture may flip our T01 to RED; that is the signal

## Step sequencing

| Step | Produces | Consumes | Teaches |
|---|---|---|---|
| 1 | Local docker-smoke run against lite@1.9.10; 2 real captures at `/tmp/session-j-captures/` | lite@1.9.10 npm install, docker image, OAuth | What claude actually says on /onboard-repo + /whereami today |
| 2 | Replace `scripts/tests/fixtures/sam-onboard-repo/golden-capture.txt` with real capture; commit | Step 1 real capture | Reference golden shape pinned to real build |
| 3 | Replace `scripts/tests/fixtures/louis-whereami/golden-capture.txt` with real capture | Step 1 | Same for Louis |
| 4 | Re-run both drivers locally; cure persona-assert if format drifted | Step 2 + 3 real captures | Which assertions survive real output |
| 5 | Add `scripts/tests/**` to `.github/workflows/docker-smoke.yml` paths-filter | Step 4 GREEN | Future PRs touching drivers get integration CI |
| 6 | PR body + /verify + CI loop + merge | Step 5 | — |
| 7 | Architect review at closeout | Full suite | — |

## Risk (3 lenses × 5 risks, folds pre-code)

**Cockburn (walking skeleton):**
- R1 — docker-smoke OAuth fails locally; cannot capture. **Fold**: use CLAUDE_CODE_OAUTH_TOKEN env, same as docker-smoke CI secret.
- R2 — real capture is 500+ lines (far over life-goal ceiling). **Fold**: raise life-goal threshold OR document that /onboard-repo output genuinely has operator-mode tail; refine assertion.
- R3 — persona-assert format assumes `=== output ===` wrapper but real capture has different shape. **Fold**: inspect real capture first; adjust lib.

**Feathers (characterization):**
- R4 — real capture carries data that won't commit (OAuth tokens, local paths). **Fold**: scrub capture before commit; add `/scripts/tests/fixtures/.gitignore` or sanitize via sed.
- R5 — real capture is non-deterministic across runs. **Fold**: pin to one capture + document the run (date, cli version, lite SHA); accept that real captures drift and update on cli releases.

**Cooper (persona):**
- R6 — real /onboard-repo may legitimately have jargon from upstream SKILL body. **Fold**: experience-goal assertion flags it as a NEW Session J finding — real defect to promote upstream, not test error.
- R7 — real /whereami output exceeds 40-line scan ceiling because current whereami doc is long. **Fold**: either raise ceiling to real-world shape OR the ceiling exposes a real UX defect to promote (/whereami body too dense).

## /temperance + /luminary + /loop discipline

- **/temperance** fires at session kickoff. Scope: one integration bridge PR; stop at Option a. Drift trigger: do NOT start /sprint × Louis real-capture work in Session J.
- **/luminary** primary cockburn + feathers; supporting cooper + beck. Marker at `state/markers/luminary/feat-session-j-integration-bridge.marker`.
- **/loop** per PR. Expect 2-3 RED iterations as persona-assert meets real output.

## /architect-review

Fires at Session J closeout per /longrun Step 7.5. Likely findings:
- Persona-assert thresholds (life-goal 40 lines) need calibration to real output
- Experience-goal jargon list may need extension from `standards/bassclef-internal-jargon.md`
- Capture scrubbing lib may need to become shared under `scripts/lib/capture-scrub.sh`

## Refs

- cli#375 — Tier A roadmap tracker
- PR #376 — walking skeleton (assertion-lib layer; what Session J bridges to real)
- PR #377 — Louis × /whereami (same)
- `docs/plans/tier-a-dynamic-driver-roadmap.md` — durable plan amended to flag integration gap
- `scripts/smoke-drive-onboard-repo.sh` — the live-claude driver Session J captures from
- `.github/workflows/docker-smoke.yml` — CI path filter to extend
- Session I honest-gap check from operator this turn

🤖 Generated with [Claude Code](https://claude.com/claude-code)
