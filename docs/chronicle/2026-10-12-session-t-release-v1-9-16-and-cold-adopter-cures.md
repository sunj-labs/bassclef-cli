---
tier: lite
session_id: 2026-10-12-session-t
project: bassclef-cli
agent: personal
status: completed
tags: [release, v1.9.16, cold-adopter-smoke, test-infra, upstream-adr-proposal]
started_at: 2026-10-12T23:00:00+0000
ended_at: 2026-10-17T22:33:00+0000
duration_minutes: 180
turns: ~80
closes: ["cli#434", "cli#435", "cli#436"]
---

# Session: v1.9.16 release + cold-adopter test-infra cures

## Entry State

Picked up from Session S closeout. Peer `bassclef-upstream-54` had the v1.10.0 install-class defect in flight. v1.9.15 shipped the prior session via substrate v1.9.6.

## Work Done

- **v1.9.16 published to npm** via OIDC trusted publisher (bundles bassclef v1.10.1 scope). Release page: https://github.com/sunj-labs/bassclef-cli/releases/tag/v1.9.16. Sigstore provenance logIndex `3237215828`.
- **cli PR #433 merged** — v1.9.16 release. Bundles v1.10.0 scorer stack + v1.10.1 Phase 2.7 cure. SHA `2157766`.
- **cli PR #437 merged** — cold-adopter test infra cures. Closes cli#434 (nuke-and-install GH-repo collision warning), cli#435 (fixture identity → GitHub noreply shape), cli#436 (smoke-drive-onboard-repo creates `chore/bassclef-bootstrap` branch). SHA `6df608f`.
- **11 defect tickets filed** from cold-adopter smoke 2026-10-13 transcript — upstream#2230 (auto-save hardcoded paths), #2232 (git identity preflight), #2233 (login preflight), #2234 (value-first opt-in), #2235 (free-plan detection), #2236 (467k char ceiling), #2237 (temperance preamble), #2238 (repo-collision one-turn); cli#434 #435 #436.
- **ADR proposal filed** as upstream#2242 — preflight-first SKILL design + prevention-grade test discipline. Three layers: SKILL authoring, test sufficiency Criterion 13, fixture hygiene Shape e. Mechanical cascade: upstream skill-preflight hook + cli clean-room runner + driver assert flag + fixture pre-commit gate.
- **2 sister tickets filed** post-cure flow re-run — upstream#2249 (/onboard-repo single-shot cannot answer Phase 1 pick menu), upstream#2250 (/riff single-shot inline-vs-file gap). Both reference #2242 as parent.
- **Full test tier GREEN** post-cure: vitest 523/523, typecheck clean, install harness 11/11, nuke-and-install tier-0 14/14, CI 3/3 (test+typecheck 37s + ADR-059 10s + docker smoke 11m14s), flow driver cures verified (smoke-drive-skills PASS 170s; onboard-repo + riff gaps moved to next layer per ADR prediction).

## Decisions Made

- **No npm re-publish needed** post-cures. `package.json files` whitelist excludes `scripts/` + state markers; the test-infra cures do not change the shipped tarball shape at v1.9.16. Evidence: `jq '.files' package.json` returns `dist/*.js`, `dist/*.cjs`, `dist/*.d.ts`, `dist/lite/**`, `README.md`, `LICENSE`.
- **ADR filed as proposal, not decision**. Explicit note to upstream maintainers that cli surfaced the pattern from release validation; upstream owns substrate authoring + adoption cadence. Rationale: upstream has substrate-design context cli does not.
- **Three-layer cascade split**. Discipline (ADR + rules + skill-side hook) belongs upstream; adopter-tarball test harness (clean-room runner, driver flags, fixture gate, nightly CI) stays cli-local. Different surface, different owner.
- **cli#434 cure as preflight warning, not auto-delete.** The script already shipped `--delete-github` + `--purge-adopter` flags. Cure adds a WARN surface at script start when prior repos exist AND cleanup flag absent — gives operator informed choice vs silent accumulation.
- **cli#435 cure as GitHub noreply shape, not unseeded identity.** Inline git-env approach kept (fixture needs an identity for the one commit). Changed value from `smoke <smoke@local>` to `cold-adopter-test@users.noreply.github.com` — adopter-realistic shape, still distinguishable from real adopters.

