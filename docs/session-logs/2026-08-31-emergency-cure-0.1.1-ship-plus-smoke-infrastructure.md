---
tier: upstream
date: 2026-08-31
session_type: emergency cure + release + follow-on infrastructure
started_at: 2026-08-31T06:25:10-0700
ended_at: 2026-08-31T14:35:44-0700
duration_minutes: 490
mode: operator-gated sequential
outcome: shipped
prs_merged: [47, 48, 50]
issue_opened: 49
release_shipped: v0.1.1
npm_unpublished: 0.1.0
---

# 2026-08-31 — 0.1.1 emergency cure ship + smoke test infrastructure

## What shipped

- **PR #47** — issue #45 cure. Prepublish writes runtime manifest to `substrate/.bassclef/lite-manifest.json`; init removes silent-catch, fails loud on missing bundle. Nygard fail-with-fix.
- **PR #48** — CI workflow reorder. Sibling checkout + prepublish run BEFORE `npm test` so init end-to-end tests exercise a populated substrate.
- **PR #50** — cold-adopter smoke test plan + `scripts/smoke-reset.sh` helper.
- **Issue #49** — /promote proposal for cross-repo auto-trigger when public bassclef ships lite-tier changes.
- **npm registry** — 0.1.0 unpublished; 0.1.1 published, live, verified end-to-end from the registry.

## Timeline

| Time (PDT) | Event |
|---|---|
| ~06:25 | Session started continuing from prior /longrun; user ran Test A smoke on published 0.1.0 |
| ~06:30 | Smoke revealed 2 files instead of 149 — issue #45 filed via /diagnose |
| ~06:40 | Filed #46 (bassclef-evolution: architect-review static-comprehension limitation) |
| ~07:00 | PR #47 fix branch shipped: prepublish manifest-write + init fail-loud + 3 Tier 0 tests |
| ~07:14 | PR #47 merged to main |
| ~07:15 | v0.1.1 tagged + release created → first publish workflow ran |
| ~07:15 | Publish workflow FAILED at checks job — 3 init tests hit exit 2 (fail-loud path fired against empty substrate) |
| ~07:20 | PR #48 fix — reordered workflow: prepublish before test |
| ~07:20 | PR #48 merged; v0.1.1 tag deleted + release deleted + retagged to new HEAD |
| ~07:16 | Publish workflow re-ran; checks passed; parked at environment gate |
| ~13:20 | User approved npm-publish environment gate → publish job completed |
| ~13:25 | Live registry verified: `[ '0.0.1', '0.0.2', '0.1.1' ]` |
| ~13:30 | Live install smoke: 150 files land in temp adopter dir |
| ~13:45 | 0.1.0 unpublish flow: found npm login expired (E401); refreshed via `npm login` browser flow (Touch ID); unpublish succeeded |
| ~14:00 | User asked for test plan for second profile + reset script |
| ~14:15 | Docs + reset script shipped in PR #50 |
| ~14:20 | /promote #49 filed (cross-repo auto-trigger design proposal) |
| ~14:35 | Session end |

## Decisions

