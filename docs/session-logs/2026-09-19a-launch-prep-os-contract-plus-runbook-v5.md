---
tier: project
title: Session — launch-prep sweep (OS contract + README rewrite + runbook v5)
date: 2026-09-19
goal_id: 2026-09-19a-launch-prep-os-contract-plus-docs-merge
duration: ~3 hours
turns: ~55
branches: feature/151-phase-1-os-contract (#152), fix/runbook-v5-bookend-plus-pipe (#153), docs/session-end-2026-09-19a-launch-prep (this PR)
outcome: 3 PRs open for review; 1 already merged (#119 whereami baseline); 2 stale PRs closed (#114, #115); #151 amendment comment landed; 5 new Tier 0 tests; 433 GREEN
---

# Session log — 2026-09-19 launch-prep sweep

## What shipped

Launch-eve session against the 2026-09-20 bassclef-lite ship. Three PRs open for operator review, one merged mid-session, two stale PRs closed as superseded.

### Merged this session

- **#119** — session-end 2026-09-18b + whereami baseline → `fc1fca9`. Merged first to set whereami baseline before this session's own whereami update.

### Open for review + merge

- **#152** — `feat(#151): Phase 1 OS support contract + README rewrite`. `package.json` gets `"os": ["darwin", "linux"]`. README rewritten from `@thebassclef/core@0.0.1 scaffold only` copy (stale since 2026-08 rename) to current 1.2.0 shape with supported-systems section. New `standards/os-support.md`. Extends `scripts/bump-version.mjs` with `writeReadmeVersion` for dynamic version marker on future releases. 5 new Tier 0 tests (`writeReadmeVersion` × 3 + `package.json.os` × 2). Suite 428 → 433 GREEN. Typecheck clean.
- **#153** — `docs(runbook): v5 — bookend banner explainer + pipe callout`. Ports content from stale #114 (bookend banner section) + #115 (pipe callout + troubleshooting) into current runbook v4 anchors. Docs-only; +42 -2 lines.

### Closed as stale

- **#114** — `docs(runbook): v4 banner-note`. Rebased-stale after PR #136 shipped a different v4 on main; version label collided and file shape drifted. Content ported into #153.
- **#115** — `docs(runbook): v5 pipe callout`. Same story; content ported into #153.

### Ticket amendment

- **bassclef-cli#151** — comment `5742446859` amending Phase 1 acceptance from `["darwin"]` to `["darwin", "linux"]`. Reasoning: WSL 2 reports as `linux` to npm; operator launch copy names both; upstream #1497 substrate portability audit is the cure path for Linux breakage. Windows PowerShell still fails fast with `EBADPLATFORM`.

## Decisions

### Pin `["darwin", "linux"]` not `["darwin"]`

Original #151 Phase 1 acceptance said `["darwin"]` — honest but blocks WSL 2 install. Operator surfaced the tension mid-session: their launch copy names both darwin + linux. Pin must match the copy or adopters lose trust in the docs. Peirce alternatives named — darwin-only, darwin+linux, omit-entirely. Chose darwin+linux for three reasons: WSL 2 needs linux in the pin, copy consistency, upstream #1497 audit runs anyway.

### Expand scope to full README rewrite

Started with the plan doc's Shape A (add supported-systems section only). Discovered mid-Step-1 that README top still named `@thebassclef/core@0.0.1 scaffold only` — the old package name deprecated 2026-09-17. Adding a section to a README that names the wrong package is worse than shipping no section. Operator confirmed Shape B (full rewrite). Added dynamic version marker mechanism per operator ask on cost of future auto-updates.

### Close #114 + #115 as stale + ship one new PR

Both branches were rebased-stale after PR #136 shipped v4. Content was still valuable. Combined into one atomic PR (#153) against current main. Cleaner than rebasing two stale branches through the v4 conflict.

### Merge order #119 first, then session PRs after review

Operator picked docs-then-code merge sequence. #119 landed the whereami baseline (2026-09-18b operator_recap). Session close now adds tonight's operator_recap on top. #152 + #153 await operator review before merge — operator-gated per default.

## Open threads

- **#152 awaits review + merge** — Phase 1 OS contract launch blocker
- **#153 awaits review + merge** — runbook v5 port
- **This session-end PR** awaits review + merge — whereami + session log update
- **cli#140** — `BASSCLEF_DIR` resolves to `$HOME` on lite-only install. Pickup prompt in this session's chat log. Real hook error from smoke #147 session-reflection FAIL. Awaits upstream substrate fix.
- **cli#147** — fresh 1.2.0 smoke report — 5 FAIL / 33 PASS. `#148`, `#149`, `#150` filed as follow-ons. Post-launch scope.
- **cli#151** Phase 2 (upstream #1497), Phase 3 (matrix CI), Phase 4 (Windows) — post-launch phases.
- **Launch scheduled tomorrow 2026-09-20** — bassclef-lite front page + npm claim + adopter docs. Coordinated at bassclef-web.

## Discipline observations

- **Miss** — did not fire `/promote` during session despite spotting the rogue auto-save-on-main commit `b0274d8`. Per `.claude/rules/blocked-items.md` §"When resolution reveals a substrate defect" this should have been promoted. Operator caught the miss at session-end. Follow-on: file the auto-save-on-main substrate-defect ticket next session.
- **Held** — the plan-doc shipped-state check (Step 0.75 of `/longrun prep`) caught that the 2026-09-17 plan doc's Option e recommendation had SHIPPED via goal 2026-09-18a. Preset correctly reshaped from converged to exploratory. New Sept plan-doc discipline paid off first time.
- **Held** — the temperance drift-trigger fired mid-session when README top staleness surfaced. Paused, surfaced to operator, got authorization to expand scope. Cleaner than silently expanding.
- **Held** — Feathers characterization approach on the OS pin decision. Read source (package.json + README + #151 body + #1497 body) before recommending shape. Operator's P2 hypothesis validated against three data points.

## Key files changed

**Modified on main (via merged PR #119):**
- `docs/whereami.md` — 2026-09-18b operator_recap block
- `docs/session-logs/2026-09-18b-cold-profile-smoke-followon.md` — session log

**Modified on feature/151-phase-1-os-contract (PR #152 pending):**
- `package.json` — `"os": ["darwin", "linux"]`
- `README.md` — full rewrite (88 → 45 lines, updated content)
- `scripts/bump-version.mjs` — `writeReadmeVersion` + allowlist entry
- `tests/bump-version.test.ts` — 3 new tests
- `tests/package-json-os-field.test.ts` — new (2 tests)
- `standards/os-support.md` — new
- `docs/iteration-bets/2026-09-19a-launch-prep-os-contract-plus-docs-merge.md` — new
- `docs/risk-ledgers/2026-09-19a-launch-prep-pre-mortem.md` — new
- Markers under `state/markers/{temperance,luminary,pre-mortem,lead-lens-signoff,arc-walk,thread-walk}/`

**Modified on fix/runbook-v5-bookend-plus-pipe (PR #153 pending):**
- `docs/runbooks/smoke.md` — v4 → v5 (bookend banner section + pipe callout + 2 troubleshooting entries + change log entry)
- Markers under `state/markers/{temperance,luminary,pre-mortem,lead-lens-signoff}/`

## Gate Evidence

<!-- FKGL-EXEMPT: table body has literal marker paths — kept for grep -->

| Gate | Fired? | Evidence |
|---|---|---|
| /temperance | YES | `state/markers/temperance/feature-151-phase-1-os-contract.marker` + `state/markers/temperance/fix-runbook-v5-bookend-plus-pipe.marker` |
| /luminary | YES | `state/markers/luminary/feature-151-phase-1-os-contract.marker` (lead: linus-torvalds) + `state/markers/luminary/fix-runbook-v5-bookend-plus-pipe.marker` (lead: donald-norman) |
| /pre-mortem light | YES | `docs/risk-ledgers/2026-09-19a-launch-prep-pre-mortem.md` (3 lenses × 5-7 risks; 7 folds, 3 defers, 2 falsified) + `state/markers/pre-mortem/*.marker` |
| /lead-lens-signoff | YES | `state/markers/lead-lens-signoff/feature-151-phase-1-os-contract.marker` (PASS, no findings) + `state/markers/lead-lens-signoff/fix-runbook-v5-bookend-plus-pipe.marker` (PASS, no findings) |
| /verify | YES | `npm test` → 433/433 GREEN; `npm run typecheck` → clean; both pre-commit hooks satisfied |
| /diagnose | n/a | No failure surfaced this session that required diagnosis |
| /roadmap-reconcile | skip | tier: lite per whereami L2; not applicable |
| /promote | MISS | Auto-save-on-main defect spotted (commit `b0274d8`) but /promote not filed. Discipline miss surfaced by operator at session-end. Follow-on: file substrate-defect ticket next session. |

<!-- /FKGL-EXEMPT -->

## Turn count + cost tracking

- Duration: ~3 hours (13:48Z first tool call → ~16:50Z session-end)
- Turns: ~55 (dispatch chain: /longrun prep → scope confirm → discovery → 2 branches × edit/test/PR)
- 1 PR merged this session (#119)
- 2 PRs open pending operator merge (#152, #153)
- 2 stale PRs closed (#114, #115)
- 1 ticket comment (#151 acceptance amendment)
- 5 new Tier 0 tests
- 0 dollar burst cost (sequential mode)

## Refs

- Goal doc: `docs/iteration-bets/2026-09-19a-launch-prep-os-contract-plus-docs-merge.md`
- Risk ledger: `docs/risk-ledgers/2026-09-19a-launch-prep-pre-mortem.md`
- Parent ticket: bassclef-cli#151
- Upstream cure path: sunj-labs/bassclef#1497
- Real hook error follow-on: bassclef-cli#140 (pickup prompt in session chat)
- Fresh smoke report: bassclef-cli#147
- Prior session log: `docs/session-logs/2026-09-18b-cold-profile-smoke-followon.md`
