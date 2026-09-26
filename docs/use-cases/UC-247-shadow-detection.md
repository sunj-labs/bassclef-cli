---
tier: project
title: UC-247 — adjacent-shadow detection in smoke harness
id: UC-247-shadow-detection
date: 2026-09-26
level: subfunction
scope: bassclef-cli smoke harness — reset + one-shot + docker entry
goal_id: 2026-09-26-247-shadow-detection
status: draft
shape: brief
references:
  - path: docs/whereami.md
    role: operator_recap 2026-09-26 — full trace + root cause + verified cure
  - path: docs/risk-ledgers/2026-09-26-247-shadow-detection.md
    role: pre-mortem light — 2 lenses × 3-5 risks + top-2 folds
  - path: state/markers/diagnose/fix-247-shadow-detection.marker
    role: diagnosis chain — reproduce + is/is-not + five-whys + hypothesis
  - id: bassclef-cli#247
    role: parent ticket
  - id: bassclef-upstream#1954
    role: peer's primary cure (resolver precedence)
  - id: bassclef-upstream#1953
    role: parent trace ticket (v1.6.0 tier-filter cure did not close leak)
---

# UC-247 — adjacent-shadow detection in smoke harness

## Sources read

- `docs/whereami.md` L23 operator_recap 2026-09-26 — cold-adopter probes named root cause + verified cure via `mv ~/tmp/bassclef aside`.
- `bassclef-cli#247` body — three call sites, acceptance criteria, out-of-scope list.
- `scripts/smoke-reset.sh` L1-80 — existing script layout, flags, logging idiom.
- `bassclef-upstream#1954` title — peer's resolver precedence cure that this ticket defends around.

## Why this UC exists

Per `.claude/rules/oo-ad-entry-point.md` matrix — existing-script extension needs a brief use case. This UC is that brief for adding one shared defensive function plus three call sites plus a runbook amendment.

## Actors

- Operator running smoke on cold-adopter Mac profile (host flow).
- CI runner executing docker cold-adopter smoke via `harness/docker/entry.sh` (container flow).
- Operator running `scripts/smoke-one-shot.sh` for the single-paste release-verification flow.

## Preconditions

- Operator or CI intends to run smoke against `@thebassclef/lite` at a specified version.
- Smoke workdir will be created at `${HOME}/tmp/bassclef-smoke-test` (host) or `/root/tmp/bassclef-smoke-test` (docker).
- Bash environment supports `[ -d ]` and `[ -f ]` file tests.

## Main scenario (compressed)

1. Smoke driver (smoke-reset, smoke-one-shot, or docker entry.sh) invokes `detect_stale_bassclef_shadows "$WORK_DIR"` before running `bassclef init`.
2. Function computes `SHADOW="$(dirname "$WORK_DIR")/bassclef"`.
3. Function checks whether `${SHADOW}/presence/install/bassclef-hook-connect.sh` exists.
4. If sentinel absent: function returns 0 silently. Smoke proceeds.
5. If sentinel present: function emits a warning to stderr naming the shadow path plus three operator options (mv aside, rm -rf, `--allow-shadow`).
6. If `SMOKE_ALLOW_SHADOW=1`: function logs the bypass via `trace-helper.sh` (when present) and returns 0. Smoke proceeds under override.
7. Otherwise: function exits 1. Smoke halts before init.

## Extensions

- **3a. Shadow dir exists but sentinel absent** — likely a coincidentally-named directory (`foo/bassclef/`) with no bassclef checkout. Return 0 silently (fail-safe on non-bassclef adjacent dirs). Prevents false positives.
- **3b. Shadow dir is a symlink** — resolve via `[ -f "$SHADOW/presence/install/bassclef-hook-connect.sh" ]` which follows symlinks. If the target has the sentinel, the check fires.
- **6a. Trace-helper missing** — some paths (host smoke on operator profile without bassclef substrate) lack `trace-helper.sh`. Function falls back to `echo` to stderr and continues without logging.
- **Docker container mount** — `harness/docker/entry.sh` computes `SHADOW="$(dirname "$WORK_DIR")/bassclef"` where `$WORK_DIR=/root/tmp/bassclef-smoke-test`. Any mount at `/root/tmp/bassclef` fires the same check.

## Postconditions

- **On sentinel absent** — smoke proceeds; no side effect.
- **On sentinel present + no bypass** — smoke halted; workdir untouched; operator sees clear warning naming path + three options.
- **On sentinel present + `SMOKE_ALLOW_SHADOW=1`** — smoke proceeds; trace log entry written when trace-helper available; adopter accepts the risk.

## Pre-mortem folds baked in

- **N2** (Norman — signifier discipline): the warning message names the exact path, the three options, and the exact bypass flag. Reader can act without reading the source.
- **S1** (Nygard — fail-safe on edge cases): sentinel absent → return 0; permission denied on stat → return 0 (fail-open on read errors, since we cannot confirm the shadow); symlink to non-bassclef → return 0.

## References

- Ticket: `bassclef-cli#247`
- Diagnosis: `state/markers/diagnose/fix-247-shadow-detection.marker`
- Risk ledger: `docs/risk-ledgers/2026-09-26-247-shadow-detection.md`
- Peer's primary cure: `bassclef-upstream#1954`
- Parent trace: `bassclef-upstream#1953`
