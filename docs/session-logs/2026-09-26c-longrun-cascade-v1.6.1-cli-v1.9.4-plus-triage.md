---
session_id: 2026-09-26c
tier: lite
started_at: 2026-09-26T13:20Z
ended_at: 2026-09-26T14:35Z
mode: /longrun exploratory + agent-merges-within-scope
turn_count: ~90
outcome: shipped
---

# 2026-09-26c — /longrun cascade v1.6.1 → cli v1.9.4 + ticket triage + peer coord

## Flash

Triaged 3 stale tickets. Verified peer's #1954 cure landed. Cascaded bassclef v1.6.1 substrate into cli v1.9.4 npm release. Docker smoke ran clean at exit-3 with 2 assertion-drift fails filed as follow-on.

## What shipped

### Step b — triage sweep (closed with evidence)

- **#219** — bassclef v1.4.0 cascade rebuild request. Superseded by v1.5.0/v1.5.1/v1.5.2/v1.6.0 cascades. Closed with commit refs.
- **#217** — docker-smoke drive shape. Cure shipped via PR #218 (`d40f13d`) on 2026-09-22. Closed.
- **#227** — CLAUDE_CODE_OAUTH_TOKEN blocks /remote-control. Dup of #245 (closed by PR #249). Closed as not-planned.

### Step c — peer coord

- **bassclef-upstream#1954 — CLOSED.** PR #1956 shipped Layer 1a (resolver precedence swap) + Layer 1c (filter-on-read) + log-on-skip stderr. Merged 2026-09-26T11:47Z.
- **bassclef-upstream#1955 — still open.** Doctor tool for adopter residue; peer's next scope.

### Cascade — v1.6.1 → cli v1.9.4 (unplanned extension)

Peer sent tag confirmation at 13:15Z ("v1.6.1 released — please rebuild npm"). Operator authorized cascade + Touch ID at env gate.

**Shipped:**
- **PR #251** — cascade merge (publish.yml pin bump + version bump + CHANGELOG). Merged as `980dc6a`.
- **PR #252** — follow-on fix. Assertion at publish.yml L151-152 was hardcoded `v1.6.0`; PR #251 missed it. Merged as `e75a699`.
- **v1.9.4 published** to npm at 14:13:02Z with Sigstore transparency log 2968602066.
- **Docker smoke** on v1.9.4 exit 3 (expected-detection class; job passes) — 41 pass / 2 fail.

### Follow-on ticket

- **#253** — smoke assertions need update for v1.6.1 log-on-skip stderr + ACTIVE BET banner allowlist. Medium priority.

## Gate Evidence

| Gate | Marker | Notes |
|---|---|---|
| /temperance (session) | `state/markers/temperance/main-2026-09-26c.marker` | Scope: b then c |
| /temperance (cascade branch) | `state/markers/temperance/feat-cascade-v1.6.1-cli-v1.9.4.marker` | Cascade pattern application |
| /diagnose | fired mid-recovery | v1.9.4 tag pointed at wrong commit; auto-save race; force-moved tag |
| /verify | passed | 41/2 on smoke; test+typecheck GREEN on both PRs |
| /loop discipline | iteration 2 | PR #251 iteration 1 with defect; PR #252 iteration 2 fixed |

## Discovery — auto-save race with tag operations

Between the `gh pr merge` and `git tag` commands, an auto-save hook fired at 13:22:19Z on local main (kingofrock user), committing the preset marker. My `git tag v1.9.4` then tagged that auto-save commit instead of the merge commit. Publish workflow validated tag-vs-package.json and failed cleanly — the safety net worked.

**Cure:** always `git fetch origin && git reset --hard origin/main` between `gh pr merge` and any tag operation. Auto-save races on any timing window between the two.

**Candidate substrate change:** should the release cascade script pattern include an explicit sync step before tagging? Follow-on candidate; not filed this session.

## What worked

- **Pre-mortem assertion check saved us.** The Nygard N1 assertion at publish.yml L151 caught the mismatched pin. Prior cascade note said "9 sites" — proof the discipline compounds.
- **CDN poll pattern.** `until npm view @1.9.4 dist.tarball ...; do sleep 20; done` fired the smoke the moment the tarball resolved (14:16:08Z, ~3 min after publish). No fixed wait.
- **Peer coord tempo.** Peer sent cascade signal → cli responded within the same session → both sides shipped in one window.

## What didn't work

- **Bash chain broke silently.** First `git commit + push + gh pr create` chain on the fix PR fell through — commit didn't land, and I moved on. Had to re-check `git status` to diagnose. Cure: don't chain non-idempotent verbs with `&&` when the first can fail.
- **PR body scrub caught `load-bearing` on second draft.** Should have scrubbed the first draft with the wordlist before firing `gh pr create`. Cost one turn.

## Refs

- PR #251 (`980dc6a`) — cascade
- PR #252 (`e75a699`) — publish.yml assertion fix
- v1.9.4 tag → `e75a699`
- npm publish workflow run 36244993825 (success) + Sigstore log 2968602066
- Docker smoke run 36247931882 — 41/2 exit-3
- bassclef-upstream#1954 (closed by PR #1956); bassclef v1.6.1 at commit `972a2a48`
- #253 (filed this session — smoke assertion drift follow-on)
