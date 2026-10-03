# Session 2026-10-03b — cli#295 bundle sync + cli#294 driver stack

## What shipped

Seven PRs merged tonight, all tied to the Kunal #2036 adopter-cure cascade.

| PR | Scope | Squash SHA |
|---|---|---|
| #297 | cli#295 bundle sync — bassclef pin v1.6.5 → v1.7.0 + cli v1.9.9 release notes | `32976ab` |
| #298 | cli#294 driver 1 — trace-log-privacy (Kunal #1 + #5) | `1e1f8d8` |
| #299 | cli#294 driver 2 — build-against-template (Kunal #2 + #3) | `be236ae` |
| #300 | cli#294 driver 3 — state-under-zsh (Kunal #6) | `34c9aa6` |
| #301 | cli#294 driver 4 — env-reach-override (Kunal #4) | `57267a5` |
| #302 | cli#294 driver 5 — onboard-free-tier-403 (Kunal #9) | `f54409e` |
| #303 | E2E cascade prototypes — /onboard-repo + /build + plan doc | `2e74219` |

Tag `v1.9.9` pushed at `32976ab`. 7 of 8 Kunal cures now have cli-side regression anchors at the file-grep layer. 2 of those cures (findings #2/#3 + #9) also have E2E cascade prototypes.

Upstream ticket filed: **bassclef-upstream#2049** — adopter-sim-test notification protocol when SKILL body changes. Names 3 cure options (manifest field, release checklist, adopter manifest). Operator ask: cli (adopter) must get notified when any skill changes in substrate so adopter-sim tests can be updated appropriately.

## Decisions landed

- **Pin shape: semver v1.7.0, not SHA.** Prep opened with a planned fallback to commit SHA `633cc2bb` because my initial tag check only grepped `v1.6.X`. Peer `bassclef-upstream-d3` surfaced the existing `v1.7.0` tag mid-prep (MINOR bump — upstream release-step6 auto-bumped because PR #1523 carried a feat commit). 5 SHA-pin risks (L1-L5 in the pre-mortem light ledger) dissolved on the shift.
- **Driver resolution chain: dist/lite first, sibling fallback.** Each driver prefers the bundled view (what adopters install) then falls back to `BASSCLEF_SIBLING_ROOT` and `~/src/sunj-labs/bassclef/`. Covers CI docker-smoke (bundled populated) and local operator runs (sibling always resolves).
- **UC per driver, not one shared UC.** Each driver's PR included its own `docs/use-cases/UC-script-cli-294-driver-N-*.md`. Only driver 1 UC was pre-authored in PR #296 ceremony prep.
- **One PR per driver, serial merge.** Not stacked — PRs #298-#302 ran against freshly-rebased main each time (fetched + reset after each merge). Simpler than a stack manifest for 5 drivers that touch disjoint files.

## Operator discipline

- `/longrun prep` ran converged (plan doc dated today). Preset marker landed at `state/markers/longrun-preset/main.marker`.
- `/pre-mortem light` fired before any code edit per `.claude/rules/loop-discipline.md` Step 0.5. 3 lenses × 5 risks each (Linus / Nygard / Saltzer-Schroeder). Ledger at `docs/risk-ledgers/2026-10-03b-cli-295-bundle-sync.md`.
- `/temperance` fired per branch (6 branches, 6 markers).
- ADR-deviation marker per branch (all outcome: ADR-honored).
- `/kiss words` discipline on every operator-facing surface.

## Peer coordination

- `bassclef-upstream-b3` closed `/session-end` before this session opened. First peer message held for recipient user approval + expired.
- `bassclef-upstream-d3` (new peer, same operator) received the re-send + confirmed `v1.7.0` already tagged the cured release. Shifted plan from SHA pin to semver pin cleanly.
- Peer release-notes RCA shape (per bassclef-upstream#2039) inherited into cli release notes for v1.9.9.

## Still open

- **Publish v1.9.9 to npm.** `gh release create v1.9.9` was blocked by Claude Code's auto-mode classifier (prod-deploy guardrail). Operator paste pending. Once fired, publish workflow runs on `release` event — checks out upstream at `v1.7.0`, bundles `dist/lite/`, publishes under the `latest` tag.
- **CI integration for bash driver tests.** Drivers 1-5 run locally via `bash scripts/tests/*.test.sh`. CI test+typecheck ran vitest only; docker-smoke path filter skipped these PRs. Follow-on PR candidate to wire bash drivers into either `npm run test:drivers` or docker-smoke always-on.
- **Pre-cure RED-first proof baked into CI.** Each driver's PR body cites the pre-cure SHA for operator-side characterization re-run. CI itself does not run against pre-cure upstream.
- **Kunal findings #7, #8, #10.** Open at upstream Slot 5/6 per `docs/next-session-plan-2026-10-04-kunal-slots-5-6.md`.
- **Session local main.** 5 auto-save marker commits accumulated on local main before each branch created. They never pushed (bassclef marker gitignore + branch flows); they stay as local audit trail of markers written mid-session.

## Discoveries

- **Semver tag check must scan all major/minor lines, not just the current major.minor.** My first `git tag -l | grep v1.6.X` missed `v1.7.0` because it only grepped `^v1.6`. Grep for the surface class, not a hard-coded prefix.
- **`dist/lite/presence/dist-templates/.gitignore` is NOT bundled by cli.** The shipped-template `.gitignore` lives in the bassclef sibling, not in cli's `dist/lite/`. Driver resolution should decouple `trace-helper.sh` and `.gitignore` paths — the first lives in bundle, the second lives in sibling.
- **Mid-build transient test failures are expected.** vitest run during `npm run build` can show 12 fails that resolve to 0 fails on re-run. The dts regen step rewrites test fixtures transiently.
- **The adopter-mode classifier blocks `gh release create` regardless of Touch ID gate state.** Classifier is harness-side, independent of GitHub Actions env gates. Removal of the Touch ID gate at the npm-publish env does not unblock the trigger action.

## Follow-ons for next session

- **E2E cascade stack continues.** Plan doc at `docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md` names 3 more drivers (/sprint, /temperance, /longrun prep). Prototypes shipped tonight set the shape; next session copies the template.
- **Driver stack CI wiring** — operator preference needed among `npm run test:drivers`, docker-smoke always-on, or vitest shell wrapper.
- Resume cli#294 extensions when upstream Slot 5/6 ships findings #7 / #8 / #10 cures.
- cli#290 (bassclef `v1.6.5` tag defect — ships v1.6.4 content). v1.7.0 pin is clean; cli#290 is upstream's historical defect to retire or document.
- cli#284 (whereami auto-update misread) + cli#291 (statusline dispatcher hardcode) — independent cli-side cures; upstream mirror candidates.
- Watch bassclef-upstream#2049 — the notification protocol downstream for these drivers.

## Session metrics

- Turn count: ~150 (prep → bundle sync → drivers 1-5 → upstream ticket → E2E prototypes → closeout)
- Commits authored on branches: 12 feat/chore + 6 markers across 7 feature branches
- Auto-save checkpoints on local main: 5
- Vitest at closeout: 498/498 GREEN
- Context budget at closeout: ample (~14.9M tokens)
- PRs merged: 7 (cli), 1 ticket filed (bassclef-upstream)
