---
id: risk-ledger-2026-10-06-cli-380-refresh-oauth-token
title: Pre-mortem light — scripts/refresh-oauth-token.sh
mode: light (per /pre-mortem SKILL — 3 lenses × 5 risks per lens, 30 min)
ticket: cli#380
luminaries: [saltzer-schroeder, tony-hoare, alan-cooper]
---

# Pre-mortem light — cli#380 refresh-oauth-token.sh

## Imagine failure: the script shipped, operator ran it, things broke. What happened?

### Lens 1: Saltzer-Schroeder (fail-safe defaults + least authority)

- **R1. Half-written token file.** Script wrote partial content on disk full OR crashed mid-write. Docker harness reads garbage, 401s on every run. Fold: atomic write via `mktemp + mv` same filesystem; never truncate target directly.
- **R2. Backup clobbered on second run.** Operator ran script twice; first run wrote `.bak`; second run also wrote `.bak`; first backup lost. Fold: timestamp the backup (`.bak-<ISO>`), never overwrite.
- **R3. Chmod race.** New file created at umask 022 (world-readable); chmod 600 fires after; brief window of exposure. Fold: `umask 077` at script start; or `install -m 600` for atomic create-with-mode.
- **R4. Token extracted from setup-token output includes trailing garbage.** Regex matches token + accidentally captures following text (e.g., newline + help message). Fold: anchor regex to word boundary; validate length; test against mocked output with trailing content.
- **R5. Probe uses stale env.** `env -i HOME=$HOME PATH=$PATH CLAUDE_CODE_OAUTH_TOKEN=<new> claude -p "hello"` leaks host Keychain via `HOME`; false pass. Fold: run probe in temporary `HOME` (mktemp dir); confirms the token alone works.

### Lens 2: Hoare (pre/postcondition contracts)

- **R6. Precondition skipped — claude missing.** Script fires setup-token without PATH check; cryptic shell error, no actionable message. Fold: `command -v claude` first thing in main; exit 3 with named error.
- **R7. Postcondition unverified.** Script claims PASS without probe. Operator believes refresh worked; docker still 401s. Fold: probe is MANDATORY; no `--skip-probe` flag; exit path requires probe PASS.
- **R8. Rollback invariant broken.** Probe fails mid-way; script writes new file anyway because rollback branch has a bug. Fold: write operation ONLY in the probe-PASS branch; rollback branch has NO write; Tier 0 test covers this exact path.
- **R9. --verify-only + --dry-run conflict.** Both flags set; script does half of each. Fold: mutually exclusive; conflict exits 3 with clear message; Tier 0 test covers.
- **R10. Length check too tight.** New Anthropic token shape ships 112 bytes; script rejects as "too long"; operator stuck. Fold: window is 90-120 bytes (loose but non-zero); doc the window; log warning if drift beyond ±5%.

### Lens 3: Cooper (operator ergonomics)

- **R11. Operator runs script expecting silent success; browser opens surprisingly.** Confusion if operator forgot setup-token is interactive. Fold: stdout banner before setup-token fires: "Browser will open for OAuth. Follow prompts; return here."
- **R12. Error messages assume substrate knowledge.** "cli#380 R6" surfaces to operator; meaningless. Fold: error messages name the actual problem + the fix command, not ticket refs.
- **R13. Operator cancels mid-flow.** Ctrl-C during setup-token leaves temp files + partial backup. Fold: trap EXIT fires cleanup; backup rename happens AFTER probe PASS, not before setup-token.
- **R14. --dry-run output lies.** Says "would write X bytes" but actual run would fail precondition. Fold: dry-run runs ALL preconditions + prints findings; only skips the write + probe.
- **R15. --help output is unmaintained.** Script evolves; help text drifts. Fold: generate help from header comment block (sed on `# tier:` ... `# ----` boundary); single source of truth.

## Pre-code folds applied

- R1 → atomic write via mktemp + mv
- R2 → timestamp backups
- R3 → `umask 077` at script start AND `install -m 600`
- R4 → regex anchor + length check as backstop
- R5 → probe in isolated HOME (mktemp dir)
- R6 → `command -v claude` early precondition
- R7 → probe mandatory; no skip
- R8 → Tier 0 test pinning "probe-fail does not write"
- R9 → mutually-exclusive flag check
- R10 → 90-120 byte window; warning on drift
- R11 → stdout banner before setup-token
- R12 → operator-plain error messages
- R13 → trap EXIT cleanup; backup after PASS
- R14 → dry-run runs preconditions
- R15 → help from header comment

## Deferred to follow-on

- R10 → monitor actual token shape over time; may need envelope widening in future
- Cloud non-interactive refresh variant → separate ticket (per cli#380 Non-goals)
