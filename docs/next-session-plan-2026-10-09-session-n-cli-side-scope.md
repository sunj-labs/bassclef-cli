---
tier: lite
author: kingofrock
created: 2026-10-07
parent_goal: cli#375 (Tier A dynamic driver roadmap, closed Session K)
preset: converged
---

# Session N — cli-side scope pass (pre-flighted)

**Problem (≤500 chars):** Session M surfaced a methodology miss — my /eisenhower prep accepted peer scope framing without checking defect code location. All 3 scope-a tickets routed upstream. Session N applies the pre-flight check first — route upstream items early, pick a cli-side item for the session's actual code work.

---

## Pre-flight — defect code location probe (new discipline from Session M)

Before scope confirmation, each candidate ticket is probed via `md5sum` or `find` against bassclef source. CLI-side work means the code to edit lives in bassclef-cli repo only. Upstream means the code lives in `~/src/sunj-labs/bassclef` and syncs down.

| Ticket | Where code lives | Route |
|---|---|---|
| cli#235 — `bassclef init` 68 files refused on fresh dir | `src/commands/init.ts` (cli repo only) | **CLI-SIDE** |
| cli#241 — /riff can't read `.claude/luminaries/` in docker | `harness/docker/Dockerfile.cold-adopter` + `entry.sh` (cli repo; smoke run #36171661966 names docker sandbox symlink shape) | **CLI-SIDE** |
| cli#320 — /personas default slug leaks git email | `.claude/skills/personas/SKILL.md` md5 matches bassclef source | **UPSTREAM** |
| cli#388 — architect-review sweep across 6 Tier A drivers | cli test harness + reviewer agent dispatch | **CLI-SIDE** |
| /build Phase 3-7 LIVE happy path capture | Dockerfile gh install + Playwright + seeded auth (cli harness) | **CLI-SIDE** |
| Refresh /onboard-repo + /whereami captures to 1.9.11 | cli test fixtures | **CLI-SIDE** |

Session N scope (a) picks from the 4 cli-side items. Routing-only tickets ship upstream in Session N scope (c).

---

## Recommended session sequence

Preset — converged. One primary option. Scan table + card for the recommend; other options one line each.

### Scan table

| Option | Scope | Turns | Compounds | Risk | Why not (non-rec.) |
|---|---|---|---|---|---|
| **a (recommended)** | cli#235 + cli#241 + route cli#320 upstream | 60-100 | per-session; two cli-side cures + consistent upstream routing habit | 🟡 med | — |
| b | cli#388 full Tier A architect-review sweep | 30-50 | per-release; closes PR 7 of 7 roadmap | 🟢 low | smaller UX impact than curing adopter-first-touch defects |
| c | /build Phase 3-7 LIVE happy path (Dockerfile surgery) | 100-200 | per-adopter; unlocks true /build characterization | 🔴 high | Dockerfile + auth seed + MCP wiring; big container surgery |
| d | Refresh /onboard-repo + /whereami to 1.9.11 | 15-25 | per-session; freshness only | 🟢 low | opportunistic; nothing broken on 1.9.10 captures |

### Compounding value — recommended only

#### Option a — cli#235 + cli#241 + route cli#320 upstream

- **Deliverable** — Two cli-side cures ship as PRs: `src/commands/init.ts` fix for 68-files-refused + `harness/docker/Dockerfile.cold-adopter` fix for luminary read. One upstream ticket filed for cli#320. Three cli tickets close.
- **Problem** — Sam's first touch (`bassclef init`) prints 68-files-refused on a truly-fresh dir. Jamie's /riff in docker reads named-strategy analysis instead of real luminary lenses. Both block the goal. cli#320 leaks git email on first /personas run (security).
- **Value prop** — Three Q1 adopter-first-touch defects cleared. Sam, Jamie, and any /personas user see the fixes in the next release.
- **Turns** — 60-100. Grounded in Session L (80 turns for 4 fixtures) + Session M (50 turns for 1 fixture + 3 routings). cli#235 is one-file + tests (~25 turns); cli#241 is Dockerfile edit + container smoke (~20 turns); cli#320 routing (~5 turns). Review + closeout rounds up.
- **Risk** — 🟡 med. cli#235 may surface the real cause of path-collision which could be in src/lib/* substrate (shared with upstream). cli#241 Dockerfile change needs docker-smoke CI run to verify. cli#320 straight routing.
- **Shipping priority** — P1 (closes 2 Q1 cli-side tickets + 1 upstream routing).

