---
tier: lite
slug: 2026-09-21c-smoke-drive-riff
scope: Epic #199 Story 1 — smoke-drive-riff.sh + harness Step 7 wire
date: 2026-09-21
status: draft
authoring_luminaries:
  primary: alistair-cockburn
  supporting: [andreas-zeller, michael-feathers]
references:
  - docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md
  - scripts/smoke-drive-onboard-repo.sh
  - harness/docker/entry.sh
---

# Spec — smoke-drive-riff

## Sources read

- `~/.claude/skills/riff/SKILL.md` — full body, notably L77 (variant paths) + L96-100 (Playwright MUST + BLOCK) + L38-40 (lite tier degrade)
- `scripts/smoke-drive-onboard-repo.sh` L1-142 — template
- `harness/docker/entry.sh` L374-391 — V2 Step 6 wire-in shape
- Epic #199 body Story 1 — acceptance list
- `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md` — top-5 folded

## What I'm NOT reading (with reason)

- `~/.claude/skills/interpret-input/SKILL.md` — `/riff` composes it but Story 1 asserts on `/riff`'s output surface, not sub-skill internals
- Playwright MCP installation docs — Playwright-in-Docker is out of scope for this Story; the smoke drive handles absence gracefully

## Problem

V2 Docker cold-adopter harness drives `/onboard-repo` + 5 utility skills. It does NOT exercise `/riff` — the first step of the primary user journey. A cold adopter's first UI work goes through `/riff`. Right now we cannot tell if a tarball ships a `/riff` that dispatches cleanly, authors HTML variants, and reports variants back to the operator.

## Goal

Ship `scripts/smoke-drive-riff.sh` modeled on `scripts/smoke-drive-onboard-repo.sh`. Drive fires `/riff` in a fresh scratch dir inside the Docker container. Asserts HTML mock variants land under `docs/prototypes/`. Handles Playwright MCP absence with a distinct exit code so the harness reports environment-degraded vs skill-regression separately.

## Acceptance

- [ ] `scripts/smoke-drive-riff.sh` shipped modeled on `smoke-drive-onboard-repo.sh` shape (envs, teardown trap, perl-alarm timeout, capture file, precondition checks, assert observable output)
- [ ] Test intent: `/riff riff a marketing landing hero` (single-line canned intent; short + deterministic)
- [ ] Timeout: default 300s via `RIFF_TIMEOUT_SEC` (per pre-mortem R5)
- [ ] Fresh scratch dir at `$HOME/riff-test` (or `$RIFF_SCRATCH`); fresh `git init` + git config
- [ ] Assert: at least ONE `*.html` file lands under `$SCRATCH_DIR/docs/prototypes/*-riff-*/` AND file is >100 bytes AND contains `<h2>` (per `/riff` SKILL L77 shape)
- [ ] Distinct exit codes: 0 pass, 3 assertion fail, 5 timeout, 6 environment-degraded (Playwright/MCP absent), 127 claude missing, 1 other setup
- [ ] Environment-degraded detection: grep capture for `Playwright|playwright|MCP|screenshot` when exit is non-zero AND HTML files absent
- [ ] Tier 0 test at `tests/harness/smoke-drive-riff.test.ts` — characterization test spawning the drive against fixture directories
- [ ] Wire-in at `harness/docker/entry.sh` V2 Step 7 (after Step 6 onboard-repo)
- [ ] Dockerfile picks up the new script (already copies `scripts/` wholesale)

## Design notes

**Model on onboard-repo template.** Same env override pattern (CLAUDE_BIN, RIFF_TIMEOUT_SEC, RIFF_SCRATCH, OUT_ROOT). Same perl-alarm timeout wrapper. Same teardown trap. Same capture-file shape. Deviate only where `/riff`'s output surface differs.

**Test intent shape.** Single-line canned string: `"riff a marketing landing hero"`. Short, deterministic, no environment dependency. Matches `/riff` SKILL L28 example use-case.

**Assertion — observable + falsifiable (Zeller).** Not "any HTML file anywhere." Match: `find "$SCRATCH_DIR/docs/prototypes" -name '*.html' -type f -size +100c`. Then grep the first match for `<h2>` (per `/riff` SKILL L77 mock body shape). Zero matches OR content-check fail → exit 3.

**Environment-degraded path (R3).** If `/riff` exits non-zero AND no HTML files land, grep the capture for `Playwright|MCP|screenshot` (case-insensitive). If matched → exit 6. If not matched → exit 3 (real skill regression).

**No PR-open assertion.** `/riff` SKILL L96 says "MUST produce a PR." Inside the smoke drive's fresh scratch dir there is no remote — pushing to origin fails. Accept that. The drive asserts on the local file surface only. PR-open is a Story 6 (verification) concern.

**Characterization test.** `tests/harness/smoke-drive-riff.test.ts` spawns the drive against 3 fixture dirs (mocking `claude` binary):
1. Happy fixture — mock claude writes HTML variants → drive exits 0
2. Playwright-block fixture — mock claude writes stderr "Playwright MCP not enabled" → drive exits 6
3. Assertion-fail fixture — mock claude exits 0 but writes no HTML → drive exits 3

## Non-goals

- No Playwright MCP install in Docker. Separate concern; Story 6 (verification) can propose it as a follow-on if the cost-benefit works.
- No PR-open assertion. Local surface only.
- No skill-content assertions (variant count, luminary tag values). Story 6 (verification) validates against a known-good tarball; skill-content checks belong there.
- No integration with `/launch` output. Story 2 wires that.

## Out of scope this session

- Stories 2 (launch) + 3 (build) of Epic #199
- Story 4 (shared library `scripts/lib/smoke-drive-common.sh`) — Story 1 duplicates onboard-repo shape; refactor after all 3 drives land
- Ticket #193 (Node/ubuntu-latest bump)

## Refs

- Epic #199 body — this spec covers Story 1
- Risk ledger `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md`
- `~/.claude/skills/riff/SKILL.md` — the skill under test
- `scripts/smoke-drive-onboard-repo.sh` — template pattern
- @luminary alistair-cockburn — walking skeleton lead
- @luminary andreas-zeller — hypothesis test
- @luminary michael-feathers — characterization
