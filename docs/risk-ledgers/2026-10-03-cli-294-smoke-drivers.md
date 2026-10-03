---
tier: lite
date: 2026-10-03
goal: cli#294 — 5 adopter-regression smoke drivers for Kunal #2036 cures
mode: light
lenses: [michael-feathers, linus-torvalds, alan-cooper]
---

# Pre-mortem light — cli#294 (5 smoke drivers)

3 lenses × 5-8 risks per Klein workshop shape. Light mode, 30 min.

## @luminary michael-feathers — characterization-test discipline

| # | Risk | Severity | Fold-in / cure |
|---|---|---|---|
| F1 | Driver passes against current main but RED-first evidence against parent-of-fix commit stays unverified | 🔴 high | **FOLD**: every PR body cites the pre-cure SHA + driver fail output. Operator can re-run `git checkout <sha> && bash scripts/tests/<driver>.test.sh` to confirm RED. |
| F2 | Driver asserts the symptom (log line text, grep match) not the behavior (no privacy leak observable from adopter view) | 🟡 med | **FOLD**: each driver's top-of-file comment names the adopter-visible behavior being pinned. Assertion follows from behavior. |
| F3 | Fixture `fake_claude.sh` returns deterministic output; real `claude` returns LLM-variable output; driver tests fake behavior not real | 🟡 med | **ACCEPT**: fake_claude is deliberate per existing drivers. Real-claude smoke runs separately in docker-smoke CI. |
| F4 | Mock `gh api` for driver 5 (onboard-free-tier-403) drifts from real `gh api` response shape | 🟡 med | **FOLD**: mock emits actual GitHub REST error payload shape (JSON with `message` + `documentation_url` fields). Cite GH API docs in fixture comments. |
| F5 | Driver 2 (build-against-template) only tests one heading form (new or legacy), misses the grace-window logic | 🟡 med | **FOLD**: driver 2 runs both heading forms in sequence, asserts step count matches for both. Test name reflects dual-coverage. |

## @luminary linus-torvalds — adopter contract

| # | Risk | Severity | Fold-in / cure |
|---|---|---|---|
| L1 | New driver shape drifts from existing 4 drivers; reviewer loads two mental models | 🟡 med | **FOLD**: each PR body includes side-by-side diff vs `smoke-drive-interactive-onboard-repo.test.sh` as the exemplar. |
| L2 | Driver fires in cli CI but silently skips on adopter machine (missing dep, wrong shell) | 🟡 med | **FOLD**: driver top-of-file declares shell requirement + checks for required binaries; exits with named skip code if missing (not silent). |
| L3 | PR 1 lands, PR 2 rebase conflicts on `smoke-drives-registry.sh` (both add new entries) | 🟢 low | **ACCEPT**: registry entries append; conflicts are trivial to resolve. If pattern recurs, extract to one-entry-per-file. |
| L4 | Driver test file lives at `scripts/tests/` which is cli-only; adopters inherit nothing | 🟢 low | **ACCEPT**: per cli#294 "Why cli, not upstream" section — this is deliberate separation of concerns. |
| L5 | 5 PRs merge quickly, adopter cold-smoke doesn't re-run between them, latent bug ships | 🟡 med | **FOLD**: closeout runs full `bash scripts/tests/*.test.sh` suite after all 5 land to confirm no cross-driver regression. |

## @luminary alan-cooper — goal-directed

| # | Risk | Severity | Fold-in / cure |
|---|---|---|---|
| C1 | Driver maps to Kunal finding # but not to the adopter goal Kunal was reaching for | 🟡 med | **FOLD**: each driver's top comment opens with "Adopter was trying to: <goal>" (e.g., "Adopter was trying to: run /sprint on their project without their machine username leaking into a public trace log"). |
| C2 | 5 drivers in one session likely hits context compaction mid-way | 🟡 med | **FOLD**: stacked per-driver PRs. Each PR squash-merges before next starts. Survival kit re-reads only cli#294 body + prior PR SHAs. |
| C3 | Operator reads 5 PRs in rapid succession, loses signal on which finding each pins | 🟡 med | **FOLD**: PR title shape — `test(cli-294): driver N — <finding slug> (<Kunal #>)` so each PR title names the pinned finding. |
| C4 | Operator wants to pause mid-sequence; sequence assumes all 5 ship contiguously | 🟢 low | **ACCEPT**: `agent-merges-within-scope` config means operator can halt by typing `pause` and resume from PR N+1 later. |
| C5 | Driver 4 (env-reach-override) assumes `lib/skip-env-inline-check.sh` exists; may need author-first | 🟡 med | **FOLD**: Step 5 pre-work reads for lib; if absent, author lib as part of driver 4 PR with its own Tier 0 test. |

## Top folds riding into Step 1

- F1 — PR body cites pre-cure SHA + RED output
- F2 — driver top-of-file names adopter-visible behavior
- L1 — PR body includes side-by-side diff vs exemplar driver
- C1 — driver top comment opens with "Adopter was trying to:"
- C3 — PR title names the pinned Kunal finding
