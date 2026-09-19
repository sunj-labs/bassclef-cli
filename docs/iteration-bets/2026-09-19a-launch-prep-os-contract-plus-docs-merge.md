---
tier: project
title: launch-prep sweep — OS contract + docs PR merges
id: 2026-09-19a-launch-prep-os-contract-plus-docs-merge
started_at: 2026-09-19T13:50:00Z
appetite: 35-65 turns (grounded — Option a expanded 2026-09-19T14:10Z to include full README rewrite + dynamic version marker in bump-version.mjs; Option b is 3 docs-only merges; lighter than 2026-09-18a which shipped ~150 turns with 41 new tests)
mode: operator-gated + sequential
authoring_luminaries:
  primary:
    - linus-torvalds
    - jerome-saltzer-and-michael-schroeder
  supporting:
    - hyrum-wright
    - donald-norman
    - gary-klein
parent_goal_ids: []
references:
  - path: docs/whereami.md
    role: launch tomorrow 2026-09-20 per operator statement 2026-09-19
  - path: docs/next-session-plan-2026-09-17-cli-pickup.md
    role: prior plan; Option e SHIPPED per goal 2026-09-18a; superseded by launch-day scope
  - path: package.json
    role: no `os` field today; adds `["darwin", "linux"]`
  - path: README.md
    role: no OS copy today; adds supported-systems section
  - ticket: sunj-labs/bassclef-cli#151
    role: parent ticket — Phase 1 launch blocker; acceptance amended via comment
  - ticket: sunj-labs/bassclef-cli#147
    role: fresh smoke report 2026-09-19 (5 FAIL / 33 PASS) — background context
  - ticket: sunj-labs/bassclef#1497
    role: upstream substrate portability audit (BSD-vs-GNU) — cure path if Linux breakage surfaces
  - pr: sunj-labs/bassclef-cli#114
    role: Option b — docs runbook v4 banner note
  - pr: sunj-labs/bassclef-cli#115
    role: Option b — docs runbook v5 pipe callout
  - pr: sunj-labs/bassclef-cli#119
    role: Option b — session-end 2026-09-18b
verification_status: draft
---

# Goal — launch-prep sweep

## Sources read

- `docs/whereami.md:1-327` — active goal 2026-09-18a shipped; launch date 2026-09-20 per operator this turn
- `docs/next-session-plan-2026-09-17-cli-pickup.md` — 39.7h old; Option e SHIPPED per whereami L18-22 + commits `bc79bed` + `307bbb0`
- `package.json` — verified no `"os"` field via `grep '"os"' package.json` at 2026-09-19T13:48Z; `"engines": {"node": ">=20"}` present
- `README.md` — no OS copy today; `grep -niE 'macos|linux|windows|wsl|powershell|darwin'` returned zero matches
- `sunj-labs/bassclef-cli#151` — parent ticket; Phase 1 acceptance amended via comment 5742446859 (`["darwin"]` → `["darwin", "linux"]`)
- `sunj-labs/bassclef-cli#147` — fresh 1.2.0 smoke report; 5 FAIL / 33 PASS on cold-adopter-1
- `sunj-labs/bassclef#1497` — upstream OPEN; substrate BSD-vs-GNU audit; problem statement names Linux + WSL untested-but-likely
- `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md:1-60` — goal-doc frontmatter shape reference

## What I'm NOT reading (with reason)

- `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md` body past frontmatter — prior goal shipped; details do not shape this scope
- Upstream `#1728` body — cross-repo coordination ticket; not this session's scope
- `docs/canvases/` — directory does not exist in this repo (verified via `ls`)
- `docs/roadmaps/` — directory does not exist in this repo (verified via `ls`)
- Prior chronicles beyond whereami operator_recap blocks — recap already carries the pickup context

## Problem

