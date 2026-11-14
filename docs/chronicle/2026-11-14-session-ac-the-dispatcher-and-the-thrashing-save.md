---
tier: lite
---

# Session AC — the dispatcher gets tracked, and the Stop hook thrashes the PR

On the EC2 box, every bassclef-cli session had been loading 97 skills and 0 rules. SessionStart called `$HOME/.claude/hooks/bassclef-sync.sh`, which does not exist there. Commit `77f4a88` fixes that by tracking the dispatcher in the repo. It went up as draft PR #516. Most of the work was keeping it still: the Stop hook pushed three junk commits onto it in five hours.

## What shipped

- **PR #516** (draft) — `fix: track the sync dispatcher so rules reach a box session`, head `77f4a88`. CI is green on both checks (`Test + typecheck`, `Validate cross-repo contracts`). No reviews yet. Two test-plan boxes are still unticked. They need a fresh box session.
- **Issue #517** — the Stop hook commits and pushes onto open PR branches. It carries four labels: promote, operator-raised, framework bug, and `p1`. It is paired with sunj-labs/bassclef-upstream#2519, which asks for the context budget after each turn. The operator calls these two the practical blockers for building from mobile.
- **One new label.** I created the framework-bug label in this repo. `/promote` expects it, and the repo did not have it.

## The Stop hook pushes onto open PRs

Three unattended commits landed on #516. The operator approved dropping each one, and I force-pushed it away:

| SHA | Pushed (UTC) | Added |
|---|---|---|
| `736895c` | 17:40:32 | `state/bassclef-sync-status.json` |
| `465476d` | 17:48:52 | rescue file `2026-11-14T17-40-34Z` |
| `2f387e6` | 22:28:32 | rescue file `2026-11-14T22-26-38Z` |

**The cause, read from source.** `.claude/hooks/session-end.sh:96` runs `save-state.sh --quiet` on every Stop, without `--auto`. The branch guard in `save-state.sh:174` refuses only `--auto` saves, so it never fires on this path. The save then stages `docs/` (L268) and `state/` (L273), and pushes (L325).

**Why the rescue files land a turn late.** `session-end.sh` writes the rescue file after the save, in the same hook. So the file from Stop N gets committed at Stop N+1. The times match: the rescue file appeared at 17:40:34 and the commit at 17:48:52.

**The workaround is manual.** Move each new rescue file out of the tree before the next Stop. I wrote this log and the whereami update in a separate worktree, on `chore/session-ac-closeout`, for the same reason. The real fix belongs upstream, where these hooks come from.

## Three things I got wrong

1. **I said I couldn't open the PR.** My setup said there was no `gh` CLI, so I didn't check. The operator pointed out `gh` was logged in as `kingofrock`. Running `gh auth status` on the first turn would have shown it. I saved this to memory as `gh-cli-on-box`.
2. **I almost missed a stale head.** At check-in 1 the head was `465476d`, not `77f4a88`. I caught it only because `gh pr view` printed the SHA. I should have compared the head SHA on every check from the start.
3. **I almost wrote the pickup plan into `docs/`.** The next Stop would have pushed it onto #516. I read the hook first and put the plan in memory instead.

## Retro

- **Worked:** reading the hook before guessing. A few lines of `save-state.sh` and `session-end.sh` turned "auto-save is annoying" into a bug with line numbers and two fix options.
- **Worked:** asking before each force-push. A yes for one SHA did not stand in for the next.
- **Didn't work:** trusting my setup text over the machine (item 1 above).
- **Change next time:** when a hook writes to the tree, read it before writing any tracked file on a branch with an open PR.

## Gate evidence

| Gate | Fired | Evidence |
|---|---|---|
| /temperance | n/a | no new code this context; git and ticket work only |
| /diagnose | yes | read `session-end.sh:67-96` and `save-state.sh:155-182, 253-325` before naming the cause in #517 |
| /luminary | n/a | no design decision this context |
| /pre-mortem light | n/a | no code shipped this context |
| /verify | n/a | `77f4a88` predates this context; CI checked it (2 of 2 pass) |
| PR review on every change | yes | #516 opened as draft; no direct push to main; this closeout ships as its own PR |
| /promote | yes | #517, framework bug, `p1` |
| /architect-review | **skipped** | git and docs session; under 10 commits since the last review. Still owed from Session AA. |

The design chain fired 0 times this session, since there were no code steps. No wiki refresh is owed: no skill, hook, rule, standard or ADR changed.

## Sources read

- `.claude/hooks/session-end.sh` (L59-110)
- `.claude/hooks/save-state.sh` (L150-185, L253-274, L315-325)
- `~/.claude/settings.json` (permissions)
- `docs/whereami.md` (frontmatter, Session AB recap, `next_in_flight_goal`)
- `docs/chronicle/2026-11-08-session-ab-the-pin-advances-and-the-window-closes.md` (format)
- `gh pr checks 516` and `gh pr view 516`, four times across the session

## What's next

1. **Verify #516 in a fresh box session.** `ls .claude/rules | wc -l` should print 90. SessionStart should run the vendored `.claude/hooks/bassclef-sync.sh`. Tick both test-plan boxes. The operator marks it ready and merges.
2. **First action of that session:** move any new `docs/deferred-actions/*-session-rescue.md` out of the tree before the first turn ends. Keep doing this until #517 ships upstream.
3. **Decide the three untracked `.claude/settings.json.bak-20261114T*` files.** That's the operator's call.
4. Older open PRs are waiting on a decision: #474, #449, #423.
