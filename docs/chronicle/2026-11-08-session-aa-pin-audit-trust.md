---
tier: lite
---

# Session AA — the pin, the record, and a trust that re-arms

**Date** 2026-11-08. **Repo** bassclef-cli. **main** `2a9880e`.
**Scope** option c of `docs/next-session-plan-2026-11-08-after-1923.md` — four
steps, in order. All four done. Four PRs merged. Five tickets filed.

## What shipped

| PR | What |
|---|---|
| #494 | `fix(#482)` — the bundler reads `.bassclef-pin`; `pr-checks.yml` stops hardcoding a tag |
| #495 | `fix(#489)` — the audit record moves outside the repo; `audit` walks the log |
| #496 | `ci` — 15 bash Tier 0 suites run on every PR, up from 1 |
| #500 | `feat(#488)` — `trust` with a deadline, `rearm` that uses it |

Closed: `#482`, `#489`. Left open on purpose: `#488`, for its trigger.

## Step 1 — the cold-adopter smoke

Ran in the Docker harness against published `1.9.23`, not
`nuke-and-fresh-install.sh --purge-adopter`. The plan doc named that script,
and `scripts/nuke-and-fresh-install.sh:339` moves `~/.claude` whenever
`--keep-claude` is absent. Running it would have moved this session's 88 hooks
mid-session, and — worse for the measurement — counted the operator's own
setup rather than an adopter's.

Three checks, three answers:

- **Brass renders.** Figlet in `38;5;179`, chip as `48;5;179` on `38;5;233`
  bold. Confirmed with `FORCE_COLOR=1`; a piped run correctly drops colour,
  per `init-brand-mark.ts:171`.
- **Something wraps.** Widest printed line is 102 columns, not 71. Session Z's
  figure held for the brass block and not for the install log above it.
  Filed `#492`.
- **The budget: 79 rule files, 481,327 bytes, 3.22x the 150,000 limit.** The
  warning text does not appear in `-p` mode at all, so no automated smoke can
  capture it. Posted to `up#2238` with the method.

Also found: `"1 config files created"` on a real install (`#493`), and a cold
adopter's first `claude` opens on the theme picker.

## Step 2 — the pin, and a third divergent path

The ticket named two bundle sources. There were three.
`pr-checks.yml:71` hardcoded `ref: v1.1.1` under a comment reading "Matches
publish.yml pin". `.bassclef-pin` names `v1.11.1`. One character apart, 27 days
apart, both real tags. So the full suite validated a bundle built from one
substrate version while publish shipped another.
`scripts/tests/bassclef-pin.test.sh:42` read `publish.yml` and nothing else —
the test written to catch a hardcoded sibling tag was pointed at one of the
two files that could carry one. T9 and T10 now read every workflow.

**The field that matters is `release_tag`, not `version`.** My first cut
compared `version` and would not have worked:

| Checkout | `version` | `release_tag` | Lite hooks |
|---|---|---|---|
| at tag `v1.11.1` | v1.11.1 | `v1.11.1` | 31 |
| release branch, 41 commits past | v1.11.1 | `release-2026-11-08-201b234b` | 46 |

The release process writes the marker before the version bump, so `version`
reads the same on both. A `version` check would have passed on a checkout
emitting 46 hooks where CI emits 31 — the exact divergence the ticket is about.

**Advancing the pin was deliberately left out.** It still names `v1.11.1` from
October 18, with upstream 41 commits ahead. The pin is now load-bearing;
choosing a new value is a decision that needs those 41 commits read.
Put to the operator; unanswered when the session closed.

## Step 3 — the record

`state/publish-gate-audit.log` is tracked, so a reset rewrites it. The record
moved to `~/.bassclef/publish-gate-audit.log`; the tracked file stays as a
view, and `audit` reports when the two disagree.

`audit` walks transitions rather than counting them. A count of `on` against
`off` passes on a log holding two of each in the wrong order.

**Calibrated against the real log, which changed the design twice.** Its first
line is an `on` from 2026-11-05, because the clear before it was a raw API call
made while `off` was broken (`#481`), so no `off` line could exist. My first
check called that a defect on every run. A check that cries wolf on its own
opening line stops being read. A leading `on` now reads as informational, and
T30 pins that a later lone restore is still caught — verified against the real
log with the reconstruction removed, where it names `2026-11-08T02:25:49Z`.

