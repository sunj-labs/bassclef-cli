---
date: 2026-08-28
goal: 2026-08-28d-npm-lite-substrate-bundling
version: v1
lenses: [john-ousterhout, david-parnas, michael-nygard]
lead_lens: john-ousterhout
next_revision: v2 at Step 3.5 (after ADR-007 lands)
---

# Risk ledger — npm-native lite substrate bundling

## Purpose

This ledger extends the /pre-mortem light output. Each row pairs a named risk with a compensator, a build target, and a verification method. The build phase wires to it — tests carry `// @risk: R#` comments, commits carry `[risk: R#]` trailers, Step 7 signoff runs a grep audit and blocks if any row lacks matching evidence.

v1 (this file) carries the 9 risks from the pre-mortem light with placeholder file paths.

v2 (Step 3.5, after ADR-007 lands) fills in exact file paths + refines verification commands + confirms build-step assignment per risk.

## Ledger

| ID | Risk | Lens | Compensator | Build target | Verification | Status |
|---|---|---|---|---|---|---|
| **R1** | `copy-substrate.ts` grows shallow — surface API takes 5+ args, hides little | Ousterhout | One public method `copySubstrate(targetDir, manifest)` — hide walk + writeSafely + hash-check | Step 6 `src/lib/copy-substrate.ts` | `grep -c "^export" src/lib/copy-substrate.ts` = 1 | pending |
| **R2** | Prepublish script becomes a chain of `execSync` calls | Ousterhout | Pure Node/TS — no execSync; read manifest, walk paths, copy files | Step 5 `scripts/prepublish-bundle-substrate.mjs` | `grep -cE "execSync\|spawn" scripts/prepublish-bundle-substrate.mjs` = 0 | pending |
| **R3** | `init.ts` and Phase 2 duplicate atomic-write and path-scoping logic | Ousterhout | Extract shared `writeSafely` helper both paths call | Step 6 `src/lib/write-safely.ts` (new) + `src/commands/init.ts` (refactor) | `grep -rc "writeFileSync" src/` = 1 (helper only); no direct fs.writeFileSync outside helper | pending |
| **R4** | Adopter init manifest schema leaks into `init.ts` and `sync.ts` as raw JSON reads | Parnas | Wrap reads/writes in `src/lib/init-manifest.ts` returning typed objects | Step 6 `src/lib/init-manifest.ts` (new) | `grep -rc "JSON.parse.*manifest" src/ --exclude-dir=lib` = 0 | pending |
| **R5** | Bundle layout (`substrate/` tree structure) leaks into consumer code | Parnas | Consumer walks the manifest, not the filesystem; layout is implementation detail | Step 6 `src/lib/copy-substrate.ts` | `grep -rc "'substrate/" src/ --exclude-dir=lib` outside module = 0 | pending |
| **R6** | Paths (`SUBSTRATE_ROOT`, `CLAUDE_TARGET_ROOT`) hard-coded across multiple files | Parnas | One source-of-truth constants module — `src/lib/paths.ts` | Step 4 test setup + Step 6 module | Test pins constants; `grep -rE "\.claude/(hooks\|skills\|rules)" src/` outside `src/lib/paths.ts` = 0 | pending |
| **R7** | `npm publish` silently ships empty substrate if sibling manifest is missing | Nygard | Fail fast — verify manifest exists AND all 146 files present BEFORE copying | Step 5 `scripts/prepublish-bundle-substrate.mjs` | Test: rename sibling manifest to `.bak`; run `npm pack`; expect exit code ≠ 0 and stderr contains "manifest missing" | pending |
| **R8** | Adopter migration breaks — existing 3-file installs hit extended sync classifier on next `bassclef sync` | Nygard | Version bump 0.1.0 (minor per semver) + migration doc + sync-time legacy-manifest detection → migration path | Step 6 `src/commands/sync.ts` + `docs/migrations/0.1.0.md` (new) | Test: fresh temp dir → install v0.0.2 → `bassclef init` → install v0.1.0 → `bassclef sync` → assert no error, 3 config files preserved, 146 substrate files added | pending |
| **R9** | Package size grows past npm limits or slows install materially | Nygard | Size check in CI; `npm pack` output < 5MB (napkin: 146 text files ≤ 1MB total) | Step 4 CI check + Step 5 pack script | CI job asserts `du -sb $(npm pack --dry-run --json | jq -r '.[0].filename')` < 5MB; local test measures | pending |

## Lens summary — strongest per lens

Per @luminary consultation:

- **Ousterhout (deep modules)** — R1 strongest. If `copy-substrate.ts` grows shallow, every consumer inherits its complexity. One public method is the design contract.
- **Parnas (information hiding)** — R4 strongest. Manifest schema is the interface between build and adopter. Raw JSON reads outside a typed module leak the schema across every call site.
- **Nygard (stability patterns)** — R8 strongest. Adopter migration is the highest-blast-radius risk. A silent break on `bassclef sync` for existing 0.0.2 installs corrupts adopter state.

## Build wiring — how the ledger pins to code

Three touchpoints wire the ledger to code:

1. **Test files carry `// @risk: R#` comments** naming which risk they verify. Example:
   ```typescript
   // @risk: R7 — publish fails fast on missing manifest
   test('prepublish exits nonzero when sibling manifest absent', () => { ... })
   ```

2. **Commits carry `[risk: R#]` trailers** per compensator shipped. Example commit message:
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

All rows start `pending` in v1. Rows flip through the transitions across Steps 4-7. Step 7 signoff requires all rows at `verified`.

## Followup — /promote if pattern proves out

If this ledger pattern reduces defect leakage on bassclef-cli goal 2026-08-28d, /promote as a first-class /longrun output — see bassclef-upstream#1420 (filed this session).

## References

- Goal doc — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md`
- Plan doc — `docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md`
- Convention citation — `.claude/rules/compounding-sequence-fresh-analysis.md` L246 (risk-ledger folder precedent)
- Evolution ticket — sunj-labs/bassclef-upstream#1420 (pre-mortem-to-compensator mapping as first-class /longrun output)
- Anchor luminaries — `.claude/luminaries/john-ousterhout.md`, `.claude/luminaries/david-parnas.md`, `.claude/luminaries/michael-nygard.md`
