# Reviewer pass — 1.9.21 release + cli#479

mode: sequential
reviewed_at: 2026-11-07T02:12:21Z
source_files_changed: 1
wu_id: cli#479
iteration_count: 1
lens_used: [michael-feathers, tony-hoare]

## Checks
- spec acceptance criteria: PASS — all four boxes in the #479 test plan done.
- tests present + green: PASS — 63 files, 550 tests, 0 failed.
- test-after pattern check: FOUND, and stated. The fix was written before its
  test. Diagnosis came first (execSync return measured, then the line read),
  so the test is not a restatement of the implementation — but the order was
  not Beck's.
- ADR compliance: N/A — no architectural surface touched. publish.yml and
  scripts/publish-gate.sh untouched.
- Designer sign-off: N/A
- architect-review: N/A

## Findings
- NOTE: Test 4 pins the default runner's shape, not a real build. The
  integration was verified by hand (dist reports 1.9.21).
- NOTE: the fix is test-after. See above.

acknowledged: true
