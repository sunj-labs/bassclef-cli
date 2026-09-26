---
date: 2026-09-26
session_start: 2026-09-26T10:23Z
session_end: 2026-09-26T12:15Z
duration_minutes: ~115
mode: longrun / operator-gated with agent-merges-within-scope
tier: standard
goals_shipped: [cli#247, cli#245, cli#227 dup, harness-test-isolation]
prs_merged: [248, 249, 250]
tickets_closed: [247, 245, 227]
---

# Session log — 2026-09-26b — /longrun shadow + OAuth file-fallback + Remote Control fix

## Value

Two harness gaps closed and one adopter workflow unblocked in one session. Cold-adopter smoke on the operator's Mac now refuses when a stale `bassclef` sits next to the workdir. Docker smoke reads the OAuth token from a file so shell env stays clean. Operator's local Remote Control works again on the Max plan.

## Openings — three-block per operator-facing-prose Rule 3

**Problem (via /state-a-problem brief):** Peer bassclef-upstream-5c handed back three cli-side tickets after the 2026-09-26 cold-adopter probes. Adopters running the smoke chain hit silent settings.json corruption when a stale bassclef checkout shadowed the npm install. Docker harness needed a way to read the OAuth token without forcing the operator to break Remote Control by exporting the token globally.

**Value prop (via /value-prop tweet):** Shipped defense-in-depth against the shadow class + file-fallback that isolates docker smoke from interactive Claude Code auth. Both cures ship in v1.6.0 substrate. Adopters no longer choose between docker smoke and Remote Control.

**Evidence:** whereami L23 operator_recap 2026-09-26 named the pickup order. Ticket #247 body specified the three call sites. Ticket #227 body carried the canonical file-scoped acceptance for #245's duplicate class.

## Work done

### Goal 1 — cli#247 adjacent-shadow detection (PR #248 → 5d9adf7)

Ships one shared function at `scripts/lib/shadow-detection.sh`. Wired at `scripts/smoke-reset.sh` Step 0 before uninstall and at `harness/docker/entry.sh` main() Action 1b before install. `smoke-one-shot.sh` inherits via `smoke-reset --cold` call path.

Full class-b OOAD chain fired end-to-end — brief use case + luminary consult (Torvalds lead + Beck supporting) + pre-mortem light (Norman + Nygard × 5 risks each; N2 + S1 folded) + Beck TDD RED-first + integration test + /verify + PR + merge. 11/11 Tier 0 GREEN.

CI failed first pass — path-resolution issue inside the container. Root cause named in one turn — entry.sh at `/adopter/entry.sh` resolved `_docker_harness_repo_root` to `/` (going up two dirs). Cured via SMOKE_SCRIPTS_DIR env var with fallback. CI green second pass.

### Goal 2 — cli#245 + cli#227 OAuth token file-fallback (PR #249 → 377799d)

`_docker_harness_preflight_v2` now reads token from `${CLAUDE_OAUTH_TOKEN_FILE:-$HOME/.config/claude/oauth-token}` when env is empty. Env var wins when both are set. Empty or unreadable file falls through to the env-missing error path.

Full class-b chain — Cooper lead (persona lens — two workflows want to run at once) + Beck supporting + pre-mortem light (Norman + Nygard, N1 + S2 folded) + Beck RED-first (2 of 5 new tests failed as expected) + Beck GREEN (35/35). Runbook amended with "Auth-path bifurcation" section covering Path 1 (file-scoped) + Path 2 (direnv-scoped).

Closes both #245 (parent, M scope) and #227 (canonical, S scope, filed 2 days earlier as duplicate class).

### Goal 3 — Test isolation from file-fallback (PR #250 → merged 12:13:10Z)

Small fix. Two existing tests unset ANTHROPIC_API_KEY + CLAUDE_CODE_OAUTH_TOKEN expecting EXIT_ENV_MISSING. The file-fallback loaded the token from operator's newly-saved `~/.config/claude/oauth-token`. Tests got 0 not 25.

Cured — both tests set `CLAUDE_OAUTH_TOKEN_FILE=/dev/null` inside their `bash -c` blocks. Test-only. No runtime change. 35/35 GREEN. Test+typecheck CI passed; docker-smoke skipped by path filter.

### Bonus — Remote Control auth path unblocked

Diagnose chain surfaced two env exports blocking `/remote-control` on operator's Mac Max plan.

`ANTHROPIC_API_KEY` was exported at shell-start from `~/.config/bassclef/secrets.env` L1 + `~/.config/bassclef/claude-route.env` L2. Removed `export` keyword in both files. Variable still readable by `claude-ant` shell function; plain `claude` no longer inherits.

`CLAUDE_CODE_OAUTH_TOKEN` was exported at `~/.zshrc` L196. Commented out. Token now lives at `~/.config/claude/oauth-token` per PR #249 setup.

Operator verified — fresh shell, `claude` header shows `Claude Max`, `/remote-control` armed with live URL. Save-token-then-login order preserved the docker-smoke path.

## Numbers

- 4 PRs merged (#248, #249, #250 — plus #242 smoke-one-shot merged at session start)
- 3 tickets closed (#247, #245, #227)
- 35/35 docker-harness Tier 0 tests GREEN
- 11/11 shadow-detection Tier 0 tests GREEN
- ~140 turns end-to-end
- 2 personal shell config files edited to unblock operator workflow

## Discoveries

- **Claude Code Mac auth reads Keychain first + env var second.** Header shows `Claude Max` only when neither long-lived token is present.
- **CLAUDE_OAUTH_TOKEN_FILE env var is a useful test isolation lever** — set it to `/dev/null` in tests to bypass file-fallback without needing HOME override.
- **`security find-generic-password -s 'Claude Code-credentials' -w`** returns the raw Keychain blob; the accessToken sits inside a `claudeAiOauth` JSON object.

## Follow-ons

- **Bassclef substrate ticket:** `/secrets-bootstrap` writes exports at shell-start. That breaks Remote Control for every adopter with the pattern. Worth filing at bassclef-upstream. Not this session.
- **cli#246 (integrated probe channel, L scope)** deferred to a future session.
- **Release cascade** ready to fire once operator names the upstream version to pin.

## Gate evidence

- /temperance markers — 3 (one per branch), populated per marker-enrichment discipline
- /luminary markers — 3, each names lead + supporting + Peirce alternatives
- /pre-mortem markers — 2 (goals 1 and 2; skipped on the trivial test fix)
- /adr-deviation markers — 3, all ADR-honored outcomes
- /diagnose markers — 3, full Is/Is-Not + Five Whys + Hypothesis chains
- /lead-lens-signoff markers — 2 (goals 1 and 2)
- /loop markers — 2 (both iteration_count 1, GREEN)
- /verify — ran on all 3 branches via pre-commit gate
- CI — pr-checks GREEN on all 3; docker-smoke GREEN on 2 (skipped on test-only PR by path filter)

## Session ends here

Operator will exit + restart to activate the shell env changes globally. Next session opens with:
- Clean env (no ANTHROPIC_API_KEY, no CLAUDE_CODE_OAUTH_TOKEN exported)
- Remote Control armed on Max plan
- Docker smoke reads token from file per PR #249
- Ready for release cascade when upstream ships next version
