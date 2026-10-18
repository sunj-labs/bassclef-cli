---
ticket: cli#439
sister_tickets: [cli#188, cli#411, cli#438]
luminaries:
  primary: [linus-torvalds]
  supporting: [tony-hoare, david-parnas, michael-feathers]
tier: brief
---

# UC-script-439 — dev-repo bassclef-version.json

## Scope

Write `bassclef-version.json` at the bassclef-cli repo root. Content tracks `.bassclef-pin` (cli#188). The statusline resolver's first non-env candidate (`$cwd/bassclef-version.json`) wins; dev-repo statusline stops depending on sibling freshness or adjacent checkouts in HOME.

## Primary actor

Operator (dev-repo statusline reader at session time); release automation at pin-bump time.

## Preconditions

- Repo contains `.bassclef-pin` at root (cli#188).
- Sibling bassclef checkout exists at `$HOME/src/sunj-labs/bassclef/` OR `BASSCLEF_SIBLING_ROOT` points at an alternative path.
- Sibling checkout's `bassclef-version.json` holds `.version` equal to the pin value.

## Main flow

1. Operator (or script) edits `.bassclef-pin` to a new tag like `v1.11.0`.
2. Operator runs `node scripts/sync-bassclef-version.mjs`.
3. Script reads `.bassclef-pin`, validates shape, reads sibling `bassclef-version.json`, verifies sibling `.version` matches pin.
4. Script writes `bassclef-version.json` at repo root with the sibling's version object verbatim.
5. Commit both files in the same PR so main carries them consistent.
6. Session-start statusline reads the local file; shows the pinned version.

## Postconditions

- `bassclef-version.json` at repo root carries `.version` equal to `.bassclef-pin` content.
- Dev-repo statusline resolver chain hits `$cwd/bassclef-version.json` (candidate #2 after `BASSCLEF_VERSION_FILE` env) and never falls back to sibling or adjacent checkout.
- Tier 0 test asserts `.version` matches `.bassclef-pin` on every run.

## Extensions

**E1 — sibling missing**: script exits 2 with explicit message; operator sets `BASSCLEF_SIBLING_ROOT` or clones sibling.

**E2 — pin ahead of sibling**: script exits 3 with explicit message; operator fetches the new tag in sibling first OR rolls the pin back.

**E3 — re-run with no change**: script reports "already current" and exits 0 (idempotent).

## Verification

- Tier 0 test `scripts/tests/sync-bassclef-version.test.sh` asserts: file exists, parses JSON, `.version` matches pin, has the 5 expected top-level keys, script is idempotent.
- Live verify: pipe a Claude Code session JSON into `~/.claude/bassclef-statusline.sh` with `cwd` pointing at bassclef-cli; output should show the pinned version.

## Patterns applied

- Information hiding (Parnas) — statusline reader doesn't know the pin lives in `.bassclef-pin`; it reads the version file.
- Single source of truth (Nygard) — `.bassclef-pin` is the source; `bassclef-version.json` at root is a projection the statusline sees.
- Idempotent operation — re-runs are safe; byte-identical content is a no-op.

## References

- cli#439 — this UC's parent ticket
- cli#188 — structural root (dynamic pin); this UC depends on it
- cli#411 (closed) — sister cure at adopter-workdir surface via `bassclef init`
- cli#438 — stale pin at root (closes with v1.11.0 pin bump)
- `scripts/sync-bassclef-version.mjs` — the sync helper
- `~/.claude/bassclef-statusline.sh` lines 44-56 — the resolver chain this cure feeds
