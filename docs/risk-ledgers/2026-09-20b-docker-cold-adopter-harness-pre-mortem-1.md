---
tier: operator-private
authored: 2026-09-20
session_id: 2026-09-20b-docker-harness
mode: pre-mortem-light
lenses:
  - michael-nygard
  - linus-torvalds
  - alistair-cockburn
handoff: requirements-to-design
parent_goal: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
target_scope: cli#162 V1 walking skeleton + V2 skill drive
---

# Pre-mortem light — Docker cold-adopter harness (Handoff 1)

Klein workshop shape. Three lenses. 5-8 risks per lens. 30 min budget.

Precondition for /pre-mortem light per `.claude/skills/pre-mortem/SKILL.md` light mode.
Marker at `state/markers/pre-mortem/feat-162-docker-cold-adopter-harness.marker` cites this ledger.

## Scope under review

Docker container starts from a clean Debian slim base image. Container installs `@thebassclef/lite@1.2.1` from npm, runs `bassclef init`, runs the smoke-assert-settings-hooks assertion, then runs the 5-skill drive pipeline. Runs locally on macOS via OrbStack and in GitHub Actions on `ubuntu-latest`. Ships as V1 (walking skeleton) + V2 (skill drive) this session per cli#162.

## Anchor lenses

- **Michael Nygard** — stability patterns. What breaks under load, cold start, network drift, arch mismatch, base-image drift?
- **Linus Torvalds** — adopter contract. Does Docker as a new smoke surface break adopters without Docker? Does the runbook assume Docker unfairly?
- **Alistair Cockburn** — walking skeleton discipline. Is the V1 slice truly end-to-end? Which piece missing produces a half-skeleton that stalls?

## Nygard risks — stability patterns

| ID | Risk | Severity | Mitigation | Step folded |
|---|---|---|---|---|
| N1 | Base image `debian:slim` tag drifts; behavior changes silently between runs | 🟡 med | Pin to `debian:12-slim` explicit tag + SHA digest; fail-loud on tag mismatch | Step 3 Dockerfile |
| N2 | Arch mismatch — Apple Silicon local (arm64) vs GHA ubuntu-latest (amd64) produces green-here-red-there | 🔴 high | Add `--platform=linux/amd64` to Dockerfile `FROM` and `docker build`; Rosetta emulation covers local run | Step 3 Dockerfile |
| N3 | npm registry timeout during `npm install -g @thebassclef/lite@1.2.1` | 🟡 med | Retry with backoff (3 attempts × 15s) in entry.sh; log the failure loudly | Step 3 entry.sh |
| N4 | CI cold cache — `docker build` on GHA has no layer cache; adds ~2-3 min per PR run | 🟢 low | Layer the Dockerfile — apt-get + node install FIRST, package install LAST; adds cache hits per PR | Step 3 Dockerfile |
| N5 | Docker registry pull rate-limit on unauth Debian pulls (~100 pulls per 6h per IP) | 🟢 low | Note limit in runbook; V3 can pin to GHCR mirror if hit | Step 4 runbook |
| N6 | Container-network flakiness — DNS resolution to npm registry fails intermittently | 🟢 low | Retry logic (N3) covers this; extend log to note DNS-vs-timeout distinction | Step 3 entry.sh |
| N7 | Container filesystem writes leak between runs (state pollution across `docker run` calls) | 🟡 med | Always `docker run --rm` so container removes on exit; V1 entry.sh does not persist state | Step 3 entry.sh |
| N8 | Docker daemon not running on operator machine (OrbStack stopped, or systemd disabled) | 🟢 low | Runbook front matter checks `docker info` and prints remediation before harness fires | Step 4 runbook |

## Linus risks — adopter contract

