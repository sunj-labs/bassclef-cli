---
tier: operator-private
rfc_id: RFC-0001
authored: 2026-09-20
session_id: 2026-09-20b
subject: Docker cold-adopter harness (cli#162)
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
disposition: Revised A (accept scope; cure HIGH findings inline before Step 2)
council:
  - hyrum-wright
  - frederick-brooks
  - john-ousterhout
  - jerome-saltzer-and-michael-schroeder
  - donald-norman
outside_set_from:
  - alistair-cockburn
  - kent-beck
  - andreas-zeller
  - michael-feathers
  - michael-nygard
  - linus-torvalds
  - jane-cleland-huang
---

# RFC-0001 — Docker cold-adopter harness outside council review

## Sources read

- `docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md` — the subject goal doc
- `docs/risk-ledgers/2026-09-20b-docker-cold-adopter-harness-pre-mortem-1.md` — pre-mortem light findings
- `bassclef-cli#162` body L1-95 — original ticket
- `.claude/skills/rfc/SKILL.md` — dispatch procedure
- Session paper — `docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md`

## Council

Outside authoring set. All five lenses are absent from the goal doc's `authoring_luminaries`.

| Lens | Role |
|---|---|
| Hyrum Wright | Observable-behavior binding; runbook commands become the contract adopters depend on |
| Frederick Brooks | Second-system effect; scope creep beyond V1+V2 walking skeleton |
| John Ousterhout | Deep modules; narrow interface for entry.sh |
| Saltzer + Schroeder | Defense in depth; least privilege on container capabilities + env passthrough |
| Donald Norman | User model; runbook error messages when Docker missing or auth misconfigured |

## Findings

### HIGH-R1 (Hyrum Wright) — runbook commands become the contract

- **Claim:** the runbook's `docker run` command with env-var passthrough becomes an observable contract. Adopters copy-paste it. Any change breaks copy-paste flows.
- **Evidence:** Hyrum's Law — with a sufficient number of users, all observable behaviors become depended on. Runbook is the highest-visibility surface.
- **Why it fails:** if we rename `ANTHROPIC_API_KEY` to a bassclef-scoped var later, or change the container name, or the invocation shape, every adopter script breaks silently.
- **Cure:** freeze the runbook invocation contract at V1. Document the CLI stability commitment in the runbook front matter — "This command shape is stable across cli minor versions per ADR-031."

### HIGH-R2 (Frederick Brooks) — V2 scope creep

- **Claim:** V2 skill drive adds ANTHROPIC_API_KEY passthrough plus 5-skill dispatch plus timeout handling plus captured output plus assertions. That is second-system syndrome — piling capability on a young skeleton.
- **Evidence:** cli#162 body L38-52 already scopes V2 tightly. But per the goal doc Steps 8-9, V2 is landing in the same session as V1 — the walking skeleton has no time to prove itself.
- **Why it fails:** V1 defects that would surface at day-2 usage get papered over by V2 noise.
- **Cure:** enforce Step 7 (V1 live run green on structure) as a hard gate before Step 8 (V2 additions). Commit V1 to main before V2 branch code writes. Two smaller PRs, not one large.

### HIGH-R3 (Ousterhout) — entry.sh must stay a thin orchestrator

- **Claim:** entry.sh sits in the container as the top-level dispatcher. Ousterhout: modules should be deep — narrow interface, deep behavior.
- **Evidence:** cli#162 body L37-52 shows entry.sh calling 6+ existing scripts. If entry.sh grows any assertion logic of its own, the module becomes shallow.
- **Why it fails:** logic in entry.sh becomes untestable at the container boundary. Tier 0 tests only cover path handling, not assertion correctness. Assertion logic must stay in the scripts under `cli/scripts/`.
- **Cure:** entry.sh does exactly 4 things — set env, install lite, invoke smoke-drive, exit with propagated code. Every other action lives in the existing bash scripts. Ousterhout narrow interface + deep modules preserved.

### MEDIUM-R4 (Saltzer + Schroeder) — least privilege on container

- **Claim:** container defaults run as root. ANTHROPIC_API_KEY sits in root's env. If container is compromised (unlikely but possible via malicious npm dep), the key leaks.
- **Cure:** add `USER adopter` in the Dockerfile after apt-get install. Adopter runs as unprivileged user with only the env-vars needed for the smoke.

### MEDIUM-R5 (Saltzer + Schroeder) — defense-in-depth on network

- **Claim:** container has full network access. It only needs npm registry + Anthropic API endpoint.
- **Cure:** V3 tightens network via `--network` flag or explicit egress rules. Deferred to V3 per cli#162 L57. Note in runbook for adopter awareness.

### MEDIUM-R6 (Norman) — runbook error messages

- **Claim:** when Docker is not installed OR OrbStack is not running OR ANTHROPIC_API_KEY is missing, the failure modes must map to human-readable remediation.
- **Cure:** runbook front matter runs three preflight checks — `docker info`, `printenv ANTHROPIC_API_KEY`, `command -v docker` — and prints specific remediation per failure. Norman's feedback-loop discipline applied.

### LOW-R7 (Brooks) — conceptual integrity of harness naming

- **Claim:** `harness/docker/` is a new top-level path. bassclef already has `scripts/` for cli-side scripts.
- **Cure:** decision needed at Step 2 (decomposition). Two options — `harness/docker/` as new top-level OR `scripts/docker/` as extension. Recommend `harness/docker/` because the harness is a distinct concern; scripts are cli operations, harness is testing infrastructure.

### LOW-R8 (Norman) — mental model for falsification-test

- **Claim:** adopters running the harness against 1.2.1 will see it exit 3 and may interpret it as harness broken, not detection working.
- **Cure:** entry.sh prints a big banner at start naming the version under test and the expected outcome. Runbook front matter explains the two-state design (red on 1.2.1, green on 1.2.2).

## Findings summary

- HIGH: 3 (R1, R2, R3)
- MEDIUM: 3 (R4, R5, R6)
- LOW: 2 (R7, R8)

## Disposition — Revised A

Accept the scope. Cure all 3 HIGH findings inline before Step 2 code writes. MEDIUM findings fold into Step 4-5 authoring. LOW findings fold into Step 4-5 authoring.

### Inline cures folded into goal doc

- **R1 fold (Step 5 runbook)** — runbook front matter carries CLI stability commitment
- **R2 fold (Step 7 → Step 8 gate)** — V1 must commit and land on main before V2 code writes; ordering enforced in commit sequence
- **R3 fold (Step 4 entry.sh)** — entry.sh is a 4-action orchestrator; assertion logic stays in `cli/scripts/`

## Follow-on plan

None. Zero scope deferrals. All findings fold into current session's steps.

## Refs

- `.claude/skills/rfc/SKILL.md` — dispatch source
- `.claude/luminaries/hyrum-wright.md` — anchor
- `.claude/luminaries/frederick-brooks.md` — anchor
- `.claude/luminaries/john-ousterhout.md` — anchor
- `.claude/luminaries/jerome-saltzer-and-michael-schroeder.md` — anchor
- `.claude/luminaries/donald-norman.md` — anchor
- cli#162 — parent ticket
