# Distribution Pre-flight Check

> **Proposed for bassclef-upstream.** This file drafts a new
> `.claude/rules/distribution-preflight-check.md` at
> `sunj-labs/bassclef-upstream`. Operator merges at upstream on their
> own cadence.

Every distribution tool's publish action fires the six-check pre-flight per `standards/distribution-preflight.md`. Rule is the methodology layer. Hook `distribution-preflight-check.sh` is the mechanical layer. Both required.

## When this rule fires

Any PreToolUse Bash matching:

- `npm publish` (bassclef-cli today; future npm tools)
- `gh workflow run publish*.yml` (workflow-dispatch of a publish workflow)
- `gh release create` (future gh-release-only tools)
- Future distribution actions declared per-tool in the tool's config file

The hook reads `.bassclef-distribution.json` in the tool's repo root to determine tool-specific paths and configuration.

## What the rule requires

Six checks pass before publish (per `standards/distribution-preflight.md`):

1. **Catalog present** — manifest exists, parses, matches schema major
2. **Manifest → bundle parity** — every catalog entry lands in the bundle
3. **Bundle → manifest parity** — no stowaway files in the bundle
4. **Prior-tag sanity** — file count within tolerance vs prior tag (WARN, not BLOCK, at V1)
5. **Walking skeleton smoke** — cold install exercises real capability
6. **ADR alignment** — no drift between ADR and manifest

Fail on any Check 1-3, 5, or 6 = publish blocks. Check 4 warns.

## Anti-patterns

**Ship without configuring `.bassclef-distribution.json`.** Rule fires; hook sees no config; block with cure ("author `.bassclef-distribution.json` in tool root").

**Publish workflow that skips the pre-flight step.** Rule requires the hook wired at PreToolUse Bash matching the publish action. Workflow must invoke through a shell action Claude Code observes; direct GitHub API calls bypass the hook (edge case; note for future coverage).

**Manifest ships new type without ADR amendment.** Check 6 fails. Cure: amend ADR OR remove the type from manifest.

**Category in ADR with zero manifest entries.** Check 6 fails. Cure: amend ADR OR add entries.

## Override

`SKIP_DISTRIBUTION_PREFLIGHT=1 <command>` — logged via trace-helper. Emergency rescue only. Never for routine work.

## Composes with

- `standards/distribution-preflight.md` — the standard this rule enforces
- `.claude/rules/we-dont-break-adopters.md` — parent (ADR-031)
- `.claude/rules/cold-adopter-harness-discipline.md` — sister at PR gate
- `.claude/rules/bootstrap-pair-discipline.md` — hook + rule + tests + settings ship together
- `.claude/rules/blocked-items.md` — BLOCK protocol the hook fires
- `.claude/rules/testing-tier-config.md` — Tier 0 strict TDD on `distribution-preflight-check.sh` + tests

## Anchor luminaries

- @luminary alistair-cockburn — walking skeleton (Check 5)
- @luminary michael-nygard — fail-loud on distribution boundary
- @luminary linus-torvalds — adopter contract; publish gate is the last defense
- @luminary hyrum-wright — every observable path becomes contract (Check 3 stowaway guard)
- @luminary jerome-saltzer-and-michael-schroeder — complete mediation (every publish routed through the check)

## Refs

- Filed by cli 1.1.0 goal 2026-09-16-cli-1.1.0-lite-catalog
- Fills gap surfaced by cli#90 regression (4 releases shipped hooks-only)
- Extends ADR-056 self-containment invariant from build-time (source graph) to publish-time (adopter surface)
