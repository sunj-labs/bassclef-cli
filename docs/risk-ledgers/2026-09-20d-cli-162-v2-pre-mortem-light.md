---
tier: project
title: Pre-mortem light V2 delta — cli#162 Docker harness V2 skill drive
id: 2026-09-20d-cli-162-v2-pre-mortem-light
authored: 2026-09-20
mode: light — 3 lenses × 3 risks, focused on V2-specific delta
prior_context: pre-mortems 1-4 from 09-20b cover V1 shape + Handoff 4 delivery
lenses:
  - alistair-cockburn
  - andreas-zeller
  - michael-nygard
---

# Pre-mortem light V2 delta — cli#162

## Sources read

- `docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md` Steps 8-9 — V2 scope declared but not shipped
- `harness/docker/entry.sh` L1-283 — V1 structure; exit-code map already carries slots for smoke-assert-hooks + smoke-assert-skills
- `harness/docker/Dockerfile.cold-adopter` — no `@anthropic-ai/claude-code` install; no perl
- `scripts/smoke-drive-skills.sh` L1-80 — uses `claude -p` non-tty; requires perl for timeout wrapper
- pre-mortems 1-4 from 09-20b — V1-shape risks; V2 delta gets its own short ledger

## Frame

V2 adds 5 things to V1: Claude CLI in image; smoke-capture; smoke-drive-skills; smoke-assert-hooks; smoke-assert-skills; smoke-report. Each carries a distinct risk class not covered by V1 pre-mortems.

3 lenses × 3 risks = 9 candidates. Fold HIGH before code.

---

## Cockburn — walking skeleton discipline (V2 as one more thread)

**C1 (MEDIUM). Scope creep — V2 tries to add too many features per action.**
Failure path: V2 grows a config layer for skill selection, a retry-on-flake mechanism, a report-comparison feature. Each looks small; together they turn V2 from walking skeleton into a full framework.
Cure: V2 ships one thread — Claude CLI + 5-skill drive per V1 spec + straight-through report. No feature additions. Any richer surface is a follow-on.

**C2 (MEDIUM). V2 code paths don't get their own Beck cycle.**
Failure path: V1 tests stay green. V2 additions get eyeball testing only. Regression class in V2 goes undetected until adopter-side hit.
Cure: extend `.claude/hooks/tests/docker-harness-entry.test.sh` with test cases for each new action's happy + edge path before writing V2 code.

**C3 (LOW). V2 hides V1 exit code semantics behind new aggregation.**
Failure path: V2's report step compresses V1's exit 0 signal into a "PASS/FAIL" that swallows the exit code the harness callers expect.
Cure: report step exits with the highest single-check code. V1 exit code semantics preserved.

---

## Zeller — hypothesis-test pairing

**Z1 (HIGH). If V2 doesn't reproduce the 12-hook cascade class on 1.2.0, the whereami L18-22 claim is confirmed wrong-dimension — but Docker may also miss a real defect.**
Failure path: V2 runs against 1.2.0 in Docker; assertions all pass; conclusion is "cascade doesn't reproduce anywhere". But adopter cold-adopter-1 profile is different environment (macOS, different $HOME, different auth state). Docker false-negative masks real macOS defect.
Cure: don't over-conclude from Docker result. Frame result as "Docker dimension: X findings". Compare to cold-adopter-1 profile separately. Both surfaces required.

**Z2 (MEDIUM). Claude CLI in container hits API rate limit on 5-skill drive.**
Failure path: 5 skills fire in quick succession. Rate limit hits. Some drives get 429. Assertions treat 429 output as skill-fail even when the skill would have succeeded.
Cure: smoke-drive-skills already has --timeout per-skill (default 120s per cli#116 bump). Space skill invocations with a small delay OR handle 429 as a distinct retry-eligible signal. Not a full rate-limit backoff — just recognize 429 in assert.

**Z3 (LOW). Container clock skew breaks any assertion that reads current time.**
Failure path: Container clock behind host by minutes. Assertions using date stamps drift out of expected windows.
Cure: none of our current assertions read wall-clock time. Note the assumption; add test if it changes.

---

## Nygard — operational stability + adopter contract

**N1 (HIGH). ANTHROPIC_API_KEY leaks in image, layer history, or logs.**
Failure path: Dockerfile bakes the key with `ENV ANTHROPIC_API_KEY=...` OR entry.sh echoes it OR Claude CLI writes it to a log file inside the container.
Cure: NEVER bake in Dockerfile — pass via `-e ANTHROPIC_API_KEY` at run time only (already the pattern in runbook). Entry.sh never echoes the value. Scan container filesystem for the value pattern in a Tier 0 test.

**N2 (MEDIUM). V2 requires the key; running without it degrades poorly.**
Failure path: Operator runs `docker run` without `-e ANTHROPIC_API_KEY`. Claude CLI fails with cryptic error mid-drive. Assertions see truncated output. Report shows FAIL for wrong reason.
Cure: preflight check for API key. If unset, run V1 only + emit friendly message "V2 skipped — set ANTHROPIC_API_KEY to enable skill drive". Preserves V1 utility even without key.

**N3 (LOW). Claude CLI version pin drift changes `-p` output shape.**
Failure path: Future Claude CLI updates change `-p` output format. Assertions parsing the output break.
Cure: pin `@anthropic-ai/claude-code` to a specific version in the Dockerfile. Note the pin. Bump deliberately.

---

## Ranked folds

**HIGH (before code)**:
- **Z1**: frame V2 result as "Docker dimension" not universal. Don't over-conclude.
- **N1**: NEVER bake API key in Dockerfile. Pass only via runtime `-e`. Add Tier 0 test that scans image for the key pattern (or verifies ENV block excludes it).

**MEDIUM (fold at test-write / code-shape time)**:
- **C1**: V2 walking skeleton discipline — no feature additions.
- **C2**: extend Tier 0 tests before code per Beck.
- **Z2**: recognize 429 in assert-skills as distinct signal (not a full backoff).
- **N2**: preflight for API key; degrade to V1 mode when unset.

**LOW (accept + document)**:
- **C3**: report exits with highest single-check code.
- **Z3**: no time-reading assertions today.
- **N3**: pin Claude CLI version in Dockerfile.

## Design edits from folds

1. **Dockerfile** — pin `@anthropic-ai/claude-code@2.x` (verify latest stable at build time) + apt install perl. No API key in ENV.
2. **entry.sh** — preflight adds API key check per N2. Missing → warn + skip V2, run V1 only, exit V1's code.
3. **Tier 0 tests** — add: image-scan test that verifies no ANTHROPIC_API_KEY value pattern in ENV output; API-key-missing skips V2 test; happy-path V2 drive test.
4. **Report step** — exits with highest single-check code, not aggregated boolean.
5. **Frame** — V2 baseline result documented as "Docker cold-Linux dimension" in whereami update. Cold-adopter-1 profile remains separate ground truth.
