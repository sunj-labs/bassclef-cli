---
tier: standard
scope: cli #212 — docker-smoke false-green cure
type: brief use case (Cockburn brief tier)
ceremony_rationale: edit to existing hook, not new; per .claude/rules/oo-ad-entry-point.md matrix row "Existing code extension" = brief + /decompose entry-point check
authoring_luminaries:
  primary: michael-feathers
  supporting: [kent-beck, tony-hoare]
---

# UC-hook-docker-harness-exit-capture

Brief use case for the fix to cli #212 — docker-smoke false-green class in `harness/docker/entry.sh`.

## Actor

Docker cold-adopter smoke workflow (`.github/workflows/docker-smoke.yml`) running `harness/docker/entry.sh` inside a Debian container.

## Preconditions

- CLI_VERSION points at a target `@thebassclef/lite@X.Y.Z`
- npm install for that version fails (registry lag, 404, network, etc.)
- entry.sh runs `_docker_harness_install_cli` which returns `EXIT_INSTALL_FAIL` (21)

## Main success scenario

1. entry.sh main() reaches the install action guard at L466
2. `_docker_harness_install_cli` returns 21
3. Guard captures 21 into local `code` variable
4. Guard emits evidence row with real code 21
5. Guard exits container with code 21
6. Docker workflow's `smoke_exit_code` output reads 21
7. Workflow's "Fail job on non-detect codes" step maps 21 to infrastructure failure and fails the job

## Failure scenarios (what today's code does wrong)

**F1 — install failure reported as PASS.** Guard uses `if ! _docker_harness_install_cli; then local code=$?`. Bash captures `$?=0` from the successful `if` test, not from the function's real return code 21. Evidence row emits "install failed with code 0". Container exits 0. Workflow reports PASS. False green.

**F2 — preflight failure reported as PASS.** Same pattern at L459. Currently dead code because `_docker_harness_preflight_all` always returns 0, but any future preflight check inherits the bug.

**F3 — init failure reported as PASS.** Same pattern at L473. `_docker_harness_init_adopter` failure exits 0 silently.

## Postcondition (after fix)

For any of the three actions (preflight, install, init):

- If action function returns non-zero code N, main() exits container with N
- Evidence row carries N verbatim, not 0
- Workflow's mapping step sees N and applies the correct verdict (PASS / DETECT / FAIL)

## Trigger

Every docker-smoke workflow_dispatch OR release-published trigger that reaches the install action.

## Frequency

Fires on every release cascade + every ad-hoc smoke run. High frequency; every false-green is a lost validation signal.

## Priority

P1 — cascade validation depends on this hook.

## Scope

`harness/docker/entry.sh:459-477`. Three guards, same shape fix.

## Design pattern applied

**Feathers characterization test first.** Existing `_docker_harness_retry_with_backoff` return path is characterized — return 21 on install-tag exhaustion (L163). Test asserts main() exits 21 when that function returns 21. Test fails against current code. Fix goes green.

**Hoare postcondition contract.** The guards enforce the postcondition: exit code from main() == exit code from action function. Current guards break the contract. Fix restores it.

**Beck TDD RED → GREEN.** Tests written before source edit. RED first. Source fixed to make GREEN.

## Cure pattern

Replace each guard:

```bash
# BEFORE (bug)
if ! _docker_harness_action; then
  local code=$?          # captures 0 from the if-test
  _docker_harness_emit_evidence_row "action_fail" "action failed with code $code"
  exit "$code"
fi

# AFTER (fix)
_docker_harness_action
local code=$?           # captures action's real return code
if (( code != 0 )); then
  _docker_harness_emit_evidence_row "action_fail" "action failed with code $code"
  exit "$code"
fi
```

Same cure at 3 sites (preflight, install, init).

## References

- cli #212 — parent ticket + full analysis
- `harness/docker/entry.sh:459-477` — the 3 guards
- `harness/docker/exit-codes.sh` — return code vocabulary
- `.claude/hooks/tests/docker-harness-entry.test.sh` — existing test file (add 3+ new tests)
- `.claude/rules/oo-ad-entry-point.md` — ceremony matrix (this is brief tier + /decompose)
- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD on `harness/docker/entry.sh`
- `.claude/luminaries/michael-feathers.md` — primary lens (characterization)
- `.claude/luminaries/kent-beck.md` — supporting (TDD rhythm)
- `.claude/luminaries/tony-hoare.md` — supporting (postcondition contract)
