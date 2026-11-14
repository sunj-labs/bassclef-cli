---
tier: lite
---

# Session AC — verify #516, and keep the Stop hook off the PR branch

**Date** 2026-11-14. **Repo** bassclef-cli. **main** `718bef9`.
**Scope** the pickup plan from the earlier 2026-11-14 session: (a) verify
PR #516 in a fresh box session, (b) stop the churn. No code changed.

## Entry state

- PR #516 (`fix/vendor-sync-dispatcher`) open as a draft at head `77f4a88`.
- cli#517 filed earlier the same day: the Stop hook commits and pushes onto
  open PR branches. Paired with sunj-labs/bassclef-upstream#2519.
- No session log for the earlier 2026-11-14 session. `docs/whereami.md` last
  updated 2026-11-09, which is one of the rescue-file triggers.

## What happened

| Item | Result |
|---|---|
| PR #516 verified | 90 rules in `.claude/rules`. `$HOME/.claude/hooks/bassclef-sync.sh` does not exist, so the sync that ran at 23:31Z was the repo copy. Both Test plan boxes ticked. CI green. Head still `77f4a88`. |
| Hook-cadence banner | Deferred by the operator. Not a new promote: cli#207 already covers it. Added a comment with today's 40-hook evidence and a second bug. |
| Stop-hook churn | Operator chose the upstream fix, sunj-labs/bassclef-upstream#973, in its own session. Sync path recorded on cli#517. |
| Settings backups | Seven `.claude/settings.json.bak*` files deleted at the operator's word. |

## The second bug in the hook-cadence banner

The banner says non-critical hooks need "no action." But no action leaves them
unlisted in `standards/hook-cadence.json`, so the banner fires again next
session. There is nowhere to record "reviewed, not critical." The operator can
only ever defer it. Posted on cli#207, with two labels added for triage.

## The Stop hook kept writing rescue files

Six rescue files appeared, one per Stop: `23-29-49Z`, `23-32-28Z`,
`23-41-03Z`, `23-48-05Z`, `23-50-40Z`, `23-53-41Z`. Each was moved to
`/tmp/scratch-rescue/` before the next Stop could push it. PR #516's head
never moved.

The cause is unchanged from cli#517. `session-end.sh:96` calls
`save-state.sh --quiet` with no `--auto`. The branch guard at
`save-state.sh:174` only checks `--auto`. No env var turns it off.

## How the upstream fix will reach this repo

1. sunj-labs/bassclef-upstream#973 merges.
2. `scripts/release-to-bassclef.sh` opens a release PR on `sunj-labs/bassclef`.
3. Someone runs `git -C ~/src/sunj-labs/bassclef pull`. Sync never pulls the
   checkout it copies from, and this repo has no `.bassclef-source.json`.
4. The next SessionStart copies the hooks in. Both hooks are untracked here,
   so nothing needs committing.

## Decisions

- Hook-cadence banner deferred; the promote stays cli#207.
- The Stop-hook fix belongs upstream, in a session with time to talk it through.
- Settings backups deleted.
- This log and the whereami update ride on `chore/session-end-2026-11-14`,
  cut from main, not on the PR branch.

## Open threads

- PR #516: operator marks ready and merges.
- sunj-labs/bassclef-upstream#973: upstream session.
- Until #973 ships: move any `docs/deferred-actions/*-session-rescue.md` out
  at the end of every turn.
- `state/install-written-paths.json` and `state/markers/last-block/` are
  untracked and keep the rescue trigger live.
- `/architect-review` still owed; last run 2026-10-11.

## Gate evidence

| Gate | Fired | Evidence |
|---|---|---|
| /temperance | n/a | no code edits this session |
| /diagnose | n/a | no fix branch; Stop-hook cause traced by reading `session-end.sh` and `save-state.sh` |
| /promote | yes | cli#207 updated with a comment and two labels |
| /verify | yes | PR #516 Test plan checks run and ticked |
| PR review on every change | yes | this log goes up as a PR, not a push to main |
| /architect-review | **skipped** | still owed |

## Session timing

- started_at: 2026-11-14T23:31:29Z (`/tmp/claude-session-timing-482a2a0d`)
- ended_at: 2026-11-14T23:57Z
- duration: about 26 minutes
