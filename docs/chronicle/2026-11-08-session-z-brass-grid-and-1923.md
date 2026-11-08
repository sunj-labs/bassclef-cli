---
tier: upstream
type: chronicle
date: 2026-11-08
session: 2026-11-08-session-z
project: bassclef-cli
preset: exploratory
outcome: shipped
started_at: 2026-11-08T00:15:35+0000
ended_at: 2026-11-08T11:21:05+0000
duration_minutes: 666
tags: [cli-481, cli-484, cli-488, cli-489, release-1.9.23, install-output, brand-mark, publish-gate, audit-log, assert-verify]
---

# Session Z — the brass finally prints, and an audit log that git can erase

Continues `docs/chronicle/2026-11-07-session-y-install-surface-and-two-releases.md`. That entry shipped 1.9.21 and 1.9.22 and named four defects of one shape. This one starts from the operator looking at a cold install of 1.9.22 and asking why the brass was missing, and ends with 1.9.23 published unattended.

Duration spans 11 hours. About 8 of those were idle between the publish landing at 02:25Z and the operator returning at 11:15Z.

## Entry state

`@thebassclef/lite@1.9.22` live. Install banner shipping a grey figlet, no brass, jammed against the install log. Gate ON. Pin 20 days stale.

## What shipped

**`@thebassclef/lite@1.9.23`**, published 2026-11-08T02:25:17Z. Sigstore log index 3747789418. 492 files, 1.5 MB packed. Published **unattended** — the operator said "publish without my touch — trust" and never clicked.

Four PRs, all merged:

| PR | What |
|---|---|
| #485 | The brass prints. Banner on a two-column grid. Prose fits 80 columns. |
| #486 | `publish-gate.sh off` works for the first time since it shipped. |
| #487 | Release 1.9.23. |
| #490 | Notes flipped to Released; restored a lost audit entry; next-session plan. |

## The defect the operator caught

The brass chip shipped in 1.9.22 with five passing tests, correct ANSI, and **no caller**. `renderBrandMark` composed its own plain text line instead. `grep -rn "renderChip" src/` found one hit, inside the file that defines it.

The tests could not have caught it. Five tests called `renderChip` directly; seven called `renderBrandMark`. Nothing asserted a relationship between them. Each half was pinned alone, so a function with no caller passed every test it had.

The fix includes the assertion whose absence let it ship: the composed mark must contain the chip. It fails on the code that shipped.

## The design work

`/extract-intent` ran LIVE (voyage-3-lite + haiku-4-5, 0.82) and returned `apple-hig`, `jony-ive`, `aarron-walter`. Two were set aside **against their own declared anti-patterns** — HIG's "cross-platform brand-led design where native fit isn't the goal", Walter's "power-tool or data-dense surfaces where personality slows the user down". A developer CLI at install is exactly Walter's exclusion.

Kept `jony-ive`. Added the catalog's typographic lenses the matcher missed: `massimo-vignelli` (lead), `edward-tufte`, `dieter-rams`, `ellen-lupton`.

Four of five reached the same answer by different routes: **the indent is the border.** Ive's lens found the actual bug — the missing blank line between install log and figlet is an unresolved seam, and that is what read as jammed, not the absence of a box.

The operator asked for "perhaps even a clean border". The honest answer was no, with the reasoning shown rather than asserted. Then they asked why the figlet had no brass — a question I had not asked myself, because I inherited the plain figlet while fixing spacing. The hierarchy was inverted: the heaviest thing on screen carried no brand.

**Font evidence, read from the binaries rather than reasoned about:**

| Glyph | Monaco | Menlo | SF Mono | Courier New |
|---|---|---|---|---|
| `─ │ ┌` square | yes | yes | yes | yes |
| `╭` rounded | **no** | yes | yes | **no** |
| `▌ ▀` blocks | **no** | yes | yes | yes |
| `𝄢` clef | no | no | no | no |

A rounded box would have walked straight back into the font trap the figlet rewrite escaped. Recorded on the ticket so the next person does not re-derive it.

## Decisions

**A2 — brass on figlet and chip.** One index (179), two devices: foreground for line art, inverted for the plate. The plate is filled so it still outweighs the art. A test fails if a second gold appears — two near-equal golds read as a mistake, not a choice.

**No border.** Four lenses, one answer. The indent costs zero characters of non-data ink; a full box costs 94 per install. The box version also has a concrete fault: its right edge is hand-counted around invisible ANSI, so `1.9.9` → `1.10.10` would ragged it with no test able to see.

**Colour detected, not assumed.** `supportsColour(env, isTTY)` is pure, so it tests without a pty. Defaults **off** — piped output stays free of escape codes, which keeps the cold-adopter smoke captures readable as the record of what an adopter sees.

**Rewrapped the prose after all.** See below.

## Two claims I got wrong

**One.** I asserted that rewrapping the long lines would break `tests/init-value-test-block.test.ts:82-84`, cited that exact range, and repeated it in a PR body. The operator asked why.

I rewrapped it and ran the suite: **9/9 pass.** The test iterates the constant it checks, so it can never fail when that constant changes. I had read the right lines and reasoned wrongly about them. The citation was accurate and the claim was false.

**Two.** I said the rewrap needed `bassclef-upstream#2006` updated first, citing the file header that says so. Reading #2006 showed it quotes its target as a markdown blockquote — it pins words and carries no column budget. I had passed the header's claim along as my own.

