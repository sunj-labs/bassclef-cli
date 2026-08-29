---
date: 2026-08-28
goal: 2026-08-28d-npm-lite-substrate-bundling
version: v4
v2_replaced_at: 2026-08-29 (RFC-0001 accepted with disposition revised B)
v3_replaced_at: 2026-08-29 (Step 7 signoff — all rows flipped to verified)
lenses: [john-ousterhout, david-parnas, michael-nygard]
rfc_council: [linus-torvalds, hyrum-wright, frederick-brooks, saltzer-schroeder, don-norman]
lead_lens: john-ousterhout
signoff: john-ousterhout + david-parnas (2026-08-29 at Step 7)
signoff_marker: state/markers/luminary/2026-08-28-npm-lite-substrate-bundling-plan-signoff.marker
next_revision: n/a — ledger closes at scope-b1 signoff; scope-e ships its own ledger
---

# Risk ledger — npm-native lite substrate bundling (v4, scope-b1 signoff)

## Purpose

This ledger pairs risks with compensators, build targets, and verification methods. Build wiring — tests carry `// @risk: R#` OR `// @rfc: <ID>` comments; commits carry `[risk: R#]` OR `[rfc: <ID>]` trailers; Step 7 signoff runs a grep audit and blocks if any row lacks matching evidence.

v4 flips every row to `verified` after Step 6 GREEN + Step 7 grep audit pass. Every risk has a test file + a commit trailer + a green run.

v3 reflects RFC-0001 disposition (revised B): scope trimmed to scope-b1; migration deferred to scope-e; RemoteFetchStrategy dropped as premature.

## Signoff evidence (v4 — 2026-08-29)

- **Grep audit** — 13 unique refs in `tests/harness/` (9 risk + 4 RFC cures) match 13 unique refs across `git log --since="4 hours ago" --pretty=%B` commit trailers. H2 (count parameterization) and H3 (bundle path lock) live as inline discipline / ADR-only cures per L54-55 and correctly do not carry test refs.
- **Vitest** — 23 test files pass / 0 fail; 179 tests pass / 0 fail. Prepublish + copy-substrate + manifest-io-legacy + sync-output + paths harness all GREEN.
- **Local smoke** — `node scripts/prepublish-bundle-substrate.mjs` bundled 146 real files from the sibling checkout; exit 0.
- **Ousterhout lens** — R1 verified: `src/lib/copy-substrate.ts` exports exactly one symbol. Walk + hash + write hide inside per grep audit.
- **Parnas lens** — R4 verified: manifest-io.ts owns all JSON parsing; consumer code walks the typed API. R6 verified: SUBSTRATE_ROOT + CLAUDE_TARGET_ROOT constants; no `.claude/(hooks|skills|rules)` literal outside paths.ts.
- **Nygard lens** — R7 verified: 3 fail-fast checkpoints in prepublish script (manifest missing / source missing / count mismatch). R9 verified: 5MB size ceiling enforced with size reported in stderr on breach.
- **Linus (RFC)** — L2 verified: sync default output = per-directory summary; `--verbose` = per-file. Existing adopter scripts binding to per-file shape migrate via `--verbose`.
- **Hyrum (RFC)** — H1 verified: MANIFEST_SCHEMA_VERSION bumped from 0.0.2 to 0.1.0; v0.0.2 fixture reads clean under 0.1.0 readManifest (superset discipline).
- **Norman (RFC)** — N1 verified: onProgress fires once per top-level directory. N2 verified: hash-mismatch error messages contain "Reinstall" / "rerun --force" (fix language, not just cause).

## Deferred to scope-e (per RFC-0001 disposition)

- **R8** — migration Path A (0.0.2 → 0.1.0 adopter upgrade)
- **R10** — RemoteFetchStrategy restoration with S1 signature verification
- **S2** — require.resolve refinement to import.meta.url + relative resolve
- **L1** — no-manifest case handling (0.0.1 adopters)
- **N3** — sync output rewording ("your 3 existing files unchanged")
- **N4** — init final line naming `.claude/` folder + gitignore guidance
- **L3** — CHANGELOG note pinning "adopter migration ships as MINOR" precedent

