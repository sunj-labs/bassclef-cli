---
plan_id: 2026-09-22-bassclef-v1.2.0-sync
created: 2026-09-21T23:22:00Z
opens_from: docs/session-logs/2026-09-21d-oauth-token-wiring.md
target_release: cli v1.5.2 or v1.6.0 (operator picks jump size)
substrate_pin_from: v1.1.1
substrate_pin_to: v1.2.0
substrate_release_url: https://github.com/sunj-labs/bassclef/releases/tag/v1.2.0
---

# Next session — sync bassclef substrate v1.1.1 → v1.2.0

## Problem

Bassclef substrate v1.2.0 shipped upstream at 2026-09-21T22:32Z. Seven cures land: statusline tarball fallback (upstream #1860 → this repo's PR #181 unblocked), T3 inode-check portable (#1877), release-script target-dirty guard (#1878), classifier JSON label (#1880), adopter-simulator Assertion 5 source-graph closure (#1866), Assertion 6 tarball ref fidelity (#1875), walker regex-metachar reject (#1889). This repo pins substrate at v1.1.1 in `publish.yml` and bundles substrate at build time. Adopters see no cures until we sync + republish.

## Recommended session sequence

### Step 1 — sync substrate pin (converged; ~30 turns)

Mirror the pattern from PR #190 (v1.1.0 → v1.1.1 sync). Files that carry the substrate version:

1. `.github/workflows/publish.yml` — 6 `bassclef-source-ref` refs (grep to find all)
2. `package.json` — bump version (1.5.1 → 1.5.2 patch OR 1.6.0 minor per operator judgment)
3. `src/index.ts` — VERSION constant
4. `README.md` — install snippet
5. `CHANGELOG.md` — new section

Use `npm run bump` per memory `feedback_use_npm_run_bump_not_hand_edit` — the script touches all four version-carrying files together.

### Step 2 — merge PR #181 (statusline tarball bundling)

Waiting on upstream #1860 which now shipped. Merge PR #181 first so the tarball bundles both dispatcher scripts + version file. Order: #181 → sync PR → tag → publish.

### Step 3 — release cascade

Tag → publish workflow → Touch ID at npm-publish environment gate → sigstore log → registry propagation. Expect ~3-minute registry lag before `npm install -g @thebassclef/lite@X.Y.Z` resolves. Refer to memory `reference_npm_publish_verification_gotchas.md`.

### Step 4 — docker harness verify

Rebuild `bassclef-cli-cold-adopter` image against the new tarball. Confirm cold install lands 27 skills → 40+ skills (whatever v1.2.0 ships) + hook count matches manifest. This runs against real npm, not local file, so wait for registry propagation.

### Step 5 (optional) — adopter-sim Assertion 5 + 6

Two new opt-in assertions ship in v1.2.0:

- Assertion 5 — source-graph closure walker (`ADOPTER_SIM_SOURCE_GRAPH=1`)
- Assertion 6 — tarball ref fidelity (`ADOPTER_SIM_TARBALL_PATH` + `ADOPTER_SIM_EXPECTED_TAG`)

Enabling both catches the class cli #186 caught by chance. Belt-and-suspenders with the existing pre-publish version-marker check.

## Loose ends carried in

- **PR #203** — `feat/199-riff-chain-semantics` open with both CI checks GREEN; mergeable UNKNOWN pending GitHub recompute after #204 landed. Merge or defer.
- **Local main hygiene** — 3 auto-save checkpoints on top of what shipped in #204: `f70e465`, `e443014`, `ec1f2f9`. Content is superseded WIP. Options: `git reset --hard origin/main` (destructive, needs OK), `git pull --rebase origin main` (harmless clutter), or leave alone.
- **Ticket #184** — closed by PR #204 merge. Confirm the auto-close fired.

## Loose ends carried out

- Epic #199 Story 2+ — `/riff` HTML end-to-end proof through docker harness. OAuth path proven, just needs a bigger time budget for the 5 sub-calls `/riff` runs. Wait for API cap reset 2026-10-01 or use OAuth to unblock sooner.
- Adopter-sim Assertion 5 + 6 enablement — additive but nice-to-have.

## Turn estimate

Grounded per prior sync sessions:

- 2026-09-21 (v1.1.0 → v1.1.1 sync): ~380 turns including publish failures + fix cycle
- 2026-09-20c (v1.2.0-cli release cascade): ~120 turns clean cycle

Range: **100-200 turns** for a clean sync + publish. Wider top of range if the publish workflow surfaces a new class (like #191 did on Sep 21 — src/index.ts + README markers stale after package.json bump; that class is now covered by `npm run bump`).

## Anchor luminaries

- **Linus Torvalds (lead)** — adopter contract. Every sync preserves working setups. New substrate cures ride on top; nothing breaks.
- **Michael Nygard** — release-cascade stability. Fail-forward at each step; no partial state.
- **Kent Beck** — TDD if any code change surfaces. Otherwise the sync is data-only.

## Refs

- Bassclef substrate v1.2.0 release notes: https://github.com/sunj-labs/bassclef/releases/tag/v1.2.0
- Prior sync session log: `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md`
- Related open PR: #181 (statusline tarball bundling)
- Ticket that just closed: #184 (OAuth token wiring)
