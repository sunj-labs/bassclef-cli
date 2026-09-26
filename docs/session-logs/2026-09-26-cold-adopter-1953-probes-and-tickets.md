---
tier: standard
session_id: 2026-09-26-1042
project: bassclef-cli
agent: personal
status: completed
tags: [diagnose, cold-adopter, peer-coordination, tickets, bassclef-upstream-1953]
started_at: 2026-09-26T10:42:19+0100
ended_at: 2026-09-26T11:23:53+0100
duration_minutes: 41
turns: ~40
closes: []
---

# Session: cold-adopter #1953 probes + five-ticket batch

## Entry State

Continued from prior session's summary. Peer bassclef-upstream-5c had asked two probes for bassclef-upstream#1953 (v1.6.0 tier filter cure did not reach adopter). Two probes: (1) `resolve_bassclef_dir` output on cold-adopter Mac; (2) diff init manifest SessionStart entries against live settings SessionStart. Also carrying tonight's next-session plan at `docs/next-session-plan-2026-09-26-1953-probes.md`. Prior evidence chain: docker smoke on v1.9.3 PASS 43/0/43, but real Claude interactive session on cold-adopter Mac showed 44 phantom BLOCKED banners.

## Work Done

### Ran the two peer probes on cold-adopter Mac profile

- Probe 1 (`resolve_bassclef_dir`): returned `/Users/cold-adopter-1/tmp/bassclef` — a full bassclef upstream checkout dated 2026-09-19, six days before v1.6.0 shipped.
- Probe 2 (init manifest vs live settings diff): live SessionStart has 1 matcher with 2 hooks (`bassclef-sync.sh` + `session-reflection.sh`). Init manifest has no `.hooks.SessionStart` key at all — init records `.files` array only. The leak is at PreToolUse, PostToolUse, and Stop event types, not SessionStart.
- Clean comm probe (writable path): disk 93 hook files, manifest 95 planned, settings 71 unique references. Delta returned 28 phantom entries — hooks referenced in settings.json without files on disk.

### Named root cause

`resolve_bassclef_dir` Check 1 tests `$CWD/../bassclef/presence/install/bassclef-hook-connect.sh` before Check 3 hits the npm install. CWD is `~/tmp/bassclef-smoke-test`, so Check 1 hits `~/tmp/bassclef` — a stale bassclef checkout with pre-v1.6.0 code. The pre-cure `bassclef-hook-connect.sh` there fires the additive merge without the tier filter. That adds 28 phantom entries to adopter settings.json.

### Verified the cure

- Moved `~/tmp/bassclef` aside to `~/tmp/bassclef.stale-cure-test-2026-09-26`
- Reset `settings.json` to `.residue-2026-09-26` (residue lives in settings.json — additive merge never subtracts)
- Ran `bassclef init --force` → wrote 29 clean lite hooks per v1.6.0 tier filter
- Restarted Claude Code in the smoke-test dir → zero phantom BLOCKED banners
- Class named: additive merge + wrong source + no filter guard

### Traced the stale checkout's provenance

Cold-adopter's `git remote -v` showed `sunj-labs/bassclef.git` (public repo). Commit `1aba00da release-2026-09-19-3742b94c` by `kingofrock` on Sat Sep 19 22:59:42 2026 +0100. Operator cloned public bassclef himself for a prior test. Left behind. Class is narrow — real adopters rarely clone bassclef adjacent to their app repo.

### Filed five tickets

- **bassclef-cli#245** — fix: docker OAuth setup conflicts with Remote Control auth path
- **bassclef-cli#246** — feat: integrated probe channel between operator agent and cold-adopter profile
- **bassclef-cli#247** — fix(smoke-reset): detect adjacent stale bassclef checkout in host, docker, and one-shot flows
- **bassclef-upstream#1954** — fix(#1953): resolver Check 1 shadows npm install with stale ~/tmp/bassclef checkout
- **bassclef-upstream#1955** — feat: bassclef doctor — shared lib + skill + cli command for adopter settings.json cleanup

Cross-refs added: #246 depends on #245; #247 depends on #1954. Comment posted on #1954 linking #247 as cli-side defense in depth.

### Peer coordination via SendMessage

Three exchanges with bassclef-upstream-5c across the session:
1. Status update after Ticket 3 filing (probe outputs + evidence bundle)
2. Ticket 5 filing + log-on-skip amendment ask for #1954 filter-on-read
3. Provenance update — public bassclef clone, operator-authored, class narrow

