---
tier: lite
slug: 2026-09-21-pre-tag-version-sync
scope: "Epic #194 Stories 1-3 — pre-tag version-sync guardrails (pre-commit hook + PR-CI check + CONTRIBUTING note)"
mode: light
lenses: [michael-nygard, kent-beck, saltzer-schroeder]
date: 2026-09-21
always_fire_matched: true
always_fire_domain: deploy-pipeline-changes
branch: feat/194-pre-tag-version-sync-guardrails
---

# Pre-mortem risk ledger — pre-tag version-sync guardrails

Scope: ship a pre-commit hook + a PR-CI pre-publish check + a CONTRIBUTING note so v1.5.0-class mis-ships stop reaching the tag surface. Four files must stay in sync at release time: `package.json`, `src/index.ts`, `README.md`, `CHANGELOG.md`. Target outcome: 33% faster release cycles + 50% fewer false-starts. Time budget: 100-150 turns.

Always-fire: yes. Domain: **deploy pipeline changes** (per skill body §Always-fire domains). Light mode kept per operator direction; full mode reserved for the next release cycle that shows two more false-starts in a row.

---

## Lens: Michael Nygard — stability + fail loud earlier

**Assumed failure:** The pre-commit hook shipped but a v1.6.0 mis-ship still happened. The hook stayed silent because a GUI client bypassed `.git/hooks/pre-commit`. The PR-CI check had a `paths:` filter that only fired on workflow files, so a stale `src/index.ts` never tripped it.

Risks:

