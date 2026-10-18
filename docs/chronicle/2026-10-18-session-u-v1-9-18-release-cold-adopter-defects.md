---
tier: lite
session_id: 2026-10-18-session-u
project: bassclef-cli
agent: personal
status: completed
tags: [release, v1.9.18, cli-188, cli-438, cli-439, cold-adopter-smoke, publish-pipeline, adr-012]
started_at: 2026-10-17T23:00:00+0000
ended_at: 2026-10-18T12:28:00+0000
duration_minutes: ~210
turns: ~140
closes: ["cli#188", "cli#438", "cli#439", "cli#180", "cli#209"]
---

# Session: v1.9.18 release — dynamic pin + v1.11.0 bundle + cold-adopter defect sweep

## Entry State

Session T closeout left v1.9.16 live on npm bundling bassclef v1.10.1. Peer `bassclef-upstream-c7` mid-session announced bassclef v1.11.0 live. Cli#438 (open) tracked publish-pin stale drift; cli#188 (open since 2026-09-21) tracked the structural dynamic-pin fix; cli#439 (new) covered the dev-repo statusline source class.

## Work Done

### Shipped

- **@thebassclef/lite@1.9.18 LIVE on npm** via OIDC trusted publisher. First release bundling bassclef v1.11.0. Sigstore logIndex `3310018075`; shasum `ee9f757534b5865d460099505dc2d6ec3adc1149`; tarball shows `+ @thebassclef/lite@1.9.18` at 2026-10-18T10:30:47Z.
- **PR #440 merged** (`4af3b11`) — cli#188 dynamic substrate pin + cli#438 v1.11.0 bump + cli#439 dev-repo `bassclef-version.json`. 14 new Tier 0 tests. ADR-004 + ADR-007 honored; §Acceptance delta amended inline.
- **PR #442 merged** (`2b5d1658`) — andon-cure for `you@example.com` in bundled onboard-repo SKILL body. One FILE_ALLOWLIST entry + ADR-004 §Ordered steps check 9 Amendment 2026-10-18.
- **PR #443 merged** (`e7af78e`) — v1.9.18 bump. First release carrying v1.11.0 content under a version number the publish gate accepted.
- **PR #449 open** — ADR-012 proposed: cold-adopter smoke as pre-publish gate.

### Tickets filed

- **cli#441** — bump-version.mjs postcondition bug (`.toString()` on null stdout under `stdio: 'inherit'`). Pre-existing; hit 3x this session.
- **cli#444** — nuke-and-fresh-install `--purge-adopter` silently proceeds past `delete_repo` scope failures.
- **cli#445** — add macos-latest smoke workflow.
- **cli#446** — scoped-PAT smoke variant.
- **cli#447** — mechanical sibling-smoke pre-publish gate.
- **cli#448** — persona-driven UX review on onboarding prose changes.
- **upstream#2253** — pre-push-shellcheck blocks first push with 72 findings in bassclef's own files.
- **upstream#2254** — SKIP env prefix doesn't reach hook from Claude Code harness.
- **upstream#2255** — OAuth preflight uses GNU `timeout(1)` missing on macOS.
- **upstream#2256** — Concise prompt lacks explain + unwind preamble.
- **upstream#2257** — bassclef init auto-save installer assumes `~/src/bassclef` sibling.

### Closeout sweep

- cli#188, cli#438, cli#439 closed with publish evidence.
- cli#180 closed (question answered by cli#411 + cli#439).
- cli#209 closed (cured upstream — v1.11.0 bassclef-version.json shape is clean).
- cli#290 + cli#291 left open with triage comments (sister concerns, not this release's scope).

## Decisions