Peer accepted #1954. Cure spec at bassclef-upstream: filter-on-read at merge (1c) + resolver precedence swap (1a) in one PR; sentinel version check (1b) deferred. Log-on-skip amendment landed as inline comment on #1954 with `BASSCLEF_HOOK_CONNECT_SKIP_WARN=N` threshold env. Peer will build fixture from #1954 as RED anchor next session.

## Decisions Made

- **File all four initial tickets rather than close as won't-fix.** Operator's judgment: filter-on-read is cheap defense that closes the class permanently, even though no real adopter has hit it in the field.
- **Add fifth ticket for doctor cleanup tool.** Existing residue in adopter settings.json still fires banners even after filter-on-read stops future phantoms. Shared lib at bassclef-upstream, two invocation surfaces (skill + cli command).
- **Fold log-on-skip observability into #1954 rather than new ticket.** Silent filter-on-read could mask real issues on unusual clones. Log every skip + warn on high count exposes bad merge sources.
- **Class named narrow, not urgent.** Provenance trace showed operator-authored stale dir. Real adopters unlikely to clone public bassclef adjacent to their app repo.

## Open Threads

### Cli-side pickup order (next session)

1. **bassclef-cli#247** (S estimate) — smoke-reset shadow detection at three call sites (host, docker, one-shot). Ships first as defensive layer.
2. **bassclef-cli#245** (M estimate) — OAuth vs Remote Control collision needs one diagnose session to name the exact overlap.
3. **bassclef-cli#246** (L estimate) — probe channel design pass. Wait until #245 clears so Remote Control candidacy is known.
4. **Cli wrapper for bassclef-upstream#1955** — waits on peer's shared lib to land. File as follow-on ticket at bassclef-cli when peer's lib ships.

### Peer waiting

- bassclef-upstream#1954 — peer builds fixture, ships resolver + filter-on-read PR
- bassclef-upstream#1955 — peer owns lib + skill; cli wrapper is follow-on

### Also observed but not filed

- `/onboard-repo` skill in cold-adopter session flagged `lib/ancestor-claude-check.sh` false-alarming on `$HOME/.claude`. Suggested treating it as a bug worth reporting. Not filed tonight — could go to bassclef-upstream if the operator wants.
- The 471.5k-char instruction budget warning is still present at every Claude open (bassclef-upstream#1952 open for the lite substrate rewrite).

## Key Files Changed

No repo file changes this session — pure diagnose + ticket filing. Working files in scratchpad:

- `/private/tmp/claude-501/.../scratchpad/ticket-1-body.md`
- `/private/tmp/claude-501/.../scratchpad/ticket-2-body.md`
- `/private/tmp/claude-501/.../scratchpad/ticket-3-body.md`
- `/private/tmp/claude-501/.../scratchpad/ticket-4-body.md`
- `/private/tmp/claude-501/.../scratchpad/ticket-5-body.md`

Session log (this file) and whereami update are the tracked changes at close.

## Gate Evidence

Diagnose session — no code changes, no temperance/verify markers written. Investigation traced root cause via probes; cure verified via manual `mv` + `init --force`. No fix code entered.

| Gate | Fired | Evidence | Outcome |
|------|-------|----------|---------|
| Temperance | n/a | No first-edit boundary crossed; diagnose + ticket filing only | N/A — no code change |
| Diagnosis | yes | Implicit through probes 1 + 2; root cause named at `~/tmp/bassclef` stale checkout shadowing npm install; cure verified | Root cause: resolver Check 1 precedence + additive merge with no phantom guard |
| Tests | n/a | No source under test this session | N/A — diagnose only |
| Verify | n/a | Cure verified by direct observation (BLOCKED banner count went to zero) | N/A — not a code branch |

### Gate skip justifications

All four gates carry valid n/a reasons — session was diagnose + ticket filing, no code changes. Per `.claude/rules/quick-fix-criteria.md` this is not a fix branch and per `.claude/rules/testing-tier-config.md` no source paths were touched.

## Promotable Patterns

- **Additive-merge phantom class** — any merge that copies entries by reference without checking target file presence accumulates residue when the source is wrong or partial. Cure pattern: filter-on-read at merge time + log-on-skip observability + a companion cleanup tool for existing residue. Worth surfacing as a design pattern for substrate systems that do additive settings.json merges. Already routed to bassclef-upstream via #1954 + #1955 — no separate /promote needed tonight since the tickets carry the pattern.

- **Zsh paste hazard on nested `$()`** — session lost several turns to zsh's paste-bracketed mode eating `$(dirname "$(readlink ...)")` and joining tokens. Existing memory `feedback_bash_paste_zsh_interactive_comments.md` covers the comment-line hazard; nested-substitution hazard is a sibling pattern worth adding to that memory. Not filed tonight — small addition, next session.
