---
tier: upstream
type: use-case
ceremony: brief
id: UC-script-444
title: Purge stops before it starts when the GitHub token cannot delete repos
closes_ticket: cli#444
scope_class: b
luminaries:
  primary: linus-torvalds
  supporting: [donald-norman, jerome-saltzer-and-michael-schroeder]
---

# UC-script-444 — purge stops before it starts when the token cannot delete repos

Brief ceremony per `.claude/rules/oo-ad-entry-point.md` — adopter-facing
script extension, one file plus its test.

## Primary actor

Cold adopter running `scripts/nuke-and-fresh-install.sh --purge-adopter`
to clear state from a prior smoke run.

## Stakeholders and interests

- **Cold adopter** — wants one command to reset everything. Needs to trust
  that "done" means done.
- **Operator** — runs smoke sessions. A half-reset wastes the session and
  surfaces as a fake `/onboard-repo` naming collision.
- **bassclef** — the flag name is a promise. Breaking it costs adopter trust.

## Preconditions

- `gh` is on `PATH` and authenticated.
- The adopter passed `--delete-github` or `--purge-adopter`.
- Prior test repos matching `*bassclef-smoke-test*` may or may not exist.

## Main success scenario

1. Adopter runs the script with `--purge-adopter`.
2. Script parses flags and sets `DELETE_GITHUB=1`, `AUTO_YES=1`.
3. Script checks whether the gh token carries the `delete_repo` permission,
   before any step that changes state.
4. Token carries the permission.
5. Script proceeds: backs up `~/.claude`, reinstalls the cli, deletes the
   matching GitHub repos, purges the workdir, runs `bassclef init`.
6. Script reports the installed version and exits 0.

## Extensions

**3a — token is missing the `delete_repo` permission (live run).**
Script prints the plain-English cause, the exact `gh auth refresh` command,
and the instruction to re-run. Script states that nothing was changed.
Script exits 4. No backup is taken. No package is installed or removed.
No repo is deleted. No workdir is touched.

**3b — token is missing the permission (`--dry-run`).**
Script prints the same cause and fix command, worded as "would stop here".
Script finishes printing the planned steps and exits 0. Dry-run keeps its
promise that a preview changes nothing and reports success.

**3c — `gh` is absent or not authenticated.**
Scope pre-check skips. Existing behavior holds — the delete block already
guards on `gh auth status` and reports a skip.

**3d — the permission list cannot be read.**
Some auth types print no scope line. The pre-check treats an unreadable
list as "cannot tell" and proceeds. The delete loop still catches a real
failure at extension 5a.

**5a — a delete call fails with a scope error mid-run.**
A permission revoked after the pre-check passed. Script prints the same
cause and fix command and exits 4 on the first such failure, rather than
looping through the remaining repos and reporting success.

**5b — a delete call fails for any other reason.**
Out of scope for this change. Script keeps the current advisory message
and continues. A repo deleted by someone else should not block the run.

## Postconditions

- **Success** — every matching repo is gone, state is reset, exit 0.
- **Permission missing, live** — nothing changed, exit 4, the fix command
  is on screen.
- **Permission missing, dry-run** — nothing changed, exit 0, the fix
  command is on screen.

Stated as a contract: the script never reaches a destructive step while a
known permission gap would stop the purge from completing.

## Why exit 4

The script already uses 1 for argument errors, 2 for a failed npm install,
and 3 for a failed `bassclef init` (`scripts/nuke-and-fresh-install.sh`
lines 91, 99, 232, 281, 370). ADR-006's exit-code table governs
`scripts/install-harness.sh`, a different script. 4 is the next free code
here.

## Refs

- cli#444 — ticket, with the cold-adopter transcript from 2026-10-18
- cli#434 — sister, added the preflight warning for the no-cleanup path
- `docs/risk-ledgers/2026-10-25-cli-444-purge-adopter-scope-hardstop.md`
- `docs/use-cases/UC-script-nuke-and-fresh-install.md` — the script's base contract
- `docs/adrs/ADR-006-install-harness.md` — exit-code precedent
- @luminary linus-torvalds — lead. The flag name is a promise.
- @luminary donald-norman — the message carries the cure, not just the fault.
- @luminary jerome-saltzer-and-michael-schroeder — check before you destroy.
