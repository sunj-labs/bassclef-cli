---
tier: standard
goal_id: 2026-09-20b-docker-cold-adopter-harness
authored: 2026-09-20
session_id: 2026-09-20b
time_budget: 95-165 turns
mode: greenfield
parent_ticket: sunj-labs/bassclef-cli#162
sister_tickets:
  - sunj-labs/bassclef-cli#150
  - sunj-labs/bassclef-cli#160
authoring_luminaries:
  primary: alistair-cockburn
  supporting:
    - kent-beck
    - andreas-zeller
    - michael-feathers
    - michael-nygard
    - linus-torvalds
    - jane-cleland-huang
adversarial_council:
  - hyrum-wright
  - frederick-brooks
  - john-ousterhout
  - jerome-saltzer-and-michael-schroeder
  - donald-norman
rfc_signoff:
  rfc_id: RFC-0001
  disposition: Revised A
  cured_inline: [R1, R2, R3, R4, R5, R6, R7, R8]
  deferred: []
references:
  - docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-1.md
  - docs/rfcs/RFC-0001-docker-cold-adopter-harness.md
  - docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md
  - bassclef-cli#162
  - bassclef-upstream#1822
  - bassclef-upstream#1824
  - bassclef-upstream#1825
  - bassclef-upstream#1827
---

# Docker cold-adopter harness — V1 walking skeleton + V2 skill drive

## Sources read

