---
tier: standard
id: ADR-004
title: Pin the safety contract for the publish pipeline — trusted publisher + tag validator + andon scan + tier filter + fixed workflow path
status: accepted
date: 2026-08-06
accepted: 2026-08-08
accepted_via: PR #7 merged — WU-4 publish pipeline shipped the safety contract this ADR pins
supersedes: null
superseded_by: null
---

# ADR-004 — Pin the safety contract for the publish pipeline

## Context

WU-4 of iteration bet
`docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` L124
lands the mechanism that publishes every future version of
`@thebassclef/core` to npm. Publish is the only path that writes to
the npm registry. Every mistake becomes globally visible and
semver-locked.

Forces at play:

- **Public install code.** Any adopter can `npm install -g @thebassclef/core`.
  A malicious publish reaches every adopter's disk on their next
  install.
- **Trusted publisher hard-codes the workflow file path.** npmjs.com
  stores the exact `<owner>/<repo>/.github/workflows/<file>.yml`
  path. Renaming the workflow file in a PR breaks publishing until an
  operator logs into npmjs.com to update the config.
- **Single operator today.** N-of-M approvers on the Environment
  gate would be one operator approving twice — theater, not defense.
  Accepted risk with layered mitigations.
- **Content-hash normalization from ADR-003 semver-locks at 0.0.2.**
  If any pre-publish check catches drift, it must run BEFORE the
  first tag.
- **Bassclef substrate assets are NOT bundled today.** The tier
  filter is machinery ready for a later WU that ships substrate.
  Today it always passes.

Alternatives considered:

1. **Token-based `NPM_TOKEN`.** Standard for older npm publish
   flows. Rejected — a leaked token publishes anything. Trusted
   publisher requires the GitHub Actions OIDC identity + repo +
   workflow-file match, so a leaked secret alone cannot publish.
2. **Publish from a maintainer laptop.** Rejected — no attestation,
   no provenance, no CI-clean checkout guarantee. Every publish
   comes from a machine with the maintainer's browser cookies, npm
   tokens, and shell history.
3. **Auto-publish on tag push (no approval gate).** Rejected — the
   gate is where the operator confirms "yes, this exact SHA + this
   exact version." Automated publish removes that beat.

## Decision

The publish pipeline for `@thebassclef/core` is a single GitHub
Actions workflow at a semver-locked path. Every published version
runs through the same shape.

### Workflow file path (semver-locked)

`.github/workflows/publish.yml`

Renaming requires:

1. An ADR amendment (or superseding ADR).
2. An npm-side config change at
   `npmjs.com/settings/<user>/packages/@thebassclef/core`.
3. Both must ship in the same coordinated release. A rename PR
   without the npm config change is a MAJOR bump under semver
   because every future release fails silently.

A Tier 0 test asserts the exact path exists.

### Trigger conditions

- `release: types: [published]` — fires on both stable and
  pre-release GitHub Releases. The `prerelease` flag on the event
  drives the dist-tag choice (see below).
- `workflow_dispatch:` with a required `tag` input for manual
  re-runs (e.g., after fixing a transient failure).

No other triggers. Not `on: push:`. Not `on: schedule:`.

### Job permissions

- `id-token: write` — required for npm provenance attestation via
  the OIDC token.
- `contents: read` — required for `actions/checkout`.

No `contents: write`, no `packages: write`, no `pull-requests: write`.
Nothing the workflow can modify in the repo.

### Ordered steps (refuse on any failure)

The workflow runs as two jobs (iteration c per audit finding D-4.1).
Job 1 (`checks`) runs on every trigger with no approval gate. Job 2
(`publish`) needs job 1 and carries the environment gate. The approver
sees the checks job green on the workflow run page before clicking
approve.

**Job 1 — checks:**

1. Resolve tag (from release event OR workflow_dispatch input).
2. `actions/checkout` at the tag ref (fetch-depth: 0 for ancestor check).
3. `actions/setup-node` at Node 20 with npm registry configured for
   provenance.
