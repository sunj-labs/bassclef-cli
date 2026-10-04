---
tier: upstream
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - linus-torvalds
    - kent-beck
---

# Next session plan — adopter-regression E2E cascade drivers

## Scope in one sentence

Ship the lite-only test runtime that proves adopters do not hit the Kunal-rerun class of issues when upstream ships cures.

## Context (read first — session is fresh)

Last session shipped bassclef v1.9.9 bundling 8 Kunal cures. A cold-adopter rerun on v1.6.6 lite then surfaced 22 new issues across 7 classes:

- **A.** Privacy and identity leaks (cli#305, cli#320, GitHub squash author, trace-helper siblings)
- **B.** Writer vs reader contract drift across skills (cli#307, cli#312, cli#317, cli#318, cli#319, cli#322, cli#324, cli#326)
- **C.** Lite packaging gaps — things lite does not ship but skills assume (cli#283, cli#308, cli#315, cli#316)
- **D.** Checks that cry wolf or misfire (cli#309, cli#310, cli#311, cli#321)
- **E.** Portability floors — macOS bash 3.2, 127.0.0.1 preview (cli#306, cli#314)
- **F.** Process and quality guards (cli#323, cli#325)
- **G.** `/build` stops after planning (cli#327, cli#328, cli#329, cli#330, cli#331, cli#332)

Full report: `~/Downloads/kunal-rerun.md`.

Upstream is working on cures for A–G at the substrate layer. Cli owns the adopter-regression anchor and the lite-only Docker runtime that proves each cure holds at the shipping boundary.

## Luminary map

- **Lead:** `alistair-cockburn` — walking skeleton. One skill end to end per session before depth.
- **Supporting:** `linus-torvalds` — adopter stability. Cross-cutting invariants the lite runtime enforces regardless of per-driver assertions.
- **Supporting:** `kent-beck` — red first. Characterization test authored BEFORE the upstream cure ships.

Picked by `/extract-intent` live (confidence 0.92). Rationale cached at `scratchpad/intent-match.json` from the prior session.

## Three principles the plan carries

**1. Walking skeleton per journey (Cockburn).** Each session ships ONE driver end to end before adding depth. The thinnest driver per journey proves the cascade works. Depth gets added after that cascade is green. This surfaces integration risk early, before four deep drivers of sunk cost.

**2. Cross-cutting invariants (Torvalds).** The lite Docker runtime enforces three invariants on every driver no matter what skill it targets:

- No absolute paths leak into trace output
- No PyYAML required to parse state
- Bash 3.2 syntax only — no `declare -A`, no `[[`, no bash 4+ features

These are the ceiling. Per-skill assertions are the floor. Without the ceiling, drivers pin symptoms, not classes. cli#305 (self-blocking identifier scrub) was Exhibit A — no sibling invariant caught it when upstream shipped the trace fix.

**3. Red first per driver (Beck).** Author the fixture plus assertion in cli BEFORE upstream ships the cure. Red is the ticket operator hands to upstream. Upstream ships; cli reruns to green. This flips the pattern (cure first, anchor later) that let sibling cases slip in the Kunal rerun.

## Recommended session sequence

1. **Session A — authoring chain (next pickup)** — `/interpret-input`, `/personas`, `/jtbd-tasks`, `/launch --local` plus the lite Docker runtime. Walking skeleton: ship `/interpret-input` first.
2. **Session B — session shape** — `/sprint`, `/longrun prep`, `/temperance`. Builds on Session A's harness.
3. **Session C — handoff cliff** — `/build` Phase 0 break corpus, `/autonomous`, `/deploy-prod`. Depends on upstream cure cadence for cli#307 + cli#331 + cli#332.

Session A is the next pickup. B and C fold off A's harness.

## Three sessions grouped by adopter journey

### Session A — authoring chain (next pickup)

**Why first.** Sam types `/launch --local` fresh. Pass 1 skipped Phases 2, 3, 3b silently in the Kunal rerun. Four mocks came back as look variations with one of four carrying ingredient counts. The authoring chain is where every first-contact adopter spends 30 minutes.

**Skills in scope.** `/interpret-input`, `/personas`, `/jtbd-tasks`, `/launch --local`.

**Walking skeleton.** Ship `/interpret-input` end to end first. Everything downstream reads what it writes. Driver scaffolds a scratch workdir, runs `/interpret-input` under adopter conditions, asserts the `intent` field appears in the output artifact (closes cli#319). Then grow to `/personas` (closes cli#318 + cli#320), then `/jtbd-tasks`, then `/launch --local` phase-order gate (closes rerun critique 6).

**Red-first assertions per skill.**

- `/interpret-input` — artifact JSON has non-empty `.intent` field (cli#319 RED today)
- `/personas` — persona slug does not match git email local part (cli#320 RED today)
- `/jtbd-tasks` — reads from the same persona path `/personas` writes (cli#318 RED today)
- `/launch --local` — Phase 4 (gallery) refuses when Phases 2/3/3b markers absent (critique 6 RED today)

**Container runtime ships here.** Dockerfile lands alongside the first driver. Base: `node:20-slim`, bash 3.2 explicit, no PyYAML, no Playwright, no gh auth. Container runs every `scripts/tests/smoke-drive-e2e-*.test.sh`.

**Time budget.** 150–250 turns across one session, maybe two if the Docker runtime takes longer than expected.

### Session B — session shape

**Why.** Louis switches context mid-week. Needs `/sprint` to orient, `/longrun prep` to kick off, `/temperance` as the scope gate.

**Skills in scope.** `/sprint`, `/longrun prep`, `/temperance`.

**Walking skeleton.** Ship `/sprint` end to end first. The orientation surface fires every session. Then `/longrun prep`. Then `/temperance`.

**Red-first assertions per skill.**

- `/sprint` — orientation gate reads whereami.md without PyYAML (closes cli#308 at this surface)
- `/longrun prep` — compounding-axis check fires with the 6-axis frame per `.claude/rules/compounding-sequence-fresh-analysis.md`
- `/temperance` — marker format fits the `/build` flow (addresses cli#328 observation)

**Time budget.** 100–150 turns. Smaller cascade than Session A.

### Session C — handoff cliff

**Why.** `/build` promises to call `/autonomous` with flags it does not recognize (cli#332 observation). Lite's no-deploy-path becomes visible — `hosting_platform: none` default plus Phase 7 stub.

**Skills in scope.** `/autonomous`, `/deploy-prod`, `/build` Phase 0 break-test corpus.

**Walking skeleton.** Ship the `/build` Phase 0 break-test corpus first. 12 fixtures where risky paths appear in step bodies, orphan steps, non-WU headings. Each asserts exit 3. Hands directly to upstream as the test corpus for cli#307. Then `/autonomous`. Then `/deploy-prod` (may remain a stub assertion if the skill itself is still stub).

**Red-first assertions per skill.**

- `/build` Phase 0 — 12 break fixtures each exit 3 (closes cli#307)
- `/autonomous` — procedure resolves without `strategy/` sibling (closes cli#331)
- `/deploy-prod` — skill tier matches declared tier (addresses cli#332 observation)

**Time budget.** 100–200 turns. Depends on how much of `/deploy-prod` upstream has cured by then.

## Container runtime contract

The lite-only Docker runtime enforces at the start of every driver:

```bash
source scripts/tests/lib/lite-runtime-invariants.sh
assert_lite_runtime  # exit 1 on any invariant violation
```

Invariants checked:

- No file in `dist/lite/` sources a module from `lib/` or `scripts/` not shipped in lite
- No bash script uses `declare -A`, `[[`, or any bash 4+ feature
- No skill body references a file at `/Users/`, `$HOME`, or any absolute path shape
- No skill assumes PyYAML, Playwright, or `gh auth`

CI wiring:

- `.github/workflows/lite-adopter-smoke.yml` — nightly against the current npm package plus tag push on releases
- `scripts/tests/run-lite-container.sh` — local operator-dispatched run of the same container

Both ship in Session A alongside the first driver.

## Related tickets

- **cli#294** — parent 5-driver stack (closed by PRs #298–#302 last session)
- **cli#305 – cli#332** — the 22 Kunal-rerun issues (upstream cure plan in flight)
- **bassclef-upstream#2049** — adopter-sim-test notification protocol filed last session

## Previous session artifacts

- `scripts/tests/smoke-drive-e2e-onboard-repo-cascade.test.sh` — E2E prototype shape
- `scripts/tests/smoke-drive-e2e-build-cascade.test.sh` — E2E prototype shape
- `scripts/tests/smoke-drive-adopter-*.test.sh` — 5 file-grep drivers from cli#294

The two E2E prototypes set the shape every Session A driver follows.

## Fresh-session kickoff

On session restart, the operator types:

```
/longrun prep
```

The agent then:

1. Reads this plan doc as Step 0.4 whereami precondition
2. Confirms Session A scope — authoring chain, four skills, Docker runtime bundled
3. Fires `/temperance` at Session A scope boundary
4. Fires `/luminary` to re-preview `alistair-cockburn`, `linus-torvalds`, `kent-beck` before any code edit
5. Fires `/pre-mortem light` (3 lenses × 5 risks) before the first Edit per `.claude/rules/loop-discipline.md` Step 0.5
6. Ships Session A walking skeleton: `/interpret-input` driver + Dockerfile + GitHub Actions nightly workflow as the first PR
7. Grows to `/personas`, `/jtbd-tasks`, `/launch --local` as follow-on PRs within the same session

The agent does NOT need to re-derive context from chronicles or git log. Everything required to kick off Session A is in this plan doc.

## What success looks like

Session A ships:

- Working lite-only Docker runtime at `scripts/tests/run-lite-container.sh`
- `.github/workflows/lite-adopter-smoke.yml` firing nightly
- At minimum one driver (`/interpret-input`) running RED today and ready to flip GREEN when upstream ships cli#319 cure
- Pattern template for Session B + Session C drivers

Sessions B + C fold cleanly off Session A's harness.
