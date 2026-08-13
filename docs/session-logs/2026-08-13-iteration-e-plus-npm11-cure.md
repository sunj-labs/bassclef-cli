---
date: 2026-08-13
session_id: 2026-08-13-iteration-e-plus-npm11-cure
duration_hours: ~3
mode: operator-gated-sequential
outcome: green
tier: lite
in_flight_goal: docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md
---

# Session log — Iteration e + npm 11 cure

## Operator recap

Iteration e shipped. `@thebassclef/core@0.0.2` is live on npm with provenance. Six publish attempts failed before the seventh landed. Root cause was hidden inside the npm CLI version — Node 20 ships npm 10.x, and npm 10 silently omits the trusted publisher headers on publish. The registry returns 404 as auth obfuscation. Pinning npm 11 in the publish job cured the class.

Five PRs shipped today (#28 through #32). One session-close PR (#10) stays open awaiting operator disposition.

## Entry state

Iteration e blocked on npm trusted publisher config. Prior session left the workflow at two-job shape with environment gate but the trusted publisher on npm was not yet set up. Local main clean at commit `122d0bb` from prior session close.

## Work done

- **PR #28 — release v0.0.2**. Branched `chore/release-0.0.2`. Ran `npm run bump patch` → package.json 0.0.1 → 0.0.2, CHANGELOG.md rewrite. Tagged v0.0.2, created release, workflow fired.
- **PR #29 — src/index.ts version sync fix**. Workflow failed on the tag because tests in `cli.test.ts` asserted `--version` prints package.json's value but got the stale `'0.0.1'` literal from `src/index.ts:14`. Bump script updated package.json + CHANGELOG.md only. Cured by extending bump script to also write `src/index.ts`, adding `tests/version-sync.test.ts` as the invariant, and fixing the literal. 157/157 tests green.
- **PR #30 — job-level id-token permission (belt-and-suspenders)**. Second workflow attempt hit 404 from npm registry despite trusted publisher config matching all four fields. Tried moving `id-token: write` to job scope. Did not cure.
- **PR #31 — npm@latest upgrade before publish**. Hypothesis K: npm 10 silently omits trusted publisher headers. Added `npm install -g npm@latest`. Hit EBADENGINE because npm@12 needs node ≥ 22.22.2.
- **PR #32 — pin to npm@11 for node 20 compat**. Range that supports trusted publishers AND runs on node 20. Seventh workflow attempt: PUBLISHED. `@thebassclef/core@0.0.2` on npm with provenance attestation.
- **PR #10** — pre-existing stale session-close PR from 2026-08-08 still open. Merge-conflict-dirty because whereami has been rewritten twice since. Left for operator disposition (path a rebase / path b close / path c leave open).

## Decisions

- **Path a for the src/index.ts cure**: re-tagged v0.0.2 from new HEAD after fix landed, rather than skip forward to 0.0.3. Nothing had consumed the broken tag; semver stays honest.
- **Belt-and-suspenders on OIDC path**: kept the job-level permissions block from PR #30 even after PR #31/32 shipped the actual cure. Costs nothing, protects against future workflow refactors that split permissions.
- **npm@11 pin (not npm@latest)**: pinned to the range that supports trusted publishers AND matches node 20. Prevents future npm@12+ releases from breaking the publish job.
- **Auto-save direct commit to main discarded via reset**: the save-state hook auto-committed `.claude/settings.json` + `.gitignore` substrate sync artifacts directly to local main. Reset local main to origin to keep history clean. Substrate sync will re-materialize the artifacts next SessionStart.

## Key files changed

- `src/index.ts` — version constant bumped, header amended with `@requirement R-NPM-007`
- `scripts/bump-version.mjs` — `writeIndexTsVersion()` added, allowlist extended for `src/index.ts`
- `tests/version-sync.test.ts` — new file, pins invariant
- `tests/bump-version.test.ts` — 3 new tests for `writeIndexTsVersion` + dirty-tree allowlist
- `docs/requirements/2026-08-11-npm-distribution.md` — R-NPM-007 registry row extended
- `.github/workflows/publish.yml` — job-level permissions + npm@11 upgrade step

## Open threads for next session

- PR #10 disposition — path a rebase / path b close / path c leave open (operator call)
- Iteration i — npm install harness with full OOAD ceremony (queued; prep in `docs/next-longrun-prep-2026-08-13-npm-install-harness.md`)
- bassclef-cli #25 (Model C reader) — still waits on bassclef-upstream #1184
- bassclef-cli #16, #19, #20 — manual `@thebassclef/lite`, `/standard`, `/ultra` npm reservations pending operator step

## Retrospective

### Went well

- **/diagnose kept firing at every failure** — the five-whys + is/is-not discipline caught each hypothesis being falsified. Ruled out A through G plus I in eight run cycles without wasted commits.
- **Byte-identical tarballs across seven runs** — determinism guarantee held. The same shasum (`8d547ccd4c3156a848721ef3f8294fc8f89a3f90`) shipped every attempt. Confidence that the code was ready never wavered; the entire investigation stayed on the auth path.
- **Cheap-to-test-first ordering** — retried before touching config; changed config before editing workflow; edited workflow before falling back to manual publish. Each step took under 5 minutes to gather evidence.
- **Traceability held through the churn** — R-NPM-007 gained the src/index.ts satisfy path AND a new verify test in the same PR. Registry stayed consistent with source.

### Harder than expected

- **npm registry returns 404 as auth obfuscation**. The error message says "not in this registry" but really means "your OIDC token cannot publish here." Read four documentation pages before finding this pattern named. Cost about 30 minutes of hypothesis-generation on wrong tracks.
- **npm 10 silently omits trusted publisher headers**. No warning, no error, no version-mismatch signal — just a 404 identical to a misconfigured trusted publisher. Sigstore accepts the token; registry rejects; the two disagree silently.
- **The npm@latest → npm@12 → EBADENGINE detour**. Cost one extra iteration because I typed `@latest` reflexively instead of pinning to a range compatible with the runtime node version.
- **Auto-save hook committing to main**. Discovered mid-session when `git pull --ff-only` refused. Discarded via reset, but the underlying hook behavior violates branching discipline. Deduped against existing upstream ticket #973.

### Change for next time

- **Set a runbook cap of 3 retries on any external auth flow** before switching to plan B. Six retries on npm publish before finding K was two too many.
- **Read the CLI version log every time an OIDC flow fails**. `npm --version` output should be the first thing checked when `registry.npmjs.org` returns unexpected status codes.
- **Pin CLI upgrades to explicit major versions in CI**. `@latest` is unstable across node/npm compatibility windows.

### Substrate observations proposed

- **dedup: version constant drift class** — candidate comment on sunj-labs/bassclef-upstream#1118 (audit: test files hardcode version strings decoupled from generator constants). Our exact instance in bassclef-cli today.
- **dedup: save-state auto-commit to main** — candidate comment on sunj-labs/bassclef-upstream#973 (save-state.sh non-auto path skips commit guard on protected branches). Same class fired today.
- **dedup: node 20 ships npm 10 which silently fails trusted publisher** — candidate comment on sunj-labs/bassclef-upstream#205 (bump workflow actions to Node.js 24-compatible versions). The Node 24 upgrade would fix this incidentally; naming the mechanism helps.
- **proposed: trusted publisher setup runbook** — new ticket candidate. First-time trusted publisher setup surfaced 7 hypotheses across 3 hours. A runbook with the "npm 11.5.1+ required" callout would save the next adopter the same cycle.
- **proposed: publish workflow template must include npm@11 upgrade step by default** — new ticket candidate. bassclef-generated publish workflows should ship with the npm upgrade baked in. Silent failure class otherwise.

### Open threads for next session

- File the two new /promotes above pending operator confirm
- Iteration i — full OOAD ceremony on npm install harness (see next-longrun prep)

### Bassclef promotes this session

- agent-self-proposed: 0 filed (5 observations captured; deferred to next session pending operator review)
- agent-user-proposed: 0
- total: 0 filed

## Gate Evidence

| Gate | Fired | Count | Path |
|---|---|---|---|
| temperance | yes | 3 | state/markers/temperance/ (chore-release-0.0.2, fix-version-constant-drift, fix-publish-job-permissions, fix-upgrade-npm-for-trusted-publisher, fix-pin-npm-11-for-node-20) |
| diagnose | yes | 2 | state/markers/diagnose/ (fix-version-constant-drift, fix-publish-job-permissions) |
| verify | yes | 4 | npm test on every fix branch before push (157/157 green each time) |
| traceability | yes | 1 | pre-commit-traceability.sh fired on PR #29 commit; green |
| kiss | yes | multiple | turn-prose-kiss-check on session prose |
