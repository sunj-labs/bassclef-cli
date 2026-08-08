---
tier: standard
id: UC-script-publish
name: Publish a new @thebassclef/core version to npm
level: user goal
primary_actor: Maintainer
scope: bassclef-cli — `.github/workflows/publish.yml` + 3 scan scripts
authored: 2026-08-08
authored_by: agent
cockburn_ceremony: brief
bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
governs_source:
  - .github/workflows/publish.yml
  - scripts/validate-tag.mjs
  - scripts/andon-scan.mjs
  - scripts/tier-filter.mjs
references_adr: ADR-004-publish-pipeline-safety-contract.md
---

# UC-script-publish — Publish a new `@thebassclef/core` version to npm

## Scope

The publish pipeline shipped in WU-4. One GitHub Actions workflow + three Node scripts. Every published version flows through this path. No maintainer can publish from a laptop (trusted publisher config on npm blocks it).

## Level

User goal — maintainer ships a new version to adopters.

## Primary actor

Maintainer. Has a green working tree at the tag they want to publish. Has trusted publisher configured on npmjs.com. Has GitHub Environment `npm-publish` set up with themselves as required reviewer. Has passkey or YubiKey 2FA on both accounts.

## Main success scenario

1. Maintainer bumps `package.json` version via WU-5's bump script (`npm run bump patch|minor|major`).
2. Maintainer commits, tags (`git tag vX.Y.Z`), and pushes both the commit and the tag.
3. Maintainer creates a GitHub Release (`gh release create vX.Y.Z`).
4. GitHub fires a `release: published` event.
5. Actions workflow triggers on the event.
6. Workflow checks out the code at the tag ref.
7. `validate-tag.mjs` refuses if tag != `package.json` version, or if the tag is not reachable from `origin/main`. On refuse: workflow red, exit 1, nothing published.
8. Workflow runs `npm ci --ignore-scripts` — installs deps without running any install scripts.
9. Workflow runs `npm run build` — clean rebuild from source.
10. Workflow runs `npm test` and `npm run typecheck`.
11. Workflow runs `npm pack --dry-run --json` — produces the tarball file list.
12. `andon-scan.mjs` scans the tarball for operator-private terms. On match: workflow red, exit 2, nothing published.
13. `tier-filter.mjs` parses YAML frontmatter on each shipped file. Refuses on any file with `tier: upstream`. On match: workflow red, exit 3, nothing published.
14. Workflow requests approval on the `npm-publish` Environment.
15. Maintainer opens the workflow run page and clicks approve.
16. Workflow runs `npm publish --provenance --ignore-scripts` via trusted publisher. No `NPM_TOKEN` used.
17. npm accepts the publish + generates provenance attestation.
18. Workflow writes step summary with npmjs.com URL + provenance URL.

## Extensions (brief)

- **Tag has pre-release suffix** (e.g., `v0.5.0-rc.1`): workflow dispatches with `--tag next` instead of `--tag latest`. Same state machine.
- **Approver rejects or times out**: workflow cancels. Nothing published.
- **Any check refuses**: workflow red. Refusal message names three things — what failed, what value was found, what the maintainer should do to fix. Nothing published.
- **Trusted publisher not configured**: publish step fails with an auth error. Cure lives in `docs/publish-setup.md`.
- **`npm-publish` Environment not set up**: workflow pauses indefinitely waiting for approval that cannot happen. Cure lives in `docs/publish-setup.md`.

## Preconditions (brief)

- `docs/publish-setup.md` one-time setup completed: npm trusted publisher, GitHub Environment `npm-publish`, 2FA on both accounts.
- Version in `package.json` matches the tag being pushed.
- Tag is on a commit reachable from `origin/main`.

## Postconditions (brief)

- New version live on npmjs.com with provenance attestation.
- Adopters can `npm install -g @thebassclef/core@latest`.
- Workflow run page shows green with the two URLs.

## Special requirements

- Zero `NPM_TOKEN` reference anywhere. Trusted publisher only.
- Workflow permissions: `id-token: write` + `contents: read`. No `packages: write`, no `contents: write`.
- Workflow file path `.github/workflows/publish.yml` is a semver-locked invariant per ADR-004 K1. Renaming requires an ADR amendment AND an npm-side config change in the same coordinated release.

## Frequency

Every version bump. Roughly weekly during active development. Slower once the project stabilizes.

## Composes with

- ADR-004 pins the safety contract this UC implements.
- `docs/decompositions/wu-4-publish.md` covers the code-shape decomposition.
- `docs/interaction-design/2026-08-08-npm-distribution.md` covers arc-level state and sequence diagrams.
- `docs/publish-setup.md` covers the one-time maintainer setup.
- WU-5 (this branch) ships the bump script that step 1 uses.
