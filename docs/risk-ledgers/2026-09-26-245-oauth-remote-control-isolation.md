---
tier: project
title: Pre-mortem light — cli#245 OAuth vs Remote Control isolation
date: 2026-09-26
shape: light
lenses: [donald-norman, michael-nygard]
folded: [N1, S2]
goal_id: 2026-09-26-245-oauth-remote-control-isolation
---

# Pre-mortem light — cli#245 OAuth vs Remote Control isolation

## Lens 1 — Donald Norman (signifiers + feedback loops)

- **N1** — File-fallback fires but log line says only `V2 auth via CLAUDE_CODE_OAUTH_TOKEN (Claude subscription)`. Adopter cannot tell whether token came from env var or file. Debug pain later.
- **N2** — Runbook Path 1 section names the file location but not the `CLAUDE_OAUTH_TOKEN_FILE` env var. Adopter with custom path has no signifier for the override.
- **N3** — Missing-both error message names two paths but not the new file path. Adopter following current runbook then hitting new error sees outdated remediation.
- **N4** — Docker workflow yaml unchanged. Adopters reading it as a template do not see the file mount pattern.
- **N5** — Runbook first section (invocation contract) does not signal that Path 1 is preferred for `/remote-control` users.

## Lens 2 — Michael Nygard (stability + fail-soft)

- **S1** — File present but empty (0 bytes) — token export succeeds with empty string; container preflight passes; downstream `claude` call fails cryptically.
- **S2** — File unreadable (chmod 000 or wrong owner) — bash `$(cat ...)` emits stderr but returns empty; same class as S1.
- **S3** — File has trailing newline — token embeds newline; downstream API call fails with malformed auth header.
- **S4** — CLAUDE_OAUTH_TOKEN_FILE env var points at a directory not a file — `cat` on a directory fails; container preflight fails cryptically.
- **S5** — Adopter has BOTH env var AND file set to different tokens — env var wins per design; adopter may assume file wins.

## Top-2 folds

- **N1 folded into UC Postconditions** — file-fallback log line names the exact source path. `INFO: loaded CLAUDE_CODE_OAUTH_TOKEN from ${token_file} (V2 file-fallback per cli#227)`. Reader knows env vs file at a glance.

- **S2 folded into UC Extensions 6c + 6d** — unreadable OR empty file treated as absent. Preflight_v2 falls through to the standard env-missing error path with the three original remediation options. Fail-loud on real absence; fail-soft on ambiguous file state.

## Deferred (not folded this ship)

- **N2** custom-path signifier — add to runbook Path 1 section but no code change.
- **N3** error-message update — add file path to remediation lines in preflight_v2 error path.
- **N4** workflow yaml — CI docker workflow keeps env-var path; no adopter template value.
- **N5** invocation contract — keep first-section framing at env var; Path 1 lives in its own section.
- **S3** trailing newline — cure inline via `tr -d '\n\r '` around the cat output.
- **S4** dir at file path — S2 fold catches via readability + empty check.
- **S5** conflicting env + file — env wins by design per backward compat; document explicitly.

## References

- Ticket: `bassclef-cli#245` + `#227`
- UC: `docs/use-cases/UC-245-oauth-token-file-fallback.md`
- Diagnosis: `state/markers/diagnose/fix-245-oauth-remote-control-isolation.marker`