- **Fail-loud over silent-catch (init.ts).** Chose Nygard fail-with-fix over defensive silent-skip. Rationale: silent skip is what let 0.1.0 ship broken; the class must never recur. Trade-off: exposed CI ordering assumption (surfaced in PR #48).
- **Retag v0.1.1 rather than bump to v0.1.2.** Nothing shipped to npm at 0.1.1 yet (first publish failed). Retagging preserved semver for adopters and avoided version-fatigue.
- **File #49 (/promote) rather than build the automation now.** Design decision — the automation touches public bassclef + bassclef-cli + bassclef-web. Multi-repo coordination benefits from an explicit design conversation before code lands.
- **Skipped Path C in #49 (public bassclef opens PRs in downstreams).** Concentrates too much logic at source; recommend Path B (`workflow_dispatch` from public bassclef) instead.

## Open threads

- **Test the cold-adopter smoke plan under second macOS user profile.** Owner: operator. Blocks: nothing. Signal: 10 numbered steps in the test plan doc; ✅ per step or FAIL with output capture.
- **#49 /promote** — awaiting bassclef triage. Design has 5 open questions naming decisions triage should make.
- **#46 /promote** — architect-review static-comprehension-only limitation. Also awaiting triage.
- **`state/luminary-implementations/michael-nygard.json`** modified (ambient hook write) but never staged. Left uncommitted; not part of the session's intended output.
- **Linux + Windows smoke plans** — separate follow-on artifacts, not scoped here.

## Key files changed

- `scripts/prepublish-bundle-substrate.mjs` — added `writeBundledManifest` + `assertBundledManifestPresent`
- `src/commands/init.ts` — `dispatchSubstrateCopy` fail-with-fix
- `tests/harness/prepublish-bundle.test.ts` — 3 new Tier 0 tests
- `.github/workflows/publish.yml` — reordered checks job steps
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` — Amendment 2026-08-31
- `CHANGELOG.md` — 0.1.1 entry
- `package.json` + `src/index.ts` — version bump 0.1.0 → 0.1.1
- `docs/test-plans/2026-08-31-cold-adopter-smoke-0.1.1.md` — new
- `scripts/smoke-reset.sh` — new

## Gate Evidence

```
Gate                    Fired  Marker
temperance              yes    state/markers/temperance/fix-prepublish-write-bundled-manifest.marker
                        yes    state/markers/temperance/docs-smoke-test-plan-and-reset-script.marker
                        yes    state/markers/temperance/fix-publish-workflow-substrate-bundling.marker
diagnose                yes    state/markers/diagnose/fix-prepublish-write-bundled-manifest.marker
adr-deviation           yes    state/markers/adr-deviation/fix-prepublish-write-bundled-manifest.marker
pre-mortem              yes    state/markers/pre-mortem/docs-smoke-test-plan-and-reset-script.marker
luminary                yes    state/markers/luminary/docs-smoke-test-plan-and-reset-script.marker
lead-lens-signoff       yes    state/markers/lead-lens-signoff/docs-smoke-test-plan-and-reset-script.marker
verify (npm test)       yes    219/219 pass on branch, on main, on tarball, live-registry install
architect-review        no     N/A — cure was diagnosis-driven; #46 filed to promote a review methodology gap
```

## What this session taught

- **Fail-loud beats defensive silent-skip.** The 0.1.0 defect was hidden by init.ts's `catch {}`. Replacing it with `process.exit(2)` + a cure message surfaced the CI ordering assumption immediately. This is the mechanism-fidelity discipline in action.
- **End-to-end smoke on a machine with stale local state is not equivalent to a cold-adopter test.** My local `substrate/` was pre-populated during dev; the fix passed unit tests + tarball inspection but the class of defect (stale local state hiding a broken tarball) needs a clean-room test to catch. That's what the smoke test plan + reset helper close.
- **Squash-merge collapses branch churn.** When commits on the branch include ambient hook writes (settings.json, gitignore refresh), they land in main via the squash. Explicit `git add` of only intended files at commit time keeps the merge clean. Confirmed by inspecting PR #47's merged diff.
- **npm security keys via WebAuthn on macOS are Touch ID.** Not stored in Authy or 1Password. `npm login` uses browser handoff; Touch ID sensor is the authenticator. Session bootstrapped this understanding.

## Refs

- Issue #45 — the 0.1.0 defect this session cured
- Issue #46 — architect-review methodology gap
- Issue #49 — cross-repo auto-trigger design proposal
- PRs #47, #48, #50 — the ship vehicles
- Failed run 33367548635 — evidence for PR #48's ordering fix
- Successful run 33396847872 — v0.1.1 publish confirmation
- ADR-007 §Amendment 2026-08-31