| ID | Risk | Severity | Mitigation | Step folded |
|---|---|---|---|---|
| L1 | Runbook assumes Docker is installed; adopters without Docker cannot run the smoke locally | 🟡 med | Runbook opens with "Docker required" note + install pointer to OrbStack + Docker Desktop docs | Step 4 runbook |
| L2 | Docker-only smoke replaces the macOS-only smoke and breaks adopters on Windows-native (no WSL) | 🟢 low | Windows adopters out of scope per cli#162 body L91; Docker via Docker Desktop for Windows covers WSL2 adopters | Step 4 runbook |
| L3 | ANTHROPIC_API_KEY passthrough requires `docker run -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY` — adopters may forget the flag and get silent-skip on skill drive | 🟡 med | entry.sh checks env at start; fails loudly with "ANTHROPIC_API_KEY not set — cannot drive skills" | Step 3 entry.sh |
| L4 | Adopter cli 1.2.1 installs succeed but the harness runs against a stale local build not the published npm package | 🟢 low | entry.sh always installs from npm registry, not from local; note in runbook | Step 3 entry.sh |
| L5 | Docker Desktop license terms shift; commercial adopters may not use it — OrbStack is macOS-only | 🟢 low | Note both options in runbook; Podman as third fallback tracked for follow-on | Step 4 runbook |
| L6 | Cli 1.2.2 (post-upstream-cures) release cadence not matched with harness readiness — harness expects 1.2.2 to exit 0, ships before upstream cures land | 🔴 high | Ship harness pinned to 1.2.1 first; falsification-test success on 1.2.1 confirms the harness works; 1.2.2 becomes the next assertion | Step 5 live run |
| L7 | Adopters using pnpm or yarn globally see `npm install -g` fail; harness assumes npm | 🟢 low | Note in runbook; npm is bassclef's stated package manager per cli README | Step 4 runbook |

## Cockburn risks — walking skeleton discipline

| ID | Risk | Severity | Mitigation | Step folded |
|---|---|---|---|---|
| C1 | V1 ships Dockerfile + entry.sh but no `.github/workflows/docker-smoke.yml` — CI cannot run it; only operator runs local | 🔴 high | Workflow file lands in Step 4 alongside runbook; both required for walking-skeleton complete | Step 4 |
| C2 | V1 ships workflow but no runbook — operator cannot invoke locally, only CI runs | 🟡 med | Runbook lands in Step 4; single-command invocation named | Step 4 runbook |
| C3 | V1 ships all pieces but no Tier 0 test on entry.sh — path bugs surface only at first live run | 🔴 high | Tier 0 test at `.claude/hooks/tests/docker-harness-entry.test.sh` lands in Step 3 alongside entry.sh; Beck RED first | Step 3 tests |
| C4 | V2 skill drive added before V1 assertion runs green — V2 hides V1 breakage under skill-timeout noise | 🟡 med | V1 exits green on Step 5 BEFORE V2 lands; enforce ordering in commit sequence | Step 5-6 sequencing |
| C5 | Runbook cites `docker run` command but omits ANTHROPIC_API_KEY env-var pass — operator reads runbook, runs command, skills silently skip | 🟡 med | Runbook shows FULL command including env-var flag; add smoke-test-of-the-runbook (operator reads + runs verbatim) | Step 4 runbook |
| C6 | Skill drive in V2 depends on upstream cures for #1824 (skills hardcode operator paths) — V2 exits red on 1.2.1 until cures land | 🟢 low | Expected per Zeller falsification test — V2 red on 1.2.1 confirms detection; cures land in 1.2.2; document in runbook | Step 5 live run |
| C7 | Entry.sh does too much and becomes untestable — should be a thin orchestrator calling existing scripts | 🟡 med | Ousterhout deep module discipline — entry.sh only orchestrates; assertion logic lives in existing scripts under cli/scripts/ | Step 3 entry.sh |
| C8 | Container time-drift skews `date` output in assertions; some captures compare timestamps | 🟢 low | Container inherits host clock via Docker default; not a problem for OrbStack + GHA | (no action) |

## Strongest concerns to fold before Step 3 code

Three HIGH-severity risks. All fold per the step-mapping column above.

1. **N2 (arch mismatch)** — pin `--platform=linux/amd64` in Dockerfile FROM + build command
2. **L6 (release cadence)** — harness ships pinned to 1.2.1; expects red on 1.2.1 for the wired-but-missing hook class; 1.2.2 is next step
3. **C1 + C3 (skeleton half-completion)** — workflow file + Tier 0 test are Step 3-4 required deliverables, not optional

## Total risks named

- Nygard: 8 (2 med, 6 low — plus 1 high overlapping with Cockburn C-set)
- Linus: 7 (1 high, 3 med, 3 low)
- Cockburn: 8 (2 high, 4 med, 2 low)
- Grand total: 23 risks; 3 HIGH; 8 MEDIUM; 12 LOW

## Refs

- `.claude/skills/pre-mortem/SKILL.md` — light mode
- `.claude/luminaries/michael-nygard.md` — stability patterns
- `.claude/luminaries/linus-torvalds.md` — adopter contract
- `.claude/luminaries/alistair-cockburn.md` — walking skeleton
- cli#162 — Docker harness ticket
- `docs/operator-private/2026-09-20-traceability-schema-ai-council-research.md` — session research paper (sister artifact)
