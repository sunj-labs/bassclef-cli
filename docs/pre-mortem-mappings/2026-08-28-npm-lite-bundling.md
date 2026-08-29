---
date: 2026-08-28
goal: 2026-08-28d-npm-lite-substrate-bundling
version: v2
v1_replaced_at: Step 3.5 (after ADR-007 D1-D6 landed)
lenses: [john-ousterhout, david-parnas, michael-nygard]
lead_lens: john-ousterhout
next_revision: v3 at Step 7 (signoff — flip all rows to `verified`)
---

# Risk ledger — npm-native lite substrate bundling (v2)

## Purpose

This ledger extends the /pre-mortem light output. Each row pairs a named risk with a compensator, a build target, and a verification method. The build phase wires to it — tests carry `// @risk: R#` comments, commits carry `[risk: R#]` trailers, Step 7 signoff runs a grep audit and blocks if any row lacks matching evidence.

## What changed v1 → v2

- **Row R10 added** — remote fetch Strategy rate limits (new risk from ADR-007 D2 opening the `BASSCLEF_MANIFEST_URL` path)
- **R2 refined** — build target path fixed at `scripts/prepublish-bundle-substrate.mjs`; verification adds `engines: {node: ">=20"}` guard in package.json
- **R7 refined** — verification now names the specific `prepublish` script command + expected stderr string
- **R8 refined** — compensator explicitly includes SHA-256 hash preservation for existing 3 config files during migration (Q4 from decomp resolved)
- **R9 refined** — verification names the CI job (`.github/workflows/publish.yml` size-check step) + local test command
- All 9 v1 rows: build target file paths confirmed against decomp § Control objects + ADR-007 D1-D6
- All 9 v1 rows: verification commands refined to be greppable + runnable

Every ledger row now has:
- Concrete file path in build target
- Runnable verification command
- Ties to a Tier 0 test in `docs/decompositions/2026-08-28-npm-lite-bundling.md` § Test list
- Ties to at least one ADR-007 decision

## Ledger

