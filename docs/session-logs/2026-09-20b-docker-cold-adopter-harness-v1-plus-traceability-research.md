---
tier: operator-private
authored: 2026-09-20
session_id: 2026-09-20b
started: 2026-09-20T10:55Z
ended: 2026-09-20T13:00Z (approx)
duration: ~2h
turn_count: ~180 (estimate)
outcome: shipped
ships:
  - bassclef-upstream#1182 comment 5749419113 (traceability schema research paper)
  - bassclef-cli PR #163 (Docker cold-adopter harness V1)
---

# Session 2026-09-20b — Docker cold-adopter harness V1 + traceability schema research

## Sources read

- `docs/whereami.md` (L1-200) — cli 1.2.1 shipped 2026-09-19; 4 upstream p0 blockers filed
- `bassclef-cli#162` body — Docker harness proposal
- `bassclef-upstream#1182 + #1590` — Traceability Subsystem + Living OOAD docs epics
- `bassclef-upstream/standards/state-spine/schemas/evidence.schema.json` — evidence schema with Observer + bandleader-Mediator declaration
- `bassclef-upstream/standards/loop-discipline.md` — Observer log pattern
- 3 web-research sources on RT (Gotel-Finkelstein, Cleland-Huang, Neo4j property graph)
- 3 web-research sources on AI-council (Ng+Kollegger, Karpathy, Huyen)

## Work done

### Wave 1 — traceability schema research (~50 turns)

