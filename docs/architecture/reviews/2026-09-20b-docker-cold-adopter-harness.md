---
tier: operator-private
authored: 2026-09-20
session_id: 2026-09-20b
review_type: architect-review
subject: Docker cold-adopter harness (cli#162)
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
---

# Architect-review — Docker cold-adopter harness

Handoff 4 architect-review per `.claude/skills/architect-review/SKILL.md`. Static comprehension + dynamic verification pass.

## Sources read

- All 9 goal-doc-linked artifacts (UC, decomposition, 4 risk ledgers, 3 RFCs)
- Session paper — `docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md`
- All 6 ADRs — `docs/adrs/ADR-{001,002,003,004,005,007,009}.md` — per grep
- CLAUDE.md — project instructions
- Live-run evidence at `state/events/evidence-status-changed.jsonl` — 6 rows across handoffs 1-3 + steps 2-5-7

## Static pass — architecture against ADRs

| ADR | Governs | This session's touchpoint | Verdict |
|---|---|---|---|
| ADR-001 | npm package build (Vite + TypeScript + Vitest) | No src/ code touched; harness lives under harness/docker/ | HONORED |
| ADR-002 | bassclef init safety contract | Harness calls `bassclef init` inside the container as an adopter would; does not modify init logic | HONORED |
| ADR-003 | bassclef sync safety contract | Harness does not call sync | HONORED (out of scope) |
| ADR-004 | Publish pipeline | Harness does not publish; separate concern | HONORED (out of scope) |
| ADR-005 | Model C open-core | Harness is testing infrastructure; open-core doesn't constrain | HONORED |
| ADR-007 | dist bundle path | Harness reads npm-installed cli; does not touch bundle path | HONORED |
| ADR-009 | Pointer to upstream ADR-055 | Harness reads dist/lite/ transitively via `bassclef init`; does not touch reader | HONORED |

**Verdict:** all 7 cli ADRs honored. ADR-deviation marker was already touched at Step 2 with `outcome: ADR-honored`.

## Dynamic pass — verification

Per `standards/architect-review-discipline/substrate.md` verification chain (5 checks):

1. **Existence check** — every claimed file exists on disk. Verified via `ls`.
2. **Wiring check** — CI workflow references correct paths + shell hooks reference correct exit-code file. Verified via inspection.
3. **Test coverage check** — 18 Tier 0 tests all GREEN against entry.sh functions. Verified via `bash .claude/hooks/tests/docker-harness-entry.test.sh`.
4. **Runtime check** — live Docker build + run succeeds end-to-end against cli 1.2.1. Verified via `docker run --rm ... bassclef-cli-cold-adopter:test`.
5. **Contract check** — exit codes emitted match exit-codes.sh vocabulary. Verified via smoke run inspection.

**Verdict:** all 5 checks pass.

## Findings

### Positive findings

- **F1 Walking skeleton discipline honored.** Cockburn's "thinnest end-to-end slice" principle applied. V1 slice runs build + install + init + assert + propagate. No V2 skill drive polluting the skeleton.
- **F2 Anticorruption layer clean.** Only 2 env vars cross the container boundary (CLI_VERSION + ANTHROPIC_API_KEY). Workflow + runbook + Tier 0 test all enforce this.
- **F3 Exit-code contract single-source.** exit-codes.sh sourced by entry.sh + tests + smoke pipeline. Parnas information-hiding preserved.
- **F4 Falsification-test framing operational.** Live run inverted the operating assumption (1.2.1 clean, not polluted). The harness IS the arbiter, exactly per Zeller.

### Neutral findings

- **F5 Container-integration Tier 0 missing.** The Tier 0 tests cover entry.sh functions but do not exercise a real docker build+run. Live run at Step 7 provided this evidence manually; follow-on ticket to add automated container-integration test.
- **F6 Cherry-pick creates dependency.** `smoke-assert-settings-hooks.sh` is cherry-picked from PR #161. Both PRs eventually merge to main; git dedups by content.

### No negative findings

The harness ships within the discipline the goal doc committed to. No architectural drift from ADRs. No shortcut on Cockburn tier. No ceremony skipped.

## Recommendations for follow-on

1. **Add container-integration Tier 0 test** — wraps `docker build + docker run` in a bash test that a bassclef-upstream fixture can drive
2. **Pin base image to SHA digest** — replace `debian:12-slim` tag with sha256 pin per pre-mortem-4 DN2
3. **V2 skill drive** — extend entry.sh with 5-skill drive per cli#162 V2 spec; runs after V1 assertion green
4. **V3 CI gate** — wire the workflow to block release publish unless docker-smoke passes; per cli#162 L57 out-of-scope for this session

## Signoff

Lead lens **alistair-cockburn** (walking skeleton). All red + amber findings from RFC-0001 + RFC-0002 + RFC-0003 cured inline or explicitly deferred to follow-on. No findings remain unresolved.