## Open Threads

- **upstream#2242 ADR** awaits upstream review. Blocks Shape e rollout + Criterion 13 extension + skill-preflight-check hook. Cli-side clean-room runner + driver `--assert-first-turn-mentions` flag + fixture pre-commit gate wait on ADR direction.
- **upstream#2249 + #2250** (single-shot mode gaps) await ADR direction. Both surfaced by cli flow driver post-cure as new preflight layer.
- **upstream#2230** (auto-save hardcoded paths) awaits upstream. Cli adopters currently work around via `WATCHED_REPOS_OVERRIDE=`.
- **8 remaining upstream tickets** (#2232-#2238) await upstream prioritization.
- **cli#436 cure flipped onboard-repo fail from Phase 0 to Phase 1 interactive menu.** Known mode mismatch — driver can't answer stdin in `-p` single-shot. Not a cure regression; sister ticket #2249 tracks.

## Key Files Changed

- `package.json` + `src/index.ts` + `README.md` + `CHANGELOG.md` — v1.9.15 → v1.9.16 bump
- `dist/lite/**` — rebuilt via `prepublishOnly` sibling-copy against upstream HEAD at v1.10.1 (release_sha `90e9af92`, source_sha `9aebf658`)
- `scripts/smoke-drive-onboard-repo.sh` — added `git checkout -b chore/bassclef-bootstrap` after git init (cli#436)
- `scripts/nuke-and-fresh-install.sh` — fixture identity → noreply shape (cli#435) + prior-repo preflight warning (cli#434)
- `state/markers/temperance/chore-release-v1.9.16-substrate-v1.10.0.marker` + `chore-cold-adopter-test-infra-cures-cli-434-435-436.marker`

## Gate Evidence

| Gate | Fired | Evidence | Outcome |
|------|-------|----------|---------|
| Temperance | yes | `state/markers/temperance/chore-release-v1.9.16-substrate-v1.10.0.marker` + `state/markers/temperance/chore-cold-adopter-test-infra-cures-cli-434-435-436.marker` | PASS — both branches gated at scope-decision boundary |
| Diagnosis | yes | Install harness tarball-audit fail diagnosed (stale `dist/lite/state/` marker from hook heartbeat; known class cli#431) + flow driver fails diagnosed before writing cures | root cause → `dist/lite/` not cleared before vite build + driver vs skill contract mismatch |
| Tests | yes | 523 vitest + 11 install harness + 14 nuke-and-install tier 0 + 41 Tier 0 shell characterization + 1 live flow driver + 3 CI jobs | all pass |
| Verify | yes | PR #433 CI 3/3 GREEN + PR #437 CI 3/3 GREEN + install harness end-to-end against bundled v1.10.1 twice (pre + post publish) | PASS |

## Promotable Patterns

- **"Fixture identity seeds mask preflight gaps"** — the cold-adopter smoke caught `/onboard-repo` identity preflight gap only because the fixture happened to use a non-noreply shape; realistic seeds would have hidden the whole class. → part of ADR proposal upstream#2242 Layer 3 Shape e
- **"Cures that pass the test move the fail to the next layer"** — all 3 cli cures passed their original fail class and surfaced the NEXT preflight gap (Phase 1 interactive menu, /riff inline-vs-file). Preflight-first discipline is self-reinforcing. → upstream#2242 ADR evidence section already cites this.

## References

- cli PR #433 (SHA `2157766`), cli PR #437 (SHA `6df608f`)
- Upstream release v1.10.1: https://github.com/sunj-labs/bassclef/releases/tag/v1.10.1
- Cold-adopter smoke transcript 2026-10-13 (session `cold-adopter-1@<machine>`)
- ADR proposal upstream#2242 full draft: `/private/tmp/claude-501/.../scratchpad/ADR-preflight-first-skill-design-PROPOSAL.md`
- Prior session: `docs/chronicle/2026-10-11-session-s-option-c-shipped.md`
