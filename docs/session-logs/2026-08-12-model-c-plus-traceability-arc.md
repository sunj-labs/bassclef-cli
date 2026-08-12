---
date: 2026-08-12
title: Model C pivot + Traceability Subsystem promote + audit fix arc
session_started: 2026-08-11
session_ended: 2026-08-12T11:25Z
prs_merged: 12
issues_filed_bassclef_cli: 4
issues_filed_upstream: 1
upstream_comments: 1
adopter_tier: lite
lite_tier_skipped: [roadmap-reconcile, journal, readiness-sweep, clean-artifacts]
---

# Session log — Model C pivot + Traceability Subsystem promote + audit fix arc

## Entry state

Session opened with `/longrun prep`. Main at `122d0bb` (chore/session-close-2026-08-08 commit). Whereami said "Setup-docs owed" but the file existed. That mismatch was the first thing the operator caught. Prompted the full OOAD audit that ran the rest of the session.

## Work done

### OOAD audit (task set 3-8)

Audited 5 ADRs + 4 use cases + 1 interaction design doc + 5 decompositions against the shipped code. Surfaced 20 drift items across 6 classes — body-vs-frontmatter Status drift (4 items), missing invariants (4 items), UC overstates code (2 items), docs disagree with code (3 items), anticipates state (1 item), naming collision (1 item), whereami staleness (1 item), plus 4 findings from a luminary review (source-map safety, cross-ADR ownership, exit-code taxonomy collision, untested diagrams).

Merged as PR #12 with the promote draft.

### Iterations shipped

