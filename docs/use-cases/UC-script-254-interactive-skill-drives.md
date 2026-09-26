---
uc_id: UC-script-254-interactive-skill-drives
tier: brief
authored_at: 2026-09-26T14:55Z
scope: docker-smoke harness — new interactive drives
level: sea-level (adopter-visible behavior via docker CI)
primary_actor: docker cold-adopter smoke framework
scope_class: adopter-facing script per .claude/rules/oo-ad-entry-point.md
---

# UC-254 (brief) — docker smoke drives interactive Claude sessions for multi-phase skills

## Preconditions

- Docker cold-adopter container built (harness/docker/Dockerfile.cold-adopter)
- cli @thebassclef/lite@<TARGET_VERSION> installable from npm
- CLAUDE_CODE_OAUTH_TOKEN present in container env (via GitHub Actions secret)
- expect binary installed in container (added in this scope)

## Success scenario

1. entry.sh Step 8 fires the interactive skill drives (after existing Step 7 headless drives complete)
2. For each of /onboard-repo, /riff, /launch:
   - Fresh scratch directory created; substrate installed via `bassclef init`
   - `expect` script spawns interactive `claude` session
   - Script feeds natural-language prompt asking for the skill
   - Script feeds any Phase-N prompts the skill emits
   - Script captures stdout + stderr to per-drive log
   - Script exits with drive-class exit code (10-19 range)
3. smoke-assert runs positive-artifact assertions per drive:
   - /onboard-repo: `.claude/settings.json` + `substrate.config.md` land
   - /launch: `docs/prototypes/` + `docs/specs/` populated
   - /riff: `docs/prototypes/<slug>/index.html` renders (advisory when cli#241 unblocked)
4. smoke-report emits interactive-class rows alongside existing headless rows
5. Container exits with worst-code across all drives (existing pattern extends)

## Extensions

- **1a. expect binary missing:** container build failed to install expect. → entry.sh Step 8 exits 20 (INFRA FAIL). Prior existing behavior for INFRA FAIL preserves.
- **2a. Fresh scratch has git init state mismatch:** /onboard-repo Phase 0 refuses on main-branch guard. → cure with first commit before drive fires; assertion catches Phase 0 refuse as expected class.
- **2b. Claude API rate limit hits mid-drive:** expect script times out at 180s. → drive exits 11 (CLAUDE_TIMEOUT). Report shows TIMEOUT class distinct from ASSERTION_FAIL.
- **2c. /riff MCP absent:** skill refuses talkatively per bassclef-upstream#1923. → assertion catches refuse pattern OR HTML presence; advisory PASS when SKIP_RIFF_INTERACTIVE=1.
- **3a. Assertion regex too tight:** skill amends output prose. → assert on filesystem artifact (per pre-mortem F1 fold), not prose.

## Postconditions

- Docker cold-adopter smoke run produces: existing 43 headless assertions + 3-6 new interactive assertions
- Exit code: worst class across all classes (existing pattern)
- Log artifact uploaded to GitHub Actions

## Refs

- Plan doc: `docs/next-session-plan-2026-09-27-interactive-skill-drives.md`
- Ticket: cli#254
- Risk ledger: `docs/risk-ledgers/2026-09-26-cli-254-interactive-drives.md`
- Blocking: cli#241 (/riff MCP sandbox gap)
- Sister UC: UC-cli-217 (drive-shape cure — headless V2)
