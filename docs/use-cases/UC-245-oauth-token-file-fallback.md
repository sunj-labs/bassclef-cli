---
tier: project
title: UC-245 — OAuth token file-fallback in docker preflight_v2
id: UC-245-oauth-token-file-fallback
date: 2026-09-26
level: subfunction
scope: harness/docker/entry.sh preflight_v2 + docs/runbook/docker-smoke.md
goal_id: 2026-09-26-245-oauth-remote-control-isolation
status: draft
shape: brief
references:
  - path: state/markers/diagnose/fix-245-oauth-remote-control-isolation.marker
    role: full Is/Is-Not + Five Whys + Hypothesis chain
  - path: docs/risk-ledgers/2026-09-26-245-oauth-remote-control-isolation.md
    role: pre-mortem light — Norman + Nygard × 5 risks
  - id: bassclef-cli#245
    role: parent ticket (M scope, diagnosis-first)
  - id: bassclef-cli#227
    role: canonical fix ticket (S scope, file-scoped or direnv paths) — duplicate class
---

# UC-245 — OAuth token file-fallback in docker preflight_v2

## Sources read

- `state/markers/diagnose/fix-245-oauth-remote-control-isolation.marker` — collision named at env var slot; Path 1 file-scoped isolates both consumers.
- `bassclef-cli#227` body — canonical acceptance: file-scoped token at `~/.config/claude/oauth-token` + optional native harness read when env var absent.
- `harness/docker/entry.sh` L116-143 — current `_docker_harness_preflight_v2` handles env-var-only.
- `docs/runbook/docker-smoke.md` L36, L75 — current recommendation exports `CLAUDE_CODE_OAUTH_TOKEN` in shell profile.

## Why this UC exists

Per `.claude/rules/oo-ad-entry-point.md` matrix — existing-script extension needs a brief use case. This UC covers extending preflight_v2 with a file-fallback branch plus documenting the two isolation paths in the runbook.

## Actors

- Operator running docker cold-adopter harness locally on their Mac + using `/remote-control` in interactive Claude Code.
- CI docker workflow (GitHub Actions) — env var stays load-bearing there; file-fallback does not fire.

## Preconditions

- Bash environment supports `[[ -r ]]` file readability test.
- Adopter has run `claude setup-token` once and stored the resulting token.
- Adopter chose Path 1 (file) OR Path 2 (direnv) — not global `~/.zshrc` export.

## Main scenario (compressed — Path 1 file-scoped)

1. Adopter runs `claude setup-token` → produces long-lived token.
2. Adopter writes token to `~/.config/claude/oauth-token` with `chmod 600`.
3. Adopter mounts `~/.config/claude` into the container OR sets `CLAUDE_OAUTH_TOKEN_FILE` env when running the container.
4. Container starts; `_docker_harness_preflight_v2` fires.
5. Function checks `CLAUDE_CODE_OAUTH_TOKEN` env → absent.
6. Function checks `CLAUDE_OAUTH_TOKEN_FILE` (default `$HOME/.config/claude/oauth-token`) → readable.
7. Function loads token from file, exports `CLAUDE_CODE_OAUTH_TOKEN` for downstream `claude` calls.
8. Log line names the source: `INFO: loaded CLAUDE_CODE_OAUTH_TOKEN from <path> (V2 file-fallback per cli#227)`.
9. Preflight returns 0; container proceeds to install + smoke.

Meanwhile on the host, `CLAUDE_CODE_OAUTH_TOKEN` env var is UNSET in shell, so interactive Claude Code sees no long-lived token and `/remote-control` arms cleanly.

## Extensions

- **6a. Both env var AND file present** — env var wins (backward compat; no behavior change from today).
- **6b. Env var absent AND file absent** — return `EXIT_ENV_MISSING` (25) as today.
- **6c. File present but unreadable** (`chmod 000`) — treat as absent; log a warning naming the readability failure.
- **6d. File present but empty or whitespace-only** — treat as absent; log a warning.

## Postconditions

- **Env var set** → token used from env; log line names `V2 auth via CLAUDE_CODE_OAUTH_TOKEN (Claude subscription)`.
- **File-fallback fires** → token exported from file; log line names the file path.
- **Neither set** → return 25; log names both remediation paths (env export OR file at default path).

## Pre-mortem folds baked in

- **N1** (Norman — signifier discipline): file-fallback log line names the exact source path. Adopter can act without reading the source.
- **S2** (Nygard — fail-soft on read failure): unreadable OR empty file treated as absent; original env-missing error path fires with same three remediation options.

## References

- Ticket: `bassclef-cli#245` (parent) + `#227` (duplicate, closing both).
- Runbook: `docs/runbook/docker-smoke.md` — new "Auth-path bifurcation" section.
- Diagnosis: `state/markers/diagnose/fix-245-oauth-remote-control-isolation.marker`.
- Risk ledger: `docs/risk-ledgers/2026-09-26-245-oauth-remote-control-isolation.md`.
