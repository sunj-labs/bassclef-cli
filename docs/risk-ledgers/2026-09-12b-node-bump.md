---
id: 2026-09-12b-node-bump
title: Pre-mortem light — Node 20 → 22 bump
date: 2026-09-12
mode: light
lens_count: 3
goal: 2026-09-12b-node-bump
---

# Pre-mortem light — Node 20 → 22 bump

## Sources read

- `docs/iteration-bets/2026-09-12b-node-bump.md` — goal frame + scope + acceptance
- `.github/workflows/harness.yml` — full workflow body (test matrix + Node setup + shellcheck)
- `.github/workflows/publish.yml` — full workflow body (checks job + publish job + environment gate)
- `.claude/luminaries/linus-torvalds.md` — primary lens (adopter contract)
- `.claude/luminaries/michael-feathers.md` — supporting lens (characterization)
- `.claude/luminaries/michael-nygard.md` — supporting lens (stability pattern)
- `docs/whereami.md` L26 + L37 — thread + recap
- `.claude/skills/pre-mortem/SKILL.md` — light-mode procedure (3 lenses × 5-8 risks each, 30 min)

## Method

Klein pre-mortem in light mode. Imagine the goal has shipped and something went wrong. Ask each luminary lens what broke. Name 5-8 risks per lens. Rate severity 🟢 low / 🟡 medium / 🔴 high. Fold the strongest concerns into the plan before edits begin.

## Lens 1 — Linus Torvalds (adopter contract)

Do not break adopters. What could break?

**T1** — Adopters install the published tarball from npm. If Node 22 in CI produces different built JS than Node 20, adopters see a behavior change without a version bump. Severity: 🟢. Cure: Vite bundle output is deterministic across Node 20/22 for our source shape (TypeScript → ESM); mitigated further by no `MINOR` bump this PR — only workflow changes. This should not touch the published tarball at all.

**T2** — Adopters on Node 20 might hit a runtime error if we accidentally use Node 22 syntax. Severity: 🟢. This PR does not touch `src/`; only workflow YAML. Not a real risk.

**T3** — GHA marketplace Actions might have Node 22 compat issues (e.g., older `actions/checkout` versions). Severity: 🟢. We use `actions/setup-node@v4` and `actions/checkout@v4` per grep of workflows; both support Node 22.

**T4** — The published tarball's `engines.node` says `>=20`. If someone reads this as "Node 20 tested" and depends on that, bumping CI runner to 22 without changing engines is silent. Severity: 🟢. The `>=20` pin explicitly allows Node 22+. No promise broken.

**T5** — Fresh clones use `node --version` from local install; may see version drift vs CI. Severity: 🟢. No `.nvmrc` today; adopter dev environment untouched.

## Lens 2 — Michael Feathers (characterization)

Where are the untested seams? What test would fail if we broke something?

**F1** — 🟡 **STRONGEST.** No characterization test asserts the published tarball is byte-identical or behavior-identical across Node 20 and Node 22. Test suite runs on whichever Node the runner picks. If Node 22 changes Vite output (e.g., different minifier output, module ordering), we ship without knowing. Cure: run `npm run build` locally on Node 22 before merge; compare tarball SHA against last Node-20 build. Better cure (out of scope this PR): freeze the tarball SHA via `npm pack --dry-run` in CI as a Tier 0 test.

**F2** — Vitest may behave differently on Node 22 (e.g., timing tests, snapshot differences). Severity: 🟢. Existing 229 tests are deterministic per prior session logs (no flaky reports). Any Node 22 breakage would surface on the CI run of this PR itself. Cure: rely on CI as the characterization step.

**F3** — Shellcheck job in `harness.yml` runs on Ubuntu, uses `shellcheck` binary, not Node. Node bump does not touch it. Severity: 🟢.

**F4** — The publish workflow's `npm ci` step could resolve dependencies differently on Node 22 (different lockfile behavior). Severity: 🟢. `package-lock.json` is deterministic; `npm ci` refuses to modify it.

**F5** — No test in the current suite asserts the Node version pins are consistent across workflow files. That is the Tier 0 grep test this goal adds. Cure: Step 1 adds the test; catches drift on future PRs.

## Lens 3 — Michael Nygard (stability pattern)

Where does a failure cascade? Where is the circuit breaker?

**N1** — 🟡 If Node 22 breaks the publish job mid-run (e.g., after `npm run build` but before `npm publish`), the tarball may already be pushed but the workflow reports failure. Adopters see the new version live; the PR looks broken. Severity: 🟡. Cure: publish workflow already gates on `environment: npm-publish` with operator review per ADR-004; operator sees the Node runner in the job log before approving. Rollback path: `npm deprecate` if a bad tarball shipped.

**N2** — GHA runner OS updates could interact with Node 22 in unexpected ways (e.g., newer glibc requirement). Severity: 🟢. `ubuntu-latest` runners have supported Node 22 since 2026-04.

**N3** — This PR itself runs on Node 20 until it merges to main. First Node 22 run happens on the post-merge harness workflow (push trigger). If it fails, main is broken. Severity: 🟢. Cure: the workflow_dispatch trigger lets us run harness on the branch manually before merge if we want extra confidence; also the PR check runs the modified workflow, so we get the signal on the PR CI itself.

**N4** — Cache keys may differ between Node 20 and Node 22 (`actions/setup-node@v4` sets up npm cache scoped by Node version). First Node 22 run rebuilds the cache. Severity: 🟢. One-time cost.

**N5** — If the bump lands and then rolls back (e.g., F1 fires post-merge), the git history shows churn. Severity: 🟢. Standard revert commit handles it.

## Summary

**Strongest concerns:**

- **F1** (Feathers, 🟡) — no test asserts Node 22 build output matches Node 20 build. Fold into Step 2 as an explicit verification step: run `npm run build` locally on Node 22 (via `nvm use 22`) before pushing the PR. If build succeeds and tarball diff is minor (e.g., only comment ordering), proceed. If tarball changes materially, pause and file a follow-on.
- **N1** (Nygard, 🟡) — publish job could fail after tarball ships. Existing operator-gated environment approval per ADR-004 already mitigates this. Operator sees Node 22 in job log; can decline approval if suspicious.

**Everything else: 🟢.**

## Folded into plan

Step 2 (local verify) now includes:

- Switch local Node to 22 (`nvm use 22` if available; otherwise skip and rely on CI as the first Node 22 signal)
- Run `npm run build` and confirm exit 0
- Optional: `npm pack --dry-run` and compare file count against last Node-20 tarball (should be identical — same source, same tsconfig, same rollup input)
- Run `npm test` and confirm 229/229 green
- Push branch; PR CI is second Node 22 signal
- Operator reviews CI log before merge; publish workflow's environment gate is third signal

If any step surfaces a real Node 22 divergence, pause and file a follow-on. Do not force the bump.

## Grade

Light mode complete. 15 risks across 3 lenses. 2 rated 🟡; 13 rated 🟢. Strongest concerns folded into Step 2. Proceed with Step 1.