## Step 4 — trust

`trust` was a spelling of `off`, and the restore was a sentence in `SKILL.md`.
It now writes a marker carrying who authorized the window and when it closes,
and `rearm` restores the gate from it and consumes it. Neither waits on the
publish, which is the point.

The deadline compares ISO-8601 strings rather than calling `date -d`, so it
behaves the same on BSD and GNU. `#498`, filed the same night, is a live
example of why that matters.

**What is not done, and was named rather than implied.** Nothing fires `rearm`
on a schedule. The project SessionStart block holds one entry and the sync
removed three project-scope hooks during this session; adding a fourth the next
sync may clear is worse than adding none. `#488` stays open for the trigger.

## The extra one, and why it rode along

CI ran one bash Tier 0 suite out of eighteen. The 23 assertions added by #494
and #495 were enforced on this machine and nowhere else. #496 runs fifteen.

Its first CI run went red and found three suites that pass on macOS and fail on
Linux — one with a macOS-only `stat` call where the file mode is in fact
correct. Filed `#498`. That is what running them was for.

## Five things I got wrong, all caught in-session

1. **Asserted without checking.** Wrote "both compounding files landed" in a
   comment on `up#2238`. Only one ships. The claim came from reading a local
   checkout and reporting it as a property of the published package — the same
   shape as `#482`, and it caught me the way it caught the four defects named
   there. Corrected in a follow-up comment.
2. **Compared the wrong field.** `version` instead of `release_tag`, above.
   Found by measuring the real repo at two refs.
3. **Leaked fixture traffic into the live record.** My tests wrote 24 lines
   into `~/.bassclef/publish-gate-audit.log`, because the pre-existing `run()`
   helper sets `PUBLISH_GATE_AUDIT` only. Found by running `status` against the
   live environment, not by reading the harness. Every runner now redirects
   `HOME`; T31 pins the default path; the record was restored and verified
   byte-identical across a full run.
4. **Marked a test-list line with no test behind it.** `[x] P10` removed.
5. **Wrote a shared function and then left the old copy.** `restore_gate`
   existed for sharing while `do_on` kept its own write. Fixed; T07-T09 are
   what made the refactor safe rather than hopeful.

## Gate evidence

| Gate | Fired | Evidence |
|---|---|---|
| /temperance | yes | 4 markers, one per branch plus the session |
| /luminary | yes | lead `michael-feathers` on #494, `saltzer-schroeder` on #495/#496/#500 |
| /pre-mortem light | yes | `docs/risk-ledgers/2026-11-08-session-aa-option-c.md`, 3 lenses, 16 risks, 6 folded before edits |
| Beck RED-first | yes | 8/9, 16, 19 assertions shown RED; T9/T10 shown RED on the unmodified file |
| /verify | yes | 4 markers |
| lead-lens sign-off | yes | 4 markers, naming 9 self-findings cleared |
| /architect-review | **skipped** | 413 commits on main but the last review was 2026-10-11; this session was 4 PRs in build tooling, CI and one bash script, with no new module. Worth running on the pin advance instead, where the architecture question actually sits. |
| cold-adopter smoke | yes | Docker harness, published 1.9.23, exit 31 — two pre-existing driver failures, neither a 1.9.23 regression |

## Sources read

- `docs/whereami.md`, recap blocks through Session Z
- `docs/next-session-plan-2026-11-08-after-1923.md`
- `#482`, `#488`, `#489`, `#329`, `up#2238`, `up#2398`, `up#2428`
- `scripts/prepublish-bundle-substrate.mjs`, `scripts/publish-gate.sh`,
  `scripts/nuke-and-fresh-install.sh`, `harness/docker/entry.sh`
- `.github/workflows/pr-checks.yml`, `publish.yml`
- the public sibling at `v1.11.1` and at `release-2026-11-08-201b234b`
- `state/publish-gate-audit.log`, all 9 lines

## What's next

**The pin.** Unanswered. Three ways were put to the operator: read the 41
commits and report the deltas (25-40 turns), leave it and make the refresh its
own goal, or advance it on my judgement — which would ship a framework set
nobody read, and is the thing `#482` exists to stop.

Then `#492`, `#493`, `#497`, `#498`, `#499`, all filed tonight, and `#488`'s
trigger.