- `docs/whereami.md` L18-22 — cli 1.2.1 shipped 2026-09-19; 12-hook cascade class from account-swap smoke; launch delayed 24h to 2026-09-21
- `bassclef-cli#162` body L1-95 — cold-adopter Docker harness proposal; 3 luminary anchors (Cockburn/Beck/Zeller) at 0.92 via `/extract-intent` LIVE; V1/V2/V3 phases; test plan; out-of-scope
- `bassclef-upstream#1822 / #1824 / #1825 / #1827` — 4 upstream cures the harness will falsify against (1.2.1 red → 1.2.2 green)
- `bassclef-upstream/standards/state-spine/schemas/evidence.schema.json` — evidence schema with Observer pattern + bandleader-as-Mediator declaration; reused this session for traceability discipline
- `bassclef-upstream/standards/loop-discipline.md` — per-PR loop discipline this goal composes
- `bassclef-upstream/architecture/substrate-assessment.md` — bandleader vocabulary + multi-agent runtime deferred
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-1.md` — this session's pre-mortem light with 23 risks across Nygard/Linus/Cockburn lenses
- `docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md` — sister artifact; extension proposal for evidence.schema.json filed at upstream#1182 issuecomment-5749419113
- `.claude/skills/longrun/SKILL.md` — dispatch source; per-handoff pre-mortem + RFC discipline applied
- `.claude/rules/loop-discipline.md` — per-step evidence discipline this goal composes
- `.claude/rules/oo-ad-entry-point.md` — fully-dressed use case required per Cockburn tier for new hook/lib work
- Session extract-intent runs — 4 LIVE runs at 0.62-0.92 confidence; matcher_version voyage-3-lite+haiku-4-5-1.0

## What I'm NOT reading (with reason)

- Existing scripts under `scripts/smoke-*` — will read at Step 3 when entry.sh design begins; premature at Step 1 goal-doc authoring
- `docs/promotes/2026-08-11-traceability-subsystem.md` Phase 1 draft — cited via upstream#1182 body summary; full read owed at Phase 2 authoring session, not this session
- Windows adopter test paths — out of scope per cli#162 body L88
- V3 CI-gate wiring — deferred per cli#162 body L57; not in this session

## Problem (≤500 chars)

Every cold-adopter smoke on the operator's Mac pulls in operator state — peer clone at `~/tmp/bassclef`, gh auth, cached credentials, `~/.claude`. Ceremony strips state; ceremony leaks state. The 1.2.1 launch surfaced 12 hooks wired-but-missing that the current smoke did not catch pre-ship. Docker container starts clean every run and closes that class structurally.

## Value prop

Docker container runs on OrbStack locally and on GitHub Actions `ubuntu-latest` in CI. Container installs the published `@thebassclef/lite` from npm, runs init, runs the assertion pipeline. Zero operator state. Zero cached credentials. Every failure maps to a defect the harness detects, not to ceremony that leaked.

Post-launch this becomes the primary smoke lane. The operator's second Mac stops being the test surface. Every future release publishes only after Docker smoke passes on both macOS and Linux CI.

## Goal

Ship the harness as V1 (walking skeleton) + V2 (skill drive). Runs green on cli 1.2.2 when upstream cures for #1822 + #1824 + #1825 + #1827 land. Runs red on cli 1.2.1 today per Zeller falsification-test framing.

## Steps

| Step | Problem + value prop | Produces | Consumes (from prior step) | How this step builds on the prior | Risk |
|---|---|---|---|---|---|
| **1** — Handoff 1 ceremony (Requirements → Design) | Pre-mortem light + RFC-0001 land the discipline floor before code | Risk ledger + RFC-0001 doc + 3 markers (pre-mortem, luminary, temperance) | goal doc (this file) | Baseline — first fired step | 🟢 low |
| **2** — Decomposition + spec | Fully-dressed use case + BCE decomposition per Cockburn/Jacobson tier | UC-docker-harness.md + decomposition doc | Step 1 findings folded | Requirements sink into a design that carries risk mitigations forward | 🟡 med |
| **3** — Handoff 2 ceremony (Design → Construction) | Pre-mortem light + RFC-0002 on the design before code writes | 2nd risk ledger + RFC-0002 doc | Step 2 decomposition | Design gets adversarial council; construction risks named | 🟢 low |
| **4** — Dockerfile + entry.sh + Tier 0 tests | The container skeleton; TDD RED first | `harness/docker/Dockerfile.cold-adopter` + `harness/docker/entry.sh` + `.claude/hooks/tests/docker-harness-entry.test.sh` | Steps 2-3 design + risk folds | Design becomes runnable; tests pin behavior | 🟡 med |
| **5** — Workflow + runbook | CI + local invocation paths | `.github/workflows/docker-smoke.yml` + `docs/runbook/docker-smoke.md` | Step 4 container | Skeleton wires into CI + operator; walking-skeleton complete | 🟡 med |
| **6** — Handoff 3 ceremony (Construction → Testing) | Pre-mortem light + RFC-0003 before live run | 3rd risk ledger + RFC-0003 doc | Steps 4-5 build outputs | Testing surface gets adversarial council | 🟢 low |
| **7** — V1 live run against 1.2.1 (falsification test) | Prove the harness detects the classes we know are there | Container run log + evidence row on `state/events/evidence-status-changed.jsonl` | Step 5 workflow | Beck RED confirmed — 1.2.1 exits non-zero on settings-hooks-present | 🟡 med |
| **8** — V2 skill drive additions | Extend entry.sh with the 5-skill drive per cli#162 V2 spec | Extended entry.sh + updated tests | Step 7 V1 GREEN on structure | V2 rides on V1 skeleton; skill drive is decoration on the skeleton | 🟡 med |
| **9** — V2 live run + evidence row | Prove V2 detects the skill-hardcode class + timeout class | Container run log + evidence row | Step 8 V2 build | Falsification-test success on V2 confirms detection | 🟡 med |
| **10** — Handoff 4 ceremony (Testing → Delivery) | Pre-mortem light + `/architect-review` before PR | 4th risk ledger + architect-review report | Steps 7 + 9 test outputs | Delivery gate — adversarial council before merge | 🟢 low |
| **11** — PR + review + merge | Ship the harness | PR body + review signoff + squash merge | Step 10 signoffs | Session ships; blocks release publish until Docker green | 🟢 low |
| **12** — Closeout | Session log + whereami + evidence-row cleanup + retro | Session log + whereami update | Step 11 merge | Closure per /longrun closeout SKILL | 🟢 low |

## Acceptance

- [ ] Dockerfile builds on macOS OrbStack + GHA ubuntu-latest
- [ ] entry.sh exits 0 on the day cli 1.2.2 (upstream-cured) publishes
- [ ] entry.sh exits 3 on cli 1.2.1 (proves detection)
- [ ] Runbook single-command invocation works verbatim
- [ ] V2 5-skill drive completes cleanly on 1.2.2 (post-cure) or exits with named skill-hardcode error on 1.2.1
- [ ] Tier 0 tests cover entry.sh path handling, env-var validation, exit-code emission
- [ ] Every handoff (1, 2, 3, 4) has a pre-mortem + RFC pair filed
- [ ] Every step emits an evidence row on `state/events/evidence-status-changed.jsonl`
- [ ] Traceability discipline as we go — no separate ledger; reuse the existing evidence schema

## Out of scope

Per cli#162 body L88-91:

- Windows-native adopter simulation (WSL2 covered via Linux behavior; separate design if needed)
- Interactive claude sessions (V2 drives skills non-interactively)
- Persistent volumes across runs (defeats the fresh-install purpose)
- Docker Desktop's Kubernetes integration
- V3 CI-gate wiring (deferred to next iteration per cli#162 L57)

## Compounding value

- **Where the payoff shows up** — per-release. Every future cli release publishes only after Docker smoke passes on both macOS + Linux.
- **How often it fires** — per-PR touching `src/**` or `harness/**` in CI; per-release locally.
- **What must be true first** — OrbStack + Docker installed locally; ANTHROPIC_API_KEY set for V2 skill drive.
- **Does this teach a shape later work reuses** — yes. The container-as-test-surface pattern applies to any future substrate delivery (bassclef-upstream harness, adopter-app smoke). Cli#162 body L92-95.
- **What breaks if we ship this half-done** — 🟡 med. Half-shipped harness (V1 without CI, or V2 without V1 green) still costs operator's Mac ceremony per release. Full V1+V2 removes that ceremony.

## Refs

- `.claude/skills/longrun/SKILL.md` — dispatch source
- `.claude/skills/pre-mortem/SKILL.md` — Handoff ceremony
- `.claude/skills/rfc/SKILL.md` — outside council ceremony
- `.claude/rules/loop-discipline.md` — per-PR discipline this goal composes
- `.claude/rules/oo-ad-entry-point.md` — fully-dressed UC required per Cockburn tier
- `bassclef-upstream/standards/state-spine/schemas/evidence.schema.json` — traceability schema reused this session
- Session paper — `docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md`
