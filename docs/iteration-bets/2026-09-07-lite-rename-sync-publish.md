---
tier: lite
goal: 2026-09-07-lite-rename-sync-publish
title: Rename @thebassclef/core → @thebassclef/lite + sync substrate to v1.5.0 + publish 0.1.0
project: bassclef-cli
execution_repo: sunj-labs/bassclef-cli
status: proposed
authored: 2026-09-07
authored_by: agent
in_flight_goal: null
parent_bet: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
time_budget: 90-155 turns
time_budget_source: |
  Parent goal 08-06b shipped Steps 1-5 at ~200 turns per step. This goal is a
  7-step rename+sync+publish chain — one shipped (backward-compat test PR #52),
  seven pending. Session log 2026-09-05 estimated Option a-plus at 70-120 turns.
  Pre-mortem light 2026-09-07 added ~20-35 turns for tarball audit + trusted-
  publisher verify + extended validate. Range covers npm 2FA retries.
authoring_luminaries:
  primary: [alan-cooper, jerome-saltzer-and-michael-schroeder, john-ousterhout]
  supporting: [linus-torvalds, michael-feathers]
lead_lens: alan-cooper
tickets: [51]
references:
  - {type: parent_bet, id: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md, anchor: parent goal — npm distribution for @thebassclef/core}
  - {type: ticket, id: 51, anchor: coord ticket — cross-repo stack rank for lite manifest release; Q1 slice}
  - {type: risk_ledger, id: docs/risk-ledgers/2026-09-07-lite-rename-sync.md, anchor: pre-mortem light — 3 lenses; top 3 risks drove scope amend}
  - {type: pr, id: 52, anchor: SHIPPED — manifest-shape backward-compat test (be1673c)}
  - {type: session_log, id: docs/session-logs/2026-09-05-longrun-prep-lite-rename-sync-scoped.md, anchor: Option a-plus origin}
  - {type: memory, id: project_lite_is_free_tier_package, anchor: lite is the shipping name; core is redundant}
  - {type: memory, id: feedback_rename_must_ride_with_manifest_sync, anchor: rename PR must include sync-and-validate}
  - {type: memory, id: feedback_npm_11_required_for_trusted_publisher, anchor: pin npm@11 in publish workflow}
  - {type: memory, id: reference_npm_2fa_is_touch_id, anchor: npm publish 2FA is macOS Touch ID WebAuthn}
  - {type: cross_session, id: bassclef-web heads-up 2026-09-07, anchor: v1.5.0 dropped upstream_commit; adds problem/value per entry}
adr_references:
  - ADR-002 (bassclef init safety contract)
  - ADR-003 (bassclef sync safety contract)
  - ADR-005 (npm packaging strategy)
  - ADR-031 (we-don't-break-adopters — @thebassclef/core adopters need a migration path)
  - ADR-051 (dist/lite/ contract — sister Q2 scope; NOT this goal)
---

# Rename @thebassclef/core → @thebassclef/lite + sync substrate to v1.5.0 + publish 0.1.0

## Problem

`@thebassclef/core@0.1.1` is live on npm but carries the wrong name for go-forward adoption per operator direction 2026-09-05 (session log 2026-09-05-longrun-prep-lite-rename-sync-scoped.md) and memory `project_lite_is_free_tier_package`. Bundled substrate is v1.2.19; upstream shipped v1.5.0 on 2026-09-06. Coord ticket #51 (filed 2026-09-03 by bassclef-upstream) asks bassclef-cli for a Q1 slice — the rename+sync fills that slot. Adopters installing today land on the wrong package name AND a two-minor-version-stale substrate.

## Value

Sam runs `npm install -g @thebassclef/lite` in 5 minutes and gets the current substrate. Existing `@thebassclef/core` adopters get a deprecation notice with a one-command migration path. Coord ticket #51 Q1 closes; Q2 (#25 dist/lite/, #49 auto-trigger) unblocked. Publish contract is proven at 0.1.1; the second ship reuses the same trusted-publisher pipeline per memory `feedback_npm_11_required_for_trusted_publisher`.

Per @luminary alan-cooper — Sam's first-touch install command changes from `npm install -g @thebassclef/core` to `npm install -g @thebassclef/lite`. Deprecation notice on core is her fallback signal.

Per @luminary jerome-saltzer-and-michael-schroeder — every publish path is mediated. Trusted publisher config extends to lite. Tarball audit runs before publish to enforce fail-safe defaults on the `substrate/**` glob.

Per @luminary john-ousterhout — `copy-substrate` module handles v1.5.0's additive `problem` + `value` fields without change (grep-confirmed no consumer reads `upstream_commit`). Deep-module interface stays clean across the sync.

## Sources read

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` — parent_bet; inherited authoring_luminaries (primary + supporting) + roadmap anchor + acceptance shape; walked this turn per state/markers/thread-walk/ + state/markers/arc-walk/ markers
- `docs/risk-ledgers/2026-09-07-lite-rename-sync.md` — pre-mortem light; top-3 risks (Saltzer #1 tarball audit + Ousterhout #1 content-hash + Saltzer #2 prepublishOnly) drove new Step 2.5, extended Step 3, new Step 3.5
- `docs/session-logs/2026-09-05-longrun-prep-lite-rename-sync-scoped.md` — Option a-plus origin; recommended pickup L82
- Memory: `project_lite_is_free_tier_package` (lite is shipping name), `feedback_rename_must_ride_with_manifest_sync` (rename PR must include sync), `feedback_npm_11_required_for_trusted_publisher` (pin npm@11), `reference_npm_2fa_is_touch_id` (publish 2FA is Touch ID at operator keyboard)
- Peer session heads-up 2026-09-07 (bassclef-web) — v1.5.0 dropped `upstream_commit`; adds `problem` + `value` per entry
- `substrate/.bassclef/lite-manifest.json` L1-30 — current bundled shape (manifest_version 1.2.19)
- `package.json` — current name @thebassclef/core@0.1.1, files array + bin + prepublishOnly
- grep bassclef-cli for `upstream_commit` — zero read paths; peer's crash class does not apply

## Steps

Step 1 is SHIPPED (PR #52 merged as be1673c 2026-09-07T06:13:18Z). Steps 2-8 remain.

| Step | Problem + value | Produces | Consumes (from prior) | How builds on prior | Risk |
|---|---|---|---|---|---|
| **1** ✅ SHIPPED — manifest-shape backward-compat test | PR #52 merged; consumers proven safe when `upstream_commit` absent + `problem`/`value` present | Test at tests/harness/copy-substrate.test.ts (11 tests GREEN); test-list [x] | session-start | baseline | 🟢 low |
| **2** sync bundled substrate v1.2.19 → v1.5.0 | Bundled substrate stale by 3 minor versions; adopters miss /build promotion + skill retags + luminary flips | Refreshed `substrate/**` pinned to upstream v1.5.0 git tag SHA; regenerated `substrate/.bassclef/lite-manifest.json`; CHANGELOG entry naming skill retags + luminary flips | Step 1 (backward-compat proof); upstream v1.5.0 tag | Test proves consumer safety; sync trusts that proof | 🟡 med — schema drift 1.2 → 1.5 |
| **3** extended validate | Content-hash mismatch on renamed files could ship silently (Ousterhout #1 HIGH) | `copy-substrate --dry-run` on fresh clone; assert 0 refused + 0 errored + all entries.length copied; smoke output at state/markers/smoke/ | Step 2 (synced bundle) | Cure for Ousterhout #1 | 🟡 med |
| **4** pre-publish tarball audit + Tier 0 test | `substrate/**` glob may bundle operator-private paths (Saltzer #1 HIGH) | `npm publish --dry-run` output; tarball listing grep for operator-private/, chronicle/, journals/, state/markers/ (must be empty); new Tier 0 test asserting tarball cleanliness | Step 3 (validated bundle) | Cure for Saltzer #1 | 🟡 med |
| **5** trusted-publisher config verification | `@thebassclef/lite` may not be registered under trusted publisher; publish would fail (Saltzer #3) | Screenshot proof + marker at state/markers/npm-config/lite-trusted-publisher.md; setup instructions if not registered | Step 4 (audited tarball ready) | Cure for Saltzer #3 | 🟢 low — verification only |
| **6** rename `package.json` name + publish `@thebassclef/lite@0.1.0` | Wrong name live on npm; needs rename + version bump + publish | package.json name flipped; version 0.1.0; git tag v0.1.0-lite; `@thebassclef/lite@0.1.0` live on npm with provenance | Steps 2-5 (bundle audited + trusted publisher confirmed) | Reuses proven 0.1.1 pipeline; operator Touch ID at publish | 🟡 med — npm 2FA operator-gated |
| **7** deprecate `@thebassclef/core` | New adopters may still land on core; explicit signal needed | `npm deprecate @thebassclef/core "use @thebassclef/lite"` executed; screenshot of deprecation notice on npm | Step 6 (lite live) | Adopter migration signal per Cooper #1 | 🟢 low |
| **8** coord ticket #51 update | Ticket Q1 slot still shows empty | Comment on #51 updating Q1 status to closed; cross-refs PRs 52 + Steps 2-7 PRs; recommends next Q2 pickup | Step 7 (deprecate live) | Closes cross-repo coord loop | 🟢 low |

## Compounding value per step

**Step 1** (SHIPPED) — Compounding surface: per-release. Compounding rate: per-substrate-refresh. Foundation prereq: none. Inverse-dependency: yes; test template reused for future manifest schema changes. Risk class: low (already shipped).

**Step 2** — Compounding surface: per-release. Compounding rate: per-substrate-refresh (frequent). Foundation prereq: Step 1 test proof + upstream v1.5.0 tag stable. Inverse-dependency: yes; sync pattern reused for #49 auto-trigger. Risk class: medium.

**Step 3** — Compounding surface: per-release. Compounding rate: per-ship. Foundation prereq: Step 2 bundle. Inverse-dependency: yes; extended-validate becomes template for every future substrate sync. Risk class: medium.

**Step 4** — Compounding surface: per-release + per-adopter-install. Compounding rate: per-ship. Foundation prereq: Step 3 validated bundle. Inverse-dependency: yes; tarball audit + Tier 0 test template reused for every future publish. Risk class: medium.

**Step 5** — Compounding surface: per-release. Compounding rate: one-shot per new package name. Foundation prereq: Step 4 audit passed. Inverse-dependency: yes; trusted-publisher verify pattern reused for standard/ultra when they ship. Risk class: low.

**Step 6** — Compounding surface: per-adopter install. Compounding rate: per-release. Foundation prereq: Steps 2-5. Inverse-dependency: yes; second-package pipeline proof unlocks standard/ultra ships. Risk class: medium.

**Step 7** — Compounding surface: per-adopter discovery. Compounding rate: one-shot per rename. Foundation prereq: Step 6. Inverse-dependency: yes; deprecation pattern reused for any future package rename. Risk class: low.

**Step 8** — Compounding surface: per-coord-ticket resolution. Compounding rate: one-shot. Foundation prereq: Step 7. Inverse-dependency: yes; cross-repo coord update pattern reused for every Q2/Q3 slice. Risk class: low.

## Acceptance

- [x] Step 1 — manifest-shape backward-compat test merged (PR #52 be1673c)
- [ ] Step 2 — bundled substrate synced to v1.5.0; CHANGELOG entry naming skill retags + luminary flips; PR merged
- [ ] Step 3 — extended validate PR: `copy-substrate --dry-run` on fresh clone returns 0 refused + 0 errored
- [ ] Step 4 — tarball audit PR: dry-run tarball listing has zero operator-private paths; Tier 0 test asserting tarball cleanliness GREEN
- [ ] Step 5 — trusted-publisher config for `@thebassclef/lite` verified; marker at state/markers/npm-config/lite-trusted-publisher.md
- [ ] Step 6 — `@thebassclef/lite@0.1.0` live on npm with provenance; git tag `v0.1.0-lite` pushed
- [ ] Step 7 — `@thebassclef/core` deprecated with migration message
- [ ] Step 8 — coord ticket #51 comment posted; Q1 status closed
- [ ] All Tier 0 tests GREEN
- [ ] /architect-review skipped (single-goal migration; not a phase boundary)
- [ ] Session log written at close per `.claude/rules/session-artifacts.md`

## Out of scope

- Q2 slice: #25 (consume dist/lite/), #49 (auto-trigger downstream) — per coord #51 attack order
- Unpublish `@thebassclef/core@0.1.1` — kept live per memory `project_lite_is_free_tier_package` (later session)
- Standard-tier and ultra-tier package rename or publish (only reservations at 0.0.1 today)
- Kilo runtime work
- UX / mock-gallery / prototype / interaction-design work — this is CLI infrastructure
- Sam demo re-recording — `@thebassclef/core` demo stays valid until deprecation date

## Refs

- Closes coord ticket #51 Q1 slice
- Refs upstream #1508 (upstream_commit removal in v1.5.0)
- Refs upstream #1480 (problem + value fields per entry)
- Refs upstream #1462 (/build promoted to lite)
- Refs upstream #1478 (4 skills retagged)
- Refs upstream #1459 (14 luminaries flipped to lite)
- Refs bassclef-web#269 (evolution — migration notes on schema-removing changes)
- Sister: `docs/risk-ledgers/2026-09-07-lite-rename-sync.md`
- Predecessor: `docs/iteration-bets/2026-08-30a-npm-lite-migrate-subcommand.md` (0.1.1 cure ship)
- Parent: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