- **Iteration a — source-map safety** (PR #11). `package.json` files field flipped to explicit whitelist (`dist/*.js`, `dist/*.cjs`, `dist/*.d.ts`). `vite.config.ts` sourcemap flipped from `true` to `'hidden'`. New Vitest at `tests/pack-no-source-maps.test.ts`. ADR-001 invariant amended. Closed the class that caused the Anthropic v2.1.88 leak (59.8 MB source map exposed 513K lines of TypeScript per InfoQ + Layer5 write-ups).
- **Iteration b — drift fix pass** (PR #13). 13 mechanical fixes across ADRs 001-004 + UC-sync + UC-script-bump + interaction design + cli.ts. Aligned docs to shipped code. No design change.
- **Iteration f — static requirement diagram** (PR #14). New `docs/requirements/2026-08-11-npm-distribution.md`. Registry with R-NPM-001 through R-NPM-013. Traceability matrix. Mermaid graph. Gap analysis. Serves as applied test case for the Traceability Subsystem promote.
- **Iteration c — 4 design decisions** (PR #15). Split publish.yml into checks + publish jobs. Environment gate now fires after checks green. Cross-ADR ownership move — init manifest-exists refusal moved from ADR-003 into ADR-002. CHANGELOG 0.0.1 merged into Unreleased. Namespace reservation intent added to ADR-005.
- **Iteration d — traceability enforcement Vitest** (PR #17). New `tests/requirements-traceability.test.ts` with 8 assertions. Parses registry. Walks source for `@requirement`, tests for `@verifies`. Blocks orphan IDs and missing edges. `@requirement` annotations added to 8 source files. `@verifies` annotations added to 7 test files. Meta exemption for R-NPM-012.
- **PR #18 — sequence diagrams**. Three views (author flow, test implementation, CI wiring) added to both the requirements doc and the promote draft.
- **Iteration g — git pre-commit hook bridge** (PR #21). New `scripts/pre-commit-traceability.sh` + `scripts/install-git-hooks.sh`. Bridges CI failsafe to author-time subsystem shape. Ran live as smoke test on its own commit.
- **Iteration h — substrate hook spec** (PR #22). `docs/proposed-substrate-hooks/requirement-annotation-check.md`. Concrete Phase 2 shape for bassclef substrate. Bash sketch + 12 Tier 0 test cases enumerated.

### Model C pivot

Operator asked mid-session — "why not a paid option handled via license file"? Triggered a full model comparison — multi-package (A) vs single-package license-check (B) vs open core (C) vs hybrid (D). Landed on Model C: `@thebassclef/core` = free CLI + lite substrate bundled; `@thebassclef/standard-pro` + `@thebassclef/ultra-pro` = paid packages via npm auth token; `@thebassclef/lite` reserved defensively.

Shipped:

- **PR #24 — ADR-005 pass-1 amendment**. Direction accepted. Extraction contract with bassclef-upstream pending upstream reply.
- **Prompt drafted for bassclef-upstream** — 4 questions on manifest, extraction, version pinning, paid tier symmetry.
- **Upstream replied** — ADR-051 (commit `d54e701a`, PR #1185) plus specific answers. Manifest at `lite-manifest.json`. Extract mechanism (A) via bassclef-upstream building `dist/lite/`. Version pinning auto-follows latest v-tag. Paid tier decision deferred.
- **PR #26 — ADR-005 pass-2 amendment**. Flipped pending markers to accepted with the specific upstream answers.
- **bassclef-cli #25 filed** — follow-on ticket for the reader implementation on this side. Waits on bassclef-upstream #1184.
- **Comment posted at bassclef-upstream #1184** (comment 5265798011) confirming (A) for extraction shape.

### Traceability Subsystem promote

Operator surfaced the traceability gap early — "we need requirement traceability as a substrate primitive." Drafted 300-line umbrella at `docs/promotes/2026-08-11-traceability-subsystem.md`. Filed as bassclef-upstream #1182. Applied test case runs live in bassclef-cli iteration d + f + g + h.

### Namespace reservation tickets

Operator asked to split the original single reservation ticket into three so `@thebassclef/lite` gets highest priority.

- bassclef-cli #16 — `@thebassclef/lite` (highest priority; operator started reservation this session)
- bassclef-cli #19 — `@thebassclef/standard`
- bassclef-cli #20 — `@thebassclef/ultra`

## Decisions

1. **Model C over Model A.** Open core over multi-package. Reason: paid content should not touch non-paying adopter disks; server-side npm auth beats client-side license check.
2. **Traceability enforcement in three layers.** CI Vitest (iteration d) + git pre-commit hook (iteration g) + proposed substrate PreToolUse hook (iteration h spec). Defense in depth.
3. **bassclef-upstream ships pre-built `dist/lite/`, bassclef-cli reads unchanged.** Primary extract lives upstream per ADR-051 D1. Backup gates stay in bassclef-cli per Saltzer-Schroeder complete mediation.
4. **Auto-follow latest v-tag at build time.** No manual pin file. Adopter accountability lives at the CLI status line per bassclef-upstream #873 sub-cure 1.
5. **Iteration e stays on the current story.** First tag 0.0.2 ships CLI + init templates only. Model C bundled ship shape lands in a follow-on cut once bassclef-upstream #1184 ships.

## Open threads

- **bassclef-upstream #1184** — extract build implementation. Waits on the bassclef-cli confirmation posted this session. Upstream will schedule as their next `/longrun`.
- **bassclef-upstream #1182** — Traceability Subsystem promote awaits triage on upstream side. Phase 1 acceptance items open.
- **bassclef-cli #25** — Model C reader implementation. Blocks on bassclef-upstream #1184.
- **Iteration e (first tag 0.0.2)** — blocked on operator-side setup — trusted publisher on npmjs.com + GitHub Environment `npm-publish`.
- **Q4 (paid tier extraction contract)** — deferred until free tier ships cleanly.
- **`@thebassclef/lite` reservation (bassclef-cli #16)** — operator started the reservation flow this session. Ticket stays open until `@thebassclef/lite@0.0.1` shows on npmjs.com.
- **`@thebassclef/standard` + `@thebassclef/ultra` reservations (#19, #20)** — lower priority; still owed.

## Key files changed

- `docs/adrs/ADR-001` — shebang banner invariant added + source-map exclusion invariant added
- `docs/adrs/ADR-002` — files count fixed + mkdirSafely mediation + manifest-exists refusal invariant added (moved from ADR-003)
- `docs/adrs/ADR-003` — case table extended (NoMarker + UnknownHash) + Init amendments section removed
- `docs/adrs/ADR-004` — workflow split into checks + publish jobs described
- `docs/adrs/ADR-005` — Namespace reservation section added; then Model C pass-1 amendment; then Model C pass-2 amendment
- `docs/requirements/2026-08-11-npm-distribution.md` — new; static requirement diagram + traceability matrix + gap analysis + sequence diagrams
- `docs/promotes/2026-08-11-traceability-subsystem.md` — new; umbrella promote draft + Phase 1 evidence with sequence diagrams + cross-ref to bassclef-upstream #1182
- `docs/proposed-substrate-hooks/requirement-annotation-check.md` — new; Phase 2 substrate hook spec
- `docs/use-cases/UC-sync.md` — unified-diff wording fix
- `docs/use-cases/UC-script-bump.md` — allow-dirty wording fix
- `docs/use-cases/UC-script-publish.md` — two-job publish sequence described
- `docs/interaction-design/2026-08-08-npm-distribution.md` — github.ref reference fix + sequence diagram updated for two-job workflow
- `.github/workflows/publish.yml` — split into checks + publish jobs + traceability annotations
- `src/cli.ts` — unknown-command exit code 1 → 3
- `src/commands/init.ts`, `sync.ts` — `@requirement` annotations added
- `scripts/tier-filter.mjs`, `andon-scan.mjs`, `validate-tag.mjs`, `bump-version.mjs` — `@requirement` annotations added
- `scripts/pre-commit-traceability.sh` + `scripts/install-git-hooks.sh` — new; iteration g bridge
- `vite.config.ts` — sourcemap flipped to 'hidden' + `@requirement` annotations added
- `package.json` — files field flipped to explicit whitelist
- `tests/pack-no-source-maps.test.ts` — new (iteration a)
- `tests/requirements-traceability.test.ts` — new (iteration d)
- `tests/workflow-path.test.ts` — extended with two-job invariant tests
- `tests/*.test.ts` — 7 files gained `@verifies` annotations
- `tests/cli.test.ts` — unknown-command exit code assertion updated to 3
- `CHANGELOG.md` — Security + Fixed + Added + Changed + Notes sections under Unreleased documenting the arc
- `README.md` — Contributing section documenting `scripts/install-git-hooks.sh`

## Gate evidence

<!-- Gate Evidence populated per templates/chronicle-template.md pattern -->

| Gate | Fired | Skipped | Reason if skipped |
|---|---|---|---|
| /temperance | Per branch (10 branches this session) | 0 | — |
| /diagnose | Not fired | Skipped (n/a) | No defect diagnosis this session; audit was proactive |
| /verify | Per iteration (npm test + tsc --noEmit + npm run build after each) | 0 | — |
| /kiss | Applied on operator-facing prose per turn-prose hooks | 0 | — |
| /luminary | Consulted for iteration c design decisions (Saltzer-Schroeder, Ousterhout, Fowler, Feathers, Cooper, Brooks) | 0 | — |
| /promote | Filed bassclef-upstream #1182 (Traceability Subsystem umbrella) | 0 | — |
| /roadmap-reconcile | 0 | 1 | Skipped per adopter tier gate (lite) |
| /architect-review | 0 | 1 | Deferred to bet close per bet L164 acceptance |

## PRs merged (this session)

| # | Title |
|---|---|
| 11 | feat(security): source-map exclusion before first tag |
| 12 | docs(audit): OOAD audit outputs + Traceability Subsystem promote draft |
| 13 | fix(docs): iteration b drift fix pass — 13 items |
| 14 | docs(requirements): add SysML requirement diagram for @thebassclef/core |
| 15 | feat(design): iteration c — 4 design decisions land |
| 17 | feat(traceability): iteration d — mechanical enforcement for the requirement diagram |
| 18 | docs(traceability): add sequence diagrams to requirements + promote |
| 21 | feat(traceability): iteration g — git pre-commit hook bridge |
| 22 | docs(traceability): iteration h — substrate hook spec + promote update |
| 23 | docs(promote): cross-reference filed ticket bassclef-upstream#1182 |
| 24 | docs(adr): ADR-005 amendment — pivot to Model C (open core) |
| 26 | docs(adr): ADR-005 second amendment — Model C contract accepted |

## Tickets filed (this session)

- bassclef-cli #16 — Reserve `@thebassclef/lite` on npm (highest priority)
- bassclef-cli #19 — Reserve `@thebassclef/standard` on npm
- bassclef-cli #20 — Reserve `@thebassclef/ultra` on npm
- bassclef-cli #25 — Follow-on: consume bassclef-upstream `dist/lite/` tree per ADR-051 D1
- bassclef-upstream #1182 — feat: Traceability Subsystem — SysML-inspired traceability + 5 luminaries (umbrella)

## Cross-repo comments (this session)

- bassclef-upstream #1184 comment 5265798011 — confirmation of (A) for lite tier extraction shape

## Sources read

- `docs/whereami.md`, `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
- All 5 ADRs (001-005) at their state as of session start
- All 4 use cases (UC-init, UC-sync, UC-script-bump, UC-script-publish)
- `docs/interaction-design/2026-08-08-npm-distribution.md`
- `docs/publish-setup.md`
- Source under `src/`, `scripts/`, `.github/workflows/`
- Tests under `tests/`
- `.claude/luminaries/john-ousterhout.md`, `martin-fowler.md`, `michael-feathers.md`
- Bassclef substrate rules including plain-english-discipline, option-label-discipline, compounding-sequence-fresh-analysis, we-dont-break-adopters, and others (per SessionStart injection)
- Web research on `@anthropic-ai/claude-code` npm package + March 2026 leak (InfoQ, Layer5, SiliconANGLE)
