---
tier: lite
session_id: 2026-10-18-session-v
project: bassclef-cli
agent: personal
status: completed
tags: [release, v1.9.19, v1.11.1, cold-adopter-cures, republish, peer-coord]
started_at: 2026-10-18T16:30:00+0000
ended_at: 2026-10-18T16:35:00+0000
duration_minutes: ~30
turns: ~45
closes: []
---

# Session: v1.9.19 republish — bundling bassclef v1.11.1 (4 upstream cold-adopter cures)

## Entry State

Session U closed 2026-10-18T12:28Z shipping `@thebassclef/lite@1.9.18` bundling bassclef v1.11.0. 10 upstream defects filed from the `giveisusfree` cold-adopter smoke (upstream#2253-#2257 plus 5 others). Peer `bassclef-upstream-c7` shipped bassclef v1.11.1 within hours, curing all 5 of the upstream cold-adopter defects (PRs #2258-#2261). Session V plan at `docs/next-session-plan-2026-10-18-session-v-v1.9.19-republish.md` prescribed republish bundling v1.11.1.

Operator picked Option a (lean republish — Ask 1 + Ask 3) with explicit scope add "tests re-run". cli#444 + cli#441 folds deferred per temperance drift-trigger.

## Work Done

### Shipped

- **@thebassclef/lite@1.9.19 LIVE on npm** via OIDC trusted publisher. Bundles bassclef v1.11.1 (release_sha `3b0203d5`). Sigstore logIndex `3313776506`; `+ @thebassclef/lite@1.9.19` at 2026-10-18T16:26:25Z. 492 files; 1.5 MB.
- **PR #451 merged** (`bc38e9ac`) — single atomic release commit: `.bassclef-pin` v1.11.0 → v1.11.1 + `bassclef-version.json` sibling-sync (release_sha 3b0203d5) + `package.json`/`src/index.ts`/`README.md`/CHANGELOG bumped 1.9.18 → 1.9.19 via `npm run bump` + CHANGELOG [1.9.19] entry naming the 4 upstream cures.
- **GitHub release v1.9.19** created at https://github.com/sunj-labs/bassclef-cli/releases/tag/v1.9.19 — publish workflow fired on release-create event.

### 4 upstream cures delivered to adopters

- **bassclef-upstream#2253 + #2254** — `pre-push-shellcheck.sh` consults `lib/install-written-paths.sh` + honors state-marker SKIP bypass. First `git push` after `bassclef init` no longer BLOCKs on 72 shellcheck findings in bassclef-shipped `.sh` files.
- **bassclef-upstream#2255** — `/onboard-repo` OAuth preflight uses `claude-oauth-probe.sh` with `gtimeout`/shim fallback. Reports OAUTH_OK on macOS without gnu coreutils.
- **bassclef-upstream#2256** — `/onboard-repo` Phase 2.7 Concise prompt carries preamble + default flipped Y → n. Opt-in stays explicit.
- **bassclef-upstream#2257** — `auto-save-schedule.sh` probes `$CLAUDE_PROJECT_DIR/.claude/hooks/` first. Installer succeeds without a `~/src/sunj-labs/bassclef` sibling.
- Plus trailing housekeeping — bassclef-upstream#2261 (`~` → `$HOME` prose cleanup).

### Test tier (full re-run per operator scope add)

- vitest **525/525** PASS (up from 523 in Session U — `init.manifest.json .version` tests gained via v1.11.1 bundle)
- typecheck ✓
- install harness **11/11** PASS
- bassclef-pin tier-0 **8/8** PASS
- sync-bassclef-version tier-0 **6/6** PASS
- nuke-and-fresh-install tier-0 **14/14** PASS
- pack+andon clean (492 files, 1.5 MB, no leaks)
- fast shell tier **14/14** PASS
- CI docker cold-adopter smoke **11m58s** PASS
- CI test+typecheck **38s** PASS
- CI ADR-059 validator **10s** PASS

**Total: 578/578 locally GREEN + 3/3 CI GREEN first iteration.**

## Decisions

- **Option a over b/c/d.** Lean release cycle. Session V = republish only. cli#444 fold (nuke-and-install silent delete) + cli#441 fold (bump-postcondition null-toString) deferred to separate cycles. Scope add was explicit test re-run, not substrate cures.
- **Hard-reset local main after merge.** Auto-save hook landed an empty `d207b2e` on local main while feature branch work ran. Hard-reset local main to origin/main (local-only, no force push). Confirmed `d207b2e` had 0 diff before reset.
- **cli#441 did fire during bump (H3 risk).** `npm run bump patch` wrote all 4 files correctly (package.json + src/index.ts + README + CHANGELOG at 1.9.19) but postcondition check crashed on null-toString. Files were consistent; test failure was in postcondition logic, not output. Deferred per temperance drift-trigger.

## Discoveries

- **Session U → Session V latency measured at ~4 hours.** Peer bassclef-upstream-c7 shipped v1.11.1 within ~2h of Session U close; cli-side republish shipped ~2h after that. End-to-end "upstream cure → adopter npm" latency = 4h for this cycle. Session U had suggested cli#447 (mechanical sibling-smoke pre-publish gate) could tighten this; the Session V evidence confirms the gap exists but is small on this cycle (operator-driven cadence).
- **npm run bump postcondition bug is reliably reproducible under normal use.** Fired on both Session U and Session V. cli#441 should ride a near-term cycle; failure mode is noisy but not corrupting (files land correctly).
- **ADR-012 (open PR #449) design still valid.** v1.9.19 release path showed the exact flow ADR-012 proposes to gate: fresh pin → bundle → test tier → publish. The 4-hour latency is the window ADR-012 would close.

## Pre-mortem fold

3-lens ledger at `docs/risk-ledgers/2026-10-18-session-v-v1.9.19.md` fired 15 risks. 4 folded into plan: L1+L2 (sibling verify precondition — verified `97c8e5e4` at v1.11.1 before sync), L3+H2+H5 (pack+andon + explicit postcondition grep — tarball bassclef-version.json verified v1.11.1), H3 (bump-postcondition grep across 4 files — fired but caught manually), N5 (temperance drift-trigger — held on cli#441 + cli#444 defer).

## Peer coord

- Operator or peer-coord to run cold-adopter smoke on `giveisusfree` post-publish (Ask 3 of plan doc). All 4 upstream cures should land clean.
- cli#447 pilot pending (Ask 4; strategic; separate session).

## Luminary rotation

- **Lead: Linus Torvalds** — we-don't-break-adopters at the publish-pipeline surface. Publish latency = adopter pain; the republish honored the discipline.
- **Supporting: Tony Hoare** — pre/postcondition contract. Precondition `.bassclef-pin` v1.11.1 + bassclef-version.json release_sha 3b0203d5. Postcondition `dist/lite/bassclef-version.json` reads v1.11.1 (verified before commit).
- **Supporting: Michael Nygard** — release cycle stability pattern. Session U path proven; Session V reused it unchanged.
- **Supporting: Michael Feathers** — characterization tests pin REAL tarball shape via full tier re-run before publish.

## Loop discipline

- **/temperance** fired at `state/markers/temperance/feat-v1.9.19-bump-v1.11.1.marker`. Scope held clean.
- **/luminary** marker at `state/markers/luminary/feat-v1.9.19-bump-v1.11.1.marker`.
- **/pre-mortem light** marker at `state/markers/pre-mortem/feat-v1.9.19-bump-v1.11.1.marker` citing ledger.
- **/loop** iteration 1 — one RED on cli#441 null-toString postcondition (deferred). Rest GREEN first pass.

## Next-session queue

**PRIMARY** — Peer-coord cold-adopter smoke on `giveisusfree` + file follow-ups if any of the 4 upstream cures regress. Operator runs:

```bash
curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-and-fresh-install.sh \
  | bash -s -- --purge-adopter
```

**SECONDARY** — cli#441 bump-postcondition quick-fix (hit 2x now across Sessions U + V; cure is small; defer-count = 2).

**STRATEGIC** — cli#447 (mechanical pre-publish gate pilot per ADR-012). Three release cycles over multiple sessions. Operator schedules.

**TRIAGE** — Dependabot #423 (node 25-slim docker base bump).
