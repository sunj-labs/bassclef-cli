---
id: UC-script-cli-380-refresh-oauth-token
title: Refresh OAuth token for docker harness
format: brief (Cockburn)
tier: standard
primary_actor: operator (on host Mac)
ticket: cli#380
luminaries:
  lead: saltzer-schroeder
  supporting: [tony-hoare, alan-cooper, michael-feathers]
---

# UC — Refresh OAuth token for docker harness

## Primary actor

Operator on host Mac. May run from a terminal pane or dispatched via future
cloud container (TBD; non-interactive variant is out of scope for V1).

## Preconditions

- `claude` CLI on PATH
- Operator subscription-authenticated on host (host claude works)
- Write permission on target file path (default `~/.config/claude/oauth-token`)

## Postcondition on success

- Target file carries a fresh OAuth token verified by a probe
- Old file backed up to `<path>.bak-<timestamp>`
- File mode is 600 (owner read/write only)
- stdout reports PASS; exit 0

## Postcondition on failure

- Target file UNCHANGED (atomic contract — write only on probe PASS)
- If backup was taken but probe failed, backup restored OR left in place
- stderr names what failed
- exit non-zero per code vocabulary

## Main success scenario

1. Operator runs `bash scripts/refresh-oauth-token.sh`
2. Script checks `claude` on PATH; checks target dir writable
3. Script backs up current file (if present) to `.bak-<ISO-timestamp>`
4. Script fires `claude setup-token`; captures stdout + stderr
5. Browser opens; operator authenticates; token prints to captured stream
6. Script extracts token via regex `sk-ant-oat01-[A-Za-z0-9_-]+`
7. Script length-checks token (100-110 byte window)
8. Script probes new token via isolated env + `claude -p "say hello"`
9. Probe PASS → script atomic-writes token to target path + chmod 600
10. Script reports PASS to stdout; exits 0

## Extensions

**2a. claude missing on PATH:** script exits 3 with stderr `claude binary not on PATH; refresh needs the claude CLI`

**2b. Target dir not writable:** script exits 3 with stderr naming the dir + perm error

**4a. setup-token exits non-zero:** script exits 1 with stderr `claude setup-token failed; see output above`

**6a. No token matched in captured output:** script exits 1 with stderr `could not extract OAuth token from setup-token output`

**7a. Token length outside 100-110 byte window:** script exits 1 with stderr naming the length; may indicate truncation OR schema change

**8a. Probe returns 401 or non-zero:** script exits 2 with stderr `new token failed probe; file unchanged. Check subscription state and retry.`

**9a. Atomic write fails (disk full, perm change):** script exits 2 with stderr; backup restored

## Variations (CLI flags)

- `--file PATH` — override target path (default `~/.config/claude/oauth-token`)
- `--dry-run` — show plan + skip write; exit 0 after plan report
- `--verify-only` — probe current file content; no refresh fires; exit 0 on PASS, exit 2 on FAIL
- `--no-backup` — skip backup step (operator takes risk)

## Related

- cli#245 — OAuth file-fallback shipped in docker harness
- Memory `feedback_oauth_verify_via_cheap_hello.md` — probe pattern
- Memory `feedback_never_paste_credentials_in_session.md` — refresh happens outside Claude Code session
- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD applies
- `.claude/rules/oo-ad-entry-point.md` — brief UC per ceremony matrix (adopter-facing script row)

## Non-goals

- NOT: cloud-hosted non-interactive refresh (separate ticket)
- NOT: service-account auth via `OP_SERVICE_ACCOUNT_TOKEN` or ANTHROPIC_API_KEY
- NOT: Keychain integration