- **Option Y over X on the v1.9.17 → v1.9.18 bump.** Preserves v1.9.17 as historical "would have shipped" tag; v1.9.18 ships what adopters actually get. Operator picked Y when I surfaced the tag-move vs new-bump trade-off.
- **ADR-012 as `proposed` status.** Mechanical implementation tracked at cli#447; the ADR documents the discipline + rationale. Lets review happen on the design before the code lands.
- **Peer coord via SendMessage, not direct PR filing on upstream.** Peer `bassclef-upstream-c7` carries the context; coord asks (pickup order, cold-adopter fixture handoff, cure path for #2253, hotfix window) returned to peer so they can shape the upstream cycle.

## Discoveries

- **The dynamic pin (cli#188) unmasked a latent andon-list gap.** v1.9.17 publish tripped on `you@example.com` because the pin advance was the first time current substrate reached the tarball in 11 days. The cure is small (one allowlist entry); the diagnostic value is bigger — our smoke tier doesn't exercise the publish-pipeline against current substrate before the pin advances.
- **CI tests the maintainer's environment, not the adopter's.** Cold-adopter smoke on real macOS with scoped PAT caught 6 bugs that CI (ubuntu-24.04 + full `SMOKE_GH_TOKEN` + plain bash scope) could never catch. Each defect maps to a specific CI-vs-adopter environment axis gap.
- **The `.claude/rules/sibling-smoke-after-substrate-change.md` rule exists already but operates methodology-only.** v1.9.17 → v1.9.18 proved methodology alone insufficient. ADR-012 formalizes the mechanical gate pattern.
- **Peer standing offer ("coordinate cold-adopter fixture") was the signal — we just hadn't turned it into a gate.** cli#447 proposes to wire the mechanical dispatch; peer coord ask #2 raised this directly.

## Open Threads

- **PR #449 (ADR-012) awaits operator review + merge** — doc only; status `proposed`.
- **cli#441 (bump postcondition bug)** — pre-existing; small cure; next session.
- **cli#445, cli#446, cli#447, cli#448** — the gap-class follow-ons; sized to one cli release each; sequence TBD.
- **upstream#2253-#2257** — peer `bassclef-upstream-c7` has the coord ask; pickup order their call.
- **Peer coord ask #2** — cold-adopter fixture handoff proposed to pilot cli#447 before it ships mechanical.
- **ADR-012 implementation triangle** — cli#445 + cli#446 + cli#447 together are the mechanical shape ADR-012 names.

## Key Files Changed

- `.bassclef-pin` (new) — single source of truth for substrate tag.
- `bassclef-version.json` (new at repo root) — dev-repo statusline source.
- `scripts/sync-bassclef-version.mjs` (new) — idempotent sync helper.
- `scripts/tests/bassclef-pin.test.sh` + `scripts/tests/sync-bassclef-version.test.sh` (new) — 14 Tier 0 tests.
- `scripts/andon-scan.mjs` — FILE_ALLOWLIST entry for `you@example.com` in bundled onboard-repo SKILL.
- `tests/andon-scan.test.ts` — 2 new vitest cases (T13a + T13b).
- `.github/workflows/publish.yml` — pin lifted from 3 hardcoded YAML sites to `.bassclef-pin`; both jobs read via new `Read .bassclef-pin` step; assertion compares against `$BASSCLEF_PIN`.
- `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` — Amendment 2026-10-18 (RFC 2606 reserved-placeholder carve-out).
- `docs/adrs/ADR-007-npm-lite-substrate-bundling.md` — §Acceptance delta points at `.bassclef-pin`.
- `docs/adrs/ADR-012-cold-adopter-smoke-as-pre-publish-gate.md` (new; proposed on branch).
- `docs/use-cases/UC-script-188-dynamic-substrate-pin.md` + `UC-script-439-dev-repo-version-file.md` (new).
- `CHANGELOG.md` — `[1.9.17]` + `[1.9.18]` sections.
- `package.json` + `src/index.ts` + `README.md` — version 1.9.16 → 1.9.18.

## Gate Evidence

```
Gates fired this session:
- temperance: 4 markers (feature/cli-188-dynamic-pin, fix/andon-allow-example-email, feat/v1.9.18-bump, docs/adr-012-...)
- diagnose: 2 markers (fix-andon-allow-example-email, this chronicle via /diagnose on andon trip)
- adr-deviation: 4 markers (same branch set; all outcome: ADR-honored)
- decompose: 4 markers (same branch set)
- /temperance: fired at every branch start
- /luminary: lead rotation — linus-torvalds (feat), saltzer-schroeder (andon-cure), linus-torvalds (bump), linus-torvalds (ADR-012). Supporting: tony-hoare, david-parnas, michael-nygard, michael-feathers, kent-beck across the four.
- /loop: iteration 1 GREEN on all 4 PRs (andon-cure went RED first then GREEN after allowlist entry — same cycle).
- /diagnose: fired on v1.9.17 andon trip (full Is/Is-Not + Five Whys + Hypothesis in state/markers/diagnose/fix-andon-allow-example-email.marker).
- /verify: 525/525 vitest + typecheck + install harness + nuke-and-install tier-0 14/14 + shell tier 84/86 + CI docker-smoke 11m53s + CI pr-checks + CI publish 39119450372.
- /kiss words: inline on PR body + ticket authoring.
- /artifact-ingestion: cited every ADR, rule, sister ticket, prior PR, and transcript source in all 3 PR bodies + 11 tickets + ADR-012 body.
```

## Luminary rotation

- **Linus Torvalds** led across PRs #440, #443, #449 — we don't break adopters; publish-pipeline cure + bundle refresh + mechanical gate ADR.
- **Saltzer-Schroeder** led PR #442 andon-cure — economy of mechanism; narrow per-file allowlist entry.
- **Tony Hoare** supported — pre/postcondition on `.bassclef-pin` + `bassclef-version.json` consistency; postcondition on cold-smoke marker shape.
- **David Parnas** supported — information hiding in dynamic-pin shape; information hiding in cold-smoke marker contract.
- **Michael Nygard** supported — stability pattern on andon-cure escape path; stability on mechanical gate.
- **Michael Feathers** supported — characterization tests on workflow + file shape + ADR-012 characterization at adopter boundary.
- **Kent Beck** supported — Tier 0 strict TDD; 14 new tests landed before source edits.

## Peer coord

- `bassclef-upstream-c7` msg_id `46f772a8-79d6-45fa-9e7e-d1e5a9879032` (publish success report).
- `bassclef-upstream-c7` msg_id `bef3215c-c8f8-427e-94d1-d9e82041eb3d` (cold-adopter defect sweep + 4 coord asks).

## Next session pickup

PR #449 (ADR-012) review + merge. Then triage ordering for cli#441/#445/#446/#447/#448. Peer upstream pickup of #2253-#2257 may land in parallel; sister cli v1.9.19 bump the moment an upstream cure that touches `/onboard-repo` ships.