4. `npm ci --ignore-scripts` — install with no script execution.
5. `node scripts/validate-tag.mjs "$TAG"` — string-equal match
   against `package.json` version + ancestor check against `origin/main`.
6. `npm run build` — clean rebuild from source.
7. `npm test` — full test suite.
8. `npm run typecheck` — TypeScript strict.
9. `npm pack --dry-run --json > /tmp/pack.json` — the exact file
   list npm will ship, without shipping.
10. `node scripts/andon-scan.mjs /tmp/pack.json` — operator-private
    term scan.
11. `node scripts/tier-filter.mjs /tmp/pack.json` —
    `tier: upstream` YAML frontmatter scan.

Job 1 exports two outputs — `tag` and `prerelease` — for job 2.

**Environment gate: `npm-publish`** — job 2 waits for operator approval.
Because the gate sits on job 2 with `needs: checks`, approval fires
only after job 1 finishes green. Operator sees the completed check
output on the workflow run page and clicks approve with evidence.
Under the pre-iteration-c single-job shape the environment gate sat
on the only job and fired before checkout, giving the approver nothing
to review.

**Job 2 — publish:**

12. `actions/checkout` at the tag ref (re-checkout is deterministic).
13. `actions/setup-node` at Node 20 (same as job 1).
14. `npm ci --ignore-scripts` (same as job 1).
15. `npm run build` — rebuild from source. Same inputs, same tool
    versions, same install flags produce the same `dist/` bytes.
16. `npm publish --provenance --ignore-scripts` — dist-tag driven by
    the `prerelease` output from job 1: `latest` for stable, `next`
    for pre-release.
17. Write the published URL to `$GITHUB_STEP_SUMMARY` for operator
    confirmation.

The rebuild in job 2 costs about 30 seconds of duplicated work versus
sharing an artifact from job 1. The trade-off buys job 2 being self-
contained — no artifact-share configuration to maintain, no hidden
coupling between jobs. Verified in `tests/workflow-path.test.ts` L52-64
that job 2 carries `environment: npm-publish` and job 1 does not.

### Content of each check

**validate-tag.mjs:**

- String-equal match between `TAG` (stripped of leading `v`) and
  `package.json` `version`. Semver-equal is NOT used — string equal
  is stricter and catches `beta.1` vs `beta.01` typos.
- Ancestor check via `git merge-base --is-ancestor $TAG origin/main` —
  refuses tags on branches not yet merged.
- Tag format check via semver regex — refuses `v0.0.2.4`,
  `v0.0.2extra`, etc.
- Refusal message names package.json path, current version, expected
  version, and the exact fix (bump + re-tag).

**andon-scan.mjs:**

- Reads the `--dry-run --json` pack output.
- For each file listed as shipped, runs two checks:
  1. **PATH check** (`scanPath`) — the file's own shipped path must
     not match `docs/operator-private/` (see Amendment 2026-08-31
     below).
  2. **CONTENT check** (`scanContent`) — file content is scanned
     against a term list.
- Content term list: absolute POSIX home paths (`/Users/*`,
  `/home/*`) and email addresses (except in LICENSE, `package.json`
  `author`, or per-file allowlist entries).
- Per-file allowlist for shipped substrate:
  - `CODE_OF_CONDUCT.md` allows `conduct@bassclef.dev`
  - `.claude/skills/promote/SKILL.md` allows `hello@bassclef.dev`
  - Both are public contact addresses that legitimately ship.
- Per-file override via `# andon-allow: <regex>` header — matches
  bassclef's own release pipeline pattern.
- List grows on incident. Quarterly review prunes terms unused for
  six months.