Operator asked for `/longrun prep` at launch-eve. Session pivoted from settings-hooks-present PR toward Docker harness (cli#162 d.2) per operator's isolation-by-design rationale.

Along the way — operator asked for a JSON-typed traceability ledger design informed by an adversarial council of AI-focused luminaries. Session ran 4 `/extract-intent` LIVE calls at 0.62-0.92 confidence, a web-research fork on RT frameworks (Gotel-Finkelstein / Wiegers / van Lamsweerde / Cleland-Huang), and a second fork on AI-council (Ng / Karpathy / Huyen / Neo4j).

Big finding: bassclef-upstream already ships an evidence schema with Observer pattern + explicit "future bandleader subscribes as Mediator" declaration. My proposed separate traceability ledger duplicated that primitive. Recommendation reshaped to Revised A3 — file the extension proposal against #1182 + #1590; use the existing evidence schema for this session's harness ledger.

Deliverable:
- Paper at `docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md` (332 lines)
- Attached as comment to `bassclef-upstream#1182` (issuecomment-5749419113)
- Committed locally

### Wave 2 — Docker cold-adopter harness V1 (~120 turns)

Full SDLC ceremony at 4 handoffs per operator directive of `/pre-mortem` + `/rfc` at each handoff.

**Handoff 1 (Requirements → Design):**
- Pre-mortem-1 — 23 risks × Nygard/Linus/Cockburn
- RFC-0001 — outside council (Hyrum/Brooks/Ousterhout/Saltzer-Schroeder/Norman) — 3 HIGH findings, all cured inline

**Step 2 (decomposition):**
- Fully-dressed use case per Cockburn tier
- BCE decomposition per Jacobson + Ousterhout deep modules + GRASP responsibility assignment
- 4 pattern annotations (gof/facade, gof/strategy, gof/observer, nygard/circuit-breaker)

**Handoff 2 (Design → Construction):**
- Pre-mortem-2 — 15 risks × Feathers/Ousterhout/Saltzer-Schroeder
- RFC-0002 — outside council (Cooper/Fowler/Vernon/Parnas/Meyer) — 2 HIGH findings, all cured inline

**Step 4 (code):**
- harness/docker/exit-codes.sh — single source of exit-code constants (Parnas R13)
- harness/docker/entry.sh — 4-action orchestrator (Cockburn walking skeleton + RFC R3 cure)
- harness/docker/Dockerfile.cold-adopter — pinned linux/amd64 debian:12-slim + node 20 + adopter user uid=1000
- .claude/hooks/tests/docker-harness-entry.test.sh — 18 Tier 0 tests
- All 18 GREEN

**Step 5 (workflow + runbook):**
- .github/workflows/docker-smoke.yml — GHA ubuntu-latest on PR + workflow_dispatch
- docs/runbook/docker-smoke.md — operator invocation contract per RFC R1

**Handoff 3 (Construction → Testing):**
- Pre-mortem-3 — 9 risks × Zeller/Beck/Nygard
- RFC-0003 — outside council (Popper/Peirce/Toulmin/Ishikawa/Deming) — 1 HIGH cured before Step 7

**Step 7 (V1 live run):**
- Docker build succeeded on OrbStack linux/amd64
- Cli 1.2.1 install + init succeeded inside container
- smoke-assert-settings-hooks reported 28 wired = 28 present = 0 missing
- Container exit 0

**Surprising finding:** whereami L18-22 claimed 12 hooks wired-but-missing on cli 1.2.1 (giveisusfree account swap). The 12-hook cascade does NOT reproduce in Docker isolation. Two-way verification via fresh install at `~/tmp/bassclef-cold-verify-1.2.1` on kingofrock concurred (28/28/0). Most likely: the account-swap smoke was polluted by `~/tmp/bassclef` peer clone. Not a cli defect.

**Handoff 4 (Testing → Delivery):**
- Pre-mortem-4 — 9 risks × Linus/Nygard/Feathers
- Architect-review — 7/7 ADRs honored; 5/5 dynamic verification checks pass
- Lead-lens signoff — Cockburn walking skeleton contract satisfied

**PR #163 opened.** Waits on operator review + merge.

## What worked

- Full SDLC ceremony compounded — every handoff surfaced risks the next step folded before code lands
- 3 outside-council RFCs used non-overlapping lenses per RFC skill contract
- Cherry-pick of smoke-assert-settings-hooks.sh from PR #161 unblocked Step 7 live run without stalling on merge
- Tier 0 tests + entry.sh sourceable-without-main pattern gave fast RED-GREEN cycles
- 2-way cold verification (Docker + host-side isolated tmp dir) inverted whereami's claim with high confidence

## What broke and healed

- Dockerfile USER order — mkdir after USER adopter → EACCES. Cure: mkdir + chown before USER.
- Global npm install as unprivileged → EACCES. Cure: NPM_CONFIG_PREFIX=/home/adopter/.npm-global + PATH.
- Bassclef init home-guard — `/adopter/test` refused because `/adopter` != `/home/adopter`. Cure: default test dir to `$HOME/test`.
- Entry.sh preflight docker-CLI check ran inside container — always failed. Cure: docker check is host-side (runbook + workflow); entry.sh only checks env vars.

## What surprised me

- Whereami's 12-hook cascade class does not reproduce in truly cold conditions
- bassclef-upstream evidence schema already ships Observer pattern + bandleader Mediator declaration — the traceability ledger I sketched was duplicative
- Andrew Ng, Karpathy, and Chip Huyen are not in bassclef's luminary catalog — this session seeds 4 luminary files (Cleland-Huang + those 3) as prototype additions

## Gate evidence

- Temperance marker touched at Step 1 with body content
- Luminary marker touched at Step 1 with lead + supporting lenses
- Pre-mortem markers touched at all 4 handoffs
- RFC marker touched at Handoff 1
- Decompose marker touched at Step 2
- ADR-deviation marker touched at Step 2 (outcome: ADR-honored)
- Lead-lens signoff marker touched at Handoff 4 (Cockburn)
- 7 evidence rows emitted on state/events/evidence-status-changed.jsonl
- 18/18 Tier 0 tests GREEN

## Next moves for the operator

1. Review PR #163 for the Docker harness V1
2. Decide on the launch calculus in light of the surprising finding
3. Consider filing a re-triage comment on bassclef-upstream#1827 with the Docker evidence
4. Merge PR #161 (settings-hooks-present) — cli PR #163 rebases cleanly
5. V2 skill drive follow-on session for cli#162 V2 spec

## Refs

- PR #163 — https://github.com/sunj-labs/bassclef-cli/pull/163
- Comment #5749419113 on upstream #1182 — https://github.com/sunj-labs/bassclef-upstream/issues/1182#issuecomment-5749419113
- Goal doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
