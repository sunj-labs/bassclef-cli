---
bet: 2026-08-06b-launch-npm-thebassclef-core
title: Launch — bassclef-lite ships via npm as @thebassclef/core
project: bassclef-upstream
execution_repo: sunj-labs/bassclef-cli
tier: upstream
status: filed
authored: 2026-08-06
authored_by: agent
in_flight_bet: null
parent_roadmap: docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md
appetite: 300-500 turns
appetite_source: |
  Bet 27c mechanism-fidelity ran ~200 turns per WU per bet 2026-08-05c plan doc L58.
  This bet has 8 substantive WUs (bootstrap repo + init + sync + publish + semver +
  cold-adopter harness + security PRs + Sam demo). Range grounded on WU-count × per-WU
  actuals. Wider top of the range covers new-repo scaffolding overhead + npm publish
  learning curve on the first ship.
authoring_luminaries:
  primary: [alan-cooper, john-ousterhout, saltzer-schroeder]
  supporting: [linus-torvalds, marty-cagan, vaughn-vernon, tony-hoare]
lead_lens: alan-cooper
tickets: [943, 944, 945, 946, 947, 948, 949, 950, 1055, 1110, 1143, 941, 3]
references:
  - {type: epic, id: 943, anchor: parent epic — npm distribution Phase 1 for @thebassclef/core CLI}
  - {type: ticket, id: 1055, anchor: npm private-content filter — mirror /release andon scan discipline}
  - {type: ticket, id: 1143, anchor: tier manifest as contract between upstream and sibling repos}
  - {type: ticket, id: 941, anchor: Sam magic demo — cold-start install path validation}
  - {type: ticket, id: 1110, anchor: version bump policy}
  - {type: ticket, id: 947, anchor: publish pipeline — amended to consume lite-manifest.json}
  - {type: ticket, id: 3, anchor: packaging + versioning methodology gap (3+ weeks open) — closes with WU-5}
  - {type: canvas, id: docs/canvases/2026-07-19-bassclef-lite.md, anchor: Q7 amendment 2026-07-27 names npm as Sam install path}
  - {type: strategy, id: docs/operator-private/strategy/2026-07-26-kilo-port-npm-strategy.md, anchor: source of truth for the npm decision + package name + repo ownership}
  - {type: bet, id: docs/iteration-bets/2026-08-06c-polish-vocab-legibility-louis.md, anchor: sibling bet — Goal B POLISH runs in parallel from bassclef-upstream}
  - {type: source, id: https://medium.com/@ddylanlinn/npm-package-development-guide-build-publish-and-best-practices-674714b7aef1, anchor: starter npm best-practices source (operator-supplied)}
  - {type: source, id: https://docs.npmjs.com/trusted-publishers/, anchor: npm trusted publishing docs — eliminates token-based auth}
  - {type: source, id: https://evilmartians.com/chronicles/the-secure-way-to-release-an-npm-package, anchor: 2026 secure-release guide (Evil Martians)}
adr_references:
  - ADR-031 (we-don't-break-adopters — npm ships adopter-observable surface; compat shims required)
  - ADR-035 (substrate-as-system — every rule cited by npm-side code owes a mechanism)
  - ADR-043 (two-axis tier vocabulary — @thebassclef/core is the lite-tier vehicle)
---

# Launch — bassclef-lite ships via npm as @thebassclef/core

## Problem

Bassclef has no shipped distribution today. A tarball path exists in code — dispatcher hook plus `.bassclef-source.json` reads a GitHub tarball URL on session-start — but zero adopters have taken it up. Ticket #3 has flagged the packaging + versioning gap for 3+ weeks. Operator direction 2026-08-06 — go straight to npm; the tarball path can come back later if npm hits friction.

The plan of record (per operator-private strategy doc 2026-07-26-kilo-port-npm-strategy.md) says npm. Sam is the target persona. In this bet, Sam's install path becomes:

```
npm install -g @thebassclef/core
bassclef init
```

Two commands. First-touch friction resolves. Every future update runs `bassclef sync` (or npm auto-upgrades if the adopter opts in).

## Value

Sam runs `npm install -g @thebassclef/core` in 5 minutes and gets a working bassclef. Adopters upgrade in place. Semver + changelog methodology closes #3. Adam Sharpe's security PRs (bash injection guard + `curl | bash` self-healing) land before the first tagged release. Cold-adopter harness gains a new check class covering the npm path.

Per @luminary alan-cooper — Sam's first-touch experience IS the acceptance test. Her attention budget is 5 minutes. If she hits jargon in the first 60 seconds, she bounces per her persona.

Per @luminary john-ousterhout — the npm interface (`npm install -g @thebassclef/core`) is shallow; the implementation (tier filter + andon scan + provenance + version bump) is deep. Adopters see the shallow interface; bassclef owns the depth.

Per @luminary saltzer-schroeder — every publish path is mediated. Trusted publishers on GitHub Actions gets rid of token-based auth. `--ignore-scripts` at publish blocks script injection. Andon scan blocks the ship if operator-private content appears in shipped files.

## Sources read

- `docs/operator-private/strategy/2026-07-26-kilo-port-npm-strategy.md` — source of truth for the decision + package name (@thebassclef/core reserved on npm at 0.0.1) + repo ownership (new sunj-labs/bassclef-cli)
- `docs/canvases/2026-07-19-bassclef-lite.md` Q7 amendment 2026-07-27 — Sam's install path becomes npm
- `docs/roadmaps/2026-07-20-bassclef-lite-market-entry.md` — current last_event (Bet 2026-07-31f — Iteration 2 telemetry build shipped end-to-end in one /longrun (~150 turns actual vs 220-440 filed appetite). 7 steps landed clean — goal doc + pre-mortem light + schema + ADR-049 + lib/telemetry.sh + hook wiring (session-start + PostToolUse Skill + session-end) + aggregator + adopter doc + opt-in rule. 29 Tier 0 tests GREEN. PR pending operator review. Passive-collect phase now runs 4-8 weeks. Iteration 3 gate — first Iteration 2 report reads decide Paddle/Stripe + tier-gate + upgrade-message scope. at 2026-08-01 09:15:00+00:00) — this bet is Iteration 2's LAUNCH slice; runs in parallel with the passive-collect phase, does not block Iteration 3 gate
- gh issue #943 body — parent epic with 7 child tickets #944-#950 named
- gh issue #1055 body — npm build must filter operator-private content; mirror /release andon scan
- gh issue #1143 body — tier manifest as contract across all three tiers; Vernon anticorruption pattern anchored
- gh issue #987 body — /onboard-repo Norman + Cooper pass (sister discipline; runs against `bassclef init` too)
- `.claude/rules/we-dont-break-adopters.md` — every npm publish carries compat window per ADR-031
- Web research (WebFetch 2026-08-06): starter medium article on npm package dev best practices
- Web research (WebSearch 2026-08-06): npm trusted publishing docs, Evil Martians 2026 secure-release guide, jsmanifest modern npm package guide
- `lite-manifest.json` (repo root) — WU-4 build script reads this as source of truth per #1143 contract
- Live check: no existing bet doc for the npm launch shape; whereami L13 pre-queued the scope but "do not shape tonight — persist for pickup"
- Parent bet: none direct; parent_roadmap is the arc anchor
- Memory: `feedback-propose-mechanisms-with-rules-not-rules-alone`, `feedback-hooks-beat-methodology-for-substrate-quality`, `feedback-smoke-test-after-cure-pattern`

## npm best practices (grounded in web research)

Woven into WU steps. Documented here so operator scans one place.

**package.json shape (per WU-1 + WU-4):**
- `bin` field maps `bassclef` → compiled entry
- `files` array as whitelist (not `.npmignore` blacklist) — explicit control over shipped artifacts
- `exports` field with granular paths — controls consumer imports
- `main` (CJS) + `module` (ESM) + `types` (`.d.ts`) — dual module + TypeScript support
- `engines` pinned to node ≥ operator-declared minimum

**Publish pipeline (per WU-4):**
- Modern shift — no `prepublishOnly` script that auto-builds; explicit separate build step instead (per Evil Martians 2026 guide; publish scripts add hidden state)
- Publish compiled JS + `.d.ts`, never TypeScript source
- `--ignore-scripts` at publish for safety
- `--provenance` OR trusted publishing (GitHub Actions auto-generates provenance attestations; gets rid of token-based auth risk)
- Tier filter runs BEFORE publish — strips any file whose frontmatter carries `tier: upstream`
- Andon scan runs at publish — refuses to ship if operator-private terms appear (mirrors `scripts/release-to-bassclef.sh` step 4)

**Security (per WU-4 + WU-7):**
- Trusted publishers config on the npm side (docs.npmjs.com/trusted-publishers)
- 2FA required on publish account (YubiKey / passkey / TOTP dedicated app — NOT SMS)
- Adam Sharpe's PRs land before first tagged release — bash injection guard + `curl | bash` self-healing

**Versioning (per WU-5):**
- Start at 0.0.1 (already reserved per whereami L8 mention of #1110 bump policy)
- Semantic versioning discipline from launch
- Adopter changelog per ADR-031 grace-window rule
- 0.x → 1.0 cut when unscoped `bassclef` transfer lands OR when adopter cohort ≥ 25 (see we-don't-break-adopters threshold)

## Workunits

| WU | Problem + value | Produces | Consumes (from prior) | How builds on prior | Risk |
|---|---|---|---|---|---|
| **0** prep | Land bet scope + tickets + markers + /diagnose + /pre-mortem + /luminary consult. Value — no shortcuts land without diagnostic parent. | this bet doc + 5+ markers + /diagnose deep + /pre-mortem light 3 lenses × 3 risks + /luminary consult on Sam persona | session-start | baseline | 🟢 low |
| **1** bootstrap `sunj-labs/bassclef-cli` repo (#944) | Ship a repo with the shape adopters can trust. Value — new-repo scaffolding done once; every future WU builds on it. | new repo with README + LICENSE (Apache-2.0 per memory) + TypeScript + Vite build + files-array whitelist + package.json bin + exports + engines pinned | WU-0 markers + Cooper lens on README | Cooper README pass IS Sam's first-touch signal; must land before any code | 🟡 med |
| **2** `bassclef init` command (#945) | Adopters get a working repo in one command. Value — closes 4-command install gap. | `bassclef init` writes settings.json + kilo.json + substrate.config.md into adopter's project; idempotent on re-run; Tier 0 tests on fixture repos | WU-1 scaffold | Uses WU-1's files structure; declares its own /decompose per oo-ad-entry-point rule | 🟡 med |
| **3** `bassclef sync` command (#946) | Adopters upgrade in place when npm publishes. Value — closes the update-ceremony gap. | `bassclef sync` replaces `bassclef-sync.sh` for npm adopters; reads current package version; runs the equivalent of session-start hook | WU-1 + WU-2 | Reuses the vendored dispatcher pattern from ADR-050 | 🟡 med |
| **4** publish pipeline (#947 + #1055 + #1143) | Ship every future version cleanly. Value — publish is deterministic + safe + private-content-clean. | GitHub Actions publish workflow with — trusted publisher config + tier filter (strip `tier: upstream` files) + andon scan (refuse on operator-private terms) + `--ignore-scripts` + provenance attestation + reads lite-manifest.json per #1143 contract | WU-1 files array | Vernon anticorruption pattern per #1143 — pipeline reads manifest, not raw frontmatter; @pattern annotation required per pattern-annotation rule | 🟡 med |
| **5** semver + changelog methodology (#1110 + closes #3) | Adopters know what changes when they upgrade. Value — closes #3 (3+ weeks open) + honors ADR-031 compat window discipline. | `standards/npm-versioning-and-changelog.md` + release-notes template for @thebassclef/core + version bump policy doc + first tagged 0.0.2 release | WU-4 publish pipeline | Discipline document with Tier 0 tests on the version bump script | 🟢 low |
| **6** cold-adopter harness against npm path (#948) | Verify the ship works from Sam's chair. Value — new check class in cold-adopter harness Shape d covers npm install path. | new check class in `scripts/cold-adopter-harness-sync.sh` (from bassclef-upstream side) + Tier 0 tests on npm install fixture | WU-4 published package | Reuses Shape d framework from bet 27c WU-5; adds check class per bootstrap-pair-discipline | 🟢 low |
| **7** Adam Sharpe security PRs land (#949) | Security posture explicit before first ship. Value — bash injection guard + `curl \| bash` self-healing merged; documented in security posture doc. | Adam's PRs reviewed + merged OR explicitly deferred with rationale in changelog | WU-1 through WU-6 | Reviewer discipline per `.claude/rules/reviewer-dispatch.md`; Saltzer-Schroeder lens applied | 🟡 med |
| **8** Sam magic demo (#941 + #950) | Prove the promise. Value — Sam runs the two commands on a fresh machine and gets a working bassclef in 5 minutes; recorded as evidence for launch comms. | Sam demo recording (screencast) + timing evidence + Louis walkthrough for validation | WU-1 through WU-7 | Cooper persona lens IS the acceptance test; timing under 5 minutes is the falsifier | 🟡 med |
| **9** PR + merge + first tagged release | Land the launch. Value — 0.0.2 tagged on npm; whereami updated; sibling repos notified. | first tagged release published to npm + adopter changelog entry + whereami flip | WU-1 through WU-8 | Same release cascade pattern as bet 2026-08-05c WU-5+WU-6 | 🟡 med |

## Discipline touchpoints (baked into WU steps)

Per operator direction (2026-08-06a prep) — drive rigor with pragmatic /decompose + /pattern-review + /architect-review use.

**Per-WU:**
- **WU-1** — /decompose before bootstrap; identify boundary (npm CLI) / entity (bassclef binary + init/sync/publish commands) / control (dispatcher + tier filter) surfaces
- **WU-2 + WU-3** — /decompose per command; GRASP responsibility split
- **WU-4** — /pattern-review after publish pipeline lands; annotate Vernon anticorruption pattern per pattern-annotation rule
- **WU-6** — /pattern-review on cold-adopter harness check class; ensure it composes cleanly with Shape d
- **WU-7** — Saltzer-Schroeder complete-mediation review on security PRs; reviewer-dispatch marker required

**Per-arc:**
- **/architect-review** at end of bet (after WU-9) — full architectural review of the new bassclef-cli repo shape before v0.1.0 cut. Named lenses: cooper (Sam experience) + ousterhout (deep modules) + saltzer-schroeder (security posture) + linus-torvalds (adopter compatibility)

**Cross-cutting:**
- **/luminary shepherding** — every WU opens by re-consulting its named luminary lens; every WU closeout confirms the lens was applied (lead-lens sign-off marker per loop-discipline rule Step 5.5)
- **/pre-mortem light** at WU-0 — 3 lenses × 3 risks each; strongest concerns fold into WU table
- **/kiss dispatch** on every operator-facing artifact (README, `bassclef init` output, changelog entries, tag release notes) per plain-english-discipline rule

## Acceptance

- [ ] `sunj-labs/bassclef-cli` repo bootstrapped with TypeScript + Vite + files-array whitelist + Apache-2.0 license
- [ ] `bassclef init` writes settings.json + kilo.json + substrate.config.md on fresh repo; idempotent
- [ ] `bassclef sync` upgrades adopter repo when a newer package version publishes
- [ ] Publish pipeline strips `tier: upstream` files (verified in dry-run)
- [ ] Publish pipeline runs andon scan for operator-private terms (verified via test fixture)
- [ ] Publish uses trusted publisher config; provenance attestations auto-generated
- [ ] `standards/npm-versioning-and-changelog.md` merged; #3 closes
- [ ] Cold-adopter harness Shape d gains npm-install-path check class; passes on fresh fixture
- [ ] Adam Sharpe security PRs reviewed + landed OR deferred with rationale
- [ ] Sam demo — fresh machine → working bassclef in ≤ 5 minutes (timing recorded)
- [ ] First tagged 0.0.2 release published to npm with full loop-discipline PR body
- [ ] All Tier 0 tests GREEN
- [ ] /architect-review run at bet close; report merged

## Out of scope

- Kilo runtime port (Phase 2 — separate epic per #943 body when Phase 1 ships + adopts)
- Kilo plugin TypeScript layer
- MCP server (deferred per strategy doc L83-L88)
- Open model calibration suite
- Standard-tier + ultra-tier npm packages (extend #1143 contract when tiers ship siblings)
- Unscoped `bassclef` name transfer from silent maintainer (pursued in parallel; if it lands, rename before 1.0 cut)

## Refs

- Closes #3 (packaging + versioning methodology gap — via WU-5)
- Closes #943 Phase 1 acceptance (parent epic)
- Closes #944 through #950 as WUs land
- Closes #1055 andon filter (via WU-4)
- Closes #1110 bump policy (via WU-5)
- Refs #1143 (tier manifest contract — consumed by WU-4; contract discipline enforced but this bet does not build the cross-repo audit script)
- Refs #941 (Sam demo — WU-8 provides the evidence)
- Sister bet: `docs/iteration-bets/2026-08-06c-polish-vocab-legibility-louis.md` (Goal B POLISH runs in parallel from bassclef-upstream)
- Predecessor: `docs/iteration-bets/2026-08-05c-verify-hook-wired-canonical-manifest.md`
- Root strategy: `docs/operator-private/strategy/2026-07-26-kilo-port-npm-strategy.md`
- Canvas: `docs/canvases/2026-07-19-bassclef-lite.md`
- ADR-031 (we-don't-break-adopters), ADR-035 (substrate-as-system), ADR-043 (two-axis tier vocabulary)
- npm best-practices sources: [medium starter (operator-supplied)](https://medium.com/@ddylanlinn/npm-package-development-guide-build-publish-and-best-practices-674714b7aef1), [npm trusted publishing](https://docs.npmjs.com/trusted-publishers/), [Evil Martians 2026 secure-release](https://evilmartians.com/chronicles/the-secure-way-to-release-an-npm-package)

## Handoff notes to bassclef-cli session

This bet's execution runs in `sunj-labs/bassclef-cli` (new repo). Bootstrap sequence for that session:

1. Create the repo (via `gh repo create sunj-labs/bassclef-cli --private --description "Bassclef CLI — npm distribution for @thebassclef/core"`)
2. Copy this bet doc into the new repo at `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
3. Read the parent tickets (#943 body carries the 7-child map)
4. Read the npm best-practices sources cited above before WU-1
5. Session running in bassclef-cli reports back to bassclef-upstream at WU-9 (whereami flip owed here)

Token pressure stays local per operator direction — bassclef-cli session doesn't need bassclef-upstream's context except the bet doc + parent tickets.
