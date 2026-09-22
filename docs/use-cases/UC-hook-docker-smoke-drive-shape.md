---
tier: upstream
uc_id: UC-hook-docker-smoke-drive-shape
title: Docker-smoke skill drives dispatch skills honestly
tier_form: brief (Cockburn — script extension per .claude/rules/oo-ad-entry-point.md matrix)
scope: bassclef-cli docker-smoke harness
primary_actor: docker-smoke harness (SmokeCoordinator control)
authoring_luminaries:
  primary: michael-feathers
  supporting: [kent-beck, alan-cooper]
related:
  - cli #217 (parent)
  - cli #210 (subclass)
  - cli #212 (sister false-green class, cured)
  - docs/next-session-plan-2026-09-23-cli-217-drive-shape-cure.md
---

# UC — Docker-smoke skill drives dispatch skills honestly

## Trigger

Release cascade fires `docker-smoke` workflow against a published `@thebassclef/lite` version. Cold-adopter container installs the tarball, runs `bassclef init`, then drives skills to prove they dispatch.

## Preconditions

- Container has `claude` binary on PATH (Claude Code CLI)
- Container has valid `ANTHROPIC_API_KEY` OR `CLAUDE_CODE_OAUTH_TOKEN` in env
- Bassclef substrate installed via `bassclef init` at `/adopter/test`
- Working dir has `.claude/skills/temperance/SKILL.md` and 4 sibling skills

## Main flow

1. Coordinator fires `scripts/smoke-drive-skills.sh` — drives 5 skills
2. For each skill in list, drive constructs a **natural-language prompt** naming the skill (e.g., `run the /temperance skill against this repo and show the output`)
3. Drive fires `claude -p "<natural-language prompt>"` with a per-skill timeout
4. Claude Code routes the natural-language string to the LLM. LLM reads the bassclef skill body from disk and dispatches the Skill tool
5. Skill produces its declared side-effect (marker file, HTML output, artifact) and prints output to stdout
6. Drive captures stdout+stderr to `docs/smoke-captures/<date>/skills/<skill-slug>.out`
7. Drive checks each capture against **positive-artifact assertions** per skill (marker exists, output contains expected phrase)
8. Drive exits 0 when all 5 skills fired + all positive artifacts present. Non-zero when any skill produced no artifact.

## Postconditions

- `docs/smoke-captures/<date>/skills/*.out` — 5 capture files carrying real skill output (not "Unknown command")
- `state/markers/temperance/*.marker` — 1 marker per `/temperance` fire
- Assertion suite reports honest signal: PASS only when the skill actually ran; FAIL when it did not

## Extensions

- **3a. `claude -p "/slashname"` returns "Unknown command"** (regression to leading-slash dispatch) — new `check_no_unknown_command` in `scripts/lib/smoke-assert.sh` catches; drive exits 3 with `FAIL:unknown-command`
- **3b. Skill dispatches but produces no artifact** — per-skill positive-artifact assertion fires; drive exits 3 with `FAIL:no-artifact:<skill-slug>`
- **3c. Skill exceeds timeout** — existing `check_no_timeout` handles; drive exits 5
- **5a. Skill dispatches but throws mid-run** — existing `check_no_crash` handles; drive exits with skill's own exit code

## Cure sequencing

1. Replace `-p "/skillname"` shape with `-p "<natural-language prompt naming /skillname>"` in all 3 drives
2. Add `check_no_unknown_command` to `scripts/lib/smoke-assert.sh` — catches the class regardless of drive
3. Add 5 per-skill positive-artifact assertions for smoke-drive-skills.sh (marker or output-content check)
4. Wire the new assertions into `scripts/smoke-assert-skills.sh`

## Adopter shape mapping

Real adopters open interactive Claude Code, type `/temperance`, and the Skill tool dispatches. Docker `-p` mode does not touch that path. Natural-language prompts route through the LLM, which then dispatches the Skill tool the same way an interactive user's typing does — closer to real adopter shape.

## Ceremony tier

Brief (Cockburn) — this UC EDITS existing scripts, does not ship new hooks or new libs. Per `.claude/rules/oo-ad-entry-point.md` matrix: existing-code extension = brief use case + `/decompose` entry-point check.

## Refs

- Cli #217 body — full trace of the invocation pattern + local repro
- `scripts/smoke-drive-skills.sh:130` — the wrong-shape invocation
- `scripts/smoke-drive-riff.sh:170` — same shape (assertion is positive)
- `scripts/smoke-drive-onboard-repo.sh:113` — same shape (assertion is positive)
- `scripts/lib/smoke-assert.sh:34-46` — `check_no_not_found` grep does not match "Unknown command"
- Local repro `/tmp/onboard-out/onboard-repo.out` — the empirical "Unknown command" trace
