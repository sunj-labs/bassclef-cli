---
id: 2026-11-08T12-51-04Z-session-rescue
created_by_session: session-end-hook-2026-11-08T12-51-04Z
created_in: desktop
created_at: 2026-11-08T12:51:04Z
pending_action: resume-unfinished-session
requires_capability: [git-push, network]
priority: high
origin_skill: /session-end
resolves_when: |
  MUST-tier session-end obligations listed below are satisfied
  (chronicle written, whereami current, working tree clean), and
  this file has been git mv'd to docs/deferred-actions/completed/.
---

## Context

Stop-hook fired before MUST-tier session-end obligations completed.
This is the forward-pointer deferred-action entry per bassclef #226
WS-3 — the next capable session picks up the unfinished work instead
of silently losing it. Reasons flagged:

- uncommitted changes in working tree

Common triggers: context exhaustion, OS-level interruption, sandbox
teardown, agent completed work but didn't run /session-end.

## Command to execute

Next session, run /session-end to complete each flagged obligation in
order. The skill's procedure enumerates the MUST tier; resolve each
before moving on. If any flagged obligation turns out to be satisfied
already (hook false-positive), note it in the resolution entry and
proceed.

## On completion

- [ ] All flagged obligations resolved
- [ ] `git mv "docs/deferred-actions/2026-11-08T12-51-04Z-session-rescue.md" "docs/deferred-actions/completed/2026-11-08T12-51-04Z-session-rescue.md"`
- [ ] `git commit -m "chore: resolve session-rescue 2026-11-08T12-51-04Z"`

## Cross-refs

- bassclef #231 — WS-3 issue that shipped this pattern
- bassclef #226 — parent bet
- `.claude/rules/session-artifacts.md`
- `.claude/hooks/session-end.sh` — the hook that wrote this entry

## Resolution — 2026-11-08, session AA

Pattern B. The flagged reason was "uncommitted changes in working tree". Those
changes were `.claude/settings.json` and `state/bassclef-sync-status.json` —
sync churn from session start, not unfinished work. Both landed in PR #494 and
are byte-identical on `origin/main`, checked with
`git diff --quiet 01eaac8:<path> origin/main:<path>` before anything was
discarded.

The session's MUST-tier obligations are satisfied: session log at
`docs/chronicle/2026-11-08-session-aa-pin-audit-trust.md`, whereami updated,
working tree clean, four PRs merged.

A hook false-positive in substance, so this is recorded rather than re-run.
