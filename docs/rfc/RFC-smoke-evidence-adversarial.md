---
tier: project
title: RFC — smoke evidence design; adversarial outside-council review
id: RFC-smoke-evidence-adversarial
date: 2026-09-18
goal_id: 2026-09-18a-smoke-evidence-capture
mode: agent-reasoned (stub; live extract-intent seeding needs Voyage keys)
status: draft
council:
  - linus-torvalds
  - hyrum-wright
  - alan-cooper
  - ash-maurya
excluded_because_in_authoring_set:
  - michael-feathers
  - jerome-saltzer-and-michael-schroeder
  - kent-beck
  - alistair-cockburn
  - donald-norman
  - john-ousterhout
  - gary-klein
  - michael-nygard  # surfaced in intent audit; treated as effective authoring
  - ivar-jacobson   # surfaced in intent audit; treated as effective authoring
references:
  - path: docs/specs/smoke-evidence-capture.md
    role: audit target
  - path: docs/use-cases/UC-smoke-run.md
    role: audit target
  - path: docs/decompositions/smoke-evidence-capture.md
    role: audit target
  - path: docs/intent-audits/2026-09-18-smoke-evidence-design.md
    role: seed — names the augmented authoring set the council excludes
---

# RFC — smoke evidence design; adversarial outside-council review

## Sources read

- `docs/specs/smoke-evidence-capture.md` — full read
- `docs/use-cases/UC-smoke-run.md` — full read
- `docs/decompositions/smoke-evidence-capture.md` — full read (spec + BCE)
- `docs/intent-audits/2026-09-18-smoke-evidence-design.md` — full read; supplies the augmented authoring set
- `docs/next-session-plan-2026-09-17-cli-pickup.md` — full read; source plan
- `docs/whereami.md` L41-77 — cli 1.1.1 shipped context and cli#101-#108 findings

## What I'm NOT reading (with reason)

- Individual luminary body files — I use catalog descriptions plus each luminary's known anchor
- Voyage embedding output — stub mode; live `/extract-intent` seeding needs Voyage keys

## Directive (per operator)

**Adversarial by design.** Each outside council member reads the three design artifacts through their own lens. Findings say what the authoring set missed. Severity is HIGH / MED / LOW. Disposition is fold-in-now / fold-in-later / defer / reject. Rubber-stamp findings are not findings; every entry cites the specific line or section.

## Council

Four outside luminaries. Excluded because they sit in the effective authoring set (declared plus surfaced in the intent audit): feathers, saltzer-schroeder, kent-beck, cockburn, norman, ousterhout, klein, nygard, jacobson.

- **linus-torvalds** — adopter contract stability; we don't break userspace
- **hyrum-wright** — every observable behavior becomes contract with enough consumers
- **alan-cooper** — persona-driven ergonomics; operator running at 3am on the cold profile
- **ash-maurya** — lean shape; riskiest-assumption first

## Findings

### F1 — Report body IS an adopter contract (severity MED)

**Lens:** linus-torvalds + hyrum-wright combined.

**Where:** `docs/specs/smoke-evidence-capture.md` § Postconditions L61-64; § Acceptance L67-77 (item 7 posts the report as an issue body); UC-smoke-run § Main flow step 16.

**Finding:** The smoke report body posts to a public GitHub issue on `sunj-labs/bassclef-cli`. Bassclef-web (docs.bassclef.dev) already reads from this repo. An agent reading a `smoke-run` issue via `gh issue view` depends on the body's markdown structure (per-hook table shape, RED row link format, exit code line). Change the shape and every agent parser breaks. The design does not name the shape as a versioned contract.

**Data:** whereami L48 shows cli#78 through #108 all reference public repo state as source of truth for agents; report body would join that class.

**Falsifiable by:** shipping V2 of the report shape and observing zero downstream breakage. If nothing breaks, the shape was not yet a contract.

**Disposition:** **fold-in-now.** Add to spec §Postconditions: "Report body shape is versioned. `smoke-run-v1` label carries V1 shape. Future format changes ship as `smoke-run-v2` with a grace window per ADR-031." One label per version; agents pick by label. Small cost; large future headroom.

### F2 — Cold profile is a fictional persona (severity HIGH)

**Lens:** alan-cooper.

**Where:** UC-smoke-run § Primary actor: "Operator on the cold-adopter profile". Spec § Actors: same. Decompose entity table: implicit throughout.

