# Distribution Pre-flight — Standard

> **Proposed for bassclef-upstream.** This file drafts a new
> `standards/distribution-preflight.md` at `sunj-labs/bassclef-upstream`.
> Operator merges at upstream on their own cadence. Cli 1.1.0 references
> this by name; wiring lands in cli 1.1.1+ once upstream ships.

## Sources read

- cli 1.0.0-1.0.4 regression trace: git commit `1c7d919` dropped `copyEntry`; skills / rules / agents / luminaries fell off the tarball for 4 releases
- cli#90 filing ticket
- ADR-056 D1 self-containment invariant (source graph scope)
- cli's ADR-057 D1 destination-path invariant (adopter contract scope)
- Cockburn walking skeleton — end-to-end capability demonstration
- Nygard — fail-loud discipline on distribution boundaries

## Why this exists

Every cli distribution tool ships a tarball that adopters install. Between the manifest that declares what should ship and the tarball that adopters actually get, drift can accumulate silently. cli 1.0.0-1.0.4 shipped hooks-only for 4 releases despite the lite tier promising skills / rules / agents / luminaries. No pre-flight check caught the gap.

This standard names six checks that every distribution build passes before publish. Any check fails → build blocks. Adopters never install a tarball that lies about what it contains.

## When this standard applies

Any bassclef tool that publishes a tarball or package to an external registry. bassclef-cli publishes to npm. Future tools may publish to PyPI, cargo, or gh releases. The standard applies to every distribution boundary.

## The six checks

Each check fails loud. Each check runs before the publish action. Each check has a specific stderr message naming the cure.

### Check 1 — Canonical catalog present

Every distribution tool declares its canonical catalog file. bassclef-cli's catalog is `lite-manifest.json` at bassclef-upstream. The catalog file must exist at the expected path, parse as valid JSON, and pass a schema-major version check.

**Fails when.** Manifest missing, unparseable, schema major differs from tool's expected major.
**Stderr shape.** Names the expected path + schema major + cure ("Reinstall upstream" or "Upgrade tool").

### Check 2 — Manifest to bundle parity

Every entry declared in the catalog must resolve to a file in the built bundle at the declared path.

**Fails when.** Manifest entry references a path that has no corresponding file in the bundle after build.
**Stderr shape.** Names the missing entry + expected path + count of missing files.

### Check 3 — Bundle to manifest parity

Every file in the built bundle must trace to a manifest entry, an allowlisted template, or a declared build artifact.

**Fails when.** Bundle has a file that doesn't match any manifest entry AND isn't on the allowlist.
**Stderr shape.** Names the stowaway file + which allowlist to add it to if intentional.

### Check 4 — Prior-tag baseline sanity

The built bundle file count is within tolerance of the prior published tag's file count.

**Fails when.** File count drops by more than 20% or rises by more than 400% vs prior tag.
**Stderr shape.** Names both counts + the tolerance band + the ADR that must document the intentional shift.

**Note.** This check is advisory (WARN, not BLOCK) at V1. Large shifts still ship, but the operator sees the delta in publish output.

### Check 5 — Walking skeleton smoke gate

A scripted cold install of the tarball in a scratch profile exercises real capability. Not just "no crash." Actual functional check.

**Fails when.** Cold install can't dispatch a skill OR can't load a rule OR can't find an agent OR can't resolve a luminary reference — any of the four fails.
**Stderr shape.** Names which capability failed + how the operator reproduces + which ADR the capability is promised in.

**Note.** Runs in publish-workflow (not local prepublish) because cold-install requires a clean profile. Local prepublish check is Checks 1-4.

### Check 6 — ADR alignment

The ADR that governs the tier ships every category the manifest ships. Every category in the ADR has entries in the manifest. Zero silent drift between ADR and manifest.

**Fails when.** ADR names a category not in the manifest OR manifest ships a category not in the ADR.
**Stderr shape.** Names the missing category + which side (ADR or manifest) has the gap + which ADR amendment path opens the fix.

## Configuration

Each distribution tool ships a `.bassclef-distribution.json` in its repo root:

```json
{
  "tool": "bassclef-cli",
  "catalog_path": "lite-manifest.json",
  "catalog_at": "sibling-upstream",
  "adr_ref": "ADR-057",
  "prior_tag_compare_base": "local",
  "smoke_command": "scripts/cold-adopter-smoke.sh",
  "expected_manifest_schema_major": 1
}
```

## Mechanical layer

Rule `.claude/rules/distribution-preflight-check.md` fires on PreToolUse Bash matching `npm publish` or `gh workflow run publish*.yml`. Hook `distribution-preflight-check.sh` runs the six checks per config file. Emits BLOCK on any Check 1-3 fail; WARN on Check 4; BLOCK on Check 5-6. Structured stderr per check.

## Override

`SKIP_DISTRIBUTION_PREFLIGHT=1` — emergency rescue only. Logged via trace-helper. Never for routine work.

## Composes with

- `.claude/rules/we-dont-break-adopters.md` — parent discipline (ADR-031)
- `.claude/rules/cold-adopter-harness-discipline.md` — sister discipline at PR gate; this one fires at publish gate
- `.claude/rules/bootstrap-pair-discipline.md` — hook + rule + tests + settings wire ship together
- ADR-056 lite-bundle-self-containment-invariant
- ADR-057 (cli) lite-catalog-destination-path-invariant
- @luminary alistair-cockburn — walking skeleton (Check 5)
- @luminary michael-nygard — fail-loud (all checks)
- @luminary linus-torvalds — adopter contract
- @luminary hyrum-wright — every observable path becomes contract (Check 3)

## Retirement condition

Retires when bassclef ships zero distribution tools. Until then, every new tool inherits the standard.
