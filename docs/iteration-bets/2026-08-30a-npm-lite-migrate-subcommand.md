---
goal: 2026-08-30a-npm-lite-migrate-subcommand
title: bassclef migrate subcommand (scope-e — adopter 0.0.x → 0.1.0 upgrade path)
project: bassclef-cli
execution_repo: sunj-labs/bassclef-cli
status: in_flight
authored: 2026-08-30
authored_by: agent
in_flight_goal: 2026-08-30a-npm-lite-migrate-subcommand
parent_goal: docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md
grandparent_goal: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
parent_roadmap: bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md
sibling_plan: docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md
scope_e_option_picked: b (bassclef migrate subcommand)
scope_e_option_picked_at: 2026-08-30
scope_e_option_picked_reason: |
  Cooper lens — Sam is deliberate; explicit commands beat silent state changes. Adopter drives the upgrade at their timing. Compounds by teaching a reusable subcommand pattern for future migrations.
time_budget: 200-250 turns
time_budget_source: |
  Plan doc L64-65 (docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md) grounds
  200-250 turns for Option b — new subcommand with dedicated safety envelope +
  interactive prompts + more testing surface than the 0.1.1 sync auto-migrate
  path (Option a, 150-200 turns).

  Prior comparable — scope-b1 goal 2026-08-28d spent ~385 turns total across
  three /longrun sessions for 8 substantive steps (Steps 0-7 shipped per
  session logs 2026-08-29-longrun-npm-lite-steps-0-through-3.5 + steps-4-through-7).
  Scope-e Option b is ~7 substantive steps; the wider top of this range
  covers the interactive prompt design surface Option a does not carry.
authoring_luminaries:
  primary: [linus-torvalds, john-ousterhout]
  supporting: [david-parnas, michael-nygard, alan-cooper, michael-feathers]
lead_lens: linus-torvalds
lead_lens_rationale: |
  Migration is an adopter-contract discipline. Linus lens leads — "we don't
  break userspace" applied per config file (adopter edits on
  .claude/settings.json + substrate.config.md must survive the upgrade).
  Ousterhout keeps the migrate module deep + the command interface shallow.
  Cooper drives the interactive prompt UX.
tickets:
  - {repo: bassclef-cli, id: 37, anchor: local /promote — sync-managed .gitignore lib pattern}
  - {repo: bassclef-cli, id: 38, anchor: local /promote — RFC council as skill}
