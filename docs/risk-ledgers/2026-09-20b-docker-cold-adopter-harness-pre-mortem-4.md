---
tier: operator-private
authored: 2026-09-20
session_id: 2026-09-20b
mode: pre-mortem-light
handoff: testing-to-delivery
parent_goal: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
lenses:
  - linus-torvalds
  - michael-nygard
  - michael-feathers
---

# Pre-mortem light — Handoff 4 (Testing → Delivery)

Klein workshop shape. 3 lenses. 5 risks per lens. Focused on PR + merge risks.

## Sources read

- All prior artifacts (goal doc, 3 pre-mortem ledgers, 3 RFCs, UC, decomposition, live-run evidence)
- Step 7 finding: cli 1.2.1 exits 0 in cold Docker. Two-way verification concurs.
- `.claude/rules/pr-body-shape.md` — required PR body shape
- `.claude/rules/reviewer-dispatch.md` — reviewer discipline

## Linus — adopter contract

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| DL1 | PR bundles cherry-picked `smoke-assert-settings-hooks.sh` from PR #161; creates a duplicate commit if PR #161 also merges | 🟡 med | Note in PR body that this branch inherits the script; if PR #161 merges first, this branch rebases cleanly (no conflict) |
| DL2 | Cli 1.2.1 users see a new `harness/docker/` folder they may not want; adds ~30 lines to their tarball | 🟢 low | The tarball published to npm excludes `harness/` per package.json `files` array (verify at merge time) |
| DL3 | Runbook cites env vars adopters may not have; frustrates first-run experience | 🟢 low | Runbook front matter walks 3-check preflight with remediation per failure |

## Nygard — stability

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| DN1 | GHA workflow fires on every PR touching src/ — increases CI minutes cost | 🟢 low | Path filter narrows to src/** + harness/** + smoke scripts; typical PR runs it in 3-5 min |
| DN2 | Base image `debian:12-slim` gets deprecated mid-year; harness silently drifts | 🟢 low | Follow-on ticket: pin to SHA digest instead of tag |
| DN3 | Rosetta emulation fails on future Apple Silicon macOS; harness stops building locally | 🟢 low | Runbook notes Rosetta requirement; document Podman as fallback if it becomes real |

## Feathers — characterization tests

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| DF1 | Tier 0 tests pass but a real container-level integration test doesn't exist | 🟡 med | Live run just proved end-to-end works against 1.2.1; add a container smoke to Tier 0 as follow-on when Docker-in-Docker available |
| DF2 | Cherry-picked `smoke-assert-settings-hooks.sh` lacks tests on this branch | 🟢 low | Tests ship with PR #161 (its own scope); merge order: #161 first, then this PR (or in parallel, no conflict) |
| DF3 | Reviewer sees a large PR (13 new files) and may miss the walking-skeleton framing | 🟡 med | PR body opens with problem statement + calls out V1 walking skeleton per Cockburn discipline; skeleton is intentionally minimal |

## Total risks

- Linus: 3 (0 high, 1 med, 2 low)
- Nygard: 3 (0 high, 0 med, 3 low)
- Feathers: 3 (0 high, 2 med, 1 low)
- Total: 9 risks; 0 HIGH; 3 MEDIUM; 6 LOW

## Strongest before PR merge

- **DL1** — note the cherry-pick dependency in PR body
- **DF1** — flag container-integration Tier 0 test as follow-on
- **DF3** — PR body opens with the Cockburn walking-skeleton framing so reviewer's mental model matches