| ID | Risk | Lens | Compensator | Build target | Verification | Status |
|---|---|---|---|---|---|---|
| **R1** | `copy-substrate.ts` grows shallow — surface API takes 5+ args, hides little | Ousterhout | One public method `copySubstrate(targetDir: string, options: CopyOptions): Promise<CopyResult>` — hide walk + `writeSafely` + hash-check inside | Step 6 `src/lib/copy-substrate.ts` (new) | `grep -c "^export" src/lib/copy-substrate.ts` = 1 | pending |
| **R2** | Prepublish script becomes a chain of `execSync` calls | Ousterhout | Pure Node — no `execSync`, no `spawn`; read manifest, walk paths, copy files. Node 20+ required via `engines: {node: ">=20"}` in package.json | Step 5 `scripts/prepublish-bundle-substrate.mjs` (new) + Step 5 `package.json` engines guard | `grep -cE "execSync\|spawn" scripts/prepublish-bundle-substrate.mjs` = 0 AND `jq '.engines.node' package.json` returns `">=20"` | pending |
| **R3** | `init.ts` and Phase 2 duplicate atomic-write and path-scoping logic | Ousterhout | Extract shared `writeSafely` helper both paths call | Step 6 `src/lib/write-safely.ts` (new; extracted from init.ts) + `src/commands/init.ts` (refactor to import) | `grep -rc "writeFileSync" src/` = 1 (helper only); no direct `fs.writeFileSync` outside `src/lib/write-safely.ts` | pending |
| **R4** | Adopter init manifest schema leaks into `init.ts` and `sync.ts` as raw JSON reads | Parnas | Wrap reads and writes in `src/lib/init-manifest.ts`; return typed `InitManifest` objects | Step 6 `src/lib/init-manifest.ts` (new); consumers import `readInitManifest` + `writeInitManifest` | `grep -rc "JSON.parse.*manifest" src/ --exclude-dir=lib` = 0 | pending |
| **R5** | Bundle layout (`substrate/` tree structure) leaks into consumer code | Parnas | Consumer walks the manifest, not the filesystem. Layout is implementation detail hidden inside `copy-substrate.ts` | Step 6 `src/lib/copy-substrate.ts` | `grep -rc "'substrate/" src/commands/ src/cli.ts` = 0 (consumer code has zero literal references) | pending |
| **R6** | Paths (`.claude/hooks/`, `.claude/skills/`) hard-coded across multiple files | Parnas | One source-of-truth constants module — `src/lib/paths.ts` exports `SUBSTRATE_ROOT` + `CLAUDE_TARGET_ROOT` | Step 4 test setup + Step 6 `src/lib/paths.ts` (new) | Test pins constants; `grep -rE "\.claude/(hooks\|skills\|rules)" src/ --exclude=src/lib/paths.ts` = 0 | pending |
| **R7** | `npm publish` silently ships empty substrate if sibling manifest is missing | Nygard | Fail fast — verify manifest exists AND all 146 source files exist AND `substrate/` file count matches AND size < 5MB BEFORE `npm pack` proceeds | Step 5 `scripts/prepublish-bundle-substrate.mjs` (3 checks per ADR-007 D3) | Test: `mv ../bassclef-upstream/lite-manifest.json ../bassclef-upstream/lite-manifest.json.bak && node scripts/prepublish-bundle-substrate.mjs; echo exit=$?` → nonzero + stderr contains `manifest missing at expected path` | pending |
| **R8** | Adopter migration breaks — existing 3-file installs hit extended sync classifier on next `bassclef sync` | Nygard | Version bump 0.1.0 (minor per semver) + migration doc + sync-time legacy-manifest detection + SHA-256 hash computation for existing 3 config files preserved in new 149-entry manifest (Q4 resolved) | Step 6 `src/commands/sync.ts` (Path A migration) + `docs/migrations/0.1.0.md` (new) + `src/lib/init-manifest.ts` `detectLegacyManifest()` | Test in `tests/harness/sync-migration.test.ts`: fresh temp dir → v0.0.2 fixture init → v0.1.0 fixture sync → assert 146 files added AND 3 config file hashes preserved AND no data loss | pending |
| **R9** | Package size grows past npm limits or slows install materially | Nygard | Size check in CI (5MB ceiling per ADR-007 D3) + `npm pack` output measured in Tier 0 test | Step 5 prepublish postflight check + Step 4 `tests/harness/prepublish-bundle.test.ts` + Step 5 amendment to `.github/workflows/publish.yml` (new size-check step before publish) | CI job asserts `du -sb $(npm pack --dry-run --json | jq -r '.[0].filename') < 5242880` (5MB in bytes); local test: `npm pack && ls -la @thebassclef-core-*.tgz` under 5MB | pending |
| **R10** | Remote fetch Strategy hits GitHub raw content rate limits (~60 req/hr anonymous) — CI runs fail with HTTP 429 in busy windows | Nygard | Cache manifest per CI job (`actions/cache` keyed on manifest URL SHA) OR use authenticated GitHub API request when `GITHUB_TOKEN` available OR use tagged commit URL with 24h cache | Step 5 `scripts/prepublish-bundle-substrate.mjs` — RemoteFetchStrategy adds retry-with-backoff + auth-header when env present | Test in `tests/harness/prepublish-bundle.test.ts`: mock HTTP 429 response → script retries with backoff (max 3 attempts, exponential); mock HTTP 200 with auth header when `GITHUB_TOKEN` set | pending |

## Lens summary — strongest per lens (v2 reconsidered)

Per @luminary consultation after ADR-007 landed:

- **Ousterhout (deep modules)** — R1 strongest. `copy-substrate.ts` is the module every consumer depends on. One public method is the design contract. Verification is one grep command; audit is mechanical.
- **Parnas (information hiding)** — R4 strongest. Manifest schema wraps drive init AND sync AND migration. Raw JSON reads outside the module leak schema across 3 call sites minimum. R6 close second — path constants have similar leak potential across 5+ modules.
- **Nygard (stability patterns)** — R8 strongest (unchanged from v1). Adopter migration is highest blast risk. R10 close second — new risk from D2 remote strategy path; less blast but real for CI users.

