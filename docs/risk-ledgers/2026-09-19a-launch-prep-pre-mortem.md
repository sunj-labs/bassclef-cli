---
tier: project
title: Pre-mortem light — launch-prep sweep (OS contract + docs merges)
id: pre-mortem-2026-09-19a-launch-prep
date: 2026-09-19
goal_id: 2026-09-19a-launch-prep-os-contract-plus-docs-merge
shape: Klein light — 3 lenses × 5-7 risks per lens
anchor: gary-klein (pre-mortem method)
lenses:
  - martin-fowler
  - kent-beck
  - frederick-brooks
references:
  - path: docs/iteration-bets/2026-09-19a-launch-prep-os-contract-plus-docs-merge.md
    role: goal doc for this pre-mortem
  - path: package.json
    role: file getting the `"os"` field added
  - path: README.md
    role: file getting the supported-systems section added
  - ticket: sunj-labs/bassclef-cli#151
    role: parent ticket; Phase 1 acceptance amended via comment
  - ticket: sunj-labs/bassclef#1497
    role: upstream substrate portability audit; cure path if Linux breakage surfaces
---

# Pre-mortem light — launch-prep sweep

## Sources read

- `docs/iteration-bets/2026-09-19a-launch-prep-os-contract-plus-docs-merge.md` — goal doc, this session
- `package.json` — no `"os"` field today; verified 2026-09-19T13:48Z
- `README.md` — no OS copy today; verified via grep 2026-09-19
- `sunj-labs/bassclef-cli#151` body + Phase 1 acceptance list
- `sunj-labs/bassclef#1497` body — upstream portability audit scope
- npm docs on `os` field semantics (memory + Node docs — `os` values match `process.platform`; `EBADPLATFORM` at install for mismatches)

## What I'm NOT reading (with reason)

