---
tier: project
title: Pre-mortem light — smoke evidence capture (Layer 1)
id: pre-mortem-2026-09-18-smoke-evidence-capture
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture
shape: Klein light — 3 lenses × 5-8 risks per lens
anchor: gary-klein (pre-mortem method)
lenses:
  - peter-deutsch
  - werner-vogels
  - martin-fowler
references:
  - path: docs/specs/smoke-evidence-capture.md
    role: post-fold spec
  - path: docs/use-cases/UC-smoke-run.md
    role: post-fold UC
  - path: docs/decompositions/smoke-evidence-capture.md
    role: post-fold decomposition
  - path: docs/rfc/RFC-smoke-evidence-adversarial.md
    role: prior adversarial pass
---

# Pre-mortem light — smoke evidence capture (Layer 1)

## Sources read

- `docs/specs/smoke-evidence-capture.md` (post-fold)
- `docs/use-cases/UC-smoke-run.md` (post-fold)
- `docs/decompositions/smoke-evidence-capture.md` (post-fold)
- `docs/rfc/RFC-smoke-evidence-adversarial.md` — prior adversarial pass; different lenses used
- `docs/intent-audits/2026-09-18-smoke-evidence-design.md` — declared lens set

## What I'm NOT reading (with reason)

- Klein 1998 body — cite the method by name
- Deutsch 8-fallacies paper — cite the fallacies by name

## Method

Klein light per `/pre-mortem` SKILL. Frame: "It is 30 days from now. We shipped Layer 1. Something went wrong. What is the risk that fired?" 3 lenses, 5-8 risks per lens, one-line mitigation per risk, disposition per risk.

Anchor luminary: gary-klein (pre-mortem originator).

Three outside lenses picked to catch what the authoring set plus the RFC 4 (linus + hyrum + cooper + maurya) missed:

- **peter-deutsch** — 8 fallacies of distributed computing
- **werner-vogels** — everything fails all the time
- **martin-fowler** — refactoring risks + test design

## Lens 1 — peter-deutsch (8 fallacies of distributed computing)

The smoke touches the network at three places — `npm install`, `gh issue create/edit`, `claude -p` (may hit the API depending on config). Deutsch's fallacies bite.

### D1 — "The network is reliable" (severity MED)

**Risk:** `gh issue create` transiently fails mid-run. Report on disk; publish half-completed. Operator does not notice; next smoke thinks the issue exists (from partial state).

**Mitigation:** Wrap the `gh` call in retry-once-with-backoff. If second attempt fails, exit non-zero with clear "publish failed; report at <path>; re-run with `--publish-only`" message. **Fold-in-Step-6.**

### D2 — "Latency is zero" (severity MED)

**Risk:** GitHub API responds slowly (200ms → 3s on busy days). Report script feels hung. Operator kills it. Report on disk but not published; second run creates a duplicate.

**Mitigation:** Print "posting to GitHub..." before the `gh` call. Add `--publish-only` flag that skips capture + assert + report generation and just posts the existing report file. **Fold-in-Step-6.**

### D3 — "Bandwidth is infinite" (severity LOW)

**Risk:** Report body grows past GitHub's ~65KB issue body limit when captures balloon. Publish fails with cryptic 422.

**Mitigation:** Report body carries only pass/fail table + top 20 lines per RED capture. Raw captures link to gists (Step 6 pattern). Cap issue body at 60KB. **Fold-in-Step-6.**

### D4 — "The network is secure" (severity LOW)

**Risk:** Man-in-the-middle on the npm install produces a tampered `lite` package. Smoke runs against a compromised binary and reports PASS.

**Mitigation:** Not this layer's problem — npm provenance handles it (whereami L34 confirms 1.1.1 shipped with provenance). Note in Step 8 test plan: "verify provenance badge on install page before smoke." **Defer to test plan.**

### D5 — "Topology does not change" (severity LOW)

**Risk:** GitHub renames the repo or transfers ownership. Publish target invalid.

**Mitigation:** Repo name in a config var, not hardcoded. `SMOKE_REPO_TARGET=sunj-labs/bassclef-cli` env default. **Fold-in-Step-6.**

### D6 — "There is one administrator" (severity LOW)

**Risk:** Operator changes `gh` auth mid-flight (switches accounts for a peer session). Publish lands as wrong user.

**Mitigation:** Report script captures `gh auth status` at run start, includes user in the report body. If mismatch with expected, warn but proceed. **Fold-in-Step-6.**

## Lens 2 — werner-vogels (everything fails all the time)

Any moving part fails. The smoke has many.

### V1 — `claude` CLI crashes during a skill drive (severity MED)

**Risk:** `claude -p "/kiss words <sample>"` segfaults or hangs past 30 second timeout. Capture file contains crash output. Assertion treats crash as regular content, no-not-found check fails on "Segmentation fault: 11". False signal.

