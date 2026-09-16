---
tier: project
id: ADR-057
title: Lite catalog destination-path invariant — pin the routing table per Hyrum + Peirce
status: proposed
date: 2026-09-16
proposed_via: PR (this branch) cli 1.1.0 lite catalog
supersedes: null
superseded_by: null
extends: [ADR-055, ADR-056, ADR-002]
references:
  - {type: adr, id: ADR-056, anchor: bassclef-upstream — self-containment invariant on source graph}
  - {type: adr, id: ADR-055, anchor: bassclef-upstream — wiring manifest as init contract}
  - {type: adr, id: ADR-002, anchor: init safety contract preserved}
  - {type: ticket, id: sunj-labs/bassclef-cli#90, anchor: filing ticket for regression}
  - {type: goal, id: 2026-09-16-cli-1.1.0-lite-catalog, anchor: ship vehicle}
  - {type: file, id: /Users/sanjay2025/src/sunj-labs/bassclef-upstream/lite-manifest.json, anchor: canonical catalog v1.6.1}
  - {type: file, id: /Users/sanjay2025/src/sunj-labs/bassclef-upstream/docs/canvases/2026-07-19-bassclef-lite.md, anchor: lite scope definition}
authoring_luminaries:
  primary:
    - hyrum-wright
    - charles-sanders-peirce
  supporting:
    - linus-torvalds
    - alistair-cockburn
---

# ADR-057 — Lite catalog destination-path invariant

## Sources read

- ADR-056 D1 self-containment invariant + D2 sync-optional clause
- ADR-055 wiring manifest as init contract
- Canvas 2026-07-19-bassclef-lite — Sam persona + magic demo path
- Goal doc 2026-09-14b (parent) + 2026-09-16-cli-1.1.0-lite-catalog (this ship)
- lite-manifest.json v1.6.1 at bassclef-upstream — 292 entries with `type` + `path` fields
- Cli #90 filing ticket
- Risk ledger rows HW (Hyrum) + Pc (Peirce) + Ck (Cockburn)

## Context

Cli 1.0.0 shipped a MAJOR bump that dropped the pre-1.0 substrate/ bundle and its `copyEntry` walker. The replacement wired hooks only. Skills, rules, agents, luminaries — 40 + 63 + 32 + 4 lite-tagged files — never reached adopters via npm through 1.0.0-1.0.4. bassclef-upstream ADR-056 committed to self-containment on the source graph (hooks + libs) but did not extend to the tagged content catalog.

Two readings of the pre-1.0.0 to 1.0.4 gap fit the evidence (Peirce — abductive reasoning):

**Reading A: regression.** Pre-1.0 cli shipped 149 files via `copyEntry` reading `lite-manifest.json`. Phase 3 MAJOR bump at commit `1c7d919` retired the walker along with substrate/. Only hooks were re-wired. Skills / rules / agents / luminaries fell off silently.

**Reading B: by design.** Sync-clone at SessionStart was the intended delivery path for the tagged catalog. The bundle-only mode shipped hooks; sync brought the rest. ADR-056 D2 says sync is optional; the bundle-only lite tier was expected to have hooks only.

Both readings are consistent with the shipped code. The canvas 2026-07-19-bassclef-lite settles it: lite ships ~15 skills, ~15 rules, ~20 standards, CLAUDE-lite.md under 30k tokens (canvas Stage 1 "Thesis"). Reading A is correct. Reading B fits ADR-056 D2 wording but ignores the canvas that predates and drives ADR-056.

Once shipped at 1.1.0, every destination path becomes an adopter contract (Hyrum's Law). Moving one file at 1.1.1 = breaking. The routing must be pinned explicitly so future readers cannot mistake the intent.

## Decision

**D1. Destination-path routing table.** The walker routes each manifest entry to a canonical destination path per this table. Entries land at the target-path prefix + entry.path.

| Entry `type` | Target scope | Target-path prefix | Rationale |
|---|---|---|---|
| `hook` (declared in settings.json) | per scope-router `classify()` from command prefix | `$HOME/.claude/hooks/` OR `$CLAUDE_PROJECT_DIR/.claude/hooks/` | 1.0.4 dual-scope logic; unchanged |
| `hook` (undeclared helper or fragment) | dual (user + project) | both scopes | 1.0.4 dual-scope logic; unchanged |
| `skill` | project | `$CLAUDE_PROJECT_DIR/.claude/skills/` | Skills discovered by Claude Code's local scan; project scope only |
| `rule` | project | `$CLAUDE_PROJECT_DIR/.claude/rules/` | Rules load via `additionalDirectories`; project scope only |
| `agent` | project | `$CLAUDE_PROJECT_DIR/.claude/agents/` | Agents dispatched by name from local registry |
| `luminary` | project | `$CLAUDE_PROJECT_DIR/.claude/luminaries/` | Referenced by `@luminary <slug>` in skill bodies |
| `lib` | project | `$CLAUDE_PROJECT_DIR/lib/` | Hooks source via `$CLAUDE_PROJECT_DIR/lib/*.sh` per ADR-056 D3 |
| `adr` | project | `$CLAUDE_PROJECT_DIR/architecture/decisions/` | Read reference for adopter |
| `standard` | project | `$CLAUDE_PROJECT_DIR/standards/` | Read reference for adopter; hooks may cite |
| `template` | project | `$CLAUDE_PROJECT_DIR/templates/` | General templates (chronicle, deferred-action, persona, pr-faq, etc.) |
| `presence-template` | project | `$CLAUDE_PROJECT_DIR/presence/install/` | Install-helper templates for downstream tools |
| `script` | project | `$CLAUDE_PROJECT_DIR/scripts/` | Adopter-runnable helper scripts |
| `root-doc` | project | `$CLAUDE_PROJECT_DIR/` (repo root) | Repo-root docs — CLAUDE-lite.md, README.md, AGENTS.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md |

**D2. Immutability of shipped paths.** Every destination-path row shipped at 1.1.0 is immutable in 1.1.x. Moving a shipped path is a MAJOR bump (2.0.0). Adding a new type at 1.2.0+ adds a new row; never modifies an existing one.

**D3. Unknown type refusal.** If the manifest ships an entry with `type` not in the D1 table, the walker refuses to route (exit 5, structured error). Prepublish preflight blocks the bundle before publish so unknown types never reach an adopter.

**D4. Scope routing rationale (against Reading B).** Skills, rules, agents, luminaries all land at project scope. Rationale: adopter repo is the natural home for content the adopter reads, greps, and vendorizes. User scope (`~/.claude/`) is reserved for cross-project state (hooks that fire across every repo). Reading B would have skills land at user scope via sync; we settle on project scope per canvas 2026-07-19 § "Sam's magic demo path" which cites `docs/curation/2026-07-17b-lite-curation-notes.md` transitive counts (14 core lite pick under the repo).

**D5. Extension via ADR amendment, not silent add.** New entry types added at 1.2.0+ ship with an ADR-057 amendment that pins the new row. Silent add to the walker without ADR amendment = review blocker.

## Consequences

**What becomes easier.**
- Adopters can pipe `bassclef init` output through `grep` for count parsing; contract stable across 1.1.x
- Reviewers verify walker code against the D1 table verbatim
- Preflight harness (Step 7 substrate cure) checks manifest ↔ bundle parity against a fixed target-path set

**What becomes harder.**
- Moving a shipped path requires a MAJOR bump; deliberate friction is the point (Hyrum)
- Every new type at 1.2.0+ triggers ADR-057 amendment (light process cost)

**What this blocks.**
- Silent path shifts at 1.1.x (D2 immutability)
- Silent addition of new types via walker code without ADR trail (D5)
- Reading-B ambiguity — future readers cannot mistake bundle-only mode as "always hooks-only by design" (D4 explicit rationale)

## Status

Proposed at PR opening (this branch feat/cli-1.1.0-lite-catalog). Accepts at merge time when architect-review #3 clears.