**Amendment 2026-08-31 — discrimination shift for `docs/operator-private/` (issue #40 follow-on):**

Before this amendment, `docs/operator-private/` was on the content
term list. When scope-b1 added `substrate/` as a shipped artifact
class, the scan started firing on every substrate file that describes
the operator-private discipline in prose (ADRs, skills, README,
CONTRIBUTING). All 14 initial hits were false positives; none were
actual leaks. Publish workflow run 33346136435 failed on this exact
class.

Per pre-code architect-review 2026-08-31, `docs/operator-private/`
moved from content scan to path scan. The real leak signal is a
shipped file whose PATH matches the operator-private location.
Content mentions of the path string in prose are legitimate
documentation and pass.

**Accepted risk (documented per Popper falsifiability):** content
mention of a specific operator-private FILENAME in prose is no longer
scanned. PR review is the mitigation. Alternative was tightening the
regex to `docs/operator-private/[^\s"'\`]+\.md` but the shape is
error-prone and blocks the common false-positive class first without
solving the rare content-pasting leak. Explicit test 14 in
`tests/andon-scan.test.ts` pins the intentional gap.

**Same-class prevention:** the checks-job assertion added at PR #41
covers the sister class — silent-empty tarball. Together, both cures
close the two failure classes that surfaced during the 0.1.0 launch
attempt.

**tier-filter.mjs:**

- For each file listed as shipped whose extension is `.md`, `.mdx`,
  or `.markdown`, parses the YAML frontmatter block at BOF.
- Frontmatter parse is a small hand-rolled regex over the block
  bounded by `---\n` at BOF and the next `---\n`. No `js-yaml`
  runtime dep.
- Refuses if `tier: upstream` appears as a top-level key inside the
  block.
- Substring matches ANYWHERE else in the file are ignored — a
  README table documenting the tier system does not trip.

### Environment gate

Environment name: `npm-publish`. Configured in the repo's
`Settings → Environments`. Required reviewer: the single operator
(kingofrock). The gate lives on the `publish` job only (per iteration
c workflow split); the `checks` job runs without a gate and its output
lands on the workflow run page before the approver clicks approve.

Accepted-risk decision per Saltzer principle 5 (separation of
privilege):

- N-of-M is impossible with one maintainer. Adding the same account
  twice adds no defense.
- Layered mitigations replace the missing separation:
  - Passkey or YubiKey 2FA required on the operator's GitHub
    account (documented in `docs/publish-setup.md`).
  - Passkey or YubiKey 2FA required on the operator's npm account.
  - Trusted publisher config on npm is a separate account requiring
    its own 2FA to change.
  - Every publish appears in the GitHub Actions run history and
    npm's activity log; a compromise is visible after the fact.
- Revisit trigger: a second maintainer joins the project. At that
  point, add the second maintainer as a required reviewer on the
  Environment. Repo-settings edit, no code change.

### Post-publish confirmation

The final step writes to `$GITHUB_STEP_SUMMARY`:

```
Published: https://www.npmjs.com/package/@thebassclef/core/v/<version>
Provenance: https://www.npmjs.com/package/@thebassclef/core/v/<version>#provenance
```

Cooper's psychological acceptability at the CLI text level: the
operator sees the URL without leaving the workflow run page.

## Status

`accepted` on 2026-08-08 via PR #7 (publish pipeline merged; see
frontmatter `accepted_via`). Amended 2026-08-11 in iteration b to
align this Status body with the frontmatter. Amended 2026-08-11 in
iteration c to split the workflow into two jobs (`checks` + `publish`)
so the environment gate fires AFTER checks land green. Approver sees
check output on the workflow run page before clicking approve. No
supersession pending.

## Consequences

**Easier:**

- Every publish is deterministic + auditable + attributable via
  provenance attestation.
- A stolen maintainer laptop cannot publish. The workflow is the
  only path.
- Scripted callers reading the exit codes can tell refusals
  apart from write failures.

**Harder:**

- First-time setup requires manual npmjs.com trusted-publisher
  config + GitHub Environment creation. Documented in
  `docs/publish-setup.md`.
- Renaming the workflow file requires a coordinated ADR + npm-side
  change. Rename is not free.
- The Environment approval step pauses the workflow. Operator must
  approve from the run page; not fire-and-forget.

**Enables:**

- Automated version bumps in future WUs can invoke the workflow
  directly by pushing a tag.
