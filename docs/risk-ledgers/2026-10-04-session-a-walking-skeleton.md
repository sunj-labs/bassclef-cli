---
goal: Session A — lite-only Docker runtime + walking skeleton + 5-PR authoring-chain driver stack
date: 2026-10-04
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - linus-torvalds
    - kent-beck
mode: pre-mortem light (3 lenses × 5-8 risks)
---

# Session A pre-mortem — lite runtime + authoring-chain drivers

## Scope under review

PR 1 (walking skeleton): Dockerfile.lite-adopter + scripts/tests/lib/lite-runtime-invariants.sh + scripts/tests/run-lite-container.sh + .github/workflows/lite-adopter-smoke.yml + scripts/tests/smoke-drive-e2e-interpret-input.test.sh + cli#305 Exhibit-A anchor.

PRs 2-5: /personas driver, /jtbd-tasks driver, /launch --local phase-gate driver, full-chain path-contract driver (cli#317).

Luminary pin: Cockburn lead (walking skeleton); Torvalds + Beck supporting (adopter stability + red-first).

## Cockburn — walking skeleton

Lens: what breaks if integration risk surfaces late?

- **R-C1. Bash version drift in container.** node:20-slim ships bash 5.x. Drivers that source /bin/bash run bash 5, not bash 3.2. Invariants anchor shows GREEN but adopter machines run bash 3.2 and break. Fold: pin bash 3.2 explicitly in Dockerfile. Run drivers under `bash --posix` or install macOS 3.2.57 equivalent.
- **R-C2. Walking skeleton misses the chain shape.** PR 1 ships /interpret-input + runtime only. We only prove the chain works end-to-end at PR 5. Four PRs of sunk cost if the shape is wrong. **Fold (highest value):** PR 1 includes a minimal /personas stub driver — invoke skill, assert output file exists at expected path. Chain shape proven at PR 1.
- **R-C3. Nightly matrix GitHub Actions cost.** Matrix across 3 releases × container run ≈ 15 min per night. Burns Actions minutes. Fold: nightly fires latest only; tag-push fires full 3-release matrix.
- **R-C4. npm CDN propagation delay.** New release lands at T. Nightly fires at T+1 and reads stale. Fold: nightly checks `npm view` time field; waits up to 15 min for propagation or skips the run.
- **R-C5. Driver exits 0 with no output.** Exact class we close (cli#319). Easy to replicate at test layer. **Fold (highest value):** every driver asserts output artifact presence AND content shape, not just exit code. smoke-assert.sh already has `check_output_contains`; extend with `check_artifact_exists`.
- **R-C6. First PR too fat.** Dockerfile + lib + workflow + driver + anchor in one PR = ~500 lines. Reviewer fatigue; agent-merges-within-scope flag depends on PR 1 being reviewable at phase boundary. Fold: operator pause at PR 1 opens Dockerfile + lib + workflow + 1 driver max. Anchor cli#305 and nightly matrix slip to PR 1b if size exceeds 500 lines.

## Torvalds — adopter stability

Lens: what breaks adopter trust?

- **R-T1. Invariants lib false-blocks docstrings.** Lib greps for the user-home shape or $HOME. Skill docstring with `# Example: <user-home>/project` triggers block. Lib blocks legitimate paths. Fold: lib scans trace output of running drivers, not skill body source. Trace is the surface adopters see.
- **R-T2. Nightly on main breaks Session B/C start.** Session A ships infrastructure Session B/C depend on. Nightly failure halts progress. **Fold (highest value):** matrix cells use `continue-on-error: true`; only tag-push run is a hard gate on CI.
- **R-T3. Local operator run breaks on M-series Mac.** run-lite-container.sh runs linux/amd64 container on M-series via Rosetta. Platform mismatch. Fold: script passes `--platform linux/amd64` explicitly; CI smoke-tests the script on macOS runner.
- **R-T4. ADR-007 bundle untouched claim fails.** Invariants lib finds cli bundles skills referencing non-lite libs. Cure requires editing dist/lite bundle. That IS ADR-007 territory. Fold: lib reports mismatch as RED; bundle edit happens in a separate PR with ADR-007 consult, not inside Session A.
- **R-T5. OAuth token propagation to matrix cells.** Nightly uses `claude -p` inside container. OAuth token file-fallback (PR #249 cure) must reach every matrix cell. Fold: workflow pattern mirrors docker-smoke.yml; use GitHub Actions secret CLAUDE_CODE_OAUTH_TOKEN into container env.
- **R-T6. Cold-adopter clone can't run tests.** Adopter clones cli to debug. Tests reference `dist/lite/` which is gitignored. Fresh clone red. Fold: tests pull bundle via `npm pack` or local tarball; document in CONTRIBUTING.md.
- **R-T7. Trace-helper siblings** (plan doc class A). cli#305 fixes one trace-helper. Other identifier-scrub siblings may carry the same self-block pattern. Fold: Exhibit-A anchor also scans for sibling trace-helpers in `.claude/hooks/` + `lib/`; one assertion per sibling.

## Beck — red-first per driver

Lens: what breaks the RED-GREEN rhythm?

- **R-B1. Fixture rot.** Upstream ships cure. Fixture greps pre-cure string. Nightly green by coincidence. Fold: fixtures carry upstream ticket ref; assertion is "find field named X" not "match exact string Y".
- **R-B2. Driver test > 2 min each.** 5 drivers × 2 min = 10 min per PR CI. TDD cycle breaks. Fold: Tier 0 fixtures mock the skill run; nightly only uses real `claude -p`.
- **R-B3. Mixed layer confusion.** Tier 0 fast on fixture; nightly real claude. Easy to confuse which layer catches which class. Fold: name files `*.tier0.test.sh` vs `*.nightly.test.sh`. CONTRIBUTING.md documents the split.
- **R-B4. RED-on-main for weeks.** Drivers go RED until upstream fixes land. Nightly red every night. Operator fatigue. **Fold (highest value):** nightly reports exit 3 (expected-RED) as success, mirrors docker-smoke exit 3 convention (whereami L54 confirmed shape). Emit structured list of waiting-for-upstream tickets.
- **R-B5. cli#305 Exhibit-A test shape.** Hard to RED test without real self-block scenario. Fold: fixture creates mock trace scenario; assert helper exits 0 (does not block) OR flags "informational" not "block".
- **R-B6. Chain driver (PR 5) needs 4 real skills.** 2 min end-to-end chain run. Nightly cost. Fold: chain driver has fast-fixture mode (grep write-paths from skill body) for Tier 0; real-run mode only in nightly.
- **R-B7. GREEN flipping test.** When upstream ships cure, driver flips GREEN. Need a signal that tells us GREEN was NOT a coincidence (R-B1). Fold: every GREEN flip triggers a sibling check that confirms the specific cured behavior, not just the fixture.

## Folds landing pre-code

Six folds applied before PR 1 opens:

1. **R-C1 → Dockerfile pins bash 3.2 explicitly.** Install `bash` 3.2.57 equivalent via apt-get or run drivers with `bash --posix`.
2. **R-C2 → PR 1 ships minimal /personas stub driver.** Chain shape proven at phase boundary 1, not PR 5.
3. **R-C5 → smoke-assert extends with `check_artifact_exists`.** Mandatory on every driver.
4. **R-C6 → PR 1 size budget 500 lines.** Overflow slips to PR 1b.
5. **R-T2 → nightly matrix cells `continue-on-error: true`.** Only tag-push is a hard gate.
6. **R-B4 → nightly reports exit 3 as success.** Mirrors docker-smoke convention. Structured waiting-for-upstream list in output.

## Folds deferred to Session A follow-ons

- R-T7 trace-helper sibling scan — extend Exhibit-A anchor in PR 1b if sibling trace helpers surface during review.
- R-B7 GREEN-flip sibling check — ships with first upstream cure (post-Session A).
- R-T6 cold-adopter clone test runnable — CONTRIBUTING.md update in PR 5.

## References

- Plan doc: `docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md`
- Whereami: `docs/whereami.md` L18 (PRIMARY queue), L26 (operator-recap)
- ADR-005 (Model C open-core split) + ADR-007 (lite bundle shape) — honored, no deviation
- `.claude/rules/loop-discipline.md` Step 0.5 — pre-mortem light fires before first Edit
- `.claude/skills/pre-mortem/SKILL.md` light mode
- Memory: `feedback_oauth_verify_via_cheap_hello` + `feedback_bash_paste_zsh_interactive_comments`
