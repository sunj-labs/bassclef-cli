---
date: 2026-10-04
goal: Session C — handoff cliff drivers (/build Phase 0 + /autonomous + /deploy-prod)
authoring_luminaries:
  lead: alistair-cockburn
  supporting:
    - michael-feathers
    - linus-torvalds
mode: pre-mortem light (3 lenses × 5 risks compact per 100-200 turn budget)
---

# Session C — risk ledger (pre-mortem light)

Session C ships drivers at the handoff cliff — where `/build` promises more than lite delivers. Upstream cured cli#307 overnight (SHA `09beb249`). cli#331 + cli#332 sit in Slot 9 of the Kunal batch (Class G, own `/longrun`); Session C does PR 1 (cli#307 driver) now; PR 2 + 3 wait for Slot 9.

## Lens C — Cockburn (walking skeleton)

- **R-C1** PR 1 ships as a lone driver instead of a walking skeleton. **Fold F1:** PR 1 IS the walking skeleton for Session C — subsequent PRs mirror its shape when Slot 9 opens.
- **R-C2** Driver scope creeps into /autonomous and /deploy-prod territory. **Fold F2:** scope marker names PR 1 as cli#307-only; /autonomous and /deploy-prod drivers deferred until Slot 9 lands.
- **R-C3** Driver mock mode doesn't reflect upstream cure shape. **Fold F3:** read upstream Tier 0 fixture at `.claude/hooks/tests/build-skill-phase-0-step-n-scan.test.sh` from upstream main SHA 09beb249 before building fixtures.
- **R-C4** Session C scope stays open past PR 1 while waiting for Slot 9. **Fold F4:** PR 1 closes Session C stage 1; stage 2 opens as a new session when Slot 9 lands.
- **R-C5** 100-200 turn budget blown by waiting + context switching. **Fold F5:** compact ceremony — reuse Session A + B harness; no new lib code.

## Lens F — Feathers (characterization)

- **R-F1** Driver asserts Phase 0 behavior but upstream could reshape the awk pattern. **Fold F6:** cite upstream fixture + SHA in driver comment; characterization survives even if upstream regex evolves because test anchors on OUTCOME (floor path detected), not pattern (awk regex).
- **R-F2** Mock trace shape doesn't match real `/build` Phase 0 output. **Fold F7:** base mock trace on upstream Tier 0 fixture format (ACCEPTANCE_CONTENT awk) — one source of truth.
- **R-F3** Driver only covers happy-path floor detection; break corpus incomplete. **Fold F8:** ship 4 fixture classes — pre-cure Step-N spec with floor path (RED), post-cure Step-N spec with floor path (GREEN), post-cure WU-N spec with floor path (regression — WU-N must still match), post-cure Step-N spec WITHOUT floor path (GREEN — nothing to flag).
- **R-F4** Driver on cli main doesn't integrate with upstream cadence. **Fold F9:** driver stays trace-layer characterization; live mode (SMOKE_LIVE=1) drives real `/build` only during nightly, inherits Session A nightly workflow.
- **R-F5** Session A + B drivers break when drivers lib changes. **No fold needed** — PR 1 uses same drive_X pattern + sources same libs.

## Lens L — Linus (adopter contract)

- **R-L1** Driver passes under test environment but adopter runs on different OS. **Fold F10:** reuses Session A nightly GHA matrix (ubuntu + macOS × 3 releases) via inheritance; no new matrix config.
- **R-L2** cli#307 cured on upstream main but no public release yet. **Fold F11:** driver characterizes trace shape, not upstream version. Operator cuts release when ready; driver stays green on current main.
- **R-L3** Floor path list drifts (new sensitive paths added in later cures). **Fold F12:** test asserts ANY of the known floor paths detected, not ALL. New paths pass through without breaking existing tests.
- **R-L4** Adopter runs `/build` on a Step-N spec and expects floor to fire — but their spec has no sensitive paths. **No fold needed** — that's the clean path; driver covers it via T04.
- **R-L5** cli#320 personas slug driver (Session A PR #336) might go GREEN after upstream cure a38f1f54 lands in release. **No fold** — expected flip; nightly catches it.

## Folds pre-code (session kickoff)

- F1-F5 (Cockburn) — walking skeleton shape; scope marker closes PR 1 as stage 1
- F6-F9 (Feathers) — 4-fixture break corpus; upstream fixture is source of truth
- F10-F12 (Linus) — nightly matrix reuse; floor path list stays open

## Scope deferrals

- cli#331 — Session C stage 2 (depends on Slot 9 ADR + cure)
- cli#332 — Session C stage 2 (depends on Slot 9 ADR + cure)
- cli#305 Exhibit-A follow-on — upstream Slot 3 remainder; cli-side driver already shipped Session A