- Deutsch 8 fallacies paper — small scope; distributed fallacies do not fire on a 3-file docs+config PR
- Klein 1998 body — cite the method by name
- Individual runbook PR bodies (#114, #115, #119) — Option b reviews each at merge time, not now

## Method

Klein light per `/pre-mortem` SKILL. Frame: "It is 7 days from now. We shipped Phase 1 on launch day 2026-09-20. Something went wrong. What is the risk that fired?" 3 lenses, 5-7 risks per lens, one-line mitigation per risk, disposition per risk.

Three lenses picked to catch what the authoring set (linus + saltzer-schroeder + hyrum + norman + klein) might miss:

- **martin-fowler** — refactor + release risks; does the change cause silent regression?
- **kent-beck** — test coverage; what proves the pin behaves right?
- **frederick-brooks** — conceptual integrity; do the three surfaces agree?

## Lens 1 — martin-fowler (refactor + release risks)

### F1 — `npm publish` refuses on `"os"` field syntax error (severity MED)

**Risk:** typo in the `"os"` array (`"os": ["darwin,linux"]` — one string instead of two) passes JSON syntax check but sets `os` to a single non-matching value. `npm install` fails on every platform with `EBADPLATFORM`. Fresh installs break at launch morning.

**Mitigation:** validate the `package.json` after edit with `npx --package=@thebassclef/lite -- true` in a fresh `~/tmp` dir OR run `node -e 'console.log(require("./package.json").os)'` and assert output is `[ 'darwin', 'linux' ]`. **Fold at Step 1 verification.**

**Disposition:** fold.

### F2 — publish workflow assertion may check `"os"` (severity LOW)

**Risk:** `publish.yml` `checks` job might grep `package.json` for expected fields and fail if `"os"` is new. Publish blocks on tag push.

**Mitigation:** read `publish.yml` before commit; if it has a `package.json` field allowlist, extend it. Otherwise no action.

**Disposition:** verify at Step 1; likely no-op.

### F3 — README section drift from `standards/os-support.md` on first edit (severity LOW)

**Risk:** README supported-systems section says "darwin + linux" but the standard says "macOS + Linux" — same content, different vocabulary. Future edits diverge because they read different anchors.

**Mitigation:** README links to `standards/os-support.md` as source of truth; README summary stays 3-4 lines, refers reader to standard for depth. **Fold at Step 1.**

**Disposition:** fold.

### F4 — `#151` acceptance list not updated to match commit (severity LOW)

**Risk:** ticket body still reads `["darwin"]` after PR merges. Reviewer six months later reads the ticket, expects darwin-only, sees the code — confusion.

**Mitigation:** the amendment comment on #151 records the pin decision + reasoning. The `Closes bassclef-cli#151 Phase 1` in the PR body carries the actual acceptance shape. Comment 5742446859 is the audit trail.

**Disposition:** already mitigated via comment 5742446859.

### F5 — regression on Docker adopters (severity LOW)

**Risk:** Docker Linux containers install `@thebassclef/lite@1.2.0` today because there is no `"os"` field. After the pin lands, `docker run node:20 npm install -g @thebassclef/lite` continues to work (Linux is in the pin). No regression.

**Mitigation:** none needed; risk falsified by pin including `linux`.

**Disposition:** risk falsified.

## Lens 2 — kent-beck (TDD + test coverage)

### B1 — no test proves `"os"` field is correct after edit (severity MED)

**Risk:** manual edit + eyeball verification. Regression class not pinned. A future edit that removes `linux` from the pin ships without a signal.

**Mitigation:** add a Tier 0 test at `tests/package-json-shape.test.ts` (or similar) asserting `package.json` `.os` equals `["darwin", "linux"]`. Cheap. **Fold at Step 1.**

**Disposition:** fold.

### B2 — README section drift not test-caught (severity LOW)

**Risk:** README supported-systems section could be deleted or edited to say `["darwin"]` only. No test catches copy-vs-config disagreement.

**Mitigation:** deferred. Tests for README prose live in bassclef-web launch content, not here. Standards file is the intermediate source of truth.

**Disposition:** defer to post-launch (follow-on ticket if drift observed).

### B3 — smoke pipeline reads `"os"` from installed tarball (severity LOW)

**Risk:** `scripts/smoke-*.sh` may inspect `package.json` for adopter path; adding a new field could break a `jq` assumption.

**Mitigation:** grep smoke scripts for `package.json` reads before commit; adjust if any read `.os` or fail on unknown keys.

**Disposition:** verify at Step 1.

### B4 — full test suite may break on `"os"` field (severity LOW)

**Risk:** existing test that reads `package.json` fixture data breaks on new key.

**Mitigation:** run `npm test` after edit; suite must stay green.

**Disposition:** enforced by acceptance list.

### B5 — pin blocks CI runner on some platform (severity LOW)

**Risk:** GHA workflow uses `ubuntu-latest`; `npm install` in publish workflow after pin lands would fail if workflow runs `npm ci` against the built package on any non-{darwin,linux} runner.

**Mitigation:** all current workflows run on `ubuntu-latest` per `.github/workflows/*.yml`. Linux is in the pin. No CI break.

**Disposition:** risk falsified.

## Lens 3 — frederick-brooks (conceptual integrity)

### K1 — three surfaces (README + package.json + standard) drift (severity MED)

**Risk:** README says one thing, `package.json` says another, `standards/os-support.md` says a third. Adopter reads any one, forms a mental model, hits contradiction on next surface. Trust erodes on first click.

**Mitigation:** ship all three in one PR with matching content. README refers reader to standard. Standard names the exact `"os"` values. **Fold at Step 1 — all three in one commit.**

**Disposition:** fold.

### K2 — WSL 2 wording ambiguity (severity LOW)

**Risk:** README says "WSL 2 untested but likely" — adopter installs on WSL 2, hits substrate bash bug, files an angry ticket. "You said it would work."

**Mitigation:** use precise wording — "WSL 2 (Windows Subsystem for Linux 2) reports as `linux` to npm, so install works. Substrate bash is macOS-tested; Linux paths may hit BSD-vs-GNU divergence per `sunj-labs/bassclef#1497`. File a ticket if you see it." **Fold at Step 1.**

**Disposition:** fold.

### K3 — Windows PowerShell adopter reads README, tries install, gets `EBADPLATFORM` — is that a good signal or bad? (severity LOW)

**Risk:** adopter with Windows PowerShell reads "we support darwin + linux" — clear. Runs `npm install -g @thebassclef/lite` on native Windows — gets `EBADPLATFORM`. Understands? Or thinks the package is broken?

**Mitigation:** README supported-systems section names Windows explicitly — "Windows native is not supported; use WSL 2. `EBADPLATFORM` on `npm install` from PowerShell is the intended fail-fast." Sets expectation before the failure. **Fold at Step 1.**

**Disposition:** fold.

### K4 — `standards/os-support.md` becomes a stale document (severity LOW)

**Risk:** future Phase 2 (portability audit) + Phase 3 (matrix CI) + Phase 4 (Windows) land without updating the standard. Adopters read outdated policy.

**Mitigation:** standard names the Phase 2/3/4 tickets by number. Each future phase PR includes a standards edit as acceptance. Not enforceable this session; document intent.

**Disposition:** document; enforce at future phase PR time.

### K5 — copy-vs-code disagreement teaches adopters to trust one and not the other (severity MED)

**Risk:** the `["darwin", "linux"]` pin is honest today but README calls the copy "the honest claim." If future audit shows Linux broken and cure lags, `package.json` still says supported → contradiction returns.

**Mitigation:** name the substrate portability audit (upstream #1497) inline in README + standard. Adopter sees "we intend Linux; audit in flight; file a ticket if you hit BSD-vs-GNU divergence." Sets expectation for the intermediate state. **Fold at Step 1.**

**Disposition:** fold.

## Summary — folds into Step 1 plan

Six folds land in Step 1 files:

- **F1** — post-edit `package.json` `"os"` shape verification via node one-liner
- **F3** — README refers to `standards/os-support.md` as source of truth; keeps README summary short
- **B1** — Tier 0 test asserting `package.json.os === ["darwin", "linux"]`
- **K1** — three surfaces ship in one commit; all three agree
- **K2** — precise WSL 2 wording with upstream #1497 pointer
- **K3** — Windows PowerShell explicit note with `EBADPLATFORM` reasoning
- **K5** — inline reference to upstream #1497 portability audit

Three deferred:

- **F2** — verify `publish.yml` at Step 1 (likely no-op)
- **B3** — grep smoke scripts for `package.json` reads at Step 1
- **K4** — future-phase discipline documented; not enforced this session

Two risks falsified:

- **F5** — Docker Linux install continues to work
- **B5** — CI runner is `ubuntu-latest`; Linux in pin

## Lead lens

**@luminary linus-torvalds** signs off Step 1 at the /loop discipline signoff step (per `.claude/rules/loop-discipline.md` Step 5.5). Adopter-contract lens is the balancing check — does the three-surface change actually keep the adopter contract?