**Finding:** The design names "Operator" as one actor. There are TWO operator states, and they need different affordances:
- **State A — release-day operator.** Just published 1.1.2 to npm. Wants a 5-minute smoke, exit code, thumbs-up. Report body irrelevant beyond pass/fail.
- **State B — diagnosis operator.** A prior smoke was RED. Wants raw captures, per-check drill-down, ability to re-run one check.

The design serves State A well (report + issue + exit code). State B has no affordance — captures land on disk but there is no "re-run assertion X" or "diff this capture against last run" surface. Diagnosis operator falls back to eyeball work, defeating the goal.

**Data:** whereami L45-46 describes the 2026-09-17 diagnosis session — operator asked the agent to re-read the transcript afterwards. That IS State B, and this design does not close it.

**Falsifiable by:** running a red smoke and observing whether the operator (or agent) can drill into one failing check without re-running the whole flow.

**Disposition:** **fold-in-now.** Add to spec § Actors: split Operator-Release and Operator-Diagnose personas. Add to UC-smoke-run: main flow steps 17-19 already cover agent pickup for diagnosis; add UC-smoke-diagnose extension for a per-check re-run affordance in Step 2 or later. Not new scripts — a `--only <check-name>` flag on `smoke-assert-hooks.sh` and `smoke-assert-skills.sh` covers it.

### F3 — 30-second timeout is a magic number (severity MED)

**Lens:** ash-maurya.

**Where:** UC-smoke-run § Extension 11b; Spec § Acceptance item 5; Decompose § Cross-cutting concerns table.

**Finding:** 30 seconds is asserted as the timeout for `claude -p` calls but not derived from data. Every luminary preview or /kiss words invocation could take 15-60 seconds depending on model latency and prompt length. A timeout too tight produces false-positive TIMEOUTs. A timeout too loose lets a hung skill drag the whole smoke past 5 minutes.

**Data:** Spec § Success metrics targets "under 5 min" for the whole flow. Five skills at 30 seconds each = 2:30 minimum. If one hits 60 seconds, budget is tight but not blown. If two hit 60, the target fails.

**Falsifiable by:** running the smoke five times on 1.1.1 baseline and measuring actual per-skill latency. Set timeout at p95 + 20%.

**Disposition:** **fold-in-later.** Ship 30 seconds in V1; add an acceptance criterion for Layer 1 closeout: measure actual latencies on the first three cold runs, adjust the constant, extract to `SMOKE_SKILL_TIMEOUT_SEC` env with 30 as default.

### F4 — "Publish" is a one-shot side effect with no idempotency (severity MED)

**Lens:** hyrum-wright + linus-torvalds combined.

**Where:** Spec § Acceptance item 7; UC-smoke-run § Main flow step 16; Decompose § BCE — PublisherController creates Issue.

**Finding:** Every `--publish` invocation creates a new GitHub issue. If the operator re-runs the smoke on the same day (fixing a false-positive, re-testing after a cure), a second issue lands. The `smoke-run` label fills with duplicates. An agent scanning `gh issue list --label smoke-run` cannot tell first-of-day from re-run.

**Data:** Session pattern from whereami L45 — operator often re-runs smokes when a false-positive fires. Three tool-block collapses on 2026-09-17 would have produced three re-run attempts if the same class recurred.

**Falsifiable by:** shipping V1 and counting duplicate issues within one week.

**Disposition:** **fold-in-now.** Add to spec § Acceptance item 7: "When an open `smoke-run` issue exists for the same `<version>` on the same date, `--publish` updates the existing issue body instead of creating a new one. Force-new via `--publish --new`." Small addition; large operator ergonomics win.

### F5 — Success metric "false-positive rate < 1 per 10 runs" is unmeasurable (severity LOW)

**Lens:** ash-maurya + linus-torvalds.

**Where:** Spec § Success metrics L166.

**Finding:** The metric assumes 10 baseline runs to measure against. Layer 1 will not have 10 runs before the next release. A metric that cannot be measured in the near term is not a metric; it is a wish.

**Falsifiable by:** attempting to compute the rate at Layer 1 closeout and finding N < 10.

**Disposition:** **fold-in-later.** Reword the metric to "First three baseline runs on 1.1.1 produce identical pass sets (deterministic)." That IS measurable at Layer 1 closeout. The 1-per-10 target moves to a follow-on ticket after Layer 2 ships.

### F6 — Reset extension `--whole` needs an undo (severity LOW)

