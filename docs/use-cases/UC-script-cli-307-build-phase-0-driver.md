---
ticket: cli#307
ceremony: brief (Cockburn — adopter-facing driver per `.claude/rules/oo-ad-entry-point.md`)
primary_luminary: alistair-cockburn
supporting:
  - michael-feathers
  - linus-torvalds
upstream_cure: SHA 09beb249 at `.claude/skills/build/SKILL.md` + `.claude/hooks/tests/build-skill-phase-0-step-n-scan.test.sh`
---

# UC-script-cli-307 — /build Phase 0 safety floor on Step-N headings

## Primary actor

Author running `/build` Phase 0 on a spec whose acceptance headings use `### Step-N` (ADR-040 vocabulary) and whose step bodies touch floor paths like `src/lib/auth/`.

## Goal

The adopter sees `/build` refuse at Phase 0 with the floor-path signal. Pre-cure (upstream before SHA 09beb249), Phase 0 scanned only `### WU-` headings; a Step-N spec read 0 acceptance lines and the floor silently passed. Post-cure, Phase 0 matches `### (Step|WU)-` and the floor fires on both heading shapes.

## Preconditions

- Spec with `### Step-N` or `### WU-N` acceptance headings.
- At least one step edits a path matching the floor list (`src/lib/auth/`, `prisma/schema.prisma`, etc.).
- Adopter runs `/build` Phase 0 on that spec.

## Main success scenario

1. Phase 0 awk reads acceptance block.
2. Awk matches `/^### (Step|WU)-/{in_wu=1; next}` — both heading shapes trip the scan.
3. Scanner enumerates acceptance lines + grep floor paths.
4. Floor path detected: Phase 0 refuses, exit 3, log names the file + line.
5. No floor path: Phase 0 passes.

## Extensions

- 2a. Spec uses `### Step-1` only: pre-cure read 0 lines; post-cure reads all lines. Driver pre-cure fixture catches this gap.
- 2b. Spec uses `### WU-1` only: pre-cure already matched; post-cure still matches (regression check — WU-N must survive).
- 3a. Multiple floor paths in one acceptance line: Phase 0 catches first match, refuses, exit 3.

## Postconditions

- Trace file shows floor-path hit count that matches acceptance block.
- Phase 0 exit code is 3 when any floor path listed; 0 when none.
- Adopter sees the file + line in log.

## Why this is brief ceremony

Per `.claude/rules/oo-ad-entry-point.md` — adopter-facing driver. Upstream owns the cure; cli ships the trace characterization. No new interface, no new lib code.

## Pattern

Characterization test (Feathers). The driver pins adopter-visible BEHAVIOR; upstream Tier 0 pins the awk REGEX. Together they close the mechanism-fidelity contract per `.claude/rules/mechanism-fidelity.md`.