Launch is tomorrow. `package.json` has no `"os"` field. README says nothing about which systems bassclef-lite runs on. Three docs PRs sit unmerged (#114, #115, #119). If the launch ships as-is, adopters get a package that installs everywhere silently and copy that says nothing. Windows PowerShell adopters hit substrate bash errors on first turn. Linux and WSL 2 adopters install without a signal about what's tested.

## Value prop

Declare the honest OS claim before launch. Clear the docs PR queue so launch day starts with a clean review board. Two atomic PRs, three merges. Every future adopter reads a `package.json` that agrees with the README.

## Goal

Ship two things before 2026-09-20 launch:

1. **Option a** — Phase 1 of #151. Add `"os": ["darwin", "linux"]` to `package.json`. Add a supported-systems section to README. Add `standards/os-support.md` naming the systems + rationale + upstream #1497 pointer.
2. **Option b** — merge PRs #114, #115, #119 in order.

## Steps

| Step | Produces | Consumes (from prior step) |
|---|---|---|
| **0** prep | goal doc + markers + pre-mortem ledger + #151 amendment comment | this session's `/longrun prep` |
| **1** OS contract | `package.json` `"os"` field + README supported-systems section + `standards/os-support.md` | Step 0 markers + pre-mortem folds |
| **2** Option a PR | one atomic PR to main; #151 Phase 1 acceptance closes | Step 1 files |
| **3** Merge Option b | #114, #115, #119 merged in order; branches deleted | Step 2 clean; no conflicts on docs |
| **4** closeout | session log + whereami update; retro on this thread | union of Steps 0-3 |

## Per-step compounding

| Step | Where the payoff shows up | How often it fires | What must be true first | Does this teach a shape later work reuses | What breaks if we ship this half-done |
|---|---|---|---|---|---|
| 0 prep | per-branch | continuous | operator scope confirmation | no (baseline) | 🟢 low — no scope anchor |
| 1 OS contract | per-adopter install | per-adopter | Step 0 markers + pre-mortem | yes — every future OS pin follows this shape | 🟡 med — package installs everywhere including PowerShell; adopters hit bash at run-time |
| 2 Option a PR | per-release | per-release | Step 1 files | no | 🟢 low — work done but not merged; no adopter effect |
| 3 Merge Option b | per-session | per-session | docs PRs mergeable | no | 🟢 low — review queue stale |
| 4 closeout | per-session | per-session | union of Steps 0-3 | no | 🟢 low — next session re-derives |

## Acceptance

- [x] `#151` Phase 1 acceptance amended via comment (pin `["darwin", "linux"]` reasoning) — comment 5742446859
- [ ] `package.json` `"os": ["darwin", "linux"]`
- [ ] `README.md` — full rewrite: correct package name (`@thebassclef/lite`); correct install commands; supported-systems section; current-release version marker for dynamic bump; drop `0.0.1 scaffold` obsolete copy
- [ ] `standards/os-support.md` — one-page standard (rationale + declared systems + Phase 2/3/4 pointers)
- [ ] `scripts/bump-version.mjs` — new `writeReadmeVersion` function mirroring `writeIndexTsVersion`; `README.md` added to `allowed` set; caller wired into `main`
- [ ] Tier 0 test — `package.json.os === ["darwin", "linux"]` assertion
- [ ] Tier 0 test — `writeReadmeVersion` behavior + refuse-when-marker-missing path
- [ ] Existing test suite green after edits (`npm test`)
- [ ] Option a PR opened, review-ready
- [ ] `#114`, `#115`, `#119` merged in order
- [ ] `#151` Phase 1 acceptance boxes checked (add note about README rewrite scope-add)
- [ ] whereami updated at closeout

## Out of scope

- `#151` Phase 2 (substrate portability audit — upstream work per sunj-labs/bassclef#1497)
- `#151` Phase 3 (matrix smoke CI)
- `#151` Phase 4 (Windows coverage)
- `#150` dynamic skill discovery (post-launch bet)
- `#148` runbook file-count landmark (post-launch)
- `#149` paths-exist over-strict (post-launch)
- `#137`, `#140`, `#145` (post-launch)
- Any `#100`, `#101`, `#105-108` upstream defect work

## Refs

- Closes bassclef-cli#151 Phase 1 (Phase 2/3/4 stay open)
- @luminary linus-torvalds — we don't break adopters; the pin honors the copy
- @luminary jerome-saltzer-and-michael-schroeder — fail-fast on Windows PowerShell keeps the contract honest
- @luminary hyrum-wright — every observable field becomes a contract; declare before adopters do
- @luminary donald-norman — signifier (copy) + mapping (`package.json`) must agree
- @luminary gary-klein — pre-mortem light before Step 1 code
