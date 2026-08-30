---
date: 2026-08-29
session_id: longrun-npm-lite-scope-b1-doc-phase
goal: docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md (scope-b1)
branch: docs/2026-08-28-npm-lite-substrate-bundling-plan
mode: orchestrator-gated + sequential
tier: lite
outcome: doc phase complete + RFC-0001 accepted + scope-e planned; Steps 4-8 next /longrun
---

# Session log — 2026-08-29 — /longrun npm-lite Steps 0-3.5 + RFC-0001

## What shipped

Nine commits on branch `docs/2026-08-28-npm-lite-substrate-bundling-plan`:

- `1268cc0` — Merge origin/main (resolved PR #36 CONFLICTING → CLEAN)
- `6f2c0a9` — Step 0: goal doc + risk ledger v1 + 3 gate markers
- `db80777` — Step 1: fully-dressed UC per Cockburn (12922 bytes; 16-step main scenario; 11 extensions)
- `81dc4e3` — Step 2: decomposition with @pattern calls + @risk cites (421 lines)
- `dd6ccf4` — Step 3: ADR-007 pins the bundling contract (235 lines; 6 decisions)
- `2772aec` — Step 3.5: risk ledger v2 (127 lines; +R10 remote fetch)
- `5f1155e` — Step 4 preflight: corrected 3 docs after finding write-safely.ts + manifest-io.ts already exist
- `9724c6f` — RFC-0001: council review by 5 outside luminaries (274 lines; 16 findings)
- (pending this commit) — Ledger v3 + goal doc scope-b1 amendment + ADR-007 amendment + scope-e plan + whereami update + this session log

Total artifact output: ~1500 lines of design docs across UC + decomposition + ADR + ledger (3 revisions) + RFC + 3 amendments + scope-e plan.

## Gates fired

- `/temperance` at Step 0 session start (scope decision: bundle 146 files via npm; drift trigger 500 turns or ADR count past ADR-007)
- `/luminary` primary lens Ousterhout + Parnas signed off at Step 0 (per marker `state/markers/luminary/2026-08-28-npm-lite-substrate-bundling-plan.marker`)
- `/pre-mortem` light at Step 0 — 9 risks × 3 lenses (Ousterhout + Parnas + Nygard)
- Compounding-axis Stop hook fired 3× on Option c due to cross-reference bug (see cross-repo tickets below); worked around by rephrasing Option c body
- `/architect-review + fresh /pre-mortem` — RFC-0001 with 5-luminary outside council (linus + hyrum + brooks + saltzer-schroeder + norman); surfaced 16 findings across HIGH/MED/LOW

## Decisions

- **Scope pick** — Option b (combined Phase 1 + Phase 2) confirmed by operator at prep
- **PR #36 disposition** — merge main into branch + force-with-lease (preserved plan doc content on branch)
- **Risk ledger path** — `docs/pre-mortem-mappings/` per operator preference (over `docs/risk-ledgers/`)
- **ADR number** — ADR-007 (ADR-006 taken by install harness per iteration i)
- **RFC-0001 disposition** — revised B (scope-b1 + selective HIGH cures + defer migration to scope-e)
- **Cures absorbed in scope-b1** — L2 sync output shape, H1 manifest schema evolution, H2 count parameterization, H3 bundle path lock, N1 progress signal, N2 user-model error messages
- **Cures dropped by scope removal** — S1 (no remote fetch = no signature check needed), B3 (RemoteFetchStrategy retired)
- **Cures deferred to scope-e** — L1 no-manifest case, B1 migration split, S2 require.resolve refinement, N3 sync output rewording, N4 folder guidance, L3 CHANGELOG semver note

## Cross-repo tickets filed this session

- **bassclef-upstream#1420** — evolution: pre-mortem-to-compensator mapping as first-class /longrun output. Adopter source cited; this goal dogfoods the pattern.
- **bassclef-upstream#1421** — substrate-defect: hook section extractor false-positive on legitimate cross-reference inside option body prose. Reproducer + 3-cure-option analysis included.

## What didn't work

- Step 0 hit compounding-axis Stop hook 3× on Option c. Root cause found by reading hook source at L199-206 — awk section extractor treats any `Option [a-z]` match as a section boundary, so "same end-state as Option b" in Option c's body dropped the rest of the section. Cure: rephrased Option c to avoid the cross-reference. Filed as bassclef-upstream#1421.
- Step 2 decomp planned module names without running `ls src/lib/` first. Confidence was high on design; state check was skipped. Caught at Step 4 preflight — `write-safely.ts` and `manifest-io.ts` already existed from WU-2 iteration. 3 docs amended via preflight commit `5f1155e`. This is the class of miss the RFC-0001 council review was called for.

## What worked

- Compressed prep path (per SKILL Step 0.85) — plan doc from prior session made prep ~10 turns instead of the full ceremony
- /pre-mortem-to-compensator mapping (ledger v3) — every risk pins to a specific code target + verification command; makes Step 7 signoff mechanical
- RFC-0001 council review before test code lands — surfaced 6 HIGH findings that would have cost 100+ turns to fix if caught at Step 7 instead
- Task list for the multi-file amendment sequence — 7 tasks, all completed cleanly at close

## Cost this session

Estimated ~250 turns end-to-end (~50% context at doc-phase close). Well within the 300-500 turn goal doc budget. Doc phase averaged ~25 turns per step; RFC + amendments added ~100 turns beyond original plan; total remains under the 495-turn ceiling per revised time budget.

## Next session

Fresh /longrun for scope-b1 Steps 4-8:

- Step 4 — 22 Tier 0 tests across 5 harness files (Beck RED); every test carries `// @risk: R#` or `// @rfc: <ID>` comment
- Step 5 — Phase 1 source (prepublish script — sibling-only per RFC B3)
- Step 6 — Phase 2 source (copy-substrate + init extension + sync 149-walk + ADR-007 amendments for H1 + H3)
- Step 7 — signoff with grep audit against ledger v3
- Step 8 — closeout PR opened for review

Revised time budget: ~200 turns per new revised step time budgets in goal doc.

After scope-b1 ships → scope-e (migration + RemoteFetchStrategy restoration) per `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md`.

## References

- Goal doc — `docs/iteration-bets/2026-08-28d-npm-lite-substrate-bundling.md` (amended for scope-b1)
- RFC-0001 — `docs/rfcs/RFC-0001-npm-lite-substrate-bundling-review.md` (accepted)
- Ledger v3 — `docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md`
- Scope-e plan — `docs/next-longrun-prep-2026-08-29-npm-lite-scope-e.md`
- Parent goal — `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