## Build wiring — how the ledger pins to code

Three touchpoints wire the ledger to code (per bassclef-upstream#1420):

1. **Test files carry `// @risk: R#` comments** naming which risk they verify. Example:
   ```typescript
   // @risk: R7 — publish fails fast on missing manifest
   test('prepublish exits nonzero when sibling manifest absent', () => { ... })
   ```

2. **Commits carry `[risk: R#]` trailers** per compensator shipped. Example:
   ```
   feat(prepublish): fail fast on missing sibling manifest [risk: R7]
   ```

3. **Step 7 signoff runs grep audit** — cross-check ledger against tests + commits:
   ```bash
   grep -r "@risk:" tests/ | grep -oE "R[0-9]+" | sort -u > /tmp/tests-covered.txt
   git log --grep "\[risk:" | grep -oE "R[0-9]+" | sort -u > /tmp/commits-covered.txt
   grep -oE "^\| \*\*R[0-9]+\*\*" docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md \
     | grep -oE "R[0-9]+" > /tmp/ledger-risks.txt
   diff /tmp/ledger-risks.txt /tmp/tests-covered.txt  # empty = all risks tested
   diff /tmp/ledger-risks.txt /tmp/commits-covered.txt  # empty = all risks committed
   ```

Any risk without a matching test AND commit blocks signoff at Step 7 (MUST per goal doc acceptance).

## Status transitions

- `pending` — risk named; no compensator shipped yet
- `in-progress` — test written (Beck RED); compensator source in flight
- `shipped` — compensator source committed with `[risk: R#]` trailer; test GREEN
- `verified` — Step 7 grep audit confirms ledger row has matching test + commit; signoff clears row

All 10 rows currently at `pending`. Rows flip through the transitions across Steps 4-7. Step 7 signoff requires all rows at `verified`.

## Decision-to-risk cross-ref (v2)

Every ADR-007 decision maps to at least one risk row. Every risk row maps to at least one ADR-007 decision.

| ADR-007 Decision | Risk rows honored |
|---|---|
| D1 — Bundle mechanism (`substrate/` in package) | R1 (one method) + R5 (walks manifest not filesystem) |
| D2 — Strategy manifest source | R7 (fail-fast) + R10 (remote rate limits) |
| D3 — Prepublish safety envelope (3 checks) | R7 (missing manifest) + R9 (size ceiling) |
| D4 — Init copy semantics | R3 (shared writeSafely) + R7 fallback (hash verification) |
| D5 — Sync migration semantics (Path A) | R8 (adopter migration + hash preservation) |
| D6 — Version bump + release cadence | R8 (migration doc names version explicitly) |

Rows R2 (no execSync) + R4 (typed manifest module) + R6 (path constants) live in decomp § Control objects. They're code-shape enforcement rather than ADR-level adopter contract, so they don't map to ADR-007 decisions but do map to Tier 0 tests.

## Test count summary (unchanged from decomp)

27 Tier 0 tests + 2 fixtures across 5 harness files. Each carries `// @risk: R#`. Signoff runs grep audit against this ledger.

Test additions for R10 (v2 new):
- `tests/harness/prepublish-bundle.test.ts` gains 2 tests (rate limit retry + auth header)
- Test count becomes **29 tests + 2 fixtures**

## Followup — /promote if pattern proves out

If this ledger pattern reduces defect leakage on bassclef-cli goal 2026-08-28d, /promote as a first-class /longrun output — see bassclef-upstream#1420 (filed this session).

## References

- Goal doc — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md`
- Decomposition — `docs/decompositions/2026-08-28-npm-lite-bundling.md` § Control objects + Test list
- ADR — `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` § Decision + Traceability
- Plan doc — `docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md`
- Convention citation — `.claude/rules/compounding-sequence-fresh-analysis.md` L246
- Evolution ticket — sunj-labs/bassclef-upstream#1420
- Anchor luminaries — `.claude/luminaries/john-ousterhout.md`, `.claude/luminaries/david-parnas.md`, `.claude/luminaries/michael-nygard.md`
