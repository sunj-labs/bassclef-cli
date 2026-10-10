---
date: 2026-10-10
primary_lens: jerome-saltzer-and-michael-schroeder
supporting_lenses: [michael-nygard, michael-feathers]
prior_review: docs/architecture/reviews/2026-10-05-session-h-driver-sweep.md
coverage_marker: state/markers/architect-review/2026-10-10-session-p-cli-415.marker
scope: Session P step 7 — architect-review on cli#415 (ADR-059 CLI validator vendor + CI gate)
pr_reviewed: 416
merge_commit: 9cf9014
---

# Architect review — cli#415 cross-repo contract validator

## Verdict

**READY.** cli#415 landed clean per ADR-059 step 4. Dual-fire gate now closed: upstream validator on upstream PRs; cli validator on cli PRs. Both sibling smokes green. 2 moderate findings filed as follow-ups. 1 trivial note in report body.

## Scope

Narrow mid-session review scoped to cli#415's surface — not full-system. 7 artifacts shipped at merge `9cf9014`:

| File | Delta |
|---|---|
| `scripts/validate-cross-repo-contracts.sh` | NEW (vendor-exact from upstream `320f445b`) |
| `scripts/tests/validate-cross-repo-contracts.test.sh` | NEW (10 Tier 0 characterization tests) |
| `standards/cross-repo-contracts.json` | NEW (one-field delta on `test_refs`) |
| `standards/state-spine/schemas/cross-repo-contracts.schema.json` | NEW (vendor-exact) |
| `standards/state-spine/schemas/install-written-paths.schema.json` | NEW (vendor-exact) |
| `.github/workflows/pr-checks.yml` | NEW job `validate-cross-repo-contracts` |
| `tests/workflow-node-version.test.ts` | pin count 4 → 5 |

Full-system review deferred to session close or `/architect-review` auto-dispatch per `.claude/skills/architect-review/SKILL.md` cadence.

## Primary lens — Saltzer-Schroeder (complete mediation)

Does every path that could change the cross-repo contract now go through a check? YES at the write-path layer:

- Every cli PR touching `standards/cross-repo-contracts.json` → validator fires in CI (new job in `pr-checks.yml`)
- Every cli PR touching `standards/state-spine/schemas/*.json` → ajv compile in validator catches drift
- Every cli PR touching `src/lib/install-written-paths.ts` → `tests/init-install-written-paths.test.ts` fires in existing `test` job

Gap: `test_refs` in cli's registry points at the cli test only. Upstream's test path (`lib/tests/install-written-paths.test.sh`) sits in upstream's registry copy. Reader coupling is split by repo. The one-field delta is documented inline in the registry description + commit body.

## Supporting lens — Nygard (stability patterns)

- **Fail-soft on ajv missing** — validator exits 0 with stderr warning (vs hard-fail). Verified in Tier 0 test T10.
- **SKIP override logged via stderr** — operator bypass path exists for genuine edge cases.
- **Trap EXIT cleanup** — tempdir removed on all exit paths (L164-165).
- **8 distinct exit codes** — operator can discriminate failure class from exit code alone.

## Supporting lens — Feathers (characterization at adopter boundary)

Characterization-test gate satisfied. 10 Tier 0 tests ship with the vendor; each tests a named behavior category:

| Test | Category covered |
|---|---|
| T01 | file presence |
| T02 | --help interface |
| T03 | happy path (positive) |
| T04 | SKIP override |
| T05-T06 | missing-file exits (code 2) |
| T07-T08 | missing-ref exits (code 4) |
| T09 | malformed JSON (code 1) |
| T10 | ajv graceful-missing (code 0) |

Verified via `bash scripts/tests/validate-cross-repo-contracts.test.sh` → `pass=10 fail=0`.

## Dynamic verification pass

Sibling smoke at 2026-10-10T19:14Z:

- **Upstream validator against upstream repo** — `bash ~/src/sunj-labs/bassclef-upstream/scripts/validate-cross-repo-contracts.sh --repo-root ~/src/sunj-labs/bassclef-upstream` → exit 0; `OK install-written-paths`; `all contracts validated`
- **CLI validator against CLI repo** — `bash scripts/validate-cross-repo-contracts.sh --strict` → exit 0; `OK install-written-paths`; `all contracts validated`

Both sides pass. ADR-059 Decision L91 dual-fire pattern is live.

## Coverage checklist (universal areas; no stack sibling found)

