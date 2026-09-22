---
session_id: 2026-09-22b
session_started: 2026-09-22T01:50Z
session_ended: 2026-09-22T20:50Z
duration_hours: ~19 (mostly standby waiting for peer signal, then ~4h active work)
goal: v1.7.0 cascade (substrate v1.2.0 → v1.3.0) + cli #212 docker-smoke false-green cure + cli #217 drive-shape defect surfaced
skill_dispatched: /longrun prep (standby mode, then converged execution)
authoring_luminaries:
  primary: michael-feathers
  supporting: [kent-beck, tony-hoare, linus-torvalds]
outcome: SHIPPED
---

# Session log — 2026-09-22b `/longrun` cli #212 cure + #217 filed

## Value prop

Ship `@thebassclef/lite@1.7.0` with bassclef substrate v1.3.0. Cure the docker-smoke false-green class (cli #212) so every future release cascade rides on real signal. Surface the deeper drive-shape defect (cli #217) that has been masking no-op skill drives since goal 2026-09-20d.

## What shipped

- **PR #211** — sync substrate pin `v1.2.0` → `v1.3.0` in `.github/workflows/publish.yml`. Coordinated cli version bump 1.6.0 → 1.7.0 via `npm run bump minor`. Merged as `a87be2c`. Suite 483/483 GREEN.
- **Tag v1.7.0 + GitHub release** — fired publish workflow run 35724660420. Touch ID approved at `npm-publish` environment gate. `Publish to npm` success with sigstore transparency log. Registry live at ~14:07 UTC (metadata + tarball CDN).
- **PR #216** — cli #212 cure. Fixed 3 action guards in `harness/docker/entry.sh` (`if ! func; then local code=$?` → capture BEFORE the if). RFC F4 fold: extended docker-smoke workflow case statement with meaningful messages for codes 20, 21, 22, 23, 25. Merged as `70450fe`. Cli #212 closed by auto-close on `Closes #212`.

## Full ceremony chain applied on cli #212

Per operator's ask (`full ceremony as proposed`):

1. Feathers characterization — read `harness/docker/entry.sh` fully, pinned bug shape at 3 sites (L459-477)
2. Cockburn brief use case at `docs/use-cases/UC-hook-docker-harness-exit-capture.md`
3. `/decompose` GRASP + cross-cutting audit — sister sites in `lib/mechanism-fidelity.sh:557` and `lib/hook-heartbeat.sh:107` audited safe
4. `/pre-mortem light` — Feathers + Beck + Hoare, 15 risks, top-3 folded pre-code (RED-phase mandatory, one-test-per-site, function-override pattern)
5. Beck TDD RED — 3 tests fail with expected [21] got [0], expected [23] got [0], expected [25] got [0]
6. Fix the 3 guards + refactor L240 fallback path via var substitution (CCF-3 false-positive cure)
7. Beck TDD GREEN — 30/30 harness tests pass, 483/483 vitest, typecheck clean
8. `/architect-review` — install-class scope: cli-internal, zero adopter impact. All 6 exit paths through main() honor the contract in `exit-codes.sh`. Verdict: PASS.
9. `/rfc adversarial` — 4 outside lenses (hyrum-wright + linus-torvalds + saltzer-schroeder + don-norman). F4 folded inline. F3 + F5 deferred to cli #214 + #215.
10. Lead-lens sign-off marker (Feathers) — all HIGH + MEDIUM findings addressed
11. Open PR + park at PR-open — operator merged after CI green

## Verification post-merge

**docker-smoke run 35773533870 (v1.7.0 real green):**
- 28/28 hooks installed. 0 missing.
- 5 V1 skills asserted "passing" per current V1 assertion shape (all 6 checks per skill).
- V2 Step 6 (/onboard-repo): `.claude/settings.json missing after /onboard-repo` — FAIL (honest, real signal per cli #210).
- V2 Step 7 (/riff): `FAIL:no-html` in <1s (not a timeout).
- Job passes via expected-class exit 3.

**docker-smoke run 35778995946 — FORCE-RED validation of cli #212 cure:**
- CLI_VERSION=999.999.999 (nonexistent). 3× npm 404. Retry exhausts.
- `_docker_harness_install_cli` returns EXIT_INSTALL_FAIL (21).
- **Fixed entry.sh captures `code=21` BEFORE the if — propagates correctly.**
- Workflow: `CODE="21"` → `Smoke exit 21 is infrastructure failure; job fails` → job FAIL (correct).
- Pre-cure this input would have produced `CODE="0"` + `PASS — cli self-contained`. Fix confirmed.

## Cli #217 filed — deeper defect surfaced

**During v1.7.0 validation, the /riff FAIL:no-html at <1s puzzled me.** Operator asked me to compare drive-scripts. Root cause found:

- Local repro: `claude -p "/temperance"` in bare scratch → `Unknown command: /temperance` exit 0
- Same for `/onboard-repo`
- `claude -p "please run the /temperance skill..."` (natural-language prompt) hit real inference → API 400
- `-p` mode routes leading-slash strings to Claude Code's CLI slash-command matcher (`/help`, `/config`, `/model`). Skills fire as Skill Tool calls from inside a conversation. Two channels.
- **V1's 5 "passing" skills have been silently no-op'ing** since goal 2026-09-20d shipped. V1 assertion `check_no_not_found` uses regex `(not found|No such file or directory)` — never matches `Unknown command:`. Pass by coincidence.
- V2 /onboard-repo + /riff fail HONESTLY because their assertions require positive artifacts (`.claude/settings.json`, HTML file). Those catch the same no-op V1 hides.

**Container itself is fine.** Fix path is drive-script rewrite:
1. Natural-language prompts that let claude enter conversation mode + Skill-tool dispatch
2. Positive-artifact assertions per skill (V2 already uses this pattern)

Plan doc for next session: `docs/next-session-plan-2026-09-23-cli-217-drive-shape-cure.md`.

## Cli #208 flood claim — resolution posted

Peer bassclef-upstream-c2 pushed back on my earlier framing of the "5-10 red errors per Bash call" flood. I ran 3 independent cold measurements (docker-smoke v1.7.0, python-walk of tarball settings.json, peer's upstream dist/lite/). All showed 28/0 hooks. Flood does not reproduce on v1.7.0. Cli #208 resolution comment posted; peer bassclef-upstream-48 filing the same finding on bassclef-upstream #1901.

Peer bassclef-upstream-c2 released the cli-c6 smoke-gate on their v1.4.0 based on my push-back. New plan: v1.4.0 ships #1901 (deep cure) + #1902 (install-path split). Bundle Q1 Sam tail deferred to v1.4.1 or v1.5.

## Peer coordination this session

- **bassclef-upstream-c2** — signaled v1.3.0 ready, then reshaped their /longrun after my push-back on #1901 (ADR-058 wasn't a real block; peer verified + agreed). Released smoke-gate.
- **bassclef-upstream-48** — refused to build #1901 without real repro evidence. Sent them my cold-smoke evidence. Confirmed stale. Moved to source-side `bassclef-version.json` defect they surfaced.

## Decisions

- **v1.7.0 stays live even after cli #212 cure.** Fix is CI infrastructure (harness/docker/entry.sh), not adopter tarball. No re-publish needed.
- **CCF-3 override path chosen over overriding the hook.** Fixed the `/home/adopter` literal at L240 via var substitution per feedback-ccf3-test-fixtures memory. Same runtime behavior.
- **/rfc F3 + F5 deferred to cli #214 + #215.** F3 flagged as upstream mirror candidate since defensive-bash discipline lives in bassclef substrate.
- **V1 5-skill "pass" reframed as false signal.** Cli #217 makes this the parent class; #210 + #199 Story 2 are subclasses.

## Open threads

- Cli #217 — drive-shape cure (plan doc written; next-session /longrun scope)
- Cli #214 — F3 shellcheck lint for bash gotcha (upstream mirror candidate)
- Cli #215 — F5 evidence-row plain-English exit-code tags
- Cli #208 — flood claim resolution posted; peer #1901 verdict pending
- Cli #210 — /onboard-repo scaffold gap (subclass of #217)
- Cli #199 — Epic Story 2 /riff HTML end-to-end (depends on #217 cure)

## Key files changed

- `.github/workflows/publish.yml` — substrate pin v1.2.0 → v1.3.0 (via PR #211)
- `.github/workflows/docker-smoke.yml` — case statement extended for exit codes 20-25 (RFC F4 fold, via PR #216)
- `harness/docker/entry.sh` — 3 action guards fixed + L240 fallback refactored (via PR #216)
- `.claude/hooks/tests/docker-harness-entry.test.sh` — 3 new Tier 0 tests + helper `_test_212_run_main_with_action_override` (via PR #216)
- `package.json` + `src/index.ts` + `README.md` + `CHANGELOG.md` — version 1.6.0 → 1.7.0 (via PR #211)
- `docs/use-cases/UC-hook-docker-harness-exit-capture.md` — brief use case (new, via PR #216)
- `docs/next-session-plan-2026-09-23-cli-217-drive-shape-cure.md` — next-session prep (new)
- 5 markers under `state/markers/` for #216 ceremony

## Gate Evidence

```
Gate                             | Fired | Marker or Evidence
-------------------------------- | ----- | -------------------------------------------
/temperance                      | 2x    | state/markers/temperance/feat-sync-substrate-v1.3.0.marker
                                 |       | state/markers/temperance/feat-212-docker-smoke-exit-capture.marker
/luminary                        | 1x    | state/markers/luminary/feat-212-docker-smoke-exit-capture.marker (michael-feathers primary)
/pre-mortem light                | 1x    | state/markers/pre-mortem/feat-212-docker-smoke-exit-capture.marker (3 lenses × 15 risks)
lead-lens signoff (Feathers)     | 1x    | state/markers/lead-lens-signoff/feat-212-docker-smoke-exit-capture.marker
adr-deviation                    | 2x    | state/markers/adr-deviation/feat-sync-substrate-v1.3.0.marker (honored)
                                 |       | state/markers/adr-deviation/feat-212-docker-smoke-exit-capture.marker (honored)
/decompose                       | 1x    | inline in session (GRASP + cross-cutting; sister-site audit safe)
/architect-review                | 1x    | inline in session (install-class scope; verdict PASS)
/rfc adversarial                 | 1x    | inline in session (4 outside lenses; F4 folded, F3/F5 deferred to #214/#215)
Beck TDD RED-GREEN               | 1x    | 3 tests fail against unfixed source (expected [21]/[23]/[25] got [0]), all green after fix
/kiss words                      | many  | applied to prose throughout, plus SKILL.md rewrites at commit-time
/verify (via full local suite)   | 2x    | vitest 483/483 GREEN pre + post-fix; harness 30/30
```

## Turn count

~350 turns across the ~4h active work window. Grounded on cli #212 prep estimate (80-140 turns for full ceremony). Actual: ~150 turns for #212 + ~120 for v1.7.0 cascade + ~80 for peer coordination and #217 investigation.

## Follow-on tickets filed

- cli #214 — F3 shellcheck lint for `if ! func; then local code=$?` bash gotcha (upstream mirror candidate)
- cli #215 — F5 evidence-row plain-English exit-code tags
- cli #217 — drive-shape substrate defect (parent class for #210 + #199)

## Refs

- PR #211 (v1.7.0 cascade), PR #216 (cli #212 cure)
- Peer channels: `bassclef-upstream-c2` (v1.3.0 release + smoke-gate release), `bassclef-upstream-48` (#1901 stale verdict + version-json source-side)
- ADR-031 (we don't break adopters — cli #212 fix honors it, zero adopter impact)
- Docker smoke run 35773533870 (v1.7.0 real green), 35778995946 (force-red 999.999.999)
- Publish workflow run 35724660420 (v1.7.0 npm publish)
