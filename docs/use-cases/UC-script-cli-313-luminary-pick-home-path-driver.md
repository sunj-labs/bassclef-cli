# UC — cli#313 luminary-pick home-path driver

**Status:** brief (Cockburn tier per `.claude/rules/oo-ad-entry-point.md` Class B)
**Date:** 2026-10-04
**Owner:** bassclef-cli
**Luminary pin:** `@luminary michael-feathers` (lead) + `@luminary linus-torvalds` (supporting)

## Primary actor

Driver script `scripts/tests/smoke-drive-e2e-luminary-pick-home-path.test.sh`.

## Preconditions

- Session A harness present (invariants lib + smoke-assert extension).
- `bash` 3.2+ on macOS; `bash` 5+ on ubuntu CI.
- `jq` + `awk` + `mktemp` available (standard POSIX).

## Trigger

`/longrun` dispatch per Session D stage 2 (operator picks cli#313 as a Session A follow-on; characterizes upstream cure before next release cascade).

## Main success scenario

1. Driver creates scratch dir via `mktemp -d`.
2. Driver bakes cured `lib/luminary-pick.sh` content inline (118-line snapshot pinned to bassclef-upstream main SHA `a38f1f54358b962d8472cc7e53858f600b0f4462`).
3. Driver sources cured file.
4. Driver sets up 6 fixture classes — each class pins one branch of the resolver cascade or the lite fallback.
5. Driver asserts `luminary_pick_catalog` trace matches the expected class output.
6. All 6 cases GREEN → driver exits 0.

## Fixture classes

| Class | Setup | Expected |
|---|---|---|
| T1 BASSCLEF_DIR branch | `BASSCLEF_DIR=<scratch>` + `state/luminary-implementations/*.json` present | Reads JSON files; emits sorted catalog |
| T2 CLAUDE_PROJECT_DIR branch | `BASSCLEF_DIR` unset + `CLAUDE_PROJECT_DIR=<scratch>` + `.claude/luminaries/*.md` present | Lite fallback fires; reads markdown frontmatter |
| T3 git-root branch | Both env vars unset + scratch is a git repo + `.claude/luminaries/*.md` present | Resolves via `git rev-parse --show-toplevel` |
| T4 pwd fallback | All env vars + git unset + runs inside `.claude/luminaries/`-containing dir | Resolves to pwd |
| T5 both missing | Scratch has no `state/luminary-implementations/` AND no `.claude/luminaries/` | Returns non-zero + emits "catalog dir missing" |
| T6 cli#313 anchor | Grep cured source | `$HOME/src/sunj-labs/bassclef` hardcoded fallback is NOT present (regression) |

## Why driver pins upstream fixture (not cli-bundled source)

The cure landed at bassclef-upstream main SHA `a38f1f54` (upstream #2057). Cli bundles `dist/lite/lib/luminary-pick.sh` from the current release (`v1.7.0`), which pre-dates the cure. So:

- Driver fetches cured source from upstream (bakes it inline as fixture).
- Driver pins the CURED contract per Feathers characterization pattern.
- Cli bundle (`dist/lite/`) still ships pre-cure source — adopters hit the bug until cli re-bundles at next release cascade.
- When cli re-bundles, `dist/lite/lib/luminary-pick.sh` matches the fixture; driver stays GREEN as regression check.

Session A used the same pattern — PR #350 (cli#307) pinned behavior against upstream main SHA `09beb249` rather than cli-bundled snapshot.

## Postconditions

- 6 Tier 0 cases GREEN under both macOS + ubuntu CI matrix.
- Driver stays GREEN after cli re-bundles cured source at next release.
- cli#313 ticket closes via `Closes #313` in PR body.

## Extensions

- E1 — awk portability: cured source uses `awk` with POSIX subset (anchored regex, `sub()`, `print`). No gawk-specific features. Verified by reading `/private/tmp/.../scratchpad/luminary-pick-cured.sh`.
- E2 — jq optional: primary path uses `jq` for JSON parse; lite fallback uses awk. Driver tests both paths.

## References

- Ticket: cli#313 (`gh issue view 313 --repo sunj-labs/bassclef-cli`)
- Upstream cure: bassclef-upstream main SHA `a38f1f54358b962d8472cc7e53858f600b0f4462` via PR #2057
- Fixture source: `/private/tmp/.../scratchpad/luminary-pick-cured.sh` (118 lines at a38f1f54)
- Session A harness: `scripts/tests/lib/lite-runtime-invariants.sh` + `scripts/lib/smoke-assert.sh`
- Risk ledger: inline in `state/markers/pre-mortem/feature-cli-313-luminary-pick-home-path-driver.marker` (compact Class B shape; 2 lenses × 5 risks)
- Sister driver: `scripts/tests/smoke-drive-e2e-build-phase-0.test.sh` (PR #350 cli#307 — same upstream-fixture pattern)

## Luminary lens notes

- `@luminary michael-feathers` lead — characterization tests pin ACTUAL behavior per cured upstream fixture. Fixture is the source of record; driver is the regression check.
- `@luminary linus-torvalds` supporting — adopter contract. The cure removes a hardcoded engineering-team path that leaked `$HOME/src/sunj-labs/bassclef` to every adopter. Driver guards against regression; T6 greps for the retired hardcoded path.
