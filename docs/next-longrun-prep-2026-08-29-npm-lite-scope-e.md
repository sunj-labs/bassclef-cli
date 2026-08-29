---
date: 2026-08-29
prepared_for: next /longrun session (scope-e — migration + follow-ons)
goal_slug: 2026-08-29-npm-lite-scope-e
tier: lite
parent_goal: docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md
sibling_docs:
  - docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md (accepted 2026-08-29 with revised B)
  - docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md (v3; R8 + R10 deferred here)
authoring_luminaries:
  primary: [linus-torvalds, john-ousterhout]
  supporting: [david-parnas, michael-nygard, alan-cooper, michael-feathers]
lead_lens: linus-torvalds
lead_lens_rationale: Migration is fundamentally an adopter-contract discipline. Linus lens leads; Ousterhout keeps the module deep.
---

# Next /longrun prep — npm-lite scope-e (migration + follow-ons)

## Sources read

- RFC-0001 disposition table (`docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md` § Disposition — this session)
- Ledger v3 (`docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` — R8 + R10 rows moved here as scope-e primary work)
- Goal doc 2026-08-28d scope amendment section — names scope-e as follow-on

## Problem

Goal 2026-08-28d ships `@thebassclef/core@0.1.0` without a migration path. Existing 0.0.2 adopters upgrading run `bassclef init --force` — works but overwrites their config file edits. Adopters on 0.0.1 (name reservation) hit no-manifest case and get no upgrade path at all. Scope-e closes both gaps and restores the remote fetch option for CI.

## Goal (scope-e)

Ship `@thebassclef/core@0.1.1` OR add `bassclef migrate` subcommand — decide at prep. Whichever ships, adopters on 0.0.1 OR 0.0.2 upgrade to the 0.1.0-substrate shape without data loss. Restore `BASSCLEF_MANIFEST_URL` remote fetch strategy with signature verification for CI + fresh machine scenarios.

## What scope-e ships

**Migration path (RFC B1 + L1):**
- `detectLegacyManifest()` in `src/lib/manifest-io.ts` — returns `current` / `legacy-3-entry` / `no-manifest`
- Path A migration in `sync.ts` — legacy 3-entry adopters get 146 new files added; 3 existing config files preserved with computed SHA-256 hashes
- Path B init dispatch — no-manifest adopters get full 149-file init (no config files present)
- `computeConfigHashes()` — SHA-256 for existing 3 config files during migration
- `docs/migrations/0.1.1.md` — adopter-facing upgrade doc
- Sync output shape: `146 files added; 3 files preserved with existing content; N refused (already present)` — user-model language per N3

**Remote fetch restoration (RFC B3 + S1):**
- `RemoteFetchStrategy` in prepublish script — restored for CI scenarios
- Signature verification: only allow URLs matching `https://raw.githubusercontent.com/sunj-labs/bassclef-upstream/refs/tags/v*/lite-manifest.json` (S1 cure — narrow attack surface)
- Retry-with-backoff for R10 rate limits — max 3 attempts, exponential
- Auth header when `GITHUB_TOKEN` env set

**Refinements (RFC S2 + N3 + N4):**
- Use `import.meta.url` + relative path resolution instead of `require.resolve` in copy-substrate (S2)
- Sync output "3 files preserved with computed hashes" → "Your 3 existing files unchanged" (N3)
- Init final line naming the `.claude/` folder + gitignore guidance (N4)

**CHANGELOG entry (RFC L3):**
- 0.1.1 CHANGELOG names the "adopter migration ships as MINOR" precedent explicitly

## Options for scope-e

**Option a — Ship as 0.1.1 patch** (~150-200 turns)
- Migration Path A wrapped into `bassclef sync` per original ADR-007 D5
- Adopters run `bassclef sync` and it detects legacy + migrates
- Small; ships fast; keeps sync as the single upgrade command

**Option b — Ship `bassclef migrate` subcommand** (~200-250 turns)
- New command with dedicated safety envelope + interactive prompts
- Explicit adopter action; scriptable; auditable
- Adds one new CLI surface; more testing

**Option c — Both (0.1.1 sync auto-migrate + `bassclef migrate` explicit)** (~250-300 turns)
- Belt + suspenders
- Adopters can pick their upgrade shape

Recommendation at prep time: pending — depends on how many 0.0.2 adopters land during scope-b1 window + operator preference on adopter agency.

## Time budget for scope-e

- Option a: 150-200 turns
- Option b: 200-250 turns
- Option c: 250-300 turns

All within a single /longrun. Fresh context runway.

## Compounding value per option

**Option a — 0.1.1 patch:**
- Where the payoff shows up (Compounding surface) — per-adopter-upgrade (each 0.0.2 install runs sync once)
- How often it fires (Compounding rate) — once per adopter over the 0.0.2 → 0.1.1 window
- What must be true first (Foundation prereq) — scope-b1 shipped (0.1.0 exists)
- Does this teach a shape later work reuses (Inverse-dependency) — yes (legacy detection pattern reuses in future schema evolutions)
- What breaks if we ship this half-done (Risk class) — medium (adopter data loss possible if hash preservation misses)

**Option b — `bassclef migrate` subcommand:**
- Where the payoff shows up (Compounding surface) — per-adopter-decision (adopter chooses when + whether)
- How often it fires (Compounding rate) — once per adopter, at their timing
- What must be true first (Foundation prereq) — scope-b1 shipped
- Does this teach a shape later work reuses (Inverse-dependency) — yes (subcommand pattern reuses for future migrations)
- What breaks if we ship this half-done (Risk class) — low (explicit adopter action; no surprise state change)

**Option c — Both:**
- Where the payoff shows up (Compounding surface) — per-adopter-choice (auto-migrate default, explicit override available)
- How often it fires (Compounding rate) — once per adopter through either path
- What must be true first (Foundation prereq) — scope-b1 shipped + design decision on defaults
- Does this teach a shape later work reuses (Inverse-dependency) — yes (both patterns reuse)
- What breaks if we ship this half-done (Risk class) — medium (both paths need testing; more surface)

## Acceptance (scope-e — TBD at prep)

- [ ] Adopter on 0.0.2 upgrades to 0.1.1 (or `bassclef migrate` command) without config file data loss
- [ ] Adopter on 0.0.1 upgrades cleanly (Path B init dispatch)
- [ ] `docs/migrations/0.1.1.md` documents the upgrade path
- [ ] Remote fetch Strategy restored with tag-URL whitelist + retry + auth header
- [ ] `require.resolve` refactored to `import.meta.url` + relative path
- [ ] All RFC MEDIUM findings absorbed (N3 sync output, S2 resolver)
- [ ] All RFC LOW findings absorbed (N4 folder guidance, L3 CHANGELOG note)
- [ ] Tier 0 tests GREEN (extends scope-b1 test set with sync-migration.test.ts + prepublish-remote-fetch.test.ts + others)

## Refs

- RFC-0001 (accepted; disposition revised B) — `docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md`
- Parent goal — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md` (scope-b1)
- Ledger v3 — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md`
- Grandparent goal — `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- Sister /promote at bassclef-upstream — #1420 (pre-mortem-to-compensator mapping pattern; this goal is a 2nd dogfood)