1. **Pre-commit hook silently skipped by GUI clients** (SourceTree, GitHub Desktop, Fork) that commit via libgit2 rather than shelling out. Local check appears armed; nothing fires.
2. **PR-CI check uses a `paths:` filter** that matches workflow files only. A drift in `src/index.ts` slips through because the check does not run on source-file PRs.
3. **`ubuntu-latest` migrates to Ubuntu 26 on 2026-10-19** (ticket #193). The new check breaks during the migration window if it pins the wrong runner.
4. **`jq` missing on the adopter machine.** Hook reads `package.json` version via `jq`; a machine without `jq` silent-skips and returns exit 0.
5. **Hook fires but exit code lost through Husky or lefthook wrappers.** GREEN commit status hides a RED assertion.
6. **Legit `npm run bump` run partway complete.** Bump script writes `package.json` first + sibling files second. If the hook fires mid-script (via a wrapper), it false-fails.
7. **The fixture pins the exact v1.5.0 shape** — package.json bumped, siblings stale. The next mis-ship class differs (say, CHANGELOG date wrong or README badge stale). One-class-only cure.

---

## Lens: Kent Beck — TDD discipline

**Assumed failure:** The version-sync test shipped but it was written after the hook. It captures the current behavior instead of the failure it claims to catch. The RED shape from v1.5.0 was never fed into the test.

Risks:

1. **Test-after antipattern.** Test written after hook; asserts what the hook does, not what the class demands.
2. **Fixture is happy-path only.** All four files agree in the fixture. The v1.5.0 RED case (package.json bumped, siblings stale) is not exercised.
3. **Test-list block missing** from the test file. No audit trail of assertions the hook owes.
4. **`npm run bump` legit-case not covered.** Hook may false-red on a legitimate bump commit.
5. **Test lives in the wrong directory** — Tier 0 discipline requires `tests/` sibling of source; a misplaced test breaks tier-tag rule enforcement.
6. **No characterization test replaying the actual v1.5.0 commit** (SHA `12d7153` per whereami L18, session log `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md` L38). Cure verified by argument, not evidence.

---

## Lens: Saltzer & Schroeder — complete mediation

**Assumed failure:** The hook fired on `package.json` changes but a developer hand-edited `src/index.ts` alone (with `package.json` unchanged). The mediation surface was too narrow. Every path to a version bump was not covered.

Risks:

1. **Hook fires on `package.json` changes only.** Edits to `src/index.ts`, `README.md`, or `CHANGELOG.md` alone bypass the check.
2. **`--no-verify` bypass** on `git commit` disables the hook with no signal.
3. **Direct push to main via merge queue** or admin override bypasses PR-CI entirely.
4. **Merge commits vs squash merges.** Hook fires on individual commits; the squashed release commit is not re-checked.
5. **Version constant read from a fragile position** in `src/index.ts`. A future refactor moves the const; check breaks silently.
6. **Publish workflow assumes PR-CI ran.** A `workflow_dispatch` on main hotfix skips PR-CI + fires straight to publish.
7. **CHANGELOG.md check is date-sensitive.** A backdated release entry passes assertion but breaks provenance.

---

## Top 5 risks — pick, owner, mitigation

| # | Severity | Lens | Risk | Owner | Mitigation |
|---|---|---|---|---|---|
| R1 | **HIGH** | Saltzer-Schroeder | Hook fires only on `package.json` changes — sibling edits alone bypass the check. | Hook trigger surface (Step 3 of Beck TDD RED). | Hook triggers when ANY of the four files is staged. Assert all four agree regardless of which file changed. |
| R2 | **HIGH** | Beck | Test written after source; happy-path fixture only. | Beck TDD RED step (test list authored first). | Author `tests/version-sync.test.ts` with characterization fixture replaying commit `12d7153`. RED case: package.json bumped, siblings stale. Test runs BEFORE hook. |
| R3 | **HIGH** | Nygard | PR-CI check uses `paths:` filter and misses source-file drift. | Workflow YAML author (Step 5 of GREEN). | Check runs unconditionally on `push` + `pull_request`. No `paths:` filter. |
| R4 | **MED** | Nygard | Hook depends on `jq`; missing binary silent-skips. | Hook shell defensive-bash discipline. | Check `jq` presence first; exit 2 with a clear message if absent. Or read `package.json` via `node -e` (always present in this repo). |
| R5 | **MED** | Saltzer-Schroeder | `--no-verify` local bypass hides the hook. | CI redundancy at the PR gate. | PR-CI check is the safety net. Even if pre-commit is skipped locally, GitHub Actions blocks the PR. Belt-and-suspenders per the two-layer defense pattern in `.claude/rules/loop-discipline.md`. |

Mitigation R3 also cures R6 from Nygard lens (legit `npm run bump` mid-state) — the CI runs on the final commit, so intermediate states never reach it.

---

## Scope-cut candidates

None. All three stories close the same class from different angles: hook = local safety net, PR-CI = server safety net, CONTRIBUTING note = intent + `npm run bump` culture. Cutting any of the three leaves a gap.

---

## Monitoring signals (post-ship)

- Next release cycle: PR CI reports the pre-publish check as a distinct job. No `release: published` failure at pre-publish.
- Zero false-fails on `npm run bump` PRs (verified by one test bump end-to-end before ship).
- Adopter feedback via bassclef-cli issues if the hook fires wrongly on legitimate work.

---

## RFC council absorption

Outside-luminary council review shipped at `docs/rfcs/2026-09-21-pre-tag-version-sync-council.md` (2026-09-21). Council: Hoare + Parnas + Brooks + Cooper + Norman. Disposition Revised A. 2 MEDIUM findings folded inline (F1 typed error contract on `readVersionSet`, F2 PR-CI scope clarification). 2 LOW findings deferred to follow-on tickets (F3 single-source audit, F5 first-commit signifier). 1 LOW cured in CONTRIBUTING (F4).

## Refs

- Epic #194 body — 6 stories total; this ledger covers stories 1-3.
- RFC: `docs/rfcs/2026-09-21-pre-tag-version-sync-council.md`
- Session log `docs/session-logs/2026-09-21-longrun-v1.1.1-sync-cascade.md` — v1.5.0 mis-ship class evidence.
- PR #190 (the mis-ship) + PR #191 (the retroactive cure).
- `scripts/bump-version.mjs` — existing helper the CONTRIBUTING note enforces.
- @luminary michael-nygard — lead lens
- @luminary kent-beck — supporting lens
- @luminary saltzer-schroeder — supporting lens
- Klein, G. (2007). "Performing a Project Premortem." HBR — method anchor.
