---
tier: project
title: Session — goal 2026-09-18a smoke evidence capture Layer 1
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture
duration: ~9 hours, one long session
turns: ~150 (well past 90-140 top; overrun accepted at prep)
branch: feat/109-smoke-evidence-capture-layer-1
issue: sunj-labs/bassclef-cli#109
outcome: shipped
---

# Session log — 2026-09-18 goal 2026-09-18a smoke evidence capture Layer 1

## What shipped

Layer 1 of a three-layer smoke test system on cold-adopter Mac profile. All nine steps of the goal doc landed. 14 commits on `feat/109-smoke-evidence-capture-layer-1` (plus 10 on main pre-branch for design, RFC, folds, pre-mortem).

**Substrate — 6 scripts:**

- `scripts/smoke-capture.sh` — captures wired SessionStart hooks
- `scripts/smoke-assert-hooks.sh` — runs 4 checks per hook capture
- `scripts/smoke-drive-skills.sh` — fires 5 skills via `claude -p`
- `scripts/smoke-assert-skills.sh` — same 4 checks per skill capture
- `scripts/smoke-report.sh` — builds report + posts issue idempotently
- `scripts/smoke-reset-whole.sh` — reset with snapshot + `--restore`

**Substrate — 2 shared libs:**

- `scripts/lib/smoke-schema.sh` — AssertionResult JSON helper
- `scripts/lib/smoke-assert.sh` — 4 check functions (Strategy per GoF)

**Fixtures — 6 defect pins from the 2026-09-17 smoke:**

- cli#101, #102, #108 pin `no-unexpected-blocked`
- cli#103, #104 pin `no-not-found`
- cli#105 pins `no-silent-skip`
- cli#106, #107 out of check scope (documented; deferred)

**Tests — 41 new Tier 0 tests:**

- 10 for `smoke-capture` (bash 3.2 compatibility fix on the way)
- 14 for `smoke-assert-hooks` (four checks × per-check happy + fail + allowlist)
- 8 for defect fixtures (coverage-walk per pre-mortem F1)
- 9 for `smoke-drive-skills` (mock claude; Perl alarm timeout)
- 4 for `smoke-assert-skills` (skills-specific defaults)
- 8 for `smoke-report` (mock gh; build + publish + idempotency + --new)
- 6 for `smoke-reset-whole` (snapshot + restore + auto-prune)

Full suite went from 355 → 396 tests. All GREEN. Zero regressions.

**Design chain — 5 artifacts:**

- Spec: `docs/specs/smoke-evidence-capture.md`
- UC-smoke-run fully-dressed
- UC-lib-smoke-assert (subfunction UC)
- Decomposition + BCE
- Intent audit
- RFC adversarial (4 outside lenses — linus, hyrum, cooper, maurya)
- Pre-mortem light (3 lenses — deutsch, vogels, fowler; 18 risks)

## What broke and what held

**Broke.** Bash 3.2 macOS default lacks `mapfile` — smoke-capture.sh needed rewrite from array to while-read. Also `set -e` combined with the exit-code capture pattern kills the script before capturing non-zero exits — needed explicit `set +e` window. Both caught by Tier 0 tests on first run. `paths-exist` check false-positive on capture-header `/skill-slug` shapes — tightened regex to skip `===` header lines and require dot-or-nested-slash paths.

**Held.** The four checks per surface (Saltzer-Schroeder complete mediation) held under adversarial review. The BCE split (HookRunner-as-Control, AssertionSuite-as-Control) held against blur risk. Shared lib pattern (F4 + F6 pre-mortem folds) paid off at Step 5 — smoke-assert-skills.sh reused the checks with zero duplication of check logic. Feathers characterization tests via fixtures (cli#101-108) proved the checks catch real defects.

## What the design chain caught

Intent audit surfaced 4 undeclared luminaries doing load-bearing work: nygard (Fail-Fast + 3 UC extensions + cross-cutting), jacobson (entire BCE section), parnas (info-hiding audit), brooks (conceptual integrity). Added to `authoring_luminaries.supporting` before code fired.

RFC adversarial pass caught 7 findings. 4 folded in before Step 1 (F1 report versioning, F2 two personas + `--only` flag, F4 publish idempotency, F6 reset undo). 3 deferred to Layer 1 closeout (F3 timeout, F5 metric, F7 CLI version).

Pre-mortem light surfaced 18 risks across 3 outside lenses. 14 folded across Steps 1-7. 1 deferred to Step 8. 3 as closeout notes.

## What did not work

The `.claude/hooks/` gate cascade fired repeatedly on new files under `lib/`, `scripts/`, `docs/use-cases/`. Each gate produced a well-crafted BLOCK message with cure paths. Cost was ~10 turns across the session touching markers. All markers are per-branch — good for audit trail but expensive on session startup. The bootstrap-pair discipline is honored; the friction is real. No follow-on filed since the cost per gate is small and adopters need the discipline.

Turn count landed ~150 vs 90-140 budget. Overrun accepted at prep. Actual driver: the 5-artifact design chain plus 4-fold RFC absorption plus pre-mortem plus 9 steps of code + tests. Each design artifact took 3-6 turns; each code step took 5-15 turns.

## Next-session pickup

**Layer 2 next session** — build the mock app. Drive `/interpret-input` + `/launch` + `/build` on a "recipe app" idea. Skill list in `smoke-drive-skills.sh` extends by adding those three skills. Byproduct: a working mock app under `~/tmp/bassclef-smoke-test/apps/recipe/` or similar.

**Layer 3 session after** — drive `/verify`, `/architect-review`, `/decompose`, `/pattern-review`, `/visual-review`, `/synthetic-user` against the mock. Same driver script pattern extends.

**Follow-on tickets to file at closeout:**

- Extend fixture set with per-check fixtures for `paths-exist` (currently only inline test coverage) — F1 pre-mortem long-term.
- Add a 5th check for message quality (cli#106 uncovered class).
- Add a 6th check for repeat warnings (cli#107 uncovered class).
- Consider merging `smoke-reset-whole.sh` back into `smoke-reset.sh` proper (currently a wrapper — F3 pre-mortem F3 note).

## Cost tracking

- Session duration: ~9 hours (2026-09-18 start ~00:00 UTC)
- Turns: ~150
- Sequential mode — $0 burst
- Deliverables: 6 scripts + 2 libs + 41 tests + 5 design artifacts + intent audit + RFC + pre-mortem + fixture set + test plan fold + this session log

## References

- Goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Issue: sunj-labs/bassclef-cli#109
- Branch: `feat/109-smoke-evidence-capture-layer-1`
- Pickup source: `docs/next-session-plan-2026-09-17-cli-pickup.md` (Option e)
- Coordination: bassclef-upstream#1728
