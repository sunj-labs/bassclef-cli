---
tier: standard
uc_id: UC-hook-docker-harness-entry
authored: 2026-09-20
session_id: 2026-09-20b
cockburn_tier: brief
parent_use_case: docs/use-cases/UC-docker-cold-adopter-harness.md
subject: .claude/hooks/tests/docker-harness-entry.test.sh
---

# UC-hook-docker-harness-entry — Tier 0 test of the harness entry.sh source

## Sources read

- `docs/use-cases/UC-docker-cold-adopter-harness.md` — parent fully-dressed use case
- `docs/decompositions/2026-09-20b-docker-cold-adopter-harness.md` — module contract for the source under test

## Brief

The test file at `.claude/hooks/tests/docker-harness-entry.test.sh` runs Tier 0 strict-TDD assertions against `harness/docker/entry.sh` per `.claude/rules/testing-tier-config.md`. It sources the entry.sh functions and calls each one directly with controlled inputs. It asserts exit codes, evidence-row emission, backoff behavior, preflight-check behavior, and signal-handler installation.

Per Feathers characterization discipline — the test file pins the actual behavior of the source before any refactor. Any future entry.sh change fails the tests loudly.

## Actors

- Test runner (`bash .claude/hooks/tests/docker-harness-entry.test.sh`) — invoked by operator or CI

## Main scenario

1. Test runner sources exit-codes.sh; asserts constants readonly
2. Test runner sources entry.sh (functions load; main does NOT run)
3. Test runner invokes each function per the test-list block header
4. Test runner reports total + passed + failed with pass/fail per assertion
5. Exit 0 when all pass; exit 1 with a failure list when any fail

## Postconditions

- Test count matches the test-list block `[x]` count
- Every entry.sh function named in the decomposition doc has at least one assertion
- Exit codes verified per the exit-codes.sh vocabulary

## Refs

- Parent fully-dressed UC at `docs/use-cases/UC-docker-cold-adopter-harness.md`
- Decomposition at `docs/decompositions/2026-09-20b-docker-cold-adopter-harness.md`
- `.claude/rules/test-list-discipline.md` — test-list block shape
- `.claude/rules/test-sufficiency.md` — 12 criteria the test file honors