- Substrate bundling (later WU) inherits the tier filter machinery
  automatically — the scan is already running at every publish.
- The andon scan detects operator-private leaks across every
  future release without per-release ceremony.

**Blocks (until reconsidered):**

- No auto-publish. Every release requires operator approval at the
  Environment gate.
- No token-based publish path. `NPM_TOKEN` is not stored, not
  configured, not accepted.
- No publish from a laptop. Trusted publisher only accepts the
  configured GitHub Actions workflow.

**Invariants established (semver-locked for 0.x):**

Workflow shape:

- Workflow path `.github/workflows/publish.yml` — rename requires
  coordinated npm-side config change.
- Triggers: `release: types: [published]` + `workflow_dispatch`
  with `tag` input.
- Job permissions: `id-token: write` + `contents: read` only.

Ordered checks:

- validate-tag (string equal + ancestor + semver format)
- npm ci with `--ignore-scripts`
- build + test + typecheck
- npm pack `--dry-run --json`
- andon scan
- tier filter (YAML frontmatter parse only, no substring match)
- Environment approval gate `npm-publish`
- npm publish with `--provenance --ignore-scripts`
- Dist-tag: `latest` for stable, `next` for pre-release

Refusal exit codes:

- `1` — validate-tag refusals (version mismatch, ancestor fail,
  format fail)
- `2` — andon-scan refusals (operator-private term found)
- `3` — tier-filter refusals (`tier: upstream` YAML frontmatter
  found)
- `4` — reserved (not used in publish; matches ADR-003's SchemaTooNew)

Tag format regex (validate-tag.mjs):

- Accepts standard semver with mandatory `v` prefix:
  `v<MAJOR>.<MINOR>.<PATCH>` and optional pre-release identifiers
  after `-`.
- Rejects four-segment versions, leading zeros in numeric parts,
  and any trailing garbage.
- Loosening the regex is a MAJOR bump — adopters piping into the
  validator inherit the acceptance set as behavior.

Refusal message shape:

- Every refusal names the failing check, the offending value, and a
  `fix:` line with the exact next step. Scripted callers parse the
  `fix:` prefix as a stable contract.

Tier-filter YAML normalization:

- Line endings — CRLF folds to LF before parsing.
- BOM — a leading UTF-8 BOM is stripped.
- Leading blank line before the first `---` is tolerated.
- Values may be bare or quoted with single or double quotes; the
  parser strips quotes before comparing.
- Any change to the normalization set is a MAJOR bump.

Any change to a listed step, permission, dist-tag rule, exit code,
the workflow path, the tag-format regex, the refusal-message shape,
or the tier-filter normalization set is a MAJOR bump under semver.

## References

- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L124 (WU-4 scope), L92-108 (npm best practices), L155-158 (bet
  acceptance)
- Decomposition: `docs/decompositions/wu-4-publish.md` — full luminary
  consult + pre-mortem + challenger pass with 3 KILL-level fixes
- ADR-001 — build toolchain pin (no `prepublishOnly`, no source
  shipped, files whitelist)
- ADR-002 — init safety contract (fail-safe defaults, atomic writes)
- ADR-003 — sync safety contract (content-hash normalization + exit
  code 4 convention)
- ADR-031 — we-don't-break-adopters (the reason default choices are
  semver-locked)
- Luminaries:
  - `saltzer-schroeder.md` — 8 principles; principles 2, 3, 5, 6, 8
    drive this contract
  - `alan-cooper.md` — operator persona; refusal messages designed
    for psychological acceptability
  - `john-ousterhout.md` — deep modules; each check is one script,
    one job
  - `vaughn-vernon.md` — anticorruption pattern; the tier filter
    reads a manifest (later) rather than raw bassclef frontmatter
- npm docs: https://docs.npmjs.com/trusted-publishers/
- Evil Martians 2026 secure-release guide (bet L98)
- Prior art: bassclef `scripts/release-to-bassclef.sh` — same andon
  scan pattern