### Per-step compounding

| Step | Produces | Consumes (from prior step) |
|---|---|---|
| **0** prep | goal doc + markers + task tracker | — |
| **1** cli#241 pre-flight | understand symlink shape; decide Dockerfile vs entry.sh fix | step 0 |
| **2** cli#241 cure | Dockerfile.cold-adopter edit; container rebuild; docker-smoke green | step 1 |
| **3** cli#235 diagnose | /diagnose Is/Is Not + Five Whys on 68-files-refused | step 2 (clean container harness) |
| **4** cli#235 cure | src/commands/init.ts edit; vitest green | step 3 |
| **5** route cli#320 | upstream filing + close cli ticket | step 4 (bandwidth) |
| **6** closeout | PRs opened + session log + whereami + inventory amend | union of steps 2 + 4 + 5 |

If step 2 (cli#241) blows past 30 turns, pause and reshape. The Dockerfile change may surface a deeper harness refactor.

## Pre-mortem light — 3 lenses × 5 risks

### Lens 1 — @luminary alistair-cockburn (walking skeleton)

- R1 — cli#241 Dockerfile change breaks the existing 6-of-6 Tier A docker-smoke suite. Fold — rebuild image + run every driver before commit; roll back the Dockerfile change if any driver RED.
- R2 — cli#235 real cause lives in `src/lib/manifest-reconcile.ts` or similar shared module; fix touches 2+ files. Fold — scope the diagnose first; if blast widens, cure only the init.ts surface and file follow-on for the shared code.

### Lens 2 — @luminary michael-feathers (characterization pin)

- R3 — cli#241 current fixture (Session L jamie-riff golden-capture.txt) was captured against the old symlink shape; fixing the Dockerfile may make the capture outdated. Fold — re-run the Jamie-riff capture after the Dockerfile fix; update if shape shifts.
- R4 — cli#235 "68 files refused" may be the correct behavior (Phase 0 refuse-on-collision gate) not a bug. Fold — diagnose first; only cure if the message is actually a false negative.

### Lens 3 — @luminary alan-cooper (Jamie/Sam 90s budget)

- R5 — Dockerfile change adds build time; drivers slow. Fold — measure before/after; if under 15% slowdown, acceptable. Over 15%, scope reduction (minimal shim instead of symlink restructure).

## Out of scope

- cli#388 architect-review sweep — reserve for Session O.
- Phase 3-7 LIVE /build happy path capture — reserve for Session O or later (needs gh + Playwright + auth seed; too big for Session N).
- Refresh /onboard-repo + /whereami to 1.9.11 — opportunistic; defer until either skill shape changes.
- bassclef-upstream substrate cures from Session M filings — upstream handles.
- `/promote bassclef-evolution` for pre-flight code-location probe methodology — defer; file as follow-on from Session N closeout.

## Luminary map

**Primary:** @luminary michael-feathers — characterization. cli#235 may be shipped-behavior-not-bug; cli#241 fixture pins current docker symlink shape that the fix will change.

**Supporting:**
- @luminary alistair-cockburn — walking skeleton (cli#241 Dockerfile change validates against existing 6-of-6 suite before commit)
- @luminary alan-cooper — Sam/Jamie first-touch persona bar
- @luminary linus-torvalds — upstream filings carry concrete repro + harness-covered labels (cli#320)

## References

- `docs/plans/tier-a-dynamic-driver-roadmap.md` — parent roadmap
- `docs/plans/tier-a-driver-inventory-state.md` — inventory state (amended Session M)
- `docs/session-logs/2026-10-08-session-m-tier-a-scope-routing-plus-build-env.md` — Session M log
- cli#235, cli#241, cli#320 (Session N scope-a targets)
- cli#388 (deferred to Session O)
- bassclef-upstream#2130, #2131, #2132 (Session M routings; sibling smoke pattern applies when cures ship)
- `.claude/rules/longrun-prep-plan-doc-compression.md` — converged preset shape (this doc's structure)

## Operator notes

Pre-flight check already done (table at top). Operator at Session N start can:
1. Confirm scope (a) and fire step 1
2. Pivot to scope (b/c/d) if priorities shifted
3. Add a `/promote bassclef-evolution` for the pre-flight code-location probe discipline per Session M methodology miss

Hard ceilings:
- No `auth`, `schema`, `security`, `prod-deploy` touches (routing-only for cli#320).
- No pushes to main without PR.
- Operator-gated merge mode by default.
