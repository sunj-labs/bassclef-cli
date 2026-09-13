---
tier: lite
title: Risk ledger — cli#25 Phase 2 publish workflow
goal: 2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite
authored: 2026-09-13
authored_by: agent
premortem_mode: light
lenses:
  - michael-nygard
  - michael-feathers
  - linus-torvalds
---

# Risk ledger — cli#25 Phase 2 publish workflow

## Method

Klein workshop shape, light mode. Three luminary lenses × three risks per lens. Phase 2 ships code (prepublish script + workflow + tests) + docs.

## Nygard lens — fail-fast at each build step

**N1 — Public bassclef tag v0.39.0 disappears or gets force-pushed.**

- Class: pinned tag reference breaks at CI time
- Falsifier: public bassclef v0.39.0 tag exists at SHA `38f906e9`; tag deletion or force-push would show as a mismatch in `gh api /git/refs/tags/v0.39.0`
- Cure: Step 2 workflow adds a tag-existence assertion after checkout. Fail with a specific message naming the tag pin.
- Fold into: Step 2 procedure.

**N2 — Inline build produces silent-empty `dist/lite/`.**

- Class: filter output is empty (no manifest entries match `tier ≤ lite`); silent success
- Falsifier: manifest at v0.39.0 has ~62 lite-tier entries per ADR-055 §Context "The manifest is now the substrate's authored source of truth"
- Cure: Step 1 script asserts `dist/lite/.claude/settings.json` hooks entries count ≥ 10 before continuing. Fail with a specific remediation (check manifest tier tags).
- Fold into: Step 1 procedure.

**N3 — Templates missing from public bassclef at v0.39.0.**

- Class: `presence/dist-templates/` incomplete (missing 1+ of the 4 files)
- Falsifier: public bassclef v0.39.0 `presence/dist-templates/` exists per `gh api` earlier this session (README + brand + cli + dist-templates + install; 4 template files under dist-templates confirmed via bassclef-upstream build script L58-63)
- Cure: Step 1 script asserts all 4 template files exist before copy. Fail with a specific remediation.
- Fold into: Step 1 procedure.

## Feathers lens — characterization tests

**F1 — Existing 232 tests break because they reference `substrate/` file counts or paths.**

- Class: Tier 0 tests characterize current substrate-only shape; new dist/lite/ addition may drift test expectations
- Falsifier: tests/harness/prepublish-bundle.test.ts + tests/init.test.ts + tests/sync.test.ts all reference substrate/ paths per current shape; dual-write preserves substrate/ unchanged
- Cure: Step 1 script's dual-write preserves substrate/ output exactly; new dist/lite/ output is additive. Step 6 tests only ADD new assertions.
- Fold into: Step 1 procedure + Step 6 procedure.

**F2 — Beck RED-first not honored for new inline build logic.**

- Class: Steps write source before test; test-tier-enforce hook may BLOCK the commit; discipline violation
- Falsifier: `.claude/rules/testing-tier-config.md` puts `.github/workflows/*.yml` + `scripts/*.mjs` at Tier 1 (WARN); the strict hook fires only on Tier 0 (`.claude/hooks/*.sh` + `lib/*.sh` + state-spine schemas). Prepublish script is at Tier 1 per this classification.
- Cure: Step 6 tests still ship in same PR to satisfy Feathers characterization. Order: Steps 1 → 6 (source before test); test presence at commit time satisfies Tier 1 WARN.
- Fold into: Step 6 procedure notes the Tier 1 classification.

**F3 — Tarball dry-run assertion regresses under new dist/lite/ shape.**

- Class: `.github/workflows/publish.yml` L156-179 "Assert substrate/ present in tarball" step reads pack.json; new dist/lite/ files may shift the substrate/ count or the pack.json shape
- Falsifier: substrate/ count filter uses `startsWith('substrate/')` (L173); dist/lite/ files match `startsWith('dist/lite/')` — no overlap
- Cure: Step 2 workflow extends the existing assertion to ALSO check dist/lite/ count; existing substrate/ assertion preserved unchanged.
- Fold into: Step 2 procedure.

## Torvalds lens — adopter invariant preservation

**L1 — Current @thebassclef/lite@0.1.3 adopters break on upgrade to 0.2.0.**

- Class: upgrade path silently changes adopter behavior
- Falsifier: cli code in 0.2.0 still reads substrate/ (Phase 3 flips the reader); dist/lite/ addition is invisible to the current cli code
- Cure: Step 3 version bump is MINOR (0.1.3 → 0.2.0) per additive changes. Step 5 ADR-007 D1 amendment names dist/<tier>/ as SECOND accepted path (additive; substrate/ preserved).
- Fold into: Step 3 procedure + Step 5 procedure.

**L2 — Files array whitelist over-includes and ships accidental source.**

- Class: adding `dist/lite/**` to files array pulls in unintended files (e.g., dist/lite/.DS_Store)
- Falsifier: ADR-001 files whitelist is strict per glob; only files matching the whitelist ship
- Cure: Step 3 uses `dist/lite/**` glob; Step 1 inline build produces only the 5 named files under dist/lite/; andon scan in workflow L152 catches any operator-private paths.
- Fold into: Step 3 procedure.

**L3 — MINOR bump 0.2.0 confuses adopters expecting 0.1.4 patch.**

- Class: version-bump discipline mismatch; adopter expects patch not minor
- Falsifier: package.json shipped `substrate/` only through 0.1.3; adding dist/lite/ is a new user-visible feature per Keep a Changelog conventions
- Cure: Step 3 version bump documented in commit message + PR body. Note: cli#25 body Acceptance line names "0.0.3 or 0.1.0 per semver per what the ship carries" — 0.2.0 fits the same shape after cascading version bumps since #25 was filed.
- Fold into: Step 3 procedure + PR body.

## Strongest concerns folded into the plan

- **N2** — Step 1 script asserts dist/lite/.claude/settings.json hook count ≥ 10 before continuing
- **F1** — Step 1 dual-write preserves substrate/ output exactly; Step 6 tests only ADD new assertions
- **L1** — Step 3 MINOR bump; Step 5 ADR-007 D1 amendment additive
- **N1** — Step 2 workflow asserts v0.39.0 tag exists after checkout

## Refs

- Goal doc — `docs/iteration-bets/2026-09-13b-cli-25-phase-2-publish-workflow-dist-lite.md`
- ADR-055 (bassclef-upstream) — reader-side contract D1
- ADR-007 (cli-side) — bundle path D1 (Phase 2 amends)
- ADR-001 (cli-side) — files whitelist (Phase 2 amends)
- Klein — *Sources of Power* (MIT Press, 1998) — pre-mortem method
- @luminary michael-nygard — fail-fast lens
- @luminary michael-feathers — characterization tests lens
- @luminary linus-torvalds — adopter contract lens
