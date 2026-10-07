---
tier: lite
author: kingofrock
created: 2026-10-07
parent_goal: cli#375 (Tier A dynamic driver roadmap)
preset: converged
---

# Session L — exercise @thebassclef/lite@1.9.11 against the Tier A harness

**Problem (≤500 chars):** Session K shipped `@thebassclef/lite@1.9.11` to npm with bassclef v1.8.0 bundled. The 7-of-7 Tier A persona drivers assert against hand-crafted scaffolds for 4 of 7 skills (louis-sprint, jamie-riff, jamie-launch, jamie-build). The harness cannot catch upstream regressions on those 4 skills until real captures from the shipped package replace the scaffolds.

---

## Recommended session sequence

One option. Operator picked the shape at Session K wrap: drive the latest npm against the harness, replace scaffolds with real captures, file any deltas on bassclef-upstream.

### Scan table

| Option | Scope | Turns | Compounds | Risk | Why not (non-rec.) |
|---|---|---|---|---|---|
| **a (recommended)** | 4 real captures from docker + driver iterations + delta filings | 80-150 | per-session; harness becomes trustworthy for every Tier A regression | 🟡 med | — |

### Compounding value — recommended only

#### Option a — Exercise v1.9.11 + replace 4 scaffolds

- **Deliverable** — 4 real-capture `golden-capture.txt` files replacing scaffolds. Updated driver assertions reflecting actual output. 0+ bassclef-upstream issues filed per delta (if any), each tagged `harness-pending` + matching `smoke-covered-*` label. Session L closeout.
- **Problem** — 4 of 7 Tier A fixtures are hand-crafted. The harness assertions pin an invented contract, not the shipped behavior. Any upstream drift in /sprint, /riff, /launch, /build goes undetected.
- **Value prop** — Real captures turn the harness into a true regression anchor. Upstream can cure safely once the harness pins the actual output.
- **Turns** — 80-150. Grounded in Session J actuals (PR #382 shipped 2 real-capture fixtures in ~60 turns; 4 fixtures at ~20-30 turns each, including driver iterations when real output does not match persona assertions).
- **Risk** — 🟡 med. OAuth refresh (PR #381) must land first OR a cured OAuth token must be set in env. Real captures may surface jargon or long output that persona-assert flags; those become upstream bugs filed under cli#389, not driver fixes. Docker container build can take 2-5 min cold.
- **Shipping priority** — P1 (closes cli#389 — the follow-on filed at Session K closeout).

### Step sequencing

| Step | Produces | Consumes (from prior step) |
|---|---|---|
| **0** prep | goal doc + markers + session board | — (session-start) |
| **1** OAuth refresh landed | `CLAUDE_CODE_OAUTH_TOKEN` set in env OR local token file at `~/.config/claude/token.json` | — (prerequisite from PR #381) |
| **2** docker build | `bassclef-cli-cold-adopter:v1.9.11` image | step 1 (OAuth available at container runtime) |
| **3** /sprint × Louis capture | `scripts/tests/fixtures/louis-sprint/golden-capture.txt` (REAL) + driver updates | step 2 |
| **4** /riff × Jamie capture | `scripts/tests/fixtures/jamie-riff/golden-capture.txt` (REAL) + driver updates | step 3 |
| **5** /launch × Jamie capture | `scripts/tests/fixtures/jamie-launch/golden-capture.txt` (REAL) + driver updates | step 4 |
| **6** /build × Jamie capture | `scripts/tests/fixtures/jamie-build/golden-capture.txt` (REAL) + driver updates | step 5 |
| **7** delta filings | 0+ bassclef-upstream issues per behavioral delta | union of steps 3-6 |
| **8** closeout | session log + whereami flip + chronicle + cli#389 close | union of all steps |

### Per-step compounding

Each capture step reuses the Session J pattern — one container exec per driver, scrub the capture, replace the fixture, re-run the driver, fix assertion mismatches. Driver iterations happen when real output's phrasing differs from the scaffold; iteration count per capture is 1-3.

Step 3 proves the pattern against the v1.9.11-bundled /sprint. Steps 4-6 reuse the pattern. If step 3 blows past 30 turns, pause and re-anchor — may indicate an OAuth or container issue that affects all four captures.

## Pre-mortem light — 3 lenses × 5 risks

### Lens 1 — @luminary alistair-cockburn (walking skeleton on real captures)

- R1 — OAuth token stale at container runtime; captures fail at auth. Fold: step 1 verifies OAuth with a `claude -p "say hello"` probe before any skill capture (per memory `feedback_oauth_verify_via_cheap_hello`).
- R2 — First real capture (step 3) blows past 30 turns on driver iteration. Fold: pause rule — hold at steps 1-3 only; defer steps 4-6 to Session M.
- R3 — Docker cold-cache build takes long; blocks all capture work. Fold: pre-build the image at step 2 before any capture; if build fails, triage before capture work starts.

### Lens 2 — @luminary michael-feathers (characterization pin to shipped output)

- R4 — Scaffold assertions pin aspirational behavior, not shipped. Real output fails the end-goal assertion. Fold: on failure, update the assertion to match shipped output; the FIXTURE is the characterization, not the assertion string.
- R5 — Real output carries jargon (operationalize, load-bearing, blast radius) that the persona-assert experience goal catches. Fold: filing surfaces an UPSTREAM substrate defect, not a driver bug — file on bassclef-upstream with `harness-pending` label.

### Lens 3 — @luminary alan-cooper (Jamie 90-second budget)

- R6 — Real /riff output exceeds Jamie's 40-line scan ceiling. Fold: filing surfaces an UPSTREAM budget violation — file on bassclef-upstream with `smoke-covered-riff` label.
- R7 — Real /build output does not include per-story PR numbers (scaffold assumed it does). Fold: update the scaffold's end-goal marker to match what /build actually produces; file upstream only if the omission breaks Jamie's "serious effort" scan.

## Out of scope

- Session K TierA architect-review sweep — cli#388 handles.
- bassclef substrate cures to any filed delta — upstream handles.
- New driver authoring for Tier B — Session M+ scope.
- Operator-private pseudonym registry refresh — orthogonal.

## Luminary map

**Primary:** @luminary michael-feathers — characterization. Real captures ARE the characterization boundary; scaffolds come down, shipped behavior pins.

**Supporting:**
- @luminary alistair-cockburn — walking skeleton (step 3 proves pattern end-to-end before 4-6)
- @luminary alan-cooper — Jamie persona bar (output quality signal)
- @luminary linus-torvalds — upstream filings carry concrete repro + harness-covered labels

## References

- cli#375 — parent roadmap (Tier A dynamic driver suite)
- cli#380 / PR #381 — OAuth refresh (prerequisite)
- cli#389 — follow-on filed at Session K closeout; this session closes it
- cli#388 — architect-review sweep (parallel; Session L and cli#388 can run in either order)
- PR #391 — Session K release v1.9.11 (merged this session)
- PR #392 — publish.yml tag-assert fix (merged this session)
- `docs/session-logs/2026-10-07-session-k-tier-a-full.md` — Session K log
- `.claude/rules/longrun-prep-plan-doc-compression.md` — converged preset shape (this doc's structure)

## Operator notes

Pre-flight: confirm OAuth refresh landed before firing `/longrun prep`. If PR #381 is still open at Session L start, the first step pivots — merge PR #381, or defer Session L and pick a different scope.

Hard ceilings:
- No `auth`, `schema`, `security`, `prod-deploy` touches.
- No pushes to main without PR.
- Operator-gated merge mode by default. Agent-merges-within-scope can be enabled at prep if operator approves.
