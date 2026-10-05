---
tier: upstream
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - linus-torvalds
    - alistair-cockburn
---

# Next session plan — Session G — v1.7.1 bundle sync + Session F driver flips

## Scope in one sentence

Pull bassclef v1.7.1 into cli, re-bundle, verify all 5 Session F drivers flip RED → GREEN, flip semantics in follow-up PRs, cli release, tickets auto-close.

## Context — what landed overnight

Peer `bassclef-upstream-9b` shipped bassclef v1.7.1 at 2026-10-05T03:43:09Z (merge commit `b708d7c2`, release page https://github.com/sunj-labs/bassclef/releases/tag/v1.7.1). 7 Q1 cures landed covering tickets cli#306 + #308 + #316 + #321 + #331 + #332 + a meta cure for capability-probe.sh.

Session F closed 5 driver PRs this evening — each driver reads shipped `dist/lite/` and asserts RED today. When bundle sync lands, each driver flips to exit 1 GREEN-UNEXPECTED. That flip is the signal that cure reached adopters.

Session F plan at `docs/next-session-plan-2026-10-05-session-f-driver-build-out.md`. Session F chronicle at `docs/session-logs/2026-10-05-session-f-driver-build-out.md`.

## Luminary map

- **Lead:** `michael-feathers` — the flip IS characterization-complete signal. Each driver's RED → GREEN closes a thread the walking skeleton opened.
- **Supporting:** `linus-torvalds` — adopter contract. Bundle sync is the moment cure reaches adopter machines. Release cascade honesty matters.
- **Supporting:** `alistair-cockburn` — same walking skeleton pattern. One PR per driver flip. Standard Session A-F shape.

## Scope — what cli does

### Step 1 — bundle sync

- Branch `feat/bundle-sync-v1.7.1`
- Edit `.github/workflows/publish.yml` L136 + L281 (or wherever the bassclef pin lives) from `v1.7.0` to `v1.7.1`
- Run `npm run bundle` to regenerate `dist/lite/`
- Verify each of 5 drivers flips to exit 1:
  - `scripts/tests/smoke-drive-adopter-306-bash32.test.sh`
  - `scripts/tests/smoke-drive-adopter-331-autonomous-lite.test.sh`
  - `scripts/tests/smoke-drive-adopter-332-hosting-platform.test.sh`
  - `scripts/tests/smoke-drive-adopter-329-adr-dead-letter.test.sh` — may stay RED if cli#329 upstream cure (bet 28a Step 1) is settings.json-only and bundle-sync pulls that in; verify empirically
  - `scripts/tests/smoke-drive-adopter-322-launch-template-jargon.test.sh`

### Step 2 — flip semantics

For each driver that flipped GREEN-UNEXPECTED, write a one-commit follow-up that inverts the assertion:

- `scripts/tests/smoke-drive-adopter-NNN-*.test.sh` — swap `if match_count -gt 0` → `if match_count -eq 0`
- Rename output tags: `RED-CONFIRMED` → `GREEN-CONFIRMED`
- Update UC extension `3a` to reflect the new semantics (now the test asserts cure PRESENT; FAIL means regression)

Each flip is one file + ceremony marker refresh. 5 drivers = 5 small commits (or one batch commit per operator preference).

### Step 3 — cli release cascade

- Bump cli version via `npm run bump patch` (v1.9.9 → v1.9.10 if no breaking change)
- Edit CHANGELOG per existing format
- Open release PR with body carrying `Closes #306`, `Closes #308`, `Closes #316`, `Closes #321`, `Closes #322`, `Closes #329`, `Closes #331`, `Closes #332` to auto-close on merge
- CI green → merge → tag `v1.9.10` → publish workflow fires → Touch ID at npm-publish env gate → `@thebassclef/lite@1.9.10` live

### Step 4 — verify tickets closed

GitHub auto-closes via Closes keywords when the release PR merges. Confirm each ticket state=CLOSED.

### Step 5 — (optional) exercise /release-close-sweep Path A

If `scripts/release-close-sweep.sh` has shipped from bassclef-upstream#2068 by this point, run it on the release branch pre-merge. First-consumer proof per cli#294 Path A tracker.

## Time budget

**30-60 turns** total:

- Bundle sync + driver flip verification: 10-15 turns
- Semantics flip PRs: 10-15 turns (5 small files)
- Release cascade: 10-15 turns (bump + CHANGELOG + PR + tag + publish)
- Verify + close: 5 turns

Grounded on Session C bundle-sync (cli#305) at ~45 turns actual.

## Pre-flight for the session

Session kickoff reads:

1. This plan doc
2. `docs/whereami.md` (snapshot after Session F closeout)
3. Session F chronicle `docs/session-logs/2026-10-05-session-f-driver-build-out.md`
4. v1.7.1 release page `https://github.com/sunj-labs/bassclef/releases/tag/v1.7.1`

Then operator types `/longrun prep` + plan doc fires converged preset.

## What NOT to do

- Do not re-run drivers in RED-assertion shape after bundle sync lands. The whole point is the flip.
- Do not skip the semantics flip. A driver that asserts GREEN after cure gives durable regression anchor; a driver stuck in RED-after-cure semantics gives silent CI pass that masks regressions.
- Do not stack 5 flip PRs on one branch. One PR per flip keeps rollback atomic.

## Related tickets

- cli#306 through cli#332 — the driver targets, all closed after release
- bassclef-upstream#2068 — /release-close-sweep Path A exercise
- cli#294 — Path A first-consumer proof

## Luminary pin rationale

Session F opened with Cockburn walking skeleton. Session G closes with Feathers characterization-complete + Torvalds release honesty. Three luminaries carry across both sessions — the pin stays stable.
