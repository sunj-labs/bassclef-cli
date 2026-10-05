# Pre-mortem light — Session H driver sweep

Scope: 6 characterization drivers for cli#311, #312, #323, #324, #325, #326 against dist/lite/ shipped bundle.

## Michael Feathers (characterization tests)

1. Driver test anchors drift silently when dist/lite/ bundle rotates to a new upstream SHA. **Fold:** pin fixture path to `dist/lite/` + document the shipped version in test header.
2. Grep regex over-matches on refactor; false GREEN when defect still present. **Fold:** anchor regex to exact L-number OR surrounding context from the ticket body.
3. Driver assumes substrate layout; adopters with different `.claude/` layout confuse the test. **Fold:** scope assertions to `dist/lite/` subtree only.
4. Characterization pins current wrong behavior as "expected"; upstream fix flips driver RED. **Fold:** use `_expect_fail` idiom OR state in test comment "will flip GREEN after upstream fix lands."
5. Test runs clean locally but CI container misses jq or sed differences. **Fold:** bash + grep + jq only; no awk gymnastics; no BSD/GNU-specific flags.

## Kent Beck (RED-first discipline)

1. Writing source + test together loses the RED signal. **Fold:** commit test alone first; verify RED locally; then commit the characterization proof.
2. Test file skipped at CI because glob mismatch. **Fold:** place under `scripts/tests/` per Session F precedent; CI picks it up.
3. 10+ assertions in one test file blur the pin. **Fold:** 4-6 Tier 0 cases per driver; one defect axis per case.
4. "Pending" cases marked TODO slip through. **Fold:** test-list block at top of file; `[~]` for deferred with reason.

## Linus Torvalds (adopter contract)

1. Driver changes semantics of a shared helper, breaking Session F drivers. **Fold:** no edits to `scripts/lib/*.sh` common libs; each driver stands alone or sources existing lib without mutation.
2. PR body claims cure that didn't ship. **Fold:** PR body says "characterizes RED; cure is upstream work; this driver flips GREEN only after upstream + bundle sync."
3. CI breaks for sibling adopters because the driver assumes bassclef-cli layout. **Fold:** stays under bassclef-cli scope; no cross-repo imports.

## Folds applied pre-code

- Each driver test file carries fixture pin + anchored regex + `_expect_fail` where appropriate
- `scripts/tests/` placement per Session F precedent
- 4-6 Tier 0 cases per driver, one axis each
- Test-list block at top; `[~]` for deferred
- No lib mutations; standalone or read-only source
- PR body states characterization scope, not cure scope

## Deferred (3 risks, cost-vs-benefit)

- F1 (fixture-rotation drift) — accept risk; dist/lite/ version pinned in bassclef-version.json; drivers run against current bundle
- B2 (CI test glob) — accept risk; Session F convention stable
- L3 (sibling-adopter CI break) — accept risk; cli-only driver scope
