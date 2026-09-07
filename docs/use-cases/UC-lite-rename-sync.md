---
tier: lite
uc: UC-lite-rename-sync
title: Adopter installs @thebassclef/lite for the first time
format: cockburn-brief
actor_primary: Sam (bassclef adopter installing lite tier for the first time)
actor_secondary: Existing @thebassclef/core adopter migrating to lite
scope: bassclef-cli npm publish + adopter install path
level: user-goal
authored: 2026-09-07
goal: 2026-09-07-lite-rename-sync-publish
references:
  - {type: parent_goal, id: docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md, anchor: authoring goal}
  - {type: parent_bet, id: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md, anchor: predecessor goal — @thebassclef/core distribution}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-07-lite-rename-sync.md, anchor: pre-mortem — extensions cover top-3 risks}
---

# UC-lite-rename-sync — Adopter installs @thebassclef/lite

## Preconditions

- `@thebassclef/lite@0.1.0` published to npm with provenance
- `@thebassclef/core@0.1.1` deprecated with migration message
- Adopter has Node ≥ 20 and npm ≥ 10

## Main success scenario

1. Adopter runs `npm install -g @thebassclef/lite`
2. npm downloads `@thebassclef/lite@0.1.0` tarball
3. Adopter runs `bassclef init` in their project directory
4. `bassclef init` writes `.claude/settings.json` + `substrate.config.md` + `.bassclef/init.manifest.json`
5. Adopter runs `bassclef sync` after future substrate refreshes; adopter repo picks up upstream updates

Outcome: adopter has a working lite-tier bassclef in ≤ 5 minutes.

## Extensions

**3a — Existing @thebassclef/core adopter runs `npm install`**
- 3a1: npm surfaces deprecation message: "use @thebassclef/lite"
- 3a2: Adopter runs `npm uninstall -g @thebassclef/core && npm install -g @thebassclef/lite`
- 3a3: Resume from step 3

**Cooper risk #1 — silent-install adopter never sees deprecation**
- Adopter installed `@thebassclef/core` once and never ran `npm install` again
- Session-start hook (out of scope; follow-on ticket) surfaces BLOCKED item when `.bassclef-source.json` still references core

**Saltzer risk #1 — publish blocks on tarball audit finding operator-private path**
- Extension at Step 4 (pre-publish tarball audit): dry-run tarball listing contains `operator-private/` or `chronicle/` path
- Publish HALTS; operator reads audit output; tightens `files` array in package.json; re-runs audit
- Publish proceeds only after zero operator-private paths confirmed

**Ousterhout risk #1 — copy-substrate reports "refused" or "errored" on synced bundle**
- Extension at Step 3 (extended validate): `copy-substrate --dry-run` on fresh clone returns non-zero refused or errored
- Diagnose which `entry.path` did not resolve; likely a renamed file in v1.5.0 manifest that lost its content-hash mapping
- Halt Step 4; either patch the sync (correct source SHA) or file upstream ticket; do not publish stale bundle

**Saltzer risk #2 — prepublishOnly script triggers on publish**
- npm publish command must run with `--ignore-scripts` if the bundle step is done separately
- If bundle step still runs via prepublishOnly, audit sync source pinned to upstream v1.5.0 git tag SHA (not moving branch)

## Postconditions (success)

- `@thebassclef/lite@0.1.0` in npm registry with provenance attestation
- `@thebassclef/core@0.1.1` deprecated with migration text on npm
- Tarball contains zero operator-private paths (audited)
- Coord ticket #51 Q1 status closed
- Session log written; whereami updated
- Bundled substrate at v1.5.0 (up from v1.2.19)

## Postconditions (failure)

- One or more publish steps halted; scope paused per session /temperance drift-trigger
- Rollback path — revert package.json rename PR; `@thebassclef/core@0.1.1` stays live as fallback
- No adopter migration signal until re-attempt

## Business rules

- Rename PR must ride with sync PR per memory `feedback_rename_must_ride_with_manifest_sync`
- Publish requires operator at keyboard for npm 2FA Touch ID per memory `reference_npm_2fa_is_touch_id`
- Publish workflow pins npm@11 per memory `feedback_npm_11_required_for_trusted_publisher`
- Files array whitelist controls what ships; `substrate/**` glob must not include operator-private paths
- Adopter compat window per ADR-031 — `@thebassclef/core` stays queryable via `npm view` after deprecation

## Refs

- Goal: `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md`
- Risk ledger: `docs/risk-ledgers/2026-09-07-lite-rename-sync.md`
- ADR-002 (init safety), ADR-003 (sync safety), ADR-005 (npm packaging), ADR-031 (we-don't-break-adopters)
- Cockburn, A. *Writing Effective Use Cases* (2000)
