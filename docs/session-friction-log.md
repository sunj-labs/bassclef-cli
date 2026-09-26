# Session friction log

## 2026-09-24T08:14:55Z — /ticket dispatch (CLAUDE_CODE_OAUTH_TOKEN bifurcation)
- Local: https://github.com/sunj-labs/bassclef-cli/issues/227
- Bassclef cross-post: https://github.com/sunj-labs/bassclef/issues/1509

## 2026-09-24T08:16:22Z — /promote dispatch (cure-signal harness gap)
- Bassclef substrate-evolution: https://github.com/sunj-labs/bassclef/issues/1510

## 2026-09-24T18:45Z — /ticket dispatch (cli #230)

- **Trigger:** v1.9.1 smoke run 36042239422 fired ASSERTION FAIL on /onboard-repo + /riff drives; both skills correctly refused work but drive assertions still checked for success-path artifacts.
- **Local ticket:** https://github.com/sunj-labs/bassclef-cli/issues/230
- **Bassclef cross-post:** SKIPPED — fix is 100% cli-side drive scripts; no bassclef change owed.
- **Scope:** update `smoke-drive-onboard-repo.sh` + `smoke-drive-riff.sh` to distinguish talkative-refuse PASS from silent-fail FAIL. Extend `harness/docker/exit-codes.sh` vocabulary. Add drive rows to report.md assert-skills table.
- **Estimate:** M — ~40-60 turns.

## 2026-09-24T22:12:00Z — /ticket dispatch
- Local: https://github.com/sunj-labs/bassclef-cli/issues/232
- Scope: harness workflow race — Fix A (workflow_run chain on publish success)
- No cross-post (100% cli-side)