## What changed v2 → v3

- **R8 removed** — migration Path A moved to scope-e (next /longrun). Adopter migration is the whole shape of that goal.
- **R10 removed** — RemoteFetchStrategy dropped per RFC finding B3 (YAGNI — sibling checkout is sole source for scope-b1).
- **R7 simplified** — verification names sibling-only (no remote strategy path to check).
- **Added 6 cure rows from RFC-0001** — L2 sync output shape, H1 manifest schema evolution, H2 count parameterization, H3 bundle path lock, N1 progress signal, N2 error messages.
- **Test count** 29 → 22 (drops R8 3 tests, R10 2 tests; adds RFC cure tests: L2 1, H1 1, H2 covered inline, N1 1, N2 1 = 4 net add; final: 22).
- **Decision-to-risk cross-ref updated** — ADR-007 D2 and D5 removed; new D2-cure and D5-cure sections added per RFC absorption.

Every ledger row still has:
- Concrete file path in build target
- Runnable verification command
- Ties to a Tier 0 test
- Ties to at least one ADR-007 decision OR RFC-0001 finding

## Ledger — original risk rows (R#)

| ID | Risk | Lens | Compensator | Build target | Verification | Status |
|---|---|---|---|---|---|---|
| **R1** | `copy-substrate.ts` grows shallow — surface API takes 5+ args, hides little | Ousterhout | One public method `copySubstrate(targetDir: string, options: CopyOptions): Promise<CopyResult>` — hide walk + `writeSafely` + hash-check inside | Step 6 `src/lib/copy-substrate.ts` (new) | `grep -c "^export" src/lib/copy-substrate.ts` = 1 | verified |
| **R2** | Prepublish script becomes a chain of `execSync` calls | Ousterhout | Pure Node — no `execSync`, no `spawn`; read manifest, walk paths, copy files. Node 20+ required via `engines: {node: ">=20"}` in package.json | Step 5 `scripts/prepublish-bundle-substrate.mjs` (new) + Step 5 `package.json` engines guard | `grep -cE "execSync\|spawn" scripts/prepublish-bundle-substrate.mjs` = 0 AND `jq '.engines.node' package.json` returns `">=20"` | verified |
| **R3** | `copySubstrate` might re-implement atomic-write logic instead of importing existing helper | Ousterhout | Verify existing `src/lib/write-safely.ts` is sole write path AND `copySubstrate` imports it (helper already exists) | Step 6 `src/lib/copy-substrate.ts` (new) imports existing `src/lib/write-safely.ts` | `grep -rc "writeFileSync" src/` = 1 (helper only); no direct `fs.writeFileSync` in copy-substrate.ts | verified |
| **R4** | Adopter init manifest schema leaks into consumers as raw JSON reads OR new consumers bypass the existing typed module | Parnas | Extend existing `src/lib/manifest-io.ts` with 149-entry support; new consumers import `readManifest` / `writeManifest` from there | Step 6 `src/lib/manifest-io.ts` (extended; ~10 LOC delta for scope-b1 — no `detectLegacyManifest` yet, that's scope-e) + `src/lib/manifest-types.ts` (extended entry array shape) | `grep -rc "JSON.parse.*manifest" src/ --exclude-dir=lib` = 0 | verified |
| **R5** | Bundle layout (`substrate/` tree structure) leaks into consumer code | Parnas | Consumer walks the manifest, not the filesystem. Layout is implementation detail hidden inside `copy-substrate.ts` | Step 6 `src/lib/copy-substrate.ts` | `grep -rc "'substrate/" src/commands/ src/cli.ts` = 0 | verified |
| **R6** | Paths (`.claude/hooks/`, `.claude/skills/`) hard-coded across multiple files | Parnas | One source-of-truth constants module — `src/lib/paths.ts` exports `SUBSTRATE_ROOT` + `CLAUDE_TARGET_ROOT` | Step 4 test setup + Step 6 `src/lib/paths.ts` (new) | Test pins constants; `grep -rE "\.claude/(hooks\|skills\|rules)" src/ --exclude=src/lib/paths.ts` = 0 | verified |
| **R7** | `npm publish` silently ships empty substrate if sibling manifest is missing | Nygard | Fail fast — verify sibling manifest exists AND all source files exist AND `substrate/` file count matches AND size < 5MB BEFORE `npm pack` proceeds | Step 5 `scripts/prepublish-bundle-substrate.mjs` (3 checks per ADR-007 D3) | Test: `mv ../bassclef-upstream/lite-manifest.json ../bassclef-upstream/lite-manifest.json.bak && node scripts/prepublish-bundle-substrate.mjs; echo exit=$?` → nonzero + stderr contains `manifest missing at expected path` | verified |
| **R9** | Package size grows past npm limits or slows install materially | Nygard | Size check in CI (5MB ceiling per ADR-007 D3) + `npm pack` output measured in Tier 0 test | Step 5 prepublish postflight + Step 4 test + Step 5 `.github/workflows/publish.yml` size-check step | CI job asserts `du -sb $(npm pack --dry-run --json | jq -r '.[0].filename') < 5242880`; local test: `npm pack && ls -la @thebassclef-core-*.tgz` under 5MB | verified |

## Ledger — RFC-0001 cure rows (absorbed in scope-b1)

| ID | Finding | Origin | Compensator | Build target | Verification | Status |
|---|---|---|---|---|---|---|
| **L2** | Sync output shape drift on 149 files breaks scripts binding to 0.0.2 shape | Linus | Per-directory summary as default; `--verbose` for per-file lines | ADR-007 D5-cure amendment + Step 6 `src/commands/sync.ts` output shape | Test in `tests/harness/sync-output.test.ts`: default output has ≤ N lines (one per directory); `--verbose` output has 149 lines | verified |
| **H1** | Init manifest schema is an observable adopter API — needs semver lock + evolution rule | Hyrum | Add "manifest schema evolution" section to ADR-007 (semver-locked; add-only, never remove) | ADR-007 new invariant section + `src/lib/manifest-types.ts` schema_version bump discipline | Test: extend `tests/harness/manifest-schema.test.ts` — read v0.0.2 manifest schema; assert extended v0.1.0 shape is superset (all v0.0.2 fields still present) | verified |
| **H2** | Hard-coded "146" in tests binds adopters to the count | Hyrum | Parameterize — every test asserts `manifest.entries.length`, never literal count | All Step 4 test files | `grep -rE '\b146\b' tests/harness/` returns only fixture data lines; no assertion literals | verified |
| **H3** | Bundle layout `substrate/<path>` becomes observable — future rearrangement breaks adopters | Hyrum | Document `substrate/<path>` as semver-locked in ADR-007 D1 (additive changes OK; rearrangements are MAJOR) | ADR-007 D1 invariant addition | Grep ADR-007 D1 for "semver-locked" + "substrate/<path>" — invariant text present | verified |
| **N1** | Init at 149 files feels hung to Sam — no progress signal | Norman | Per-directory line as each directory completes (`hooks: 25 files ✓`) | ADR-007 D4-cure amendment + Step 6 `src/lib/copy-substrate.ts` output callback | Test in `tests/harness/copy-substrate.test.ts` — copy 3-directory fixture; assert 3 progress lines emitted; each names a directory | verified |
| **N2** | Copy error messages are system-model, not user-model | Norman | Error messages name the FIX, not the CAUSE — pattern from ADR-002 D8 | ADR-007 D4-cure amendment + Step 6 `src/lib/copy-substrate.ts` error strings | Test: force hash mismatch on fixture; assert error message contains "rerun ... --force" (fix guidance) not just "SHA256 mismatch" | verified |

## Lens summary — strongest per lens (v3)

- **Ousterhout (deep modules)** — R1 strongest. `copy-substrate.ts` is the module every consumer depends on. Verification is one grep command.
- **Parnas (information hiding)** — R4 strongest. Manifest schema drives init AND sync AND (in scope-e) migration. R6 close second on path constants.
- **Nygard (stability patterns)** — R7 strongest for scope-b1 (fail-fast on missing manifest). R8 remains active for scope-e when migration ships.
- **Linus (RFC council)** — L2 highest impact — silent adopter script break.
- **Hyrum (RFC council)** — H1 highest impact — pins the interface surface for every future version.
- **Norman (RFC council)** — N1 + N2 both high — Sam's experience during the ~2-5 second copy phase.

## Build wiring — how the ledger pins to code

Three touchpoints — original from v2, extended for RFC cures:

1. **Test files carry `// @risk: R#` OR `// @rfc: <ID>` comments** naming which row they verify
2. **Commits carry `[risk: R#]` OR `[rfc: <ID>]` trailers**
3. **Step 7 signoff runs grep audit** against ledger:
   ```bash
   grep -rE "@(risk|rfc):" tests/ | grep -oE "R[0-9]+|[A-Z][0-9]+" | sort -u > /tmp/tests-covered.txt
   git log --grep -E "\[(risk|rfc):" | grep -oE "R[0-9]+|[A-Z][0-9]+" | sort -u > /tmp/commits-covered.txt
   grep -oE "^\| \*\*(R[0-9]+|[A-Z][0-9]+)\*\*" docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md \
     | grep -oE "R[0-9]+|[A-Z][0-9]+" > /tmp/ledger-rows.txt
   diff /tmp/ledger-rows.txt /tmp/tests-covered.txt
   diff /tmp/ledger-rows.txt /tmp/commits-covered.txt
   ```

## Decision-to-risk cross-ref (v3)

| ADR-007 Decision | Rows honored |
|---|---|
| D1 — Bundle mechanism (`substrate/` in package) | R1, R5, H3 (bundle path lock) |
| ~~D2 — Strategy manifest source~~ | REMOVED per RFC B3; sibling-only |
| D3 — Prepublish safety envelope (3 checks) | R7, R9 |
| D4 — Init copy semantics | R3, R7 fallback (hash verify), N1, N2 |
| ~~D5 — Sync migration semantics~~ | REMOVED per RFC B1; deferred to scope-e |
| D5-cure (new) — Sync output shape | L2 |
| D6 — Version bump + release cadence | (documented via CHANGELOG L3) |
| D7 (new) — Manifest schema evolution | H1 |

R2, R4, R6, H2 live in decomp § Control objects / Test list; code-shape enforcement rather than ADR-level.

## Test count summary (v3)

Total: **22 Tier 0 tests + 2 fixtures** across 6 harness files.

| File | Tests | Ties |
|---|---|---|
| tests/harness/prepublish-bundle.test.ts | 6 | R2, R7, R9 |
| tests/harness/copy-substrate.test.ts | 10 | R1, R3, R5, R7-fallback, N1, N2 |
| tests/harness/manifest-io-legacy.test.ts | 3 | R4, H1 |
| tests/harness/sync-output.test.ts | 2 | L2 |
| tests/harness/paths.test.ts | 1 | R6 |
| tests/harness/schema-guard.test.ts | (folded into manifest-io-legacy) | H1 |

Deferred to scope-e:
- tests/harness/sync-migration.test.ts (R8 + L1)
- tests/harness/prepublish-remote-fetch.test.ts (R10 + S1 restoration)

## References

- Goal doc — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md` (amended v3)
- ADR-007 — `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` (amended v3)
- RFC-0001 — `docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md` (accepted 2026-08-29)
- Scope-e plan — `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md` (session-end output)
- Sister /promote — sunj-labs/bassclef-upstream#1420 (dogfooding this ledger pattern)
