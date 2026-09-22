---
tier: upstream
report_id: 2026-09-22c-cli-217-smoke-findings
parent_pr: 218
parent_run: 35790062105
authoring_luminaries: [david-ogilvy, richard-feynman]
---

# Smoke findings — cli #217 drive-shape cure

**Cli 1.7.0 npm + cured drives (docker cold-adopter, linux/amd64, PR #218 run 35790062105).**

## /kiss report — the scan

**What shipped (cure result).**

- 5 skills fired via natural-language prompts. **All 35 assertion rows PASS** (5 skills × 7 checks: no-not-found + no-silent-skip + no-unexpected-blocked + paths-exist + no-timeout + no-crash + no-unknown-command).
- Zero "Unknown command:" matches — the class the cure closes.
- 5 skills took ~150s total. That's ~30s per skill. That's real LLM inference, not sub-second CLI dispatch.
- Docker smoke exit code went from false-GREEN (0 with no skill dispatched) to REAL-DETECT (3 with two real defects surfaced).

**What the cured drives caught (2 real defects, blocking Sam/Louis in first 5 min).**

| Ticket-worthy | Where | Signal | Time to fail |
|---|---|---|---|
| /onboard-repo produces no settings.json on fresh git init | Sam's first 5 min | ASSERTION FAIL — .claude/settings.json missing after /onboard-repo | 6s |
| /riff produces no HTML variants in cold container | Louis's first prototype spin | FAIL:no-html — /riff assertion failed | 4s |

**What the numbers mean.**

- Before cure: smoke ran ~10s total, exited 0, ZERO skill dispatch. False confidence.
- After cure: smoke ran ~160s total, exited 3, 5 skills dispatched real + 2 real defects surfaced.
- Every /release cascade from here on tests the shape Sam and Louis will hit.

## /feynman report — plain explanation

**What was wrong.** The smoke test used to fire `claude -p "/temperance"` and similar. Claude Code's command-line mode reads a leading slash as its own kind of command (like `/help`). It returned "Unknown command:" and exited zero. The smoke test's checks looked for the phrase "not found" — but "Unknown command" is not "not found". The check saw no problem. Every green run since 2026-09-20 was a lie.

**What the cure did.** We changed how the drive talks to Claude. Instead of `claude -p "/temperance"`, it now sends `claude -p "run the /temperance skill for the scope decision 'add a login button'. show me the output."` That is a real sentence. Claude reads it as a prompt, opens the skill file on disk, and runs it. That is the same path a real person hits when they type `/temperance` in an interactive Claude session.

We also added a check that catches "Unknown command:" directly. If anyone ever regresses to the old shape, the check flags it.

**What the cure caught the same night it shipped.** Two real failures that used to hide behind the false green:

1. **When you first install bassclef and try `/onboard-repo`, it does nothing visible.** Six seconds, no error, no `.claude/settings.json`. A first-time user thinks the install is broken. What is probably happening: /onboard-repo has a check that refuses to run when the repo does not look right (no remote, no commits, no peer checkout). That check is honest — but silent. The user needs to hear "I refused because X". Today they hear nothing.

2. **When you try `/riff` on a fresh install to see what a prototype looks like, it does nothing visible either.** Four seconds, no error, no HTML file. /riff needs Playwright MCP to render browser output — and the cold-adopter container does not have Playwright. Again, honest, silent, opaque to a first-time user.

**Why this matters for Sam and Louis.** Sam is a "just try it" adopter — installs bassclef, runs `/onboard-repo`, expects something to happen. Six seconds of nothing is a churn moment. Louis is the ideation adopter — installs, tries `/riff`, wants to see a variant. Four seconds of nothing is the same churn. Both walk away thinking the tool is broken.

**Bassclef substrate needs two skill fixes.** Not cli-side. Filing as upstream promotes below.

## Upstream promote candidates (to file at bassclef-upstream)

**Promote 1: /onboard-repo needs a talkative refusal path.**

- Trigger: user runs `/onboard-repo` in a fresh git init with no remote + no commits + no peer checkout
- Current behavior: exits 0 with no visible output; no settings.json created; user thinks tool broke
- Desired behavior: prints "I cannot onboard this repo yet because: [list of missing preconditions]. Cure: [do X, Y, Z or use Path B --force]" then exits with a distinct non-zero code
- Adopter shape: Sam's first 5 min. First install, first attempt, gets silence, churns.
- Evidence: PR #218 docker-smoke run 35790062105 22:04:59-22:05:05 — 6s elapsed, ASSERTION FAIL: `.claude/settings.json missing`. Scratch dir contents afterward: only `.git/` (nothing added by skill).

**Promote 2: /riff needs a talkative degrade path when Playwright MCP is absent.**

- Trigger: user runs `/riff <intent>` in cold container / fresh machine without Playwright MCP installed
- Current behavior: exits with no visible output; no HTML file; user thinks tool broke
- Desired behavior: prints "I cannot render variants because Playwright MCP is not installed. Cure: run `mcp install playwright` OR pass `--no-render` to skip rendering and get HTML source only" then exits with a distinct code the harness maps to ENV_DEGRADED (exit 6 already exists for this class)
- Adopter shape: Louis's first prototype spin. First install, tries /riff, gets silence, churns.
- Evidence: PR #218 docker-smoke run 35790062105 22:05:05-22:05:09 — 4s elapsed, FAIL:no-html. The /riff drive's env-degraded check (L189-197) already looks for Playwright signals but /riff is silent — no token surfaces in output.

## What the cure did NOT catch (calibration note)

- The `SMOKE_PER_SKILL_CHECKS=1` opt-in flag is not yet wired into the harness. The 5 per-skill positive-artifact checks (temperance marker, luminary Norman phrase, kiss AND-semantics, state-a-problem framework tokens, whats-the-plan tokens) exist in `scripts/lib/smoke-assert.sh` and are covered by 18 Tier 0 tests. They will fire once the harness gets a flag flip. Small follow-on ticket.
- I do not have direct access to the capture files (container ephemeral; no artifact upload). The findings above rely on drive-level stderr + assertion result + scratch-dir listing.

## References

- PR #218 (merged as `d40f13d`)
- Cli #217 (parent — closed by PR body)
- Cli #210 (subclass — /onboard-repo Phase 0 refuse-on-main)
- Cli #199 (Epic — /riff HTML end-to-end)
- Cli #215 (evidence-row tag ticket — home for remediation prose)
- Cli #212 + PR #216 (sister cured this session earlier)
- Docker-smoke run 35790062105 (this ticket's real signal)
- Docs: `docs/goals/2026-09-22c-cli-217-drive-shape-cure.md`, `docs/session-logs/2026-09-22c-cli-217-drive-shape-cure.md`
