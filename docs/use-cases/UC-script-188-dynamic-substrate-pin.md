---
ticket: cli#188
sister_tickets: [cli#438, cli#439]
luminaries:
  primary: [linus-torvalds]
  supporting: [tony-hoare, michael-feathers, kent-beck]
tier: brief
---

# UC-script-188 — dynamic substrate pin in publish workflow

## Scope

Lift the hardcoded bassclef substrate pin from `.github/workflows/publish.yml` into a single-source-of-truth file at the bassclef-cli repo root. The publish workflow reads the pin at run time. The sync PR that advances the bassclef substrate also advances the pin — one file edit instead of three places in a YAML workflow.

## Primary actor

Release automation (GitHub Actions `publish` workflow).

## Preconditions

- Repo contains `.bassclef-pin` at root with a single-line git tag (e.g., `v1.11.0`).
- Tag exists on `sunj-labs/bassclef` and is reachable via the fine-grained PAT the publish workflow carries.

## Main flow

1. Operator triggers `publish` via a GitHub release OR workflow dispatch.
2. Checks job starts. Steps 1-6 run as today (resolve tag, checkout cli repo, setup Node, npm ci, validate tag, build).
3. New step reads `.bassclef-pin` into `BASSCLEF_PIN` env var exposed to subsequent steps.
4. Next step (previously hardcoded) checks out `sunj-labs/bassclef` at `${{ env.BASSCLEF_PIN }}` into `./bassclef/`.
5. Assertion step verifies the resolved tag equals `$BASSCLEF_PIN` (not a hardcoded string).
6. Remaining steps run as today — bundle via prepublish, run tests, exit.
7. Publish job gated on checks job success. Repeats the same read-pin step after rebuild, before sibling checkout.

## Postconditions

- Both jobs land the SAME substrate tag (both read the same file).
- A sync PR that advances `.bassclef-pin` from `vX.Y.Z` to `vX.Y+1.0` moves BOTH jobs atomically.
- The 3 L136 / L151 / L281 hardcoded `v1.8.0` references at `.github/workflows/publish.yml` no longer exist.

## Extensions

**E1 — pin file missing**: workflow fails at the read step with explicit message naming the file + its expected shape. Reversible via commit.

**E2 — pin value does not match a tag on sunj-labs/bassclef**: checkout step fails with GitHub's native unknown-ref message. Operator fixes the pin file + retriggers.

**E3 — pin file has junk content (multi-line, whitespace, blank)**: read step trims and validates against `v[0-9]+\.[0-9]+\.[0-9]+` shape; fails loud when the shape does not match.

## Verification

- Tier 0 test `scripts/tests/bassclef-pin.test.sh` asserts: `.bassclef-pin` exists, parses as a single tag line, matches the shape regex. Asserts `.github/workflows/publish.yml` contains NO hardcoded `v[0-9]+\.[0-9]+\.[0-9]+` after `ref:` in sibling checkouts.
- Post-merge: operator triggers a trial run via workflow dispatch; checks job output confirms resolved tag = pin.

## Patterns applied

- Externalized configuration — pin moves out of workflow code
- Information hiding (Parnas) — workflow does not know what version it ships; pin owns that fact
- Single source of truth (Nygard) — one file feeds both jobs

## References

- cli#188 (open) — this ticket's parent; recommended shape B
- cli#438 (open) — stale pin drift at root; closes with pin bump to v1.11.0 + this cure
- cli#439 (new) — dev-repo bassclef-version.json; reads from `.bassclef-pin` for same-source consistency
- `.github/workflows/publish.yml` — the workflow this UC refactors
- ADR-004 — publish pipeline safety contract (honored; mechanism refactor only)
- ADR-007 — pin-at-checkout decision (honored; §Acceptance delta carries a one-line amendment pointing at `.bassclef-pin`)
