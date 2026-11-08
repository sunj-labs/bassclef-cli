# Next session plan — after 1.9.23

**Written** 2026-11-08 at the close of the session that shipped 1.9.23.
**Repo** bassclef-cli. **main** at `af30083` plus PR #490.

This exists so the next `/longrun prep` fires the converged preset and
shows a pick instead of re-deriving scope. Per
`.claude/rules/longrun-prep-plan-doc-compression.md`, a plan doc modified
within 48 hours carrying a `## Recommended session sequence` section is
the converged signal.

---

## Where things stand

`@thebassclef/lite@1.9.23` is live. Published 2026-11-08T02:25:17Z,
Sigstore log index 3747789418, 492 files. The install banner now prints
brass on a two-column grid and nothing wraps on an 80-column terminal.

The publish ran unattended. The operator said "publish without my touch
— trust", and `trust` turned out to be broken, so the session fixed it
mid-flight (#481) before it could be used.

**What the session did not fix, and should bother us:**

- `.bassclef-pin` is `v1.11.1` from 2026-10-18 — **39 upstream commits
  behind**. 1.9.23 ships the same framework content 1.9.22 did.
- A cold adopter's first `claude` still opens with a yellow warning:
  79 rule files, 488,201 bytes, against a 150,000-char limit.
- Two of the publish gate's own records failed tonight. One because the
  verb was broken, one because a `git reset` erased the entry.

---

## Recommended session sequence

Four steps, in this order. Each one feeds the next.

### 1 — Smoke 1.9.23 on a cold adopter (15-25 turns, 🟢)

**Produces:** a capture of what an adopter actually sees on 1.9.23.
**Consumes:** session-start.

Run `scripts/nuke-and-fresh-install.sh --purge-adopter` and read the
output. Three things to check, and the third is the point:

- The brass renders. The figlet and the chip should both be brass, and
  the block should sit two columns in from the install log.
- Nothing wraps. The widest line we print is 71 columns.
- **The instruction-budget warning.** It will still be there. Capture
  the exact text and file count, because that number is the measurement
  `up#2238` wants and it has gone up every time anyone has looked.

Why first: tonight's work was verified by rendering locally and by the
Docker smoke, not by a human looking at a real install. Per the memory
written this session, execution beats reading — and a real install is
the strongest execution available here. It also costs almost nothing.

### 2 — The pin (#482) and what it drags behind it (60-100 turns, 🟡)

**Produces:** a pin that matches what we mean to ship, and a bundler
that reads it.
**Consumes:** step 1's capture, which shows what adopters have today.

Two problems in one ticket. A local build reads `../bassclef-upstream`
at HEAD while CI reads the mirror at the pin — 46 hooks against 31. And
the bundler never reads `.bassclef-pin` at all.

This is the highest-value item on the cli side because it decides what
adopters actually receive. Every release until it is fixed ships a
framework set nobody chose. It is also step 1 of the go-live cascade
(`docs/iteration-bets/2026-11-07a-go-live-cascade.md`, upstream branch
`docs/roadmap-release-cascade-go-live`), where it is marked red.

The 🟡 is the refresh itself: moving the pin forward 39 commits pulls in
whatever landed in those commits, and that needs reading before it needs
shipping.

### 3 — The audit log (#489) (25-40 turns, 🟢)

**Produces:** an audit log that survives a branch switch.
**Consumes:** nothing from steps 1-2 — parallel-safe, sequenced here
because it is small and the reasoning is already written down.

`state/publish-gate-audit.log` is tracked in git, so any `reset --hard`
rewrites it. Tonight that erased an operator authorization for an
unattended publish, leaving a gate restore with no matching clear.

Four options are weighed on the ticket. The one that looks right is a
local untracked log as the record of truth with a tracked mirror for
review, but that is a call for whoever picks it up. Worth adding either
way: a check that reports unpaired `on`/`off` entries, which would have
surfaced tonight's hole immediately.

### 4 — A real trust verb (#488) (30-50 turns, 🟡)

**Produces:** a `trust` that clears the gate and re-arms it itself.
**Consumes:** step 3's decision about where the log lives — the two
touch the same script and the same record.

`trust` works today only because it routes to `off`, and the only thing
restoring the gate afterwards is a sentence in `SKILL.md` telling the
agent to do it. A promise kept by prose is kept as often as the prose
is read. Tonight it was read. That is not a mechanism.

The 🟡 is the re-arm: it must not depend on the publish path completing,
so it needs a marker with a deadline and a session-start check.

---

## If there is less time than that

Steps 1 and 3 alone are a good session. Step 1 proves tonight landed and
produces the measurement `up#2238` needs. Step 3 closes a hole this
session opened. Together, 40-65 turns.

Step 2 is the one worth protecting a long session for. It should not be
started with under 60 turns left.

---

## Not in this sequence, and why

- **`up#2238`, the instruction budget.** 488,201 bytes against a
  150,000-char limit, so every cold adopter opens with a warning. The
  highest adopter-facing item open anywhere — but the files are upstream
  and the fix is upstream's call. Step 1 feeds it a fresh measurement.
  Flag worth passing on: `#1951` deduped `compounding-axis` against
  `compounding-sequence` and closed, yet **both still ship in
  `dist/lite`**, and `compounding-sequence-fresh-analysis.md` is the
  single largest file in the bundle at 17.4k.
- **`up#2398`, the first-run epic.** 13 children, p0, untouched since
  filing. Tonight's banner work was one of them. The rest are upstream.
- **`cli#475`, the bass clef glyph.** Still deferred on the operator's
  call, not on merit. The font evidence is now on `cli#484` — the clef
  is in none of Monaco, Menlo, SF Mono or Courier New and renders only
  through terminal fallback, which is exactly what the ticket says.
- **`up#973`, the auto-save flag.** Evidence added tonight. Upstream's.

---

## One pattern worth carrying into the next session

Six defects in two days shared one shape: **a path that runs in one
place, never compared against the other.**

| | |
|---|---|
| `cli#479` | three tests, all injecting a stub, so the real runner never ran |
| `cli#481` | sixteen tests over a write that returned 422 every time |
| `cli#482` | a local build reading a different repo than CI |
| `cli#484` | five passing tests, zero callers |
| watch script | `gh run list --limit 1` returning the previous run |
| two claims | read the right source line, drew the wrong conclusion |

In every case the tests were green and meant nothing, because they
exercised a stub. `up#2428` was filed to ask whether the assert-verify
rule should rank its evidence — an execution outranking a read, and a
fix's proof being a test shown RED on the old code rather than GREEN on
the new.

Step 2 (#482) is the one remaining open instance. Worth naming that out
loud when it is picked up.

---

## Sources read

- `docs/whereami.md` recap blocks, 2026-11-08
- `gh issue list` on bassclef-cli and bassclef-upstream, 2026-11-08
- `docs/iteration-bets/2026-11-07a-go-live-cascade.md` (upstream branch)
- Publish workflow log, run 42438385522
- `state/publish-gate-audit.log`
- Tickets #482, #484, #488, #489, `up#2238`, `up#2398`, `up#2428`