I was also inconsistent: #2006's quoted block shows `/launch` directly under its lead-in, and my blank-line fix had already moved that shape. I called one change safe and the other blocked when both touch the shape and neither touches the words.

Both corrections are in the PR body rather than quietly dropped.

## The audit log hole

The gate cleared, the publish ran, the gate re-armed. Then the audit log showed a **restore with no matching clear** — the one shape an audit trail must not have.

Cause: `state/publish-gate-audit.log` is tracked in git. The successful `off` wrote its line to the working tree on `fix/481`. I committed only the script and its test, then ran `git reset --hard origin/main` to reconcile a diverged local main. The reset reverted the file and took the operator's authorization with it. Verified it never reached a commit — `git log --all -S` over that path finds nothing.

**Second time in one session an operator authorization lost its record.** The first was #481: the verb was broken and wrote nothing. Different cause, same outcome.

Restored as a `RECONSTRUCTED` entry, bounded rather than guessed — the clear ran before `308b56f` at 01:34:18Z. Filed as #489 with four options weighed.

The `reset --hard` was mine. I ran it without checking what tracked state it would revert.

## The pattern, named

Six instances in two days of **a path that runs in one place, never compared against the other**:

| | |
|---|---|
| `cli#479` | three tests, all injecting a stub, so the real runner never ran |
| `cli#481` | sixteen tests over a write that returned 422 every time |
| `cli#482` | a local build reading a different repo than CI |
| `cli#484` | five passing tests, zero callers |
| watch script | `gh run list --limit 1` returning the previous run's success |
| two claims | right source line, wrong conclusion |

The operator saw it first and asked for the rule-level question to be filed. `up#2428` asks whether assert-verify should rank its evidence: an execution outranking a read, and a fix's proof being a test shown RED on the old code rather than GREEN on the new.

## Tickets

**Filed:** `cli#484` (the brass), `cli#488` (a real `trust` verb), `cli#489` (the tracked audit log), `up#2428` (rank assert-verify evidence).

**Not filed — searched first, found existing:** `up#973` (auto-save `--auto` flag), `up#2238` (instruction budget). Evidence added to both instead. That search caught three would-be duplicates tonight.

On `up#2238` a finding worth carrying: `#1951` deduped `compounding-axis` against `compounding-sequence` and closed, yet **both still ship in `dist/lite`**, and `compounding-sequence-fresh-analysis.md` is the largest single file in the bundle at 17.4k.

## Open threads

- **`cli#482`** — pin is `v1.11.1` from Oct 18, **39 commits behind**. 1.9.23 ships the same framework content 1.9.22 did. Named in the release notes under "Known, and not fixed here".
- **`up#2238`** — `dist/lite/.claude/rules/` is 79 files, 488,201 bytes against a 150,000-char limit. Every cold adopter's first `claude` opens with a warning.
- **`cli#488`, `cli#489`** — both filed tonight, both in the next-session plan.
- **1.9.23 not yet smoked on a real cold adopter.** Verified by local render and Docker, not by a human looking at an install. Step 1 of the next-session plan.
- **`up#973`** — the Stop hook committed and pushed in-progress work mid-edit, twice. `session-end.sh:95` calls `save-state.sh --quiet` with no `--auto`, so the `fix/*` guard is never consulted.

## Gate evidence

| Gate | Fired | Evidence |
|---|---|---|
| `/temperance` | 2 | `state/markers/temperance/fix-48{1,4}-*.marker` |
| `/diagnose` | 2 | `state/markers/diagnose/fix-48{1,4}-*.marker` |
| `/luminary` | 2 | `state/markers/luminary/fix-48{1,4}-*.marker` |
| `/pre-mortem` | 1 | `state/markers/pre-mortem/fix-484-*.marker` (3 lenses, 8 risks) |
| lead-lens sign-off | 2 | `state/markers/lead-lens-signoff/fix-48{1,4}-*.marker` |
| `/extract-intent` | 1 | LIVE, 0.82, recorded on the luminary marker |
| `/sprint` | 1 | `state/markers/sprint-preset/main.marker` (exploratory) |
| `/verify` | n/a | CI stood in — 575 tests, Docker smoke green on each head sha |

The `fix/484` pre-mortem covers both branches; `fix/481` reused its folds rather than re-running three lenses on a one-line change. Named rather than silent.

## Key files changed

- `src/lib/init-brand-mark.ts` — chip called, brass on art, `supportsColour`, `indentBlock`, `BRAND_MARK_INDENT`; raw ESC bytes replaced with `\x1b`
- `src/lib/init-value-test-block.ts` — cue rhythm, sentence-boundary wrap
- `src/commands/init.ts` — leading newline, colour decided once, shared indent
- `scripts/publish-gate.sh` — `off` sends JSON instead of a typed `-F`
- `scripts/tests/publish-gate.test.sh` — stub now refuses what GitHub refuses
- `tests/init-brand-mark.test.ts`, `tests/init-value-test-block.test.ts` — 21 tests added
- `docs/release-notes/v1.9.23.md`, `docs/next-session-plan-2026-11-08-after-1923.md`

## Design artifact

https://claude.ai/code/artifact/aed98b4c-0d15-4362-97f1-67987eb97898 — the banner in real brass, four treatments compared, lens verdicts, font table.