references:
  - {type: plan, id: docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md, anchor: scope-e plan doc; Option b picked}
  - {type: goal, id: docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md, anchor: parent goal (scope-b1 SHIPPED via PR #36 merge ae8ac31)}
  - {type: rfc, id: docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md, anchor: RFC-0001 revised B disposition names scope-e deferrals}
  - {type: risk-ledger, id: docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md, anchor: ledger v4 signoff notes scope-e deferrals}
  - {type: adr, id: docs/adrs/ADR-007-npm-lite-substrate-bundling.md, anchor: parent ADR for the bundle contract; ADR-008 to author at Step 3}
  - {type: session-log, id: docs/session-logs/2026-08-29-longrun-npm-lite-steps-4-through-7.md, anchor: scope-b1 closeout}
  - {type: roadmap, id: bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md, anchor: parent roadmap (ACTIVE); 5-iteration market entry sequence}
adr_references:
  - {id: ADR-002, anchor: init safety envelope — migrate inherits atomic-write + symlink-refuse discipline}
  - {id: ADR-003, anchor: sync safety envelope — migrate borrows the four-case classifier}
  - {id: ADR-005, anchor: npm distribution architecture — Model C direction}
  - {id: ADR-007, anchor: scope-b1 bundle contract — migrate builds on the extended manifest shape}
  - {id: ADR-008, anchor: TO AUTHOR at Step 3 — pins the migrate subcommand contract}
---

# bassclef migrate subcommand (scope-e — adopter 0.0.x → 0.1.0 upgrade path)

## Sources read

- `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md` L26-73 — scope-e problem statement + 3-option enumeration + compounding value per option; Option b picked by operator
- `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md` L1-155 (parent goal, scope-b1) — frontmatter shape template, scope amendment section, Steps table format, acceptance format
- `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` v4 § "Deferred to scope-e" (L98-107) — 6 RFC deferrals landing here (B1 migration split + L1 no-manifest + S2 require.resolve + N3 sync output + N4 folder guidance + L3 CHANGELOG)
- `docs/session-logs/2026-08-29-longrun-npm-lite-steps-4-through-7.md` L48-72 — scope-b1 test evidence + grep audit + turn cost baseline for time budget grounding
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` head — parent contract; ADR-008 pattern will follow
- `src/lib/manifest-io.ts` L92-116 — `detectLegacyManifest` already exists from scope-b1 Step 6 per commit c84fa84; migrate builds on it, does not re-implement
- `bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` frontmatter L1-45 — parent roadmap; status ACTIVE; 5-iteration market entry sequence; parent_drivers include 5 existing adopters + 9 signups waiting; scope-e migrate directly serves the "existing adopter upgrades cleanly" driver

## What I'm NOT reading (with reason)

- RFC-0001 full body — the disposition landed at scope-b1 Step 7 signoff; ledger v4 § Deferred to scope-e carries the enumerated deferrals; re-reading the full RFC would duplicate work
- Existing init.ts + sync.ts source — Step 2 decompose reads these when the specific reuse surface for migrate is clear; premature to read at goal-doc drafting
- Roadmap body past frontmatter — the frontmatter carries the parent_drivers + parent canvas; roadmap body details iteration structure this goal's scope does not need

## Problem

Adopters on `@thebassclef/core@0.0.2` need a way to upgrade to `0.1.0` without losing their config edits. Today `bassclef init --force` is the only path — it overwrites `.claude/settings.json` and `substrate.config.md`. Adopters on `0.0.1` (name reservation) have no path at all. Scope-e adds a migration step. It detects the legacy shape. It adds the 146 new substrate files. It preserves the 3 config files an adopter already edited.

## Value

Sam runs one command:

```
bassclef migrate
```

The command detects her current install (`0.0.2` init manifest with 3 config files, or `0.0.1` name-reservation state with no manifest). It walks the bundled 149-entry manifest. It adds every substrate file that is missing. It preserves every config file she has edited. It writes a new `0.1.0` init manifest recording every file's hash.

Per @luminary alan-cooper — Sam runs the command deliberately; no surprise state change from sync.

Per @luminary linus-torvalds — every adopter edit survives; hash preservation on the 3 config files is the migrate contract. Per parent roadmap L18-19, 5 existing adopters + 9 signups depend on a clean upgrade path.

Per @luminary john-ousterhout — one CLI verb; the walk + hash + writeSafely chain hides depth inside `src/lib/migrate.ts`.

Per @luminary michael-nygard — every failure path names a fix. Missing manifest exits nonzero with `Reinstall @thebassclef/core`. Legacy shape not detected exits nonzero with `Adopter state does not match 0.0.x or 0.1.0`. Adopter mid-migration crash resumes cleanly on rerun.

## Evidence

- **Source** — Plan doc `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md` L59-73 lists the 3 options with turn budgets + compounding value; operator picked Option b (`bassclef migrate`) 2026-08-30 per adopter-agency Cooper-lens rationale.
- **Warrant** — Scope-e plan doc names 6 RFC-0001 deferrals that land here (B1 migration split + L1 no-manifest case + S2 require.resolve refinement + N3 sync output rewording + N4 folder guidance + L3 CHANGELOG semver note). Ledger v4 § "Deferred to scope-e" confirms the same list. Parent roadmap parent_drivers section grounds the adopter-upgrade need.

## Scope this goal

**In scope:**
- New `src/commands/migrate.ts` + `src/commands/migrate-argv.ts` — the subcommand + argv reducer
- New `src/lib/migrate.ts` — the migrate module (detectLegacyManifest already exists from scope-b1; extend with `computeConfigHashes` + Path A migration logic + Path B init dispatch)
- Extended `src/cli.ts` — dispatch `migrate` verb
- New `docs/migrations/0.1.0.md` — adopter-facing migration doc (RFC L3 CHANGELOG note lands here too)
- New Tier 0 tests — migrate.test.ts + migrate-argv.test.ts
- ADR-008 — pins the migrate subcommand contract (safety envelope + interactive prompt shape + failure modes)
- Refinements per RFC-0001 deferrals — N3 sync output rewording + N4 init folder guidance + S2 require.resolve refinement + L3 CHANGELOG entry

**Out of scope (deferred):**
- RemoteFetchStrategy restoration + S1 signature verification — separate scope; can ship in a follow-on goal or wait for CI need
- `bassclef sync` auto-migrate (Option a shape) — operator picked Option b explicitly; auto-migrate stays available for a future goal if adopter feedback justifies

## Steps

| Step | Produces | Consumes | Time budget | Risk |
|---|---|---|---|---|
| **0** prep | goal doc + risk ledger v1 + gate markers | this proposal | 15-25 turns | 🟢 |
| **1** use-case | `docs/use-cases/UC-migrate.md` — Cockburn brief (interactive prompt shape + failure extensions) | prep | 20-30 turns | 🟢 |
| **2** decompose | `docs/decompositions/2026-08-30-migrate.md` with `@pattern` calls + `@risk R#` cites | UC | 25-35 turns | 🟢 |
| **3** ADR + ledger | `docs/adrs/ADR-008-bassclef-migrate-subcommand.md` + risk ledger with 6-8 rows | decomposition | 20-30 turns | 🟢 |
| **4** Tier 0 tests | Beck RED — migrate.test.ts (~8 tests) + migrate-argv.test.ts (~4 tests) + migrations doc test | ledger | 25-40 turns | 🟡 |
| **5** Phase 1 source | migrate-argv.ts + cli.ts dispatch (Beck GREEN for argv path) | Step 4 RED | 20-30 turns | 🟢 |
| **6** Phase 2 source | migrate.ts + `src/lib/migrate.ts` (Beck GREEN for full path) + N3/N4/S2/L3 refinements | Step 5 GREEN | 40-60 turns | 🟡 |
| **7** signoff | Linus + Ousterhout signoff marker + grep audit + PR body | Steps 4-6 evidence | 20-30 turns | 🟢 |
| **8** closeout | session log + whereami update + PR opened for review | signoff | 15-20 turns | 🟢 |

## Acceptance

- [ ] `bassclef migrate` on a fresh `0.0.2` install (3-file init manifest + no substrate files) writes the 146 substrate files without touching the 3 existing config files
- [ ] `bassclef migrate` on a fresh `0.0.1` install (name reservation; no manifest) dispatches full init flow + writes all 149 files
- [ ] Adopter edited one config file post-init → migrate preserves the edit (hash comparison detects the edit; writeSafely refuses without `--replace-edits`)
- [ ] Migrate reports counts: `146 files added; 3 files preserved; 0 errored` in default output; per-file lines with `--verbose`
- [ ] `docs/migrations/0.1.0.md` documents the upgrade path
- [ ] N3 refinement — sync output says `3 files preserved with existing content` in plain language
- [ ] N4 refinement — init final line names the `.claude/` folder + gitignore guidance
- [ ] S2 refinement — copy-substrate.ts uses `import.meta.url` + relative path resolution (replaces createRequire)
- [ ] L3 refinement — CHANGELOG 0.1.0 entry names the "adopter migration ships as MINOR" precedent
- [ ] Tier 0 tests GREEN in bassclef-cli CI
- [ ] ADR-008 committed with @luminary linus + ousterhout + parnas + nygard signoff
- [ ] Risk ledger every row `verified` at signoff
- [ ] Ready for `@thebassclef/core@0.1.1` minor bump + npm publish (0.1.0 must ship first)

## Blockers to watch

- **0.1.0 not yet on npm** — Publish workflow gated on operator dispatch. Scope-e code work can proceed without 0.1.0 live; runtime testing against a real 0.0.2 → 0.1.1 adopter needs 0.1.0 published. Track as a dependency, not a blocker for code work.
- **Interactive prompt design** — Option b adds a prompt layer. Cooper lens shapes it (Sam sees a confirmation before writes). Design at Step 2 decompose; test at Step 4.
- **Config file hash preservation** — R8 from ledger v3 (deferred to scope-e). Adopter edits to `.claude/settings.json` must survive; hash computation + writeSafely-refuse discipline pins it.
- **detectLegacyManifest already exists** — Shipped in scope-b1 Step 6 per commit c84fa84. Migrate builds on it; no re-implementation.

## References

- Plan doc — `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md`
- Parent goal — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md` (scope-b1 SHIPPED)
- Parent roadmap — `bassclef-upstream/docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` (ACTIVE)
- RFC-0001 — `docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md` (revised B disposition names scope-e deferrals)
- Risk ledger v4 — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md` (§ Deferred to scope-e)
- Parent ADR — `docs/adrs/ADR-007-npm-lite-substrate-bundling.md`
- Sister ADRs — ADR-002 (init safety) + ADR-003 (sync safety) + ADR-005 (npm distribution)
- Grandparent goal — `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- Session log (scope-b1 closeout) — `docs/session-logs/2026-08-29-longrun-npm-lite-steps-4-through-7.md`
- Local /promote tickets this session — bassclef-cli#37 + bassclef-cli#38
