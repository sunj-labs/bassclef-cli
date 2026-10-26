---
tier: upstream
type: risk-ledger
date: 2026-10-25
scope: cli#444 — --purge-adopter hard-stop on missing delete_repo scope
mode: light
lenses: [linus-torvalds, donald-norman, jerome-saltzer-and-michael-schroeder]
---

# Pre-mortem light — cli#444

Mode: light. Three lenses, 5-8 risks each. Imagine the fix shipped and the
next cold-adopter smoke went worse, not better. What happened?

## Lens 1 — Linus Torvalds (adopter contract)

| # | Risk | Fold or drop |
|---|---|---|
| L1 | Hard-stop fires for adopters who never asked to delete repos. `--delete-github` alone (no `--purge-adopter`) now blocks a run that used to work. | **Fold.** Gate the hard-stop on `DELETE_GITHUB=1`. That is the only path that calls delete. Adopters who pass neither flag see no change. |
| L2 | `--dry-run` starts exiting non-zero. Breaks the existing test and the "preview changes nothing" promise. | **Fold.** Dry-run prints the warning and the fix line, then still exits 0. Pin with a test. |
| L3 | A scope line that `gh` does not print is read as "scope missing", so the script hard-stops on a token that would have worked. | **Fold.** Fail soft. Only hard-stop when the scope line is present AND lacks `delete_repo`. Unparseable means proceed; the delete loop still catches a real failure. |
| L4 | Exit code 4 collides with a code the harness already means something by. | **Drop after check.** Script uses 1, 2, 3 today (`scripts/nuke-and-fresh-install.sh:91,99,232,281,370`). ADR-006's table governs `install-harness.sh`, a different script. 4 is free. |
| L5 | Non-scope delete failures (404, network) start hard-stopping too, so a repo someone else deleted blocks the whole run. | **Fold as a boundary.** Scope errors hard-stop. Other failures stay advisory, unchanged. State the line in the PR Out of scope. |
| L6 | Adopter on an older cached copy of the script sees none of this and reports the bug again. | **Drop.** The script is fetched by curl from `main` on every run. There is no cached copy. |

## Lens 2 — Donald Norman (signifier + feedback)

| # | Risk | Fold or drop |
|---|---|---|
| N1 | The message names the problem but not the cure, so the adopter still has to search. | **Fold.** Print `gh auth refresh -h github.com -s delete_repo` on its own line, copy-ready, no wrapping punctuation. |
| N2 | The message does not say what to do after refreshing. Adopter refreshes and stops. | **Fold.** Add a second line: re-run the same command. Name the flag they used. |
| N3 | Message lands in a wall of other stderr and gets missed. | **Fold.** Blank line above and below, plus a leading marker consistent with the existing `⚠` preflight block at line 190. |
| N4 | Adopter reads "scope" as a bassclef idea rather than a GitHub token setting. | **Fold.** Say "your GitHub token is missing the delete_repo permission". Plain words first, the literal scope name second. |
| N5 | Hard-stop feels like the script broke rather than protected them. | **Fold.** Say plainly that nothing was changed. That turns a dead end into a safe stop. |
| N6 | Dry-run warning reads identical to the live hard-stop, so the adopter cannot tell which happened. | **Fold.** Dry-run text says "would stop here". Live text says "stopping". |

## Lens 3 — Saltzer & Schroeder (fail-safe defaults)

| # | Risk | Fold or drop |
|---|---|---|
| S1 | Check runs at Step 3b, so `~/.claude` is already moved and npm already reinstalled before the stop. The adopter is left half-reset. | **Fold — this is the core of the fix.** Move the scope pre-check to the top, ahead of Step 1. A failed run changes nothing. |
| S2 | Check calls `gh` without confirming `gh` exists or is authenticated, so the script dies on an unbound command under `set -u`. | **Fold.** Guard with `command -v gh` and `gh auth status`, matching the existing preflight at line 189. |
| S3 | `gh auth status` writes the scope line to stderr on some versions and stdout on others, so parsing reads an empty string and the check silently never fires. | **Fold.** Capture both streams (`2>&1`). Pin the parse with a stubbed-`gh` test. |
| S4 | The scope check leaks the token into logs or stderr. | **Fold.** Parse only the scope list. Never echo the `gh auth status` body. |
| S5 | A test that runs the live path writes to the real `$HOME`. | **Fold.** Tests override `HOME` to a temp dir and stub `gh` on `PATH`. Assert the real `~/.claude` is untouched. |
| S6 | The delete loop's own scope check (Cure A) is skipped because the pre-check is assumed to have caught everything. A scope revoked mid-run goes unnoticed. | **Fold.** Ship both. Cure C up front, Cure A in the loop. cli#444 asks for the pair. |

## Folded into the plan

- Scope pre-check moves to the top, before any destructive step (S1).
- Gated on `DELETE_GITHUB=1` only (L1).
- Fails soft when the scope line is absent or unreadable (L3, S3).
- Guards on `gh` present and authenticated (S2).
- Dry-run warns and exits 0, with different wording from the live stop (L2, N6).
- Message carries the plain-English cause, the copy-ready fix command, the
  re-run instruction, and the "nothing changed" reassurance (N1, N2, N4, N5).
- Delete loop keeps its own scope-error hard-stop (S6).
- Exit code 4 (L4).
- Tests override `HOME` and stub `gh` (S5).

## Deliberate boundary

Non-scope delete failures stay advisory. Only scope errors hard-stop (L5).
This goes in the PR Out of scope section.
