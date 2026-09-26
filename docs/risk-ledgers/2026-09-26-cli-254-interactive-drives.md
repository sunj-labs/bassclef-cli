---
ledger_id: 2026-09-26-cli-254-interactive-drives
mode: /pre-mortem light
lenses: [michael-feathers, kent-beck, alistair-cockburn]
authored_at: 2026-09-26T14:50Z
goal: cli#254 — expect-based interactive drives for /onboard-repo + /riff + /launch
---

# Pre-mortem light — cli#254 interactive skill drives

Klein-style pre-mortem. 3 lenses × 5-8 risks each. Strongest folds land pre-code.

## Feathers lens — characterization tests

Real Claude output as the fixture. Tests pin actual behavior.

- **F1** — expect regex too tight; real Claude prose shifts on prompt-tuning; test breaks silently. Cure: anchor on skill-produced artifacts (filesystem outputs), not prose regex.
- **F2** — expect timeout too short; real Claude turn takes 30-60s; false FAIL on cold API cache. Cure: 180s per turn baseline; 300s for /riff MCP init.
- **F3** — /riff MCP absent in container; drive fires but no HTML produced; assertion catches it as expected refusal per bassclef-upstream#1923. Cure: assert on refusal message pattern OR on HTML presence; two-branch assertion.
- **F4** — Phase 0 refuse text hardcoded in test; skill amends refuse language; test breaks on upstream change. Cure: assert on refuse EXIT CLASS not prose; refuse produces exit code + marker file.
- **F5** — expect matches on stderr but skill emits to stdout; false PASS on empty match. Cure: capture both stdout + stderr; assert on both channels.
- **F6** — expect script doesn't fail-fast on prompt mismatch; timeout instead of fast fail; slow signal. Cure: `expect_before { timeout 30 }` block per drive.

## Beck lens — TDD RED-first

Test discipline. RED first, always.

- **B1** — implementation before failing test; violates RED-first. Cure: git commit each test suite BEFORE source cure lands; audit trail.
- **B2** — assertion set too broad; passes on partial implementation. Cure: one assertion per artifact per drive; positive-artifact discipline per PR #218 pattern.
- **B3** — Tier 0 tests mock expect calls instead of running real expect; doesn't test real behavior. Cure: Tier 0 tests spawn real `expect` binary against fixture claude.
- **B4** — no test isolation between drives; prior drive's state leaks (settings.json, scratch dir, MCP). Cure: fresh scratch per drive; `rm -rf` teardown in trap EXIT.
- **B5** — tests share fixtures without reset; non-deterministic pass/fail. Cure: per-test fixture reset via setUp/tearDown pattern.
- **B6** — no force-red validation; GREEN result meaningless. Cure: `git stash source cure; run tests; expect RED; git stash pop; expect GREEN`.

## Cockburn lens — walking skeleton

End-to-end coverage. Every layer wired.

- **C1** — skeleton missing /launch drive scaffold; only 2 of 3 drives ship. Cure: file the 3 stub drives first (empty scripts + Tier 0 test each); walking skeleton verifies wire before content.
- **C2** — skeleton doesn't wire into docker entry.sh; drives exist but never fire. Cure: Tier 0 test asserts entry.sh calls each new drive.
- **C3** — skeleton doesn't handle CDN lag on npm install; smoke fails first run. Cure: reuse retry pattern from `harness/docker/entry.sh` per PR #249 (3 retries with backoff on `npm install`).
- **C4** — skeleton missing report row for interactive class; smoke report incomplete. Cure: extend `scripts/smoke-report.sh` to emit interactive-class rows alongside headless-class rows.
- **C5** — skeleton doesn't distinguish expect exit codes from claude exit codes; conflates failure classes. Cure: expect wrapper writes distinct exit codes (10 = expect script bug, 11 = claude timeout, 12 = assertion fail, etc.).
- **C6** — skeleton doesn't clean up temp dirs; container disk fills over runs. Cure: `trap 'rm -rf "$SCRATCH_DIR"' EXIT` in every drive.

## Top folds pre-code

Six folds land BEFORE the first line of source:

1. **F1 fold** — assert on filesystem artifacts, not prose regex.
2. **F5 fold** — capture stdout + stderr; assert on both.
3. **B1 fold** — RED-first commit discipline; test suite lands before source cure.
4. **B6 fold** — force-red validation ships in the PR body as evidence.
5. **C3 fold** — reuse PR #249 retry pattern for npm install in new drives.
6. **C4 fold** — smoke-report gets interactive-class row shape as part of skeleton.

## Deferred to follow-on

- F3 (/riff MCP two-branch assertion) — depends on cli#241 cure; ship as ADVISORY skip with `SKIP_RIFF_INTERACTIVE=1` env if #241 not landed.
- C1 (walking skeleton first) — Cockburn discipline says yes, but plan doc's option a ships all 3 drives together. Compromise: land 3 empty stubs + Tier 0 tests as commit 1 (walking skeleton); land 3 cures as commits 2-4.

## Anchor luminaries

- Michael Feathers — *Working Effectively With Legacy Code* (2004). Characterization tests as the safety net.
- Kent Beck — *TDD By Example* (2002). Red-Green-Refactor.
- Alistair Cockburn — *Writing Effective Use Cases* + walking skeleton pattern (1999).

## Refs

- Plan doc: `docs/next-session-plan-2026-09-27-interactive-skill-drives.md`
- Ticket: cli#254
- Sister /pre-mortem: 2026-09-22c cli#217 drive-shape cure (18 risks, top-3 folded)
- Sister /pre-mortem: 2026-09-22b cli#212 docker-smoke exit capture (15 risks, top-3 folded)
