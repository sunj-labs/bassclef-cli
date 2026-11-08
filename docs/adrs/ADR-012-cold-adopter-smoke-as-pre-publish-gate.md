---
id: ADR-012
title: Cold-adopter smoke as pre-publish gate
status: proposed
date: 2026-10-18
supersedes: []
superseded_by: []
luminaries:
  primary: [linus-torvalds, michael-feathers]
  supporting: [jerome-saltzer-and-michael-schroeder, michael-nygard, david-parnas]
---

# ADR-012 — Cold-adopter smoke as pre-publish gate

## Context

`@thebassclef/lite@1.9.17` tagged on 2026-10-18 (commit `4af3b11`) tripped the andon scan at publish because the v1.11.0 substrate bundle carried `you@example.com` in the bundled `/onboard-repo` SKILL body — content bassclef v1.11.0 added via upstream#2232 that our andon term list hadn't accommodated. Publish failed. v1.9.18 shipped the cure (PR #442) + the bump (PR #443), then published cleanly.

Minutes after v1.9.18 published, cold-adopter smoke on a real macOS profile with a realistic gh PAT surfaced 6 adopter-break bugs:

- cli#444 — `scripts/nuke-and-fresh-install.sh --purge-adopter` silently proceeds past `delete_repo` scope failures.
- upstream#2253 — `pre-push-shellcheck.sh` BLOCKs the first push with 72 findings in files bassclef just copied in.
- upstream#2254 — `SKIP_PRE_PUSH_SHELLCHECK=1` env prefix doesn't reach the hook from Claude Code harness.
- upstream#2255 — `/onboard-repo` OAuth preflight uses GNU `timeout(1)` missing on macOS.
- upstream#2256 — Concise opt-in prompt lacks what-it-does + how-to-disable preamble.
- upstream#2257 — auto-save installer assumes `~/src/bassclef` sibling checkout exists.

Our pre-publish CI tier (vitest + typecheck + install harness + ADR-059 + docker-smoke 11m53s) passed GREEN on PR #443. None of the 6 bugs caught. Each slipped a specific CI-vs-adopter environment gap:

| Axis | CI | Cold adopter |
|---|---|---|
| OS | ubuntu-24.04 | macOS (BSD coreutils) |
| gh PAT scope | full `SMOKE_GH_TOKEN` | adopter-shaped (no `delete_repo`) |
| Shell scope | plain bash | Claude Code tool-call subprocess |
| Filesystem | dev-repo + sibling checkouts present | fresh HOME, no siblings |
| Prose assertion | behavior-shape only | human UX judgment |

The gap is systemic: CI tests the maintainer's environment, not the adopter's.

`.claude/rules/sibling-smoke-after-substrate-change.md` already names the discipline. It operates methodology-only — "operator should run sibling smoke after a substrate change." Nothing mechanical blocks publish when the operator forgets. v1.9.17 → v1.9.18 proved the methodology layer alone is insufficient.

## Decision

Make cold-adopter smoke a mechanical pre-publish gate. Publish workflow refuses to proceed unless:

1. A marker exists at `state/markers/cold-adopter-smoke/<RESOLVED_TAG>.marker` at the tag ref being published.
2. The marker's body reports `result: PASS`.
3. The marker's timestamp is within a configurable window of the tag's commit date (default 24h — tight enough to catch drift; loose enough for human operator turnaround).

Three cold-adopter environments to cover (each may be a separate marker; publish gate accepts any one but encourages all three):

- **a. macOS cold adopter** — fresh profile, BSD coreutils only, Homebrew not required.
- **b. Scoped-PAT variant** — gh PAT shaped like a real adopter (no `delete_repo`, no `admin:repo_hook`, no `workflow`).
- **c. Linux cold adopter** — fresh Debian/Ubuntu container with no dev checkout under `~/src/`.

CI automation (sister ticket cli#447) implements the marker-write path. Operator can also write the marker by hand after running smoke manually.

The gate stays separate from the andon scan. Andon catches content-shape leaks at build time. Cold-adopter smoke catches environment-shape bugs at runtime. Both load-bearing.

## Status

Proposed. Will accept when sister implementation ships at cli#447 (mechanical gate in `.github/workflows/publish.yml`) + cli#445 (macos-latest smoke workflow) + cli#446 (scoped-PAT variant) land.

## Consequences

### What becomes easier

- Adopters stop being our smoke environment. Bugs surface pre-publish, not post-install.
- Peer `bassclef-upstream-c7`'s standing offer to coordinate cold-adopter fixture runs becomes a formal input to the publish gate, not an ad-hoc favor.
- Audit trail — every published version carries smoke-evidence under `state/markers/cold-adopter-smoke/`. Future regressions grep against the markers to find when behavior last worked.

### What becomes harder

- Publish turnaround extends by cold-smoke runtime (currently ~15 min for the three environments combined, if parallelized).
- Operator must either run smoke manually before publish OR dispatch the CI automation + wait.
- "Hotfix" releases need an escape hatch — proposed: `SKIP_COLD_ADOPTER_SMOKE=1` operator-only env in the publish workflow, logged to the release notes with rationale.

### What this enables

- `.claude/rules/sibling-smoke-after-substrate-change.md` becomes mechanical. The rule's current V1 methodology-only shape graduates to V2 enforced.
- Pre-publish catches the entire cli-vs-adopter environment gap class, not just the two specific instances this release surfaced.
- Peer-coord workflow with other substrate-stacks (future bassclef-cli siblings) can bake cold-smoke into their own release gates using the same marker pattern.

### What this blocks

- Publishes without cold-smoke evidence. By design.
- "Fast ship" tempo during active substrate-change cycles. Each cli release carrying new bassclef substrate waits on cold-smoke confirmation.

## References

- `.claude/rules/sibling-smoke-after-substrate-change.md` — V1 methodology layer this ADR mechanizes.
- `.claude/rules/mechanism-fidelity.md` — pattern this ADR follows (rule + mechanism must ship paired).
- `scripts/nuke-and-fresh-install.sh` — the cold-adopter smoke primitive this ADR gates on.
- `.github/workflows/docker-smoke.yml` — existing Linux-container smoke that would extend to carry the marker write.
- Sister implementation tickets: cli#445 (macos-latest workflow), cli#446 (scoped-PAT variant), cli#447 (publish gate).
- Related defects this gate would have caught: cli#444, upstream#2253, upstream#2254, upstream#2255, upstream#2256, upstream#2257.
- ADR-004 (publish pipeline safety contract) — this ADR adds a new ordered-steps check 10 to that pipeline.
- ADR-031 (we-don't-break-adopters) — this ADR operationalizes the discipline at the publish boundary.
- ADR-035 (substrate-as-system) — this ADR extends the system boundary to include adopter-environment realism.

## Luminary pins

- **Linus Torvalds** — "we don't break adopters." Publish without cold-smoke evidence is publishing without checking whether we broke adopters. The gate is the operational form of the rule.
- **Michael Feathers** — characterization tests at the adopter boundary. Cold-smoke runs are the characterization test for "what adopters actually get."
- **Saltzer & Schroeder** — complete mediation. Every pre-publish check should run against every planned publish; the cold-smoke gate closes a mediation gap.
- **Michael Nygard** — stability pattern. The mechanical gate is the circuit-breaker between a passing CI and a failing adopter install.
- **David Parnas** — information hiding. Publish workflow doesn't need to know what cold-smoke does; it checks the marker. Smoke environment can evolve under the marker contract.
