---
tier: operator-private
authored: 2026-09-20
authored_by: kingofrock + claude-opus-4-7
session_id: 2026-09-20b-longrun-prep-traceability-research
target_upstream_ticket: sunj-labs/bassclef-upstream#1182
sister_upstream_ticket: sunj-labs/bassclef-upstream#1590
parent_cli_ticket: sunj-labs/bassclef-cli#162
authoring_luminaries:
  primary: jane-cleland-huang
  supporting:
    - andrew-ng
    - andrej-karpathy
    - chip-huyen
    - eric-evans
    - hunt-thomas
    - alistair-cockburn
---

# Traceability schema — AI-council research + property-graph proposal

## Problem

The Phase 1 traceability draft on umbrella #1182 uses a flat-frontmatter shape. Rows carry `parent_requirement`, `derives_from`, `verifies`, `refines`, and a code-annotation rule marks source files. That shape works for greenfield first-execution mode. It does not model brownfield ongoing evolution, does not survive AI-driven link discovery, and duplicates the existing evidence primitive that bandleader already subscribes to.

## Value prop

Extend the Phase 1 draft with a property-graph shape, a snapshot block for change detection, and a schema-refinement audit trail. Align with `state/events/evidence-status-changed.jsonl` so bandleader subscribes to one event log, not two. Ships the traceability subsystem as an extension of the evidence primitive rather than a new one.

## Executive summary

Session 2026-09-20b ran a full RFC council on the traceability schema design. Council included the RT classical anchors named on #1182 (Cleland-Huang, Gotel, Wiegers, van Lamsweerde) plus three AI-focused lenses the operator asked for (Andrew Ng, Andrej Karpathy, Chip Huyen) plus a property-graph anchor (Neo4j). Council surfaced four HIGH findings:

1. Fixed link-type enumeration blocks agent-refinement of trace ontology
2. No snapshot at write time — Mode B evolution flags are ambiguous
3. Fixed field-group shape does not survive ontology growth without migration
4. Proposed ledger duplicates the existing evidence primitive that bandleader already subscribes to

The four findings converge on one recommendation: do not ship a new ledger schema. Extend `standards/state-spine/schemas/evidence.schema.json` with trace-link fields. Reuse the Observer log at `state/events/evidence-status-changed.jsonl`. Preserve the DRY contract Hunt & Thomas anchor.

Session also seeds four new luminary files as prototype additions to the catalog.

## Context — existing Phase 1 draft on umbrella #1182

The umbrella cites `sunj-labs/bassclef-cli/docs/promotes/2026-08-11-traceability-subsystem.md` as the working draft. Phase 1 delivered:

- 5 luminaries planned — Cleland-Huang, Gotel, Mäder, Egyed, Hayes
- SysML relationships mapped — containment, deriveReqt, verify, satisfy, refine
- `.claude/rules/requirement-annotation.md` — `@requirement R-XXX` code annotation
- `.claude/rules/traceability-frontmatter.md` — frontmatter fields for adjacent artifacts
- `standards/traceability-subsystem.md` — reference model
- Applied test case — 8 tests, 8 source files, 7 test files at cli/docs/requirements/2026-08-11-npm-distribution.md

Session 2026-09-20b research is additive. Phase 1 stays intact. This paper informs Phase 2 schema authoring.

## Session research signals

Three signal sources fed the finding table.

### `/extract-intent` LIVE runs

Four intents ran against the Voyage + Haiku matcher this session.

| Intent | Matched luminaries | Confidence |
|---|---|---|
| Lightest-weight OOAD ledger, workflow determinism | Ash Maurya, Alistair Cockburn, Conventional Commits | 0.82 |
| Typed traceability structure, both modes | Hunt & Thomas, Mermaid, Eric Evans | 0.78 |
| Adversarial review — AI + graph engineering | Eric Evans, Craig Larman | 0.62 |
| Bandleader impact on schema | Hunt & Thomas, Eric Evans | 0.62 |

The 0.62 confidence on the AI-focused intent is a real signal. Bassclef's luminary catalog holds none of Andrew Ng, Andrej Karpathy, or Chip Huyen. That gap motivates the four new luminary files this session proposes.

### Web-research fork findings

#### Gotel & Finkelstein (1994) — canonical RT

- Bi-directional at the primitive level. Two semantically distinct directions — `origin_of` (backward) and `implemented_by` (forward). Not inverses of one symmetric edge.
- "Majority of problems attributed to poor RT are due to inadequate pre-RS traceability" — origin metadata carries the weight.

#### Sodius Willert (industry blog)

- Forward-only tracing produces orphan implementation artifacts.
- Names impact-analysis pain, prescribes no protocol.