**Mitigation:** Skill-drive script captures exit code separately; assertion suite reads exit code first and skips the four checks with a CRASH row when exit is non-zero-non-timeout. **Fold-in-Step-4 or Step-5.**

### V2 — Filesystem full (severity LOW)

**Risk:** `~/tmp` fills mid-capture. Writes fail. Some captures land, some do not. Assertion inconsistent.

**Mitigation:** Capture script checks `df` before starting. Fail-fast if under 500MB free. **Fold-in-Step-1.**

### V3 — Snapshot dir fills over time (severity LOW)

**Risk:** 7-day auto-expire on `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/` (per F6 fold). Over months of runs, expire logic breaks (bug, missed cron, etc.). Disk fills.

**Mitigation:** Every reset run prunes any snapshot dir older than 7 days. Idempotent. Do not rely on external cron. **Fold-in-Step-7.**

### V4 — `bassclef init` produces different file counts run to run (severity MED)

**Risk:** File count varies because init reads from bassclef's upstream tree that itself changes. Assertion `paths-exist` succeeds today, fails tomorrow, with no cli defect.

**Mitigation:** Report captures the manifest count and the upstream commit hash it read (per whereami L34 pattern). Include in report so an operator can distinguish upstream drift from cli defect. **Fold-in-Step-6.**

### V5 — Report post succeeds; the issue body renders garbled (severity LOW)

**Risk:** Markdown edge case in a capture file (unescaped backticks in path names, HTML-like content) renders broken in the issue body. Report says GREEN but the reader sees noise.

**Mitigation:** Report script escapes capture-embedded content per GitHub's markdown rules. Add a fixture that tests the escape. **Fold-in-Step-6 with a Step-3 fixture.**

### V6 — `gh` CLI updates and changes issue-list output shape (severity LOW)

**Risk:** `gh issue list --label smoke-run-v1` output shape changes between versions. Idempotency search breaks silently.

