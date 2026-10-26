---
tier: upstream
type: risk-ledger
date: 2026-10-26
scope: cli#453 — scripts/audit-skill-reader-prose.sh
mode: light
lenses: [alan-cooper, michael-feathers, michael-nygard]
---

# Pre-mortem light — the audit script

Imagine the script shipped and the sweep of the remaining 59 skills went
badly. What happened?

## Lens 1 — Alan Cooper (does the output serve the reader)

| # | Risk | Fold or drop |
|---|---|---|
| C1 | 129 lines of output buries the two findings that matter. | **Fold.** Sort worst-first and print a per-pattern count at the end. Done. |
| C2 | Output names the fault and not the fix, so the reader has to work out what to do. | **Fold.** Tail line names the cheapest fix and the repo where fixes land. Done. |
| C3 | Someone reads the inflated P2 count as 77 real problems and spends a day on it. | **Fold.** The audit says plainly why the number is inflated. Risk remains if the script runs without the audit at hand — accepted, since the tail line points at P1 first. |
| C4 | A reader runs it against the wrong directory and trusts a clean result. | **Fold.** Default is the assembled package. Exit 2 with the reason when the directory is missing. Done. |
| C5 | 300 lines is arbitrary and flags a skill that reads fine. | **Fold.** `LONG_SKILL_LINES` is an environment variable, so the threshold is tunable without editing the script. |

## Lens 2 — Michael Feathers (does it pin real behavior)

| # | Risk | Fold or drop |
|---|---|---|
| F1 | Counts drift as skills change and nobody notices the script broke. | **Partly fold.** The audit records today's numbers, so a future run can be compared. No test pins them — noted below as a gap. |
| F2 | The verb list in P3 flags prose that legitimately addresses the reader. | **Fold.** Shipped as a warning with that limit stated in the audit, not as a gate. |
| F3 | Stripping inline backticks hides a real finding sitting inside code spans. | **Fold as a boundary.** Matches how the existing prose hooks treat backticks. Stated in the use case. |
| F4 | No test file, so a later edit silently changes what it reports. | **Accepted gap.** `scripts/*.sh` is Tier 1 per testing-tier-config, so a warning rather than a block. Exit codes 0, 1, and 2 were each exercised by hand before commit. A test belongs with the sweep ticket. |
| F5 | The fold heading gets renamed upstream and every skill reads as unfolded. | **Fold.** Would show as a sudden jump to 73 P1 findings, which is loud rather than silent. |

## Lens 3 — Michael Nygard (fail-soft)

| # | Risk | Fold or drop |
|---|---|---|
| N1 | A missing skills directory throws a stack trace instead of saying what to do. | **Fold.** Guarded, exit 2, names the build script and the override. Done. |
| N2 | A glob matching nothing silently reports clean. | **Fold.** `nullglob` plus an empty-array check, exit 2. Done. |
| N3 | A file that is not UTF-8 crashes the read mid-sweep. | **Partly fold.** Read is explicitly UTF-8. A malformed file still raises. Acceptable for a read-only operator script; it fails loudly rather than reporting a false clean. |
| N4 | `python3` absent, so the script dies with a confusing shell error. | **Accepted.** Every other script in this repo assumes `python3` or `node`. Out of scope to solve here. |
| N5 | The script writes somewhere by accident. | **Dropped after check.** It only reads and prints. No redirect, no write call. |

## Folded into the plan

Sorted output with counts · fix named in the tail line · default to the
assembled package · exit 2 with a reason when there is nothing to read ·
tunable threshold · P3 shipped as a warning · boundary limits written into
the use case.

## Accepted gaps

- No test file (F4). Tier 1 path, exit codes checked by hand, test belongs
  with the sweep ticket.
- Counts are recorded in the audit but not pinned by a test (F1).
