---
tier: lite
---

# Whereami — bassclef-cli

Current project-state snapshot. Schema: `standards/whereami-schema.md`.
Read at session-start, updated at session-end.

## Project-level phase

phase: Construction
note: Execution home for Goal A — build + launch `@thebassclef/core` on npm. Bassclef substrate inherited via user-scope `~/.claude/hooks/bassclef-sync.sh`; this repo carries only the config layer + build artifacts. Model C direction (open core) locked in ADR-005 §Amendment 2026-08-12 pass 2.

## Active iteration

iteration_bet: Node 20 → 22 bump in GHA workflows (SHIPPED as PR #69 → main commit 399bfb5 on 2026-09-12)
iteration_started: 2026-09-12
session: docs/session-logs/2026-09-12b-node-22-bump.md
iteration_phase: **SHIPPED — Node 20 → 22 bump merged to main via PR #69 (399bfb5) at 2026-09-12T19:58:17Z.** GHA deprecation warning that fired on the v0.1.3 publish run now cleared for future publishes. 3 setup-node@v4 pins bumped to '22' across harness.yml + publish.yml; Tier 0 grep test at tests/workflow-node-version.test.ts pins the invariant so future regressions surface at PR time. Issue #66 auto-closed via `Closes #66`. Local suite 232/232 GREEN (229 prior + 3 new); CI ran the modified harness workflow on Node 22 as the first Node 22 signal. Session ran ~15 turns end-to-end. Next scope waits on bassclef-upstream 12e (wiring manifest tier extension + dist/<tier>/ tree) for the cli-side #68 init fix per ADR-051 D1 hybrid Path 1 + Path 2.

open_threads:
  - **#68 — ADR + OOAD updates post-ADR-007 pivot** (filed 2026-09-12 by bassclef-upstream side; blocks on upstream 12e). Waits for wiring manifest tier extension + dist/<tier>/ tree + Feathers characterization test at bassclef-upstream. Cli-side scope: ADR-002, ADR-005, ADR-007 amendments + UC-init + npm-install-harness-domain updates + new ADR pinning manifest-as-init-contract. Then the one-PR init fix walks dist/<tier>/ + copies verbatim.
  - **#67 — session-start prompt for auto-sync when adopter behind latest** (filed 2026-09-12). Depends on upstream 12e shipping `.bassclef-source.json` template + cli init fix landing. Cross-ref comment added.
  - Cooper #1 pre-mortem gap — silent-install adopters (never re-run install) miss the deprecation notice on @thebassclef/core. Follow-on ticket recommended: session-start hook that checks bundled package name against expected.
  - Unpublish @thebassclef/core after grace window per memory `project_lite_is_free_tier_package.md`. No specific date set; operator judgment.
  - Cold-adopter smoke test on second macOS profile — still blocked on operator resetting the second profile's password. Test plan at docs/test-plans/2026-08-31-cold-adopter-smoke-0.1.1.md.
  - Journal drafts still in `docs/operator-private/journals/` awaiting Google Doc push (no `journal_doc_id` configured).
  - Issue #42 — extract substrate-bundled assertion to scripts/ + Tier 0 test. Standalone bug, ~25-45 turns.
  - Issues #46 + #49 (/promote candidates) still awaiting bassclef triage.
  - **#70 — bassclef-evolution: bet-doc-gate.sh false-positive on parent_bet: null / parent_roadmap: null** (filed 2026-09-12b). Substrate hook reads YAML nulls as declared parents needing citation; workaround is dropping null keys entirely.
  - **#71 — bassclef-evolution: whereami-schema §Last updated section drift** (filed 2026-09-12b). SessionStart hook warns on the observed adopter pattern (parenthetical summary + stacked prior_session entries); reconcile schema or hook message.
  - **#72 — bassclef-evolution: /promote ingest hook misses bassclef-cli** (filed 2026-09-12b; mirrored at bassclef-upstream#1612). Two-part gap — bassclef-cli not in child_repos list AND hook repo-name check fails on bassclef-upstream sessions. Motivated by 8 open bassclef-cli promote tickets sitting 13+ days with zero triaged.

next_bet: wait for upstream 12e merge notification, then file cli-side one-PR init fix (reads dist/<tier>/ + copies verbatim + mirror characterization test)

## Operator recap

2026-09-12b short session bumped Node 20 → 22 in GHA workflows. Scope was the smallest available maintenance thread — 3 `node-version:` pins in `.github/workflows/harness.yml` + `.github/workflows/publish.yml`, all under `actions/setup-node@v4`. PR #69 opened + merged same-session (main commit `399bfb5c48c9f08a55f15d5271b7cfbcaa3fa82c` at 2026-09-12T19:58:17Z). Issue #66 auto-closed via `Closes #66`. Session shipped 2 commits — `85398ac` Step 0 prep (goal doc + risk ledger + 4 markers) + `c149af9` Step 1+2 (workflow edits + Tier 0 grep test + npm@11 comment cleanup where the "incompatible with node 20 EBADENGINE" reason no longer applies). Tier 0 grep test at `tests/workflow-node-version.test.ts` pins 3 invariants — every pin 22+, count stays at 3, no stale `Setup Node 20` step name. Full suite 232/232 GREEN locally on Node 24 (229 prior + 3 new); CI ran the modified harness workflow on Node 22 as the first Node 22 signal. Pre-mortem light 3 lenses × 15 risks — F1 (Feathers, characterization gap on build parity across Node versions) folded into Step 2 verify; N1 (Nygard, publish job could fail mid-run) mitigated by existing operator environment gate. `/architect-review` skipped — 3-file workflow-only change, no substrate wiring change, no cross-cutting concerns. Session ran ~15 turns. Next work waits on bassclef-upstream 12e merge notification.

prior_operator_recap: 2026-09-12 session shipped `@thebassclef/lite@0.1.3` live via trusted publisher (OIDC + provenance) — first non-manual publish since the trusted-publisher UI unblocked mid-session. Session ran ~120 turns across ~5 hours. Cold-adopter test on isolated macOS profile surfaced #60 — `bassclef init --dry-run` reported 2 files while real run wrote 283 (~140x under-report). Root cause at `src/commands/init.ts:125-127` — dry-run returned early before invoking `dispatchSubstrateCopy`; `copySubstrate` already had the dry-run gate at `src/lib/copy-substrate.ts:51,142-145` but never got called with the flag. Two-line wiring fix shipped as PR #61 (81c8ed6) with Beck RED/GREEN Tier 0 test + counter unification + `--help` rewrite. Bumped 0.1.2 → 0.1.3 as PR #65 (4bf8f15); tagged v0.1.3; GitHub Release fired the publish workflow; operator approved environment gate; publish landed. Cold-adopter smoke on live 0.1.3 install confirmed all three fix defects end-to-end. Trusted publisher path: pursued NPM_TOKEN fallback after `/diagnose` of the 404, then closed PR #64 + #62 + #63 when the setup UI loaded successfully. Also filed #66 (Node 20 → 22 bump — closed same-day by this session's follow-on) + #67 (session-start prompt for auto-sync when behind). Cross-session dialogue with bassclef-upstream surfaced a bigger class — `settings.json` ships `hooks: {}` empty at init time; 14+ vendored hooks dead-letter on every cold adopter since 0.1.0. Boundary converged on hybrid Path 1 + Path 2 per ADR-051 D1 — upstream owns the wiring manifest; cli reads dist/<tier>/ verbatim. Cli-side one-PR fix (bassclef-cli#68) waits on upstream 12e. All 229/229 tests green throughout.

previous_recap: 2026-09-11 /longrun shipped PR #56 — cold-adopter `--help` first-run hint + 4 tagline proposal drafts. Session ran ~90 turns. Reconciled ticket #55 scope against ADR-008 D2 at Step 1 by reading source before writing code. Original ticket asked for a uniform zero-state nudge on sync + migrate + bare `bassclef`. Reading `src/lib/manifest-io.ts` L34-40 showed sync already refuses with a Cooper-good message pointing at init. Reading `src/lib/migrate.ts` L86-105 showed migrate no-manifest dispatches Path B full-init per ADR-008 D2 (deliberate design; not a bug). Shipped a one-line `USAGE` addition + 5 Tier 0 tests. Suite 227/227 GREEN.

previous_recap: 2026-09-07 /longrun executed the full 8-step chain and shipped `@thebassclef/lite@0.1.0` live to npm. Session ran ~130 turns end-to-end. Coordination ticket #51 Q1 closed. Peer bassclef-web session flagged a manifest-shape crash class mid-flight (upstream #1508 dropped `upstream_commit`); grep of bassclef-cli source returned zero reads, converted the heads-up into a Tier 0 test (PR #52). Pre-mortem light Saltzer #1 (tarball leak class) shipped as PR #53. Rename + version bump + ADR-004 Amendment + CHANGELOG landed as PR #54. Substrate sync surfaced 8 stale v1.2.19 files on first run; `rm -rf substrate/ && re-run` cleaned. Tag v0.1.0 moved from dangling core@0.1.0 attempt to the merge commit. GHA publish workflow failed with npm 404 (trusted publisher not attached to lite package); operator + I diagnosed persistent 404 across mobile web + desktop web + second Mac + two request IDs — filed as follow-on. Shipped via manual `npm publish` from operator's own Mac with Touch ID. @thebassclef/core deprecated across all 3 versions with migration message. Coord ticket #51 comment posted. All 222 tests green throughout.

previous_recap: 2026-09-05/06 /longrun prep — scope discovery + option-shape iteration. Coordination ticket #51 was the anchor. Operator surfaced two shape changes mid-prep — (1) `@thebassclef/lite` is the new free-tier package name; `@thebassclef/core` is redundant. (2) Manifest sync belongs with the rename; upstream at `manifest_version: 1.4.1` vs bundled 1.2.19 drift. Landed on Option a-plus proposal (sync + validate + rename + publish `@thebassclef/lite@0.1.0`, ~70-120 turns). Scope not confirmed this session; goal proposed pending next-session dispatch. No code shipped.

previous_recap: 2026-08-31 emergency-cure session. Smoke on published 0.1.0 revealed the tarball shipped without the runtime manifest — adopters got 2 files instead of 149. Root cause via /diagnose: prepublish script never wrote `substrate/.bassclef/lite-manifest.json`; `copySubstrate` threw at runtime; `dispatchSubstrateCopy` silent-catch hid the error. Two-part cure landed in PR #47 (prepublish writes manifest with Saltzer-Schroeder postflight assertion + init fails loud per Nygard). First 0.1.1 publish attempt failed at CI checks — new fail-loud path exited 2 in init tests because workflow ran `npm test` before prepublish populated substrate. PR #48 reordered the workflow. Retagged v0.1.1, republished, operator approved environment gate, publish succeeded. Live registry: `[0.0.1, 0.0.2, 0.1.1]`. 0.1.0 unpublished via `npm login` browser flow + Touch ID + `npm unpublish` (npm 2FA is a MacBook Touch ID security key, not TOTP). Follow-on PR #50 shipped 10-step cold-adopter smoke test plan for the second macOS profile + `scripts/smoke-reset.sh` reset helper (bounded to `~/tmp/bassclef-smoke-test` + global npm entry; --dry-run supported). /promote #49 filed as a designed proposal for auto-trigger of bassclef-cli + bassclef-web when public bassclef ships a lite-tier change (recommends `workflow_dispatch` from public bassclef; 5 open questions for triage).

previous_recap: 2026-08-30 fifth session — /longrun scope-e migrate Option c (full ship Steps 1-8) landed autonomously per orchestrator-gated dispatch. 7 atomic commits shipped in order (UC-migrate → decomposition → ADR-008 + risk ledger v1 → Tier 0 RED harness + Step 3.5 corrections → Phase 1 argv reducer → Phase 2 full migrate + RFC N3/N4/S2/L3 refinements → Step 7 signoff). PR #39 open. Full Beck GREEN — 29 files / 210 tests pass. New surface: `bassclef migrate` subcommand with Path A (0.0.2 → 0.1.0 preserving 3 config files via SHA-256) + Path B (0.0.1 → full init dispatch via runInit reuse). Interactive prompt via readline/promises + ttyOverride injection. RFC refinements — N4 folder guidance in init + migrate final lines; S2 import.meta.url refactor with createRequire fallback; L3 CHANGELOG precedent note pinning "adopter migration ships as MINOR". Two preflight corrections landed at Step 4 — detectLegacyManifest is boolean (not enum; composed inside migrate.ts as detectAdopterState); 3rd config file is substrate.secrets.md (not CLAUDE.md; per v0.0.2 fixture). One friction — R3 test initially failed because fixture used fake bundle hashes; real SHA-256 in fixture unblocked. Retro skipped per lite tier gate; two-line note in session log covers what worked + what did not.

previous_recap: 2026-08-30 fourth session — PR #36 merged 2026-08-30T05:52:48Z (scope-b1 shipped). Operator asked "file the follow-on ticket to bassclef-upstream and proceed" — I initially filed the two /promote tickets directly at upstream (#1430 gitignore lib pattern + #1431 RFC-as-skill), which bypassed the /promote workflow (files at adopter repo; upstream pulls via /triage-public). Operator caught the process error; I refiled locally at bassclef-cli#37 (gitignore lib pattern) + bassclef-cli#38 (RFC-as-skill outside-luminary council), added cross-ref comments + closed the two upstream tickets. Then operator picked scope-e Option b (`bassclef migrate` subcommand) over Option a (0.1.1 sync auto-migrate) for adopter-agency reasons per Cooper lens. Started scope-e branch feat/scope-e-migrate; Step 0 landing this turn — goal doc + markers.

previous_recap: 2026-08-29 third session — /longrun prep + Steps 4-7 of scope-b1 landed autonomously for goal 2026-08-28d. Operator said "go step 4, orchestrator-gated" then went to gym; interpretation B fired (continue through Step 4-8 sequence per orchestrator-gated mode + prep-confirmed Option a scope). 15 commits landed. Grep audit: 13 unique @risk/@rfc refs in tests match 13 unique refs in commit trailers. Vitest final: 23 test files GREEN / 179 tests pass. PR #36 CLEAN + MERGEABLE + subsequently merged 2026-08-30T05:52:48Z (commit ae8ac31).

next_bet: post-merge — tag + publish @thebassclef/core@0.1.1 (or 0.2.0 per operator judgment); update whereami subsystem row; scope-e follow-ons (RemoteFetchStrategy restoration + S1 signature verification) available for a future goal

previous_recap: 2026-08-29 second session — /longrun prep + Steps 4-5 of scope-b1 landed for goal 2026-08-28d. Operator said "go step 4, orchestrator-gated" then went to gym. Compressed prep fired per SKILL Step 0.85. Step 4 shipped 6 commits with 22 Tier 0 tests carrying @risk R# / @rfc <ID> comments per bassclef-upstream#1420 build wiring. Beck RED confirmed. Step 5 shipped scripts/prepublish-bundle-substrate.mjs + package.json extension + .gitignore extension. Vitest after Step 5: 19 files pass / 4 fail. Total turns: ~50. Paused at Step 5 → Step 6 boundary for operator return.

previous_recap: 2026-08-29 first session — /longrun prep + Steps 0-3.5 landed for goal 2026-08-28d (npm-lite substrate bundling). 5 commits pushed on branch docs/2026-08-28-npm-lite-substrate-bundling-plan. Artifacts: goal doc + fully-dressed UC + decomposition with @pattern calls + ADR-007 + risk ledger v3. Mid-session finding — decomp mislabeled 2 existing modules (`write-safely.ts` and `manifest-io.ts`) as new; corrected via preflight commit 5f1155e. Operator asked for /architect-review + fresh /pre-mortem with council of luminaries outside authoring set — RFC-0001 written (5 outside luminaries: linus + hyrum + brooks + saltzer-schroeder + norman); 16 findings surfaced across HIGH/MEDIUM/LOW. Operator picked revised B — scope-b1 (bundle + init copy + sync 149-walk; migration deferred to scope-e). Ledger v3 + goal amendment + ADR-007 amendment + scope-e plan all landed. 2 /promote tickets filed at bassclef-upstream — #1420 (evolution: pre-mortem-to-compensator mapping as first-class /longrun output; this goal dogfoods) and #1421 (substrate-defect: hook section extractor false-positive on cross-reference; observed 3× this session). PR #36 rebased green.

previous_recap: 2026-08-28 short session — operator dispatched /longrun prep for the npm-native lite substrate bundling plan, then waved off. The prompt belonged in bassclef-web, not bassclef-cli. Compressed prep did read the plan doc + whereami + parent goal frontmatter and drafted Option b (combined Phase 1 + Phase 2) scope, but no goal doc was created and no commits landed. Plan doc at docs/next-longrun-prep-2026-08-28-npm-lite-substrate-bundling.md is still current for the next bassclef-cli /longrun that picks up npm-native lite bundling.

previous_recap: 2026-08-27 session shipped iteration i — install harness for @thebassclef/core with full OOAD ceremony per operator direction. 7 commits on feat/iteration-i-npm-install-harness. 11 tests pass at 735ms local; 1 test skipped by design (published-fetch scenario env-gated). Two /loop iterations both RED → GREEN in one cycle each (npm -g flag defect at Step 6a; stale walking-skeleton assertion at Step 6b). Feathers lead lens signed off; Cockburn + Cooper + Nygard + Prater + Ousterhout supporting. 3 pre-mortem light runs (Step 0, Step 6b, Step 7); 27 total risks named + strongest folded per step. Step 8 pattern-annotation pass surfaced substrate gap — 3 bassclef-upstream catalog entries missing (fowler test-fixture, gof command, gof template-method); false annotations removed per pattern-annotation.md rule; follow-on candidate named in session log. Step 9 workflow verify deferred to post-merge (feature branch can't dispatch workflow_dispatch until file lands on default). PR awaits operator review.

previous_recap: Short 2026-08-18 followup session. Filed bassclef-upstream#1197 — meta-ticket for the OOAD-plus-traceability chain as a first-class bassclef offering, with a luminary consult ask on over-engineering guard + adopter tier boundary. Cross-commented on umbrella #1171. Closed stale PR #10 without merge (path b). No code shipped.

previous_bet: —
next_bet: 2026-08-29-npm-lite-scope-e (migration + follow-ons; see docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md)

## Shipped (across session history)

**Base ship (WU-1 through WU-5 per goal doc):**

- PR #1 — chore/bassclef-bootstrap MERGED (substrate config layer)
- PR #3 — feat/wu-1-scaffold MERGED (scaffold shell + package.json + LICENSE + WU-1 tests)
- PR #4 — feat/wu-2-init MERGED (bassclef init command with ADR-002 safety contract)
- PR #5 — feat/wu-3-sync MERGED (bassclef sync command with ADR-003 safety contract)
- PR #6 — chore/decomp-diagrams-backfill MERGED (WU-2 + WU-3 state + sequence diagrams)
- PR #7 — feat/wu-4-publish MERGED (publish pipeline with ADR-004)
- PR #8 — docs(wu-5): backfill ADRs + interaction-design + use cases MERGED
- PR #9 — feat(wu-5): semver + changelog methodology + bump script MERGED

**Session 2026-08-11 to 2026-08-12 (audit + Model C arc):**

- PR #11 — feat(security): source-map exclusion before first tag MERGED (iteration a)
- PR #12 — docs(audit): OOAD audit outputs + Traceability Subsystem promote draft MERGED
- PR #13 — fix(docs): iteration b drift fix pass — 13 items MERGED
- PR #14 — docs(requirements): SysML requirement diagram MERGED (iteration f)
- PR #15 — feat(design): iteration c — 4 design decisions MERGED
- PR #17 — feat(traceability): iteration d — mechanical enforcement MERGED
- PR #18 — docs(traceability): sequence diagrams added to requirements + promote MERGED
- PR #21 — feat(traceability): iteration g — git pre-commit hook bridge MERGED
- PR #22 — docs(traceability): iteration h — substrate hook spec MERGED
- PR #23 — docs(promote): cross-reference filed ticket bassclef-upstream#1182 MERGED
- PR #24 — docs(adr): ADR-005 amendment — pivot to Model C MERGED
- PR #26 — docs(adr): ADR-005 second amendment — Model C contract accepted MERGED

**Session 2026-08-13 (iteration e + npm 11 cure):**

- PR #28 — chore: release v0.0.2 MERGED
- PR #29 — fix: sync src/index.ts version constant with package.json MERGED
- PR #30 — fix(ci): declare id-token permission at publish job level MERGED
- PR #31 — fix(ci): upgrade npm before publish for trusted publisher MERGED
- PR #32 — fix(ci): pin npm upgrade to @11 for node 20 compat MERGED
- npm publish landed on run 31688236246 — `@thebassclef/core@0.0.2` live with provenance

## In flight

- **Goal 2026-08-30a — scope-e bassclef migrate SHIPPED via PR #39.** 7 atomic commits on feat/scope-e-migrate. Test state: 29 files GREEN / 210 tests pass; ledger v2 all 11 rows verified. Awaits operator merge review. On merge, tag + publish @thebassclef/core@0.1.1 (or 0.2.0 per ADR-008 D6 amendment) via existing publish workflow.
- Goal 2026-08-28d — npm-lite substrate bundling (scope-b1) SHIPPED via PR #36 merge ae8ac31. 0.1.0 not yet on npm; publish gated on operator dispatch of existing workflow per ADR-004.
- Iteration i — install harness SHIPPED 2026-08-27; PR on feat/iteration-i-npm-install-harness awaits operator review + merge.
- PR #10 — pre-existing stale session-close PR from 2026-08-08. Merge-conflict-dirty. Operator disposition pending (path a rebase / b close / c leave).
- bassclef-cli #25 — Model C reader implementation. Waits on bassclef-upstream #1184 shipping `scripts/build-lite-bundle.sh` + `dist/lite/` tree.
- bassclef-cli #16 — `@thebassclef/lite` reservation. Operator started this session; ticket stays open until `@thebassclef/lite@0.0.1` shows on npmjs.com.
- bassclef-cli #19 — `@thebassclef/standard` reservation. Lower priority.
- bassclef-cli #20 — `@thebassclef/ultra` reservation. Lower priority.

## Cross-repo tickets filed this session

- bassclef-upstream #1182 — Traceability Subsystem umbrella promote. Filed 2026-08-12. Awaits triage.
- bassclef-upstream #1184 comment 5265798011 — confirmation of (A) for lite tier extraction. Waits on upstream `/longrun` schedule.
- bassclef-upstream #1420 — pre-mortem-to-compensator mapping as first-class /longrun output. Filed 2026-08-29 (this session). Adopter-source: bassclef-cli goal 2026-08-28d dogfoods the pattern.
- bassclef-upstream #1421 — hook section extractor false-positive on cross-reference. Filed 2026-08-29 (this session). Observed 3× during /longrun prep compounding-axis check.

## Active agents

- operator-gated-sequential (this session ran orchestrator-gated for the audit + fix arc)

## Subsystem phases

| Subsystem | Phase | Last iteration | Notes |
|-----------|-------|---------------|-------|
| npm package (`@thebassclef/core`) | Construction | 2026-08-12 | 12 audit-driven PRs merged; iteration e blocked on operator npm setup |
| CLI dispatcher | Construction | 2026-08-12 | Complete: init + sync + publish workflow all merged |
| Publish pipeline | Construction | 2026-08-12 | Two-job shape (checks + publish) with environment gate after checks green |
| Bump discipline | Construction | 2026-08-08 | `scripts/bump-version.mjs` + `standards/npm-versioning-and-changelog.md` + 27 tests |
| Requirement traceability | Construction | 2026-08-12 | Static diagram + Vitest enforcement + git pre-commit + upstream promote filed |
| npm 0.0.1 reservation | DONE | 2026-07-12 (pre-session) | `@thebassclef/core@0.0.1` on npm; verified via `npm view` this session |

## Gate progress (project-level)

### Inception — COMPLETE
- [x] Vision doc (goal at docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md)
- [ ] Risk register populated
- [x] Appetite set (8 WUs per goal)
- [x] Viability hypothesis written (goal doc)
- [x] Build/buy/defer decision (build — npm distribution)

### Elaboration — COMPLETE
- [x] Architecture decisions (ADR-001 through ADR-005 all accepted; ADR-005 twice amended for Model C direction + contract)
- [x] Standards defined (`standards/npm-versioning-and-changelog.md`; upstream ships `lite-manifest.json` for extraction contract)
- [ ] Design principles established (partial — luminary map + ADRs cover most surfaces)
- [x] Object model documented (interaction-design + 4 UCs + 5 decompositions + requirement diagram)

### Construction — IN PROGRESS
- [x] TypeScript + Vite scaffold — merged (PR #3)
- [x] package.json with `bin` + files array whitelist + Apache-2.0 LICENSE — merged (PR #3, whitelist tightened in PR #11)
- [x] Init command with safety contract (ADR-002) — merged (PR #4)
- [x] Sync command with safety contract (ADR-003) — merged (PR #5)
- [x] npm publish workflow with safety contract (ADR-004) — merged (PR #7, split into two jobs in PR #15)
- [x] Semver + changelog methodology — merged (PR #8, #9)
- [x] Source-map safety — merged (PR #11)
- [x] Static requirement diagram — merged (PR #14)
- [x] Traceability enforcement Vitest — merged (PR #17)
- [x] Model C direction + contract accepted — merged (PR #24, #26)
- [ ] Model C reader implementation (bassclef-cli #25) — waits on bassclef-upstream #1184
- [x] Install harness (iteration i) — 7 commits on feat/iteration-i-npm-install-harness; 11 tests pass + 1 env-gated skip
- [ ] Cold-adopter harness against npm path (WU-6 — bassclef-upstream side; separate from iteration i)
- [ ] Adam Sharpe security PRs (WU-7 — deferred per goal L128)
- [ ] Sam demo (WU-8 — needs live 0.0.2)

### Transition — PENDING
- [x] npm 0.0.1 name reservation (done 2026-07-12)
- [x] Trusted publisher config on npmjs.com (operator setup 2026-08-13)
- [x] GitHub Environment `npm-publish` with operator as required reviewer (operator setup)
- [x] First tagged 0.0.2 release (iteration e SHIPPED 2026-08-13; workflow run 31688236246)
- [x] Install harness (iteration i) — SHIPPED 2026-08-27; PR awaits operator merge
- [ ] `/architect-review` run at goal close
- [ ] Session log for goal close

## Open promote tickets

**bassclef-upstream:**

- #1167 — wire OOAD dispatch into /longrun
- #1168 — wire OOAD dispatch into /build
- #1169 — mechanize oo-ad-entry-point.md as PreToolUse hook
- #1170 — adr-discipline-check.sh warn on proposed ADRs after PRs merge
- #1171 — umbrella: OOAD artifacts as first-class inputs to /build /longrun /sprint
- #1182 — Traceability Subsystem umbrella (filed this session)
- #1184 — extract build implementation per ADR-051 D4 (awaits `/longrun` schedule)

## Risk register

- WU-7 (Adam Sharpe security PRs) deferred per goal L128 — must land before 0.1.0 or 0.0.3.
- Model C reader work (bassclef-cli #25) depends on bassclef-upstream #1184 shipping. If upstream deprioritizes, iteration e still ships (0.0.2 stays on the current story) but the Model C bundled shape slips.
- Paid tier extraction contract (Q4 from Model C amendment) pending. If deferred too long, could block a paid-tier launch when the moment comes.

## Last updated

2026-09-12T20:00:00Z — session-end (Node 20 → 22 bump shipped via PR #69 → main commit 399bfb5; issue #66 auto-closed via `Closes #66`; Tier 0 grep test tests/workflow-node-version.test.ts added; suite 232/232 GREEN; ~15 turns)
session: docs/session-logs/2026-09-12b-node-22-bump.md

prior_session: 2026-09-12T16:45:00Z — session-end (@thebassclef/lite@0.1.3 shipped live to npm via trusted publisher OIDC + provenance; PR #61 fixed #60 dry-run parity; PR #65 released 0.1.3; issues #66 + #67 + #68 filed; cross-session boundary alignment with bassclef-upstream on hybrid Path 1 + Path 2 per ADR-051 D1)
prior_session_log: docs/session-logs/2026-09-12-dry-run-fix-plus-trusted-publisher-plus-boundary-align.md

prior_session: 2026-09-12T00:30:00Z — session-end (@thebassclef/lite@0.1.2 shipped live to npm; PRs #56 + #58 + #59 merged; tag v0.1.2 pushed; substrate refreshed v1.5.1 → v1.5.7; skipped 0.1.1 for lite due to core tag conflict)
prior_session_log: docs/session-logs/2026-09-11-cold-adopter-nudge-plus-taglines.md

prior_session: 2026-09-07T19:30:00Z — session-end (@thebassclef/lite@0.1.0 shipped live to npm; PRs #52 + #53 + #54 merged; tag v0.1.0 pushed; @thebassclef/core deprecated across 3 versions)
prior_session_log: docs/session-logs/2026-09-07-lite-rename-sync-publish-shipped.md

prior_session: 2026-08-30T14:00:00Z — session-end (goal 2026-08-30a scope-e migrate SHIPPED — Steps 1-8 landed autonomously per orchestrator-gated dispatch full-ship Option c; 29 test files GREEN / 210 tests pass; ledger v2 all 11 rows verified; PR #39 open for operator review)
session: docs/session-logs/2026-08-30-longrun-scope-e-migrate-full-ship.md

prior_session: 2026-08-29T23:20:00Z — session-end (goal 2026-08-28d scope-b1 code phase complete)
prior_session_log: docs/session-logs/2026-08-29-longrun-npm-lite-steps-4-through-7.md

2026-08-29T20:50:00Z — session-pause (goal 2026-08-28d scope-b1 Steps 4-5 shipped; Beck RED harness + prepublish bundle script both landed; paused at Step 5 → Step 6 boundary)
prior_session: (subsumed by 2026-08-29T23:20:00Z session log above)

2026-08-29T14:00:00Z — session-end (goal 2026-08-28d scope-b1 Steps 0-3.5 shipped + RFC-0001 council review accepted with revised B disposition)
prior_session: docs/session-logs/2026-08-29-longrun-npm-lite-steps-0-through-3.5-plus-rfc-0001.md

2026-08-28T15:02:36Z — session-end (short session; /longrun prep waved off; wrong repo; no code changed)
prior_session: docs/session-logs/2026-08-28-longrun-prep-waved-off.md

## Configuration

See substrate.config.md for external resource references.