**Lens:** alan-cooper.

**Where:** Spec § Acceptance item 8; UC-smoke-run § Extension 1a.

**Finding:** `smoke-reset.sh --whole` clears npm global cache, `~/.claude/projects/<repo>/`, and `~/tmp/bassclef-smoke-test`. `--dry-run` is preserved. There is no `--undo` and no snapshot. An operator who runs `--whole` and realizes they wanted `--cold` loses `~/.claude/projects/<repo>/` state that may hold in-flight session context.

**Data:** whereami L98 references the "second macOS profile" — the operator has cross-profile isolation but no per-profile snapshot before the reset lands.

**Falsifiable by:** running `--whole`, immediately realizing intent was `--cold`, and observing whether recovery is possible.

**Disposition:** **fold-in-now.** Add to spec: "Before clearing, `--whole` copies affected directories to `~/tmp/bassclef-smoke-reset-backups/<ISO-timestamp>/`. Restore command: `bash scripts/smoke-reset.sh --restore <ISO-timestamp>`. Backups auto-expire after 7 days." Cheap belt-and-suspenders.

### F7 — Missing: what happens when Claude Code CLI updates mid-session (severity LOW)

**Lens:** hyrum-wright.

**Where:** UC-smoke-run § Preconditions ("`claude` CLI on PATH"); Spec § Preconditions L58-63.

**Finding:** The smoke assumes `claude` CLI behavior is stable across a run. If Claude Code auto-updates between the hook capture and the skill drive (~30 second window), the `claude -p` invocations run against a different binary than the SessionStart hooks did. Silent version skew.

**Falsifiable by:** capturing `claude --version` at start of run AND at end; comparing.

**Disposition:** **fold-in-later.** Add to spec: "Report captures `claude --version` at flow start and end. Mismatch surfaces as a warning row." One line of shell; catches a class that will fire zero times per year but is invisible otherwise.

## Aggregated dispositions

| Finding | Severity | Disposition | Cost |
|---|---|---|---|
| F1 — Report body versioning | MED | fold-in-now | 1-2 turns; one spec addition |
| F2 — Two operator personas | HIGH | fold-in-now | 3-5 turns; spec + UC + one script flag |
| F3 — 30 sec timeout is magic | MED | fold-in-later (Layer 1 closeout) | 1 turn to add env var default |
| F4 — Publish idempotency | MED | fold-in-now | 2-3 turns; publisher logic |
| F5 — Unmeasurable metric | LOW | fold-in-later | 1 turn to reword |
| F6 — Reset undo | LOW | fold-in-now | 2-3 turns; snapshot + restore |
| F7 — CLI version capture | LOW | fold-in-later | 1 turn to add |

**Fold-in-now (before Step 1 code):** F1 + F2 + F4 + F6. Total cost roughly 8-13 turns. Spec + UC + one decomposition update.

**Fold-in-later (before Layer 1 closeout):** F3 + F5 + F7. Total cost roughly 3 turns.

## What the authoring set caught right

Not a rubber-stamp. Naming what held under adversarial review:

- Four checks per surface (Saltzer-Schroeder) — complete mediation shape survives lens attack; no gap the outside council found
- Fixtures pinning cli#101-#108 (Feathers) — real defects as fixtures resist the "checks that pass on everything" failure mode
- BCE split (Jacobson, via intent audit) — HookRunner-as-Control and AssertionSuite-as-Control resist blur under adversarial questioning
- Fail-Fast on `bassclef init` exit 4/5 (Nygard, via intent audit) — no drift found; the fail-loud path is well-designed
- Report as one file plus issue body (Norman) — signifier discipline holds

## Verdict

Design is sound at the load-bearing layer. Four fold-in-now findings sharpen it without changing shape. Three fold-in-later findings are safe to defer.

**Recommend to operator:** fold F1 + F2 + F4 + F6 into spec + UC + decomposition before Step 1 fires. Amend goal doc frontmatter `authoring_luminaries.supporting` per intent audit (add nygard + jacobson).

## References

- Spec: `docs/specs/smoke-evidence-capture.md`
- Use case: `docs/use-cases/UC-smoke-run.md`
- Decomposition: `docs/decompositions/smoke-evidence-capture.md`
- Intent audit: `docs/intent-audits/2026-09-18-smoke-evidence-design.md`
- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- RFC skill: `.claude/skills/rfc/SKILL.md`
