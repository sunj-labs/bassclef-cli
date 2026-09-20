---
tier: operator-private
authored: 2026-09-20
session_id: 2026-09-20b
mode: pre-mortem-light
handoff: construction-to-testing
parent_goal: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
lenses:
  - andreas-zeller
  - kent-beck
  - michael-nygard
---

# Pre-mortem light — Handoff 3 (Construction → Testing)

Focused on Step 7 live-run risks against cli 1.2.1.

## Sources read

- All prior artifacts through Step 5 (Dockerfile + entry.sh + workflow + runbook + tests all GREEN)
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-2.md` — 15 code-writing risks
- `scripts/smoke-assert-settings-hooks.sh` — the V1 assertion the harness calls

## Zeller — falsification-test discipline

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| Z1 | Container exits 0 against 1.2.1 (false negative). Assertion buggy — misses the 12-hook class | 🔴 high | Manual counter-test: run smoke-assert-settings-hooks.sh directly on operator machine against a fresh 1.2.1 install; confirm it exits 3. If yes, containerized run should exit 3 too |
| Z2 | Container exits with wrong non-zero code (e.g., 21 install fail masking real class) | 🟡 med | Read entry.sh output; distinguish infra failures (20+) from detection classes (3-6) |
| Z3 | smoke-assert-settings-hooks.sh path assumptions inside container differ from operator machine | 🟡 med | Dockerfile copies scripts/ to /adopter/scripts/; verify smoke-assert reads the correct settings.json path |

## Beck — TDD RED-GREEN cycle

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| B1 | First live docker build fails (npm register lookup, apt-get slow) | 🟢 low | Retry per BackoffRetrier logic; log full docker build stderr for diagnosis |
| B2 | Container start fails on `USER adopter` — uid/gid conflict with mounted volume | 🟢 low | V1 mounts no volumes; unprivileged user works cleanly |
| B3 | npm install fails inside container due to lockfile or `--force` semantic drift | 🟡 med | Global install `-g` bypasses lockfile; single-package install has no lockfile concerns |

## Nygard — stability under first-run drift

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| N9 | Rosetta emulation slower than expected (>5min build on M-series) | 🟢 low | Timeout is 15 min in workflow; local run has no timeout; if slow, note in runbook |
| N10 | Debian 12 image size ~150MB pulls slowly on first run | 🟢 low | One-time cost; subsequent runs cache. Not a bug |
| N11 | The `latest` npm tag resolves to a version different from the operator expects | 🟡 med | Runbook + workflow default `CLI_VERSION=latest`; runbook shows override to specific version |

## Strongest concerns before Step 7 live run

- **Z1** — verify smoke-assert-settings-hooks.sh exits 3 on 1.2.1 on operator machine FIRST before running in Docker. Confirms the assertion works before the container isolates variables.
- **Z3** — inspect the smoke-assert script for path assumptions; may need env var or arg for settings.json path

## Total risks

- Zeller: 3 (1 high, 2 med)
- Beck: 3 (0 high, 1 med, 2 low)
- Nygard: 3 (0 high, 1 med, 2 low)
- Total: 9 risks; 1 HIGH; 4 MEDIUM; 4 LOW
