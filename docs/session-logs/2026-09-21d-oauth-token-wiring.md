---
tier: standard
session_id: 2026-09-21d-oauth-token-wiring
project: bassclef-cli
agent: personal
status: completed
tags: [oauth-token, ticket-184, pr-204, subscription-billing, docker-harness]
started_at: 2026-09-21T22:00:00Z
ended_at: 2026-09-21T23:22:00Z
duration_minutes: ~80
turns: ~35
closes: [184]
---

# Session: ticket #184 — wire CLAUDE_CODE_OAUTH_TOKEN into Docker harness

## Entry state

Session opened as `/longrun prep` in the parent conversation. Earlier turns shipped PR #196 (Epic #194 Stories 1-3) and PR #200 (Epic #199 Story 1). Post-compaction, operator asked to close ticket #184 — wire the Claude subscription OAuth token alongside `ANTHROPIC_API_KEY` so Docker harness runs bill against the subscription, not the metered API.

## Work done

- Extended `harness/docker/entry.sh` `_docker_harness_preflight_v2` to accept either `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`. When both are set, unset `ANTHROPIC_API_KEY` so `claude` routes to the subscription per `claude config list` precedence.
- Added 2 new Tier 0 tests (`test_v2_preflight_oauth_only_passes` + `test_v2_preflight_prefers_oauth_when_both_set`). Full suite 27/27 GREEN.
- Extended `.github/workflows/docker-smoke.yml` to pass `CLAUDE_CODE_OAUTH_TOKEN` from GitHub secret.
- Updated `docs/runbook/docker-smoke.md` with Path A (OAuth/subscription) + Path B (metered API key) + both-set behavior + CI secret setup.
- PR #204 merged to main as squash commit `1cdce70` after both CI checks GREEN.
- OAuth verified end-to-end via `claude -p "say hello in 3 words"` inside the container with `ANTHROPIC_API_KEY=""` empty. Returned `Hi there, friend!` cleanly.

## Decisions

- Prefer OAuth over API key in the preflight when both are present. The unset-and-route pattern comes from `claude config list` precedence rules; the alternative would be requiring adopters to unset API key at the shell layer, which is fragile.
- Defer `/riff` end-to-end HTML verification. OAuth authentication was proven with the hello test in ~2 seconds. The 120-second silence on `claude -p "/riff ..."` from the earlier verify script was `/riff` doing real work across 5 sub-calls, not auth failing. `/riff` HTML output belongs to Epic #199 continuation, not to this ticket.
- Hold local main sync. Local has 3 auto-save checkpoints on top of what shipped in #204. Content is superseded WIP. Operator to decide reset vs rebase vs leave in the next session.

## Open threads

- PR #203 (`feat/199-riff-chain-semantics`) still OPEN. Both CI checks GREEN but mergeable UNKNOWN (GitHub recomputing after #204 landed). Held for operator review.
- Local main has 3 auto-save checkpoints (`f70e465`, `e443014`, `ec1f2f9`) that predate PR #204's final content. Discardable but needs explicit operator OK per `.claude/rules/destructive-operations.md`.
- Epic #199 Story 2+ still open. `/riff` HTML output through the docker harness has not been proven end-to-end. Wait for the API cap reset (2026-10-01) or fresh time budget.
- Ticket #184 closes with this PR.

## Key files changed

- `harness/docker/entry.sh` — V2 preflight accepts OAuth
- `.github/workflows/docker-smoke.yml` — pass OAuth token from secret
- `docs/runbook/docker-smoke.md` — auth paths documented
- `.claude/hooks/tests/docker-harness-entry.test.sh` — 2 new tests
- `state/markers/{temperance,luminary,adr-deviation}/feat-184-oauth-token.marker` — ceremony markers per bassclef discipline

## Gate evidence

- /temperance fired at scope-decision boundary — marker at `state/markers/temperance/feat-184-oauth-token.marker`
- /luminary primary lens `linus-torvalds` (adopter compatibility); supporting `[saltzer-schroeder, kent-beck]`
- /loop iteration_count 1 — single RED → GREEN cycle
- Tier 0 tests: 27/27 GREEN (25 prior + 2 new)

## Next-session prep

Operator asked to prep for a new session going after v1.2.0 (bassclef substrate v1.2.0 released 2026-09-21). See `docs/next-session-plan-2026-09-22-bassclef-v1.2.0-sync.md`.