#### Cleland-Huang — live-traceability + augmentation

- ["Live-traceability challenges" arXiv 2306.10972](https://arxiv.org/pdf/2306.10972) — "Software traceability is the process of establishing AND MAINTAINING relationships between artifacts."
- ["Trace link augmentation" arXiv 1804.02433](https://arxiv.org/pdf/1804.02433) — targets "incomplete trace links"; assumes brownfield partial-graph state.
- ["Automated maintenance via ML" arXiv 1807.06684](https://arxiv.org/pdf/1807.06684) — CI-triggered classification patches the graph per commit.

#### Andrew Ng + Andreas Kollegger (DeepLearning.AI)

- ["Agentic Knowledge Graph Construction" course](https://learn.deeplearning.ai/courses/agentic-knowledge-graph-construction/) — agents refine schema via fact-checking feedback loops.
- Schema implication: schemas for AI-consumed data are refinable by agents, not fixed at design time.

#### Andrej Karpathy — LLM compiles wiki

- Verbatim from [DAIR.AI blog on Karpathy Knowledge Bases](https://academy.dair.ai/blog/llm-knowledge-bases-karpathy) — "You rarely ever write or edit the wiki manually; it's the domain of the LLM."
- Schema implication: the ledger must be compilable — dense, machine-parseable, structured for LLM working memory.

#### Chip Huyen — CACE

- CACE principle from [Sculley et al. 2015 as summarized in arxiv/2012.07919](https://arxiv.org/pdf/2012.07919) — "change anything, changes everything".
- Established position via [DMLS TOC](https://huyenchip.com/machine-learning-systems-design/toc.html) — feature reproducibility needs schema + data + snapshots versioned together.
- Schema implication: entries need snapshot fields pinning schema-version plus upstream hashes at write time.

#### Neo4j — property-graph flexibility (VERIFIED VERBATIM)

- ["Graph database vs relational database" Neo4j blog](https://neo4j.com/blog/graph-database/graph-database-vs-relational-database/) — "Adding new nodes, relationships, or properties doesn't require changing existing data or rewriting application code."
- "When changing the data model, you can add new types of nodes, new properties, and new relationships while leaving existing data untouched."
- Schema implication: link types + entry types should be extensible; add-a-new-type must not require migrating existing entries.

### Bandleader alignment finding

Reading `bassclef-upstream/standards/state-spine/schemas/evidence.schema.json` revealed the load-bearing discovery of the session.

Evidence schema description already declares:

- **Observer pattern** — status transitions emit events to `state/events/evidence-status-changed.jsonl`
- **Future bandleader subscribes as Mediator** — named directly in the schema description
- **CQRS read-model per Young**
- **Append-only event log per Helland**
- **DDD bounded context per Evans**

Fields already present in evidence.schema.json:

- `id` — `ev-YYYY-MM-DD-NNN` stable identifier
- `schema_version` — bumped per ADR-031
- `date` — ISO
- `ticket_refs[]` — GitHub issues
- `problem_plain` — ≤280 chars, tweet-shaped
- `trigger.skill` — closed vocabulary
- `trigger.operator_initiated` — false when dispatched by bandleader
- `agent`
- `status`

Per `standards/loop-discipline.md` — "Subscribers (chronicle composer, bet-doc acceptance flipper, future bandleader, future HUD) read the event log to derive their own views."

The primitive bandleader will subscribe to already exists. A separate traceability ledger would fragment that subscription surface.

## RFC-0001 findings — outside council on the schema

Council: outside the Phase 1 authoring set. Andrew Ng + Andreas Kollegger, Andrej Karpathy, Chip Huyen, Neo4j property-graph, Hunt & Thomas, Eric Evans.

### HIGH-1 — fixed link-type enumeration blocks agent-refinement

- **Claim:** the Phase 1 shape hard-codes link kinds at design time via named frontmatter fields (`derives_from`, `verifies`, `refines`).
- **Evidence:** Kollegger's DeepLearning.AI course positions agents as refining schema via feedback. Bassclef's `/extract-intent` LIVE is the same architectural shape today.
- **Why it fails:** when `/extract-intent` discovers a link kind not enumerated (e.g., "requirement mentioned in a prior chronicle", "risk borrowed from sibling goal"), the schema silently drops the signal.
- **Cure:** version the schema per entry (`schema_version`); add `refined_by` audit block; make link kinds an open string enum.

### HIGH-2 — no snapshot at write time

- **Claim:** Mode B evolution flips a trace to `suspect` without recording what changed.
- **Evidence:** Chip Huyen's CACE principle — coupled ML systems drift silently unless snapshots pin schema + data + model versions.
- **Why it fails:** three drift sources (upstream artifact, schema, matcher model) collapse to one flag. Reader cannot tell which shifted.
- **Cure:** add `snapshot` block per entry — `{schema_version, upstream_hashes, matcher_version, captured_at}`.

### HIGH-3 — fixed field-group shape does not survive ontology growth

- **Claim:** adding a new link type in Phase 2 requires migrating every existing entry.
- **Evidence:** Neo4j verbatim — property-graph shape adds new relationships without existing-data migration.
- **Why it fails:** post-launch, when Cleland-Huang-style automation surfaces new edge kinds, migration cost cascades across every adopter.
- **Cure:** replace fixed field groups with an `edges[]` array. Each edge carries `{kind, direction, target_ref, properties}`. `kind` is an open string, not a closed enum.

### HIGH-4 — duplicates the existing evidence primitive

- **Claim:** shipping a separate traceability ledger duplicates `state/events/evidence-status-changed.jsonl` — the primitive bandleader will subscribe to.
- **Evidence:** evidence.schema.json description names Observer pattern + bandleader-as-Mediator + CQRS + append-only + DDD boundary. All architectural primitives already exist.
- **Why it fails:** shipping a second primitive splits bandleader's subscription surface. Adopters wire two event streams for one architectural purpose. Hunt & Thomas DRY violation.
- **Cure:** do not ship a new ledger schema. Extend evidence.schema.json with trace fields. Emit trace-link events on the same log. Reuse `lib/evidence.sh` accessors.

### MEDIUM-1 — deeply-nested prose fields hurt LLM parsing

- **Claim:** rationale prose sits inside frontmatter blocks, mixing structure with narrative.
- **Evidence:** Karpathy — the wiki is the domain of the LLM; structure and prose need clean separation.
- **Cure:** move all prose to a per-entry `notes` field. Keep the structured tree machine-clean.

### MEDIUM-2 — per-session ledger duplicates cross-session requirement entries

- **Claim:** a requirement referenced across sessions A and B gets two full entries.
- **Cure:** normalize. Ledger holds a shared `nodes[]` array. Sessions link to node ids, not embed them.

### LOW-1 — no confidence field on discovered edges

- **Cure:** add `discovered_by` block per edge — `{matcher_version, confidence, at}` — for agent-surfaced trace candidates.

## Proposal — Phase 2 schema extension

The proposal extends `standards/state-spine/schemas/evidence.schema.json` with a `trace` sub-object per evidence row. It does not ship a separate schema file.

### Property-graph shape as a `trace` extension

```json
{
  "$comment": "Extension of evidence.schema.json — adds trace field group",
  "properties": {
    "trace": {
      "type": "object",
      "properties": {
        "schema_version": {"type": "string", "const": "0.1.0"},
        "mode": {"type": "string", "enum": ["greenfield", "evolution"]},
        "snapshot": {
          "type": "object",
          "properties": {
            "captured_at": {"type": "string", "format": "date-time"},
            "matcher_version": {"type": "string"},
            "upstream_hashes": {
              "type": "object",
              "additionalProperties": {"type": "string"}
            }
          }
        },
        "nodes": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "node_id": {"type": "string"},
              "node_kind": {
                "type": "string",
                "description": "Open string. Recognized: requirement, design, code, test, verification. New kinds add without migration."
              },
              "ref": {"type": "string", "description": "File path or ticket ref"}
            }
          }
        },
        "edges": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "kind": {
                "type": "string",
                "description": "Open string. Recognized: origin_of, implemented_by, verifies, refines, folds_risk, superseded_by, refined_by."
              },
              "direction": {"type": "string", "enum": ["forward", "backward"]},
              "source_node_id": {"type": "string"},
              "target_ref": {"type": "string"},
              "properties": {"type": "object"},
              "link_state": {
                "type": "string",
                "enum": ["fresh", "suspect", "stale", "orphan"]
              },
              "discovered_by": {
                "type": "object",
                "properties": {
                  "matcher_version": {"type": "string"},
                  "confidence": {"type": "number"},
                  "at": {"type": "string", "format": "date-time"}
                }
              }
            }
          }
        },
        "notes": {"type": "string", "description": "Free-form prose. Keeps structured tree clean."},
        "refined_by": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "agent": {"type": "string"},
              "refinement": {"type": "string"},
              "at": {"type": "string", "format": "date-time"}
            }
          }
        }
      }
    }
  }
}
```

### Alignment with bandleader subscription

- Trace events emit to `state/events/evidence-status-changed.jsonl` — the same log bandleader will subscribe to.
- Event payload adds a `trace_change` kind for edge additions, suspect flips, and refinements.
- Bandleader Mediator role stays unchanged. Trace agents write; bandleader coordinates.

### Backward compatibility

- The `trace` field is optional per JSON Schema. Existing evidence rows without it stay valid.
- Phase 1 `@requirement` code annotations continue to work. They resolve to `edges[].kind = "implemented_by"` when the schema-extension accessor walks source files.
- Phase 1 frontmatter fields (`derives_from`, `verifies`, `refines`) map to `edges[].kind` values via a translation table in `standards/traceability-subsystem.md`. Adopters do not rewrite their existing frontmatter.

### Mode contract

- **Greenfield first execution** — new evidence row per SDLC step; `trace.mode = "greenfield"`; edges added forward as work progresses.
- **Brownfield ongoing evolution** — existing evidence rows re-visited; `trace.mode = "evolution"`; affected edges flip to `link_state = "suspect"` when upstream hash changes; new edges append with `supersedes` pointers.

## Four new luminary files owed

Session seeds these under `.claude/luminaries/` in bassclef-cli. Prototype for upstream promote via bassclef-upstream#1590 living-docs epic.

1. **`jane-cleland-huang.md`** — automated traceability + live-traceability maintenance. Primary lens for Phase 2 schema evolution.
2. **`andrew-ng.md`** (co-author Andreas Kollegger) — agentic knowledge graph construction. Anchors schema refinement by agents.
3. **`andrej-karpathy.md`** — context engineering. Anchors LLM-compiled structured data.
4. **`chip-huyen.md`** — ML systems + CACE. Anchors snapshot discipline.

Each file ~60-80 lines. Signature quote, primary domain, when-to-invoke, when-NOT-to-invoke, one anti-pattern.

## Recommendation

Fold this research into #1182 Phase 2. Preserve Phase 1 (methodology, rules, annotations, applied test case). Extend Phase 2 schema authoring with the property-graph shape and the four HIGH-finding cures. Author the four AI-council luminary files as sister ship.

## Ship path

- **This session (2026-09-20b)** — this paper filed under `docs/operator-private/`. Comment posted on #1182 with paper contents. Focus pivots to Docker harness (cli#162) using the existing evidence primitive for traceability discipline.
- **Upstream Phase 2 authoring session** — extends evidence.schema.json with the `trace` sub-object. Ships accessor updates in `lib/evidence.sh`. Ships luminary files.
- **Post-launch** — Cleland-Huang-style automated maintenance ships as `/trace` skill wired to `/extract-intent` LIVE.

## Refs

- bassclef-upstream#1182 — Traceability Subsystem umbrella (parent)
- bassclef-upstream#1590 — Living OOAD docs epic (sister)
- bassclef-cli#162 — Docker cold-adopter harness (this session's primary scope)
- `bassclef-cli/docs/promotes/2026-08-11-traceability-subsystem.md` — Phase 1 draft
- `bassclef-upstream/standards/state-spine/schemas/evidence.schema.json` — extension target
- `bassclef-upstream/standards/loop-discipline.md` — Observer + bandleader subscription
- `bassclef-upstream/architecture/substrate-assessment.md` — bandleader vocabulary
- Gotel + Finkelstein 1994 — via [Semantic Scholar](https://www.semanticscholar.org/paper/An-analysis-of-the-requirements-traceability-Gotel-Finkelstein/ebc86c81ace4607f3f59a9053ec542cf323140a2)
- Cleland-Huang — [arXiv 2306.10972](https://arxiv.org/pdf/2306.10972), [1804.02433](https://arxiv.org/pdf/1804.02433), [1807.06684](https://arxiv.org/pdf/1807.06684)
- Andrew Ng + Kollegger — [DeepLearning.AI course](https://learn.deeplearning.ai/courses/agentic-knowledge-graph-construction/)
- Andrej Karpathy — [DAIR.AI blog](https://academy.dair.ai/blog/llm-knowledge-bases-karpathy)
- Chip Huyen — [DMLS TOC](https://huyenchip.com/machine-learning-systems-design/toc.html)
- Neo4j — [Graph vs relational blog](https://neo4j.com/blog/graph-database/graph-database-vs-relational-database/)
- Sculley et al. CACE — [arXiv 2012.07919](https://arxiv.org/pdf/2012.07919)
- Session extract-intent runs — matcher_version voyage-3-lite+haiku-4-5-1.0 (4 runs, 0.62-0.82 confidence range)

---

Filed by kingofrock. Session 2026-09-20b. Research paired with Docker harness scope work under cli#162.
