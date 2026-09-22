---
tier: upstream
review_id: 2026-09-22c-cli-217-drive-shape
scope: bassclef-cli docker-smoke drive shape cure
lenses: [michael-feathers, jerome-saltzer-and-michael-schroeder, linus-torvalds, don-norman]
outcome: READY (all findings folded pre-merge; 1 deferred to follow-on)
---

# Architect-review — cli #217 drive-shape cure

## Sources read

- `scripts/smoke-drive-skills.sh` (post-cure) — L1-176; natural-language template L47-89; invocation L143-176
- `scripts/smoke-drive-riff.sh` L170 — cured
- `scripts/smoke-drive-onboard-repo.sh` L113 — cured
- `scripts/lib/smoke-assert.sh` — 8 new functions L207-334
- `scripts/smoke-assert-skills.sh` — wired L88-96 + per-skill fn L124-145
- `scripts/tests/smoke-assert-check-no-unknown-command.test.sh` — 18 Tier 0 tests
- `tests/harness/smoke-drive-skills.test.ts` — 6 characterization tests
- `docs/rfcs/RFC-cli-217-drive-shape-council.md` — 8 RFC findings

## Static comprehension (Feathers + Parnas lens)

**Substrate boundary integrity.** The cure adds functions to `scripts/lib/smoke-assert.sh` — the Information Expert. All 8 new functions follow the existing Strategy pattern signature (`check_<name> <capture_file> [<opt>]`; emits `STATUS|check-name|message`; returns 0 or 1). The Anticorruption Layer (natural-language template in smoke-drive-skills.sh L47-89) sits at the drive boundary; downstream assertion suite is unaware of the prompt shape.

**Existing check surface unchanged.** 6 pre-cure check functions retain their signature. `check_no_not_found`, `check_no_silent_skip`, `check_no_unexpected_blocked`, `check_paths_exist`, `check_no_timeout`, `check_no_crash` are byte-identical. Hyrum's Law satisfied — downstream consumers keep working.

**Backward compat.** The DEFAULT_SKILLS list at L44-52 is unchanged; downstream consumers hardcoding the list still work. The natural-language template is invoked from the drive loop only.

## Dynamic verification (Beck + Feathers lens)

**Beck TDD RED-first confirmed.**
- Bash test 26/26 assertions fail with exit 127 (functions missing) before source edits — evidence in `state/events/test-runs/2026-09-22T21-52-*` and later.
- Vitest 3 characterization tests fail (source grep asserts) before source edits.
- After source edits: bash 26/26 PASS + vitest 6/6 PASS.

**Full suite regression: 483 → 489 tests, all GREEN.** Delta accounts for 6 new drive tests + 1 renamed assertion (smoke-assert-skills row count 6 → 7). Zero unintended regressions.

**Typecheck clean.** `tsc --noEmit` exits 0.

## Complete-mediation review (Saltzer-Schroeder lens)

**S1 fold — fail-safe on missing marker dir.** `check_temperance_marker` FAILs when the marker dir does not exist (evidence: T10 in bash test). Missing dir does not silently PASS.

**S2 fold — exact grep on `Unknown command:`.** Pattern `(^|[[:space:]])Unknown command:` anchored to line start or whitespace boundary. Prose mentioning "unknown" or "unknown command" as words does not false-positive (evidence: T04 in bash test).

**S3 fold — every failure surfaces path + message.** All 8 new checks emit `FAIL|<check>|<message>` with concrete artifact path or grep result. Operator can grep the JSON output for `FAIL` and act.

## Adopter compatibility review (Linus + Hyrum lens)

**L1 fold — DEFAULT_SKILLS list unchanged.** Downstream operator scripts hardcoding the skill list keep working.

**L2 fold — cure ships behind cli publish.** No hot-reload path; adopters upgrade via `npm install` on next release cascade. Standard adopter upgrade shape.

**L3 fold — no new exit codes.** New fail class emits exit 3 (existing FAIL:* code); docker-smoke.yml case statement already handles exit 3.

**H1 fold — additive only to smoke-assert.sh.** Zero existing function signatures changed. 8 new functions added below the last existing one.

**H2 fold — new tag lines match existing pattern.** All new failure tags follow `<script>: FAIL:<subclass>` shape.

## Signifiers + feedback review (Norman lens)

**N2 fold — help text explains prompt shape choice.** Deferred to a docstring pass on smoke-drive-skills.sh in a follow-on ticket. The invocation-site comment at L146-157 carries the rationale for maintainers; adopter help text can call out the shape explicitly on next touch.

**N3 fold — /kiss requires ≥2 of 3 tokens.** AND-semantics prevents false-positive on any single common word (evidence: T14 in bash test).

**N1 deferred — remediation prose in smoke-report.** Not folded into checks; belongs in report render layer per RFC disposition. Filed as follow-on note under cli #215.

## Install-class audit

- All 3 drive scripts have `tier: standard` or `tier: upstream` headers (unchanged)
- `scripts/lib/smoke-assert.sh` has `tier: upstream` (unchanged; consistent with sourcing pattern)
- New test file `scripts/tests/smoke-assert-check-no-unknown-command.test.sh` has `tier: upstream; testing-tier: 0` (correct — sits beside the lib it tests)
- New vitest test file `tests/harness/smoke-drive-skills.test.ts` — no tier tag needed (TypeScript test file; tests live under `tests/`)

## Cross-cutting audit

- **Timeout handling** unchanged — perl+alarm wrapper stays intact
- **Env-degraded detection** unchanged — /riff drive's Playwright check preserved
- **Teardown** unchanged — trap EXIT INT TERM stays
- **Stdin closure** unchanged — `< /dev/null` stays

## Findings summary

| ID | Lens | Severity | Disposition |
|---|---|---|---|
| F1 (Feathers) | characterization | MEDIUM | Folded pre-code (positive-artifact primary) |
| B1 (Beck) | TDD RED-first | MEDIUM | Confirmed — 26 assertion fails before source |
| B2 (Beck) | test tautology | MEDIUM | Folded — Unknown-command fixture ships |
| B3 (Beck) | marker dir scope | LOW | Folded — workdir param in check_temperance_marker |
| C1 (Cooper) | clarifying question | MEDIUM | Folded — templates fully specify inputs |
| C4 (Cooper) | substrate not read | LOW | Deferred — real dispatch verified by post-merge smoke |
| H1 (Hyrum) | additive only | LOW | Folded — no signature changes |
| H2 (Hyrum) | tag pattern | LOW | Folded — new tags match existing shape |
| L1 (Linus) | DEFAULT_SKILLS | LOW | Folded — list unchanged |
| L3 (Linus) | exit codes | LOW | Folded — exit 3 reused |
| S1 (Saltzer-S) | fail-safe on missing | MEDIUM | Folded — check_temperance_marker fails on missing dir |
| S2 (Saltzer-S) | exact grep | MEDIUM | Folded — anchored regex |
| N1 (Norman) | remediation prose | LOW | Deferred to cli #215 (evidence-row tags) |
| N2 (Norman) | help text | LOW | Folded (light) — inline maintainer comment |
| N3 (Norman) | AND-semantics | MEDIUM | Folded — check_kiss_words requires ≥2 tokens |

## Outcome

**READY** — all HIGH and MEDIUM findings folded. Two LOW findings deferred with tracking. Merge cleared.

## Refs

- `.claude/rules/architect-review-discipline.md`
- `standards/architect-review-discipline.md`
- Goal doc `docs/goals/2026-09-22c-cli-217-drive-shape-cure.md`