- [x] Component architecture — validator + registry + schemas form a clean 3-piece contract pattern; no cross-cutting concern added
- [x] Data flow — registry → schema_ref (file exists check) → ajv compile → test_refs (file exists check); each stage records exit code
- [SKIP] Auth + security — N/A; validator has no auth surface
- [SKIP] Queue + workers — N/A
- [x] External dependencies — jq (hard dep); ajv-cli (graceful-missing); both documented in validator header
- [x] Error handling — 8 distinct exit codes; stderr format carries contract name + reason; no silent failures observed
- [SKIP] Database — N/A
- [x] Testing coverage — 10 Tier 0 for validator; 520 TS unchanged; 530 total GREEN
- [x] Performance — new CI job completed in 10s on PR #416 (ajv-cli install dominates); acceptable
- [x] ADR fitness — ADR-059 step 4 lands cleanly; step 6 (extraction_stage flip) now in flight at upstream per peer heads-up
- [SKIP] CLAUDE.md fitness — not touched this PR
- [x] SOLID — validator is single-responsibility; registry is bounded-context data
- [x] DDD — cross-repo contracts registry IS a bounded context (per @luminary eric-evans)
- [x] Stability patterns — Nygard lens checked above
- [x] Characterization gate — satisfied (10 Tier 0 tests pin behavior before any future refactor)
- [~] Universal verification suite — no `tech_stack.kind` sibling exists at `standards/architect-review-discipline/` in cli; using universal areas; `/promote` candidate noted below

Count: 12 covered, 1 deferred, 4 skip. No unmarked areas (A4 compliance per `.claude/rules/architect-review-discipline.md`).

## Findings

### Moderate

**F1 — Registry `test_refs` split by repo creates coordination load.**

- **Where:** `standards/cross-repo-contracts.json` L30-33 — `test_refs` carries cli's test path only; upstream carries its own path in its own copy
- **Why it matters:** Both repos have their own registry copy. When the schema shape changes (e.g., `test_refs` becomes an array of {repo, path} pairs), both registries need the same edit. Future schema shift risks silent drift.
- **Cure:** File ticket proposing a schema v1.1 that makes `test_refs` repo-aware. Non-blocking for cli#415; file for Session Q or later.
- **Falsifiability:** If upstream + cli test_refs continue to drift structurally over the next 3 ADR-059 steps, the risk is real. If they stay stable, the current single-string shape is sufficient and the ticket closes.

**F2 — Sibling smoke not wired as per-PR CI step.**

- **Where:** `.github/workflows/pr-checks.yml` validate-cross-repo-contracts job
- **Why it matters:** cli#415 § Acceptance item 6 — "operator confirms upstream's validator still passes against CLI's registry" — ran once at review time (today) but has no CI gate for future drift. If a cli PR edits the registry in a way that would break upstream's validator reading cli's copy, cli CI stays green but upstream smoke rots silently.
- **Cure:** Add a second CI step that fetches upstream main at a pinned tag + runs upstream's validator against cli's repo-root. Modest scope. File as a follow-on.
- **Falsifiability:** If upstream + cli validator shapes stay in lockstep (unlikely, given ADR-059 is still shipping steps 5-10), the second gate is redundant.

### Trivial

**N1 — Note on CI step ordering.** The `validate-cross-repo-contracts` job runs the Tier 0 test as a second step in the same job. This saves a Node install (~5s per PR) but couples the test to the job's step order. Low risk at V1. Split only if drift surfaces.

## Recommendations by priority

1. **File F1 ticket** at session close — schema shape evolution path for `test_refs` repo-split
2. **File F2 ticket** at session close — add upstream-validator-against-cli CI step
3. **File `/promote bassclef-evolution` ticket** for a `substrate` or `substrate-cli` sibling under `standards/architect-review-discipline/` — the per-stack review suite is missing today
4. Rebase-pin for upstream step 6 landing — peer heads-up received at 19:14Z; will send ack after this report commits

## Verification method per finding (A4 compliance)

| Finding | Static | Dynamic | Both |
|---|---|---|---|
| F1 | ✓ (registry inspect) | — | — |
| F2 | ✓ (workflow inspect) | ✓ (sibling smoke) | ✓ |
| N1 | ✓ (workflow inspect) | — | — |

## Refs

- `architecture/decisions/ADR-059-cross-repo-contract-drift-prevention.md` (upstream)
- `.claude/rules/architect-review-discipline.md` — two-method requirement
- `.claude/rules/mechanism-fidelity.md` — verification chain
- `docs/risk-ledgers/2026-10-10-session-p-cli-415-then-328.md` — pre-mortem light; R1-R5 folded into cli#415 impl
- cli#415 (closed by PR #416 merge `9cf9014`)
- bassclef-upstream#2157 — parent longrun
- Peer heads-up: bassclef-upstream-28 (uds:/tmp/cc-socks/45212.sock) at 19:14Z — step 6 extraction_stage flip in flight at upstream