(Note 2026-09-19 per PR #141: label is now `smoke-run-<version>`, not `smoke-run-v1`; substance of the risk unchanged.)

**Mitigation:** Use `gh issue list --json number,body --jq '...'` for parse-stable output. Never scrape human text. **Fold-in-Step-6.**

## Lens 3 — martin-fowler (refactoring risks + test design)

The smoke system will change. What breaks when it does?

### F1 — Adding a fifth check breaks all fixtures (severity MED)

**Risk:** Layer 2 or Layer 3 adds a fifth check. Existing fixtures for cli#101-#108 do not exercise the new check; every fixture appears to pass the new check trivially. The check is untested.

**Mitigation:** Each check ships with its own fixture set (at least one PASS + one FAIL). Extending the check list requires extending the fixture set. Enforce via a Tier 0 test that walks the check list and asserts fixture coverage. **Fold-in-Step-3.**

### F2 — Skill list grows without allowlist updates (severity LOW)

**Risk:** Layer 2 or Layer 3 adds `/build` and `/verify` to the skill list. Their expected outputs contain `BLOCKED:` blocks (as design intent, not error). The no-unexpected-blocked check fails for the wrong reason.

**Mitigation:** Allowlist per check (per spec) accepts a JSON per skill naming BLOCKED patterns that are expected. Layer 2 populates for its skills. **Fold-in-Step-5.**

### F3 — Sequence diagram becomes wrong when scripts collapse (severity LOW)

**Risk:** A future refactor merges `smoke-assert-hooks.sh` and `smoke-assert-skills.sh` into one script. Decomposition sequence diagram becomes wrong. No test catches doc drift.

**Mitigation:** Not this layer's problem. Note in Layer 1 closeout: "if scripts consolidate later, update decompose sequence in the same PR." **Note in closeout.**

### F4 — Assertion strategy signature drifts (severity MED)

**Risk:** Strategy pattern per check requires `(capture_path, allowlist) → AssertionResult`. Future check adds a fifth argument. Old checks break unless refactored together.

**Mitigation:** Assertion signature enforced by a shared function contract in `lib/smoke-assert.sh`. Any check that adds an argument amends the contract in one place. **Fold-in-Step-2.**

### F5 — Fixture location becomes hard to find (severity LOW)

**Risk:** Fixture dir `.claude/hooks/tests/fixtures/2026-09-18-smoke-findings/` is dated. Future readers see "2026-09-18" and think it is a snapshot from that date, not living fixtures.

**Mitigation:** Rename to `.claude/hooks/tests/fixtures/smoke-defect-fixtures/` when it starts holding non-2026-09 defects. **Note in closeout.**

### F6 — Report format bakes assumptions the assertion suite does not (severity LOW)

**Risk:** ReportBuilder assumes AssertionResult always has `capture_path` field. Some future check produces a result without one (e.g., a whole-run check). ReportBuilder crashes with missing key.

**Mitigation:** AssertionResult schema declared once in `lib/smoke-schema.sh`. Every field optional-or-required declared. ReportBuilder handles missing optionals. **Fold-in-Step-2.**

## Aggregated risk register

| # | Lens | Severity | Risk | Disposition |
|---|---|---|---|---|
| D1 | Deutsch | MED | gh transient fail mid-publish | Fold-in Step 6 (retry + `--publish-only`) |
| D2 | Deutsch | MED | GitHub latency looks hung | Fold-in Step 6 (progress print) |
| D3 | Deutsch | LOW | Report body > 65KB limit | Fold-in Step 6 (cap + gist) |
| D4 | Deutsch | LOW | Tampered npm binary | Defer to Step 8 test plan (provenance check) |
| D5 | Deutsch | LOW | Repo rename breaks publish | Fold-in Step 6 (env var) |
| D6 | Deutsch | LOW | gh auth switch mid-flight | Fold-in Step 6 (capture auth status) |
| V1 | Vogels | MED | claude CLI crashes on drive | Fold-in Step 4 or 5 (CRASH row on exit code) |
| V2 | Vogels | LOW | ~/tmp full | Fold-in Step 1 (df check) |
| V3 | Vogels | LOW | Snapshot dir fills | Fold-in Step 7 (self-prune) |
| V4 | Vogels | MED | Upstream drift shifts file count | Fold-in Step 6 (capture upstream hash) |
| V5 | Vogels | LOW | Markdown edge case garbles report | Fold-in Step 6 + Step 3 fixture |
| V6 | Vogels | LOW | gh output shape drift | Fold-in Step 6 (use --json) |
| F1 | Fowler | MED | Fifth check trivially passes all fixtures | Fold-in Step 3 (coverage-walk Tier 0 test) |
| F2 | Fowler | LOW | Skill list grows without allowlist | Fold-in Step 5 (per-skill allowlist JSON) |
| F3 | Fowler | LOW | Script consolidation breaks decompose diagram | Note in closeout |
| F4 | Fowler | MED | Assertion signature drift | Fold-in Step 2 (contract in `lib/smoke-assert.sh`) |
| F5 | Fowler | LOW | Fixture dir date confuses future reader | Note in closeout (rename later) |
| F6 | Fowler | LOW | AssertionResult schema baked into report | Fold-in Step 2 (contract in `lib/smoke-schema.sh`) |

## What folds into which step

**Step 1 (capture):**
- V2 — `df` check before write

**Step 2 (assert-hooks + shared lib):**
- F4 — shared assertion contract in `lib/smoke-assert.sh`
- F6 — shared schema in `lib/smoke-schema.sh`

**Step 3 (fixtures):**
- F1 — coverage-walk Tier 0 test
- V5 — markdown-edge-case fixture

**Step 4 or 5 (skill drive + assert):**
- V1 — CRASH row on non-zero exit code
- F2 — per-skill allowlist JSON

**Step 6 (report + publish):**
- D1 — retry + `--publish-only`
- D2 — progress print
- D3 — cap + gist for big captures
- D5 — `SMOKE_REPO_TARGET` env var
- D6 — capture `gh auth status`
- V4 — capture upstream commit hash
- V6 — `gh --json` for parse-stable

**Step 7 (reset extension):**
- V3 — self-prune snapshot dirs older than 7 days

**Step 8 (test plan fold):**
- D4 — provenance check note

**Closeout notes (no code changes):**
- F3 — sequence diagram drift note
- F5 — fixture-dir rename plan

## Ledger summary

- 18 risks surfaced across 3 lenses
- 6 MED + 12 LOW
- 14 fold-in-now (across Steps 1-7)
- 1 fold-in-later (Step 8 test plan)
- 3 closeout notes (F3 + F5; D4 mostly-defer)

Estimated added turn cost: 8-15 turns total across Steps 1-7. Sits inside the existing overrun budget the operator accepted.

## Verdict

Design plus RFC folds already covered the load-bearing failure classes (Feathers characterization tests catch defect regressions; Nygard Fail-Fast catches init failures; Saltzer-Schroeder complete mediation covers every surface). This pre-mortem catches the second-order layer — network failures, refactoring risks, silent drift. Every fold has a specific home.

**Recommend to operator:** proceed to Step 1 code. Each step's code cites the folds landing in it. Layer 1 closeout notes F3 + F5.

## References

- Klein, *Sources of Power* (1998) — pre-mortem method
- Deutsch, *8 Fallacies of Distributed Computing* (Sun Microsystems, ~1994)
- Vogels — Amazon Web Services principle, oft-cited
- Fowler, *Refactoring* (1999) and *xUnit Test Patterns* (with Meszaros)
- Spec: `docs/specs/smoke-evidence-capture.md`
- Use case: `docs/use-cases/UC-smoke-run.md`
- Decomposition: `docs/decompositions/smoke-evidence-capture.md`
- Prior RFC: `docs/rfc/RFC-smoke-evidence-adversarial.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
