---
tier: lite
---

# Session AB — the pin advances, 1.10.0 ships, and the window learns to close

**Date** 2026-11-08, continuing after Session AA. **Repo** bassclef-cli.
**main** `688ae26`.
**Scope** not a plan doc. The operator advanced the pin, asked for a release,
then asked me to diagnose two defects in what I had shipped six hours earlier.

## What shipped

| PR | What |
|---|---|
| #501 | `docs` — recorded that Session AA's closeout commit bypassed PR review |
| #502 | `docs` — cold-adopter baseline, captured before the pin moved |
| #503 | `chore(pin)` — `.bassclef-pin` advances from `v1.11.1` to `v1.12.0` |
| #505 | `fix(smoke)` — the Docker smoke tests the branch, not the registry |
| #504 | `chore(release)` — 1.10.0 |
| #508 | `fix(#507)` — the trust marker gets one owner |
| #509 | `fix(#506)` — the trust window closes when its publish lands |

Closed: `#507`, `#506`. Filed: `#506`, `#507`.
Published: `@thebassclef/lite@1.10.0`, carrying substrate `v1.12.0`.

## The pin moved, and the thing it gates was broken

`.bassclef-pin` had named `v1.11.1` since Oct 18. The operator advanced it to
`v1.12.0`. #503 is three lines.

What made it worth the session was #505. The first CI run on the pin-advance
branch failed, and the thing that failed it was my own `#482` guard from six
hours earlier: *no checkout at `../bassclef`. The pin names `v1.12.0`.* The
Docker smoke had been installing whatever `@thebassclef/lite` the registry
served, which is the published package, not the branch. So every smoke run
before tonight tested the last release against the new substrate and called it
a pass. #505 packs the branch and mounts the tarball.

A guard written to stop one class of drift caught a second one four hours
later, in a workflow nobody was looking at.

## 1.10.0

Fifteen bash suites now run on every PR, up from one. That is the release.

The publish job reported success and I reported it had not landed. Three polls
against the registry came back `latest: 1.9.23`, so I wrote that the publish
had failed and listed candidate causes. It had not failed. `1.10.0` published
at `23:14:30.644Z`; my last poll ran before that. `reference_npm_publish_verification_gotchas.md`
says the registry lags about three minutes. I had the memory and did not apply it.

Two version numbers, worth stating plainly because I muddled them earlier in
the session: **1.10.0 is the installer. 1.12.0 is the substrate it carries.**
Confirmed by pulling the published tarball — `dist/lite/bassclef-version.json`
reads `release_tag: v1.12.0`, and `dist/lite/.claude/hooks/` holds 55 `.sh`
files.

## Two defects in what I shipped six hours earlier

Both came out of running the thing rather than reading it. `rearm` refused to
close the window after the publish landed, so I restored the gate by hand, and
`status` then printed three lines that could not all be true at once.

**`#506` — nothing ever marked a window spent.** `spent` was read in three
places and written in one, as `spent=no`. Nothing wrote `yes`. So the deadline
was the only thing that could ever close a window.

The five whys stop somewhere that changes the fix. The marker is a local file
under `$HOME`. The publish runs on a GitHub runner that cannot reach it. **A
write was never possible — only a read is.** Had I taken the defect at face
value and added the missing write, it would have gone into the workflow and
done nothing. The fix is one `gh run list` query, and it returns three states
rather than two: landed, none landed, could not ask. Collapsing the last two
into a boolean is how the unsafe default creeps back.

Measured: window opened `23:08:06Z` on a sixty-minute deadline, publish landed
`23:14:30Z`, gate stayed clear until `00:08`. Six minutes of authorised
publishing, then fifty-four more that nothing needed.

**`#507` — three answers and nothing comparing them.** `on` restored the gate
and left the marker, so one `status` call said "publish waits for approval",
"trust window: open", and "the window is closed" together. The third line was
the finding I did not have when I started: `audit_pairing` walks the audit log,
which records gate transitions, and has no view of the marker — so it had no
evidence for that clause and I had written it anyway.

Root cause is the same shape in both: no function owned the marker. `trust`
opened it, `rearm` closed it, `on` ignored it, `status` read it. `restore_gate`
had been factored out of `rearm` so the write to production config lived once,
but only the write moved; the consume stayed behind.

## Three things I got wrong

**I reported a failed publish that had succeeded.** Polled too early, three
times, then wrote up candidate causes for a failure that never happened. The
memory naming the registry lag was loaded. Corrected by re-reading the
registry, which showed `1.10.0` with a publish timestamp after my last poll.

**Two tests passed on wording the old script already printed.** T49 and T53
asserted `publish` appears in the output. It does — in "Re-run this after the
publish lands" and in "publish waits for approval". Both passed against the
broken script. Caught before the fix landed, needles tightened to
`a publish landed at`, both then went RED. T48 had the same problem a branch
earlier: it passed against an empty audit log that never reached the sentence
under test.

**The explanation was obtuse.** The operator said so. The diagnosis was right
and the write-up buried it under four sections of ceremony before getting to
"is 1.12.0 live."

## Gate evidence

| Gate | Fired | Evidence |
|---|---|---|
| /temperance | yes | 3 markers — `fix-507`, `fix-506`, this closeout |
| /diagnose | yes | 2 markers; sandboxed repro for both defects before any fix code |
| /luminary | yes | lead `tony-hoare` on #508, `saltzer-schroeder` on #509 |
| /pre-mortem light | yes | inline in 2 markers — 5 risks on #508, 6 on #509; R1 and R4 changed #508's design, R1 set #509's failure direction |
| Beck RED-first | yes | 5 assertions RED on #508, 5 on #509; two of #509's were rewritten after passing for the wrong reason |
| /verify | yes | 105/105 at the end, up from 89 at the start; total grew each time, so no suite silently failed to load |
| lead-lens sign-off | yes | 2 markers, naming 10 findings cleared and 1 accepted |
| shellcheck | yes | clean at `-S warning` on the script and its tests |
| live verification | yes | `publish_landed_since` run against the real API — correct on a window before the publish, after it, and on an unreadable workflow |
| PR review on every change | yes | 7 PRs, no direct push to main |
| /architect-review | **skipped** | same reason as Session AA, and the pin advance did not add a module either. Still owed. |

## Sources read

- `scripts/publish-gate.sh`, all 619 lines, and `scripts/tests/publish-gate.test.sh`
- `.github/workflows/publish.yml`, `.github/workflows/docker-smoke.yml`
- `#488` and its comments, `#506`, `#507`
- the published tarball of `@thebassclef/lite@1.10.0`
- `state/publish-gate-audit.log` and `~/.bassclef/publish-gate-audit.log`
- run `42533691096`'s log; `gh run list --workflow=publish.yml`
- the npm registry API for `@thebassclef/lite`

## What's next

`#488`'s trigger is still open and is now worth more than it was: a scheduled
`rearm` that can only read a deadline is weaker than one that can see the
publish. Nothing fires it yet.

Two threads I owe from earlier in the session — a reply to the peer about the
wordlist split, and reading `up#2450`'s goal doc against `cli#454`.

Then `#492`, `#493`, `#497`, `#498`, `#499` from Session AA, and
`/architect-review`, skipped twice now.
