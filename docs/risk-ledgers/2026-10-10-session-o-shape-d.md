---
tier: lite
id: risk-ledger-2026-10-10-session-o-shape-d
status: active
started: 2026-10-10
goal: Shape d — cli#406 init 5-min value test + cli#411 bassclef-version.json write
mode: light-compressed
scope_class: class b (cli#406) + class b (cli#411)
authoring_luminaries:
  primary: michael-feathers
  supporting: alan-cooper
pre_mortem_lenses:
  - linus-torvalds
  - michael-feathers
  - michael-nygard
---

# Pre-mortem light — Session O Shape d

Compressed shape: 3 lenses × 3 risks each. Both tickets are class b (script extension; low blast radius). Full 5-8 per lens would overfit the scope.

## Lens 1 — Linus Torvalds (adopter contract)

| # | Risk | Mitigation |
|---|---|---|
| L1 | Rewriting the init final output breaks an adopter who greps the current banner shape (e.g. CI jobs matching "N files written"). | Preserve the technical safety output (hook counts, refusal lines). Only the trailing summary changes per cli#406 body. |
| L2 | `bassclef-version.json` write at adopter workdir root collides with an adopter who already has a file at that path. | writeSafely refuses existing files without --force per ADR-002 §Invariants. Reuse the same safety contract. |
| L3 | `.bassclef/init.manifest.json` row addition breaks the manifest schema for old cli versions reading it. | Row is additive. Schema allows unknown rows per ADR-009. Confirm via grep of init-manifest consumers. |

## Lens 2 — Michael Feathers (characterization)

| # | Risk | Mitigation |
|---|---|---|
| F1 | New Tier 0 test pins a shape that drifts from Sam's actual verbatim target. | Read bassclef-upstream#2006 body for Sam's exact words. Test asserts those words appear verbatim. |
| F2 | Existing init tests still pass but the shape they pin is the old shape. | Audit `scripts/tests/*init*` for banner-shape assertions. Update or deprecate as part of this PR. |
| F3 | Tier 0 test for cli#411 asserts file exists but not that its `.version` matches bundled source. | Test reads `dist/lite/bassclef-version.json` + asserts written file's `.version` equals bundled `.version`. |

## Lens 3 — Michael Nygard (stability + failure modes)

| # | Risk | Mitigation |
|---|---|---|
| N1 | `bassclef-version.json` write races with a later tool that overwrites it (sync, update). | Register via `registerInstallWrittenPaths` so install-written-paths manifest covers it. Future tools consult the manifest before clobbering. |
| N2 | `--verbose` flag conflicts with existing cli flags or clashes with --verbose semantics in subcommands. | Grep `src/commands/*.ts` for existing --verbose flag use. Reuse the same parser if present. |
| N3 | Reading bundled `dist/lite/bassclef-version.json` fails because the file is absent in dev install (not production tarball). | Fail soft with a one-line warning. Do not block init when the bundled file is missing. Tier 0 test covers this path. |

## Highest-concern risks to fold pre-code

- **L2 + N1 — write collision at adopter workdir root.** Both cures already live in cli (writeSafely + registerInstallWrittenPaths). Verify both are wired on first commit.
- **F1 — verbatim shape drift from Sam's target.** Read bassclef-upstream#2006 body carefully. Pin the words in the test.

## Deferred risks

Full pre-mortem would add 3 more risks per lens (adopter upgrade path, test fixture freshness, concurrent npm cache invalidation, bundled-file schema drift, cross-platform path separator handling, etc.). Those are low-probability for class b scope. Fold if a RED iteration surfaces them.

## Composes with

- `.claude/rules/loop-discipline.md` Step 0.5 — pre-mortem light required before first edit
- `.claude/skills/pre-mortem/SKILL.md` light mode
- @luminary gary-klein — pre-mortem originator
- `docs/next-session-plan-2026-10-09-session-o-attack-tier-a-gaps.md` — scope anchor
- `docs/adrs/ADR-002-bassclef-init-safety-contract.md` — write-safety contract
- `docs/adrs/ADR-009-manifest-as-init-contract-source.md` — manifest schema
