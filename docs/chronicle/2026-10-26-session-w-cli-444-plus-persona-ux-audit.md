---
tier: upstream
type: chronicle
date: 2026-10-26
session: 2026-10-26-session-w
project: bassclef-cli
preset: converged
outcome: shipped
tags: [cli-444, cli-448, cli-453, cli-454, cli-425, persona-ux, coherence-audit, jargon-reader]
---

# Session W — cli#444 fix plus the persona-UX audit that reshaped the plan

## What shipped

Three PRs merged. No package build, no release — the operator held that, correctly, because a fix is still heading upstream.

| PR | What |
|---|---|
| #452 | `--purge-adopter` stops before it starts when the token cannot delete repos |
| #456 | Coherence audit of the 7 first-touch skills, plus a reusable scan script |
| #455 | Canvas amendment — repo placement, and a read before any build |

## Thread 1 — cli#444

A cold adopter ran `--purge-adopter` on 2026-10-18 without the `delete_repo` permission. Every delete failed, the script printed one advisory line per repo, then carried on and reported success. Their test repos were still on GitHub.

Shipped cure A plus C, the pair the ticket recommended. The substance was placement. The old flow backed up `~/.claude` and reinstalled the package before it reached the delete loop, so a failed run left the adopter half-reset. The scope check now sits ahead of all of it, exits 4, and changes nothing.

The delete loop also stops on the first permission error, which covers a permission revoked after the pre-check passed. Non-permission failures stay advisory — a repo someone else already deleted should not block the purge.

28 tests, up from 12. Ten assertions failed before the fix. The one that mattered was T17: it failed because the script moved `~/.claude` before checking the token. One loop iteration, no rework.

## Thread 2 — stopped, then replaced

The plan said build the mechanical prompt check here. It cannot run here.

`.gitignore:76` ignores `.claude/skills/` and `.gitignore:20` ignores `dist/`. `git ls-files` returns zero for both. The onboarding SKILL is tracked in bassclef-upstream, and `scripts/prepublish-bundle-substrate.mjs:86` copies it in at publish time. A pre-commit check here would match nothing, forever, and no test would reveal that.

Stopped and surfaced it rather than shipping a hook that cannot fire. The dead branch was removed with nothing committed.

Then the operator reframed the work: a cheap read against the personas is the right first step, not a build. That became the new Step 1, and it was right — the read produced the rule the checks should encode, which a hook written first would have guessed at.

## The audit

Read 7 skills from `dist/lite/.claude/skills/` — the assembled package, which is what adopters receive. All 7 byte-identical to the upstream source today.

**The word-list checks already work.** 5 hits across all 7 against the 64 BLOCK terms. The existing hooks did that. Every remaining finding sits in the three questions no machine covers.

**The worst finding is structural.** `onboard-repo` (1910 lines) and `launch` (1032 lines) carry no `## Details below the fold` heading. All five others do. These are the two longest skills and `onboard-repo` is the first thing a new person runs. Sam skims first and bails third; with no boundary there is no signal where skimming ends. One heading fixes it.

**Worst single line** is `onboard-repo:645`, the production-deploy question — 10 words of prose above it, against 17 and 19 for the two other questions in the same skill.

Six patterns came out of the read. Four are mechanized in `scripts/audit-skill-reader-prose.sh`, which turns the sweep of the remaining 59 skills into one command.

## The jargon-reader thread

Started as a footnote on cli#425 and turned into the session's largest finding.

`persona_assert_experience_goal` in `scripts/lib/persona-assert.sh` checks adopter output against 9 jargon words. The standard has 64. All 19 call sites take the 9-word default — the second token on each line is `2>/dev/null`, a redirect, not an argument. So 56 terms are unreachable, including `wirings` and `operator-eyes`, which this session's audit found in `onboard-repo` — the skill that `smoke-drive-e2e-onboard-repo-sam.test.sh` drives and passes.

Then the operator asked why cli would write a parser when the substrate ships the list. That question killed the proposal and found the real defect.

Nine upstream hooks each read the jargon table. A shared reader already exists — `load_block_terms` at `lib/code-comment-discipline.sh:34` — buried in a lib named for code comments, so nobody uses it. Every reader extracts the term column raw, so 40 of 63 extracted terms carry parentheses that `grep -E` reads as a regex group:

```
term: "seed (verb)"
  "we seed verb here"   -> MATCHES   (a phrase nobody writes)
  "we seed the catalog" -> no match  (the thing actually banned)
```

Roughly 23 of 64 BLOCK terms enforce, across all nine hooks at once.

Nine copies of a read is why it was never fixed once. There was no single place to fix it. Filed as upstream#2277 and surfaced on upstream#1780, the hook-consolidation ticket, because that pass is where it pays — consolidate without this in hand and nine copies get carried forward faithfully, bug included.

## Gate evidence

| Gate | Where | Evidence |
|---|---|---|
| orientation | prep | `state/markers/orientation-gate/main.marker` — whereami, plan doc, canvas read |
| temperance | both threads | markers per branch; Thread 1 scope held, Thread 2 drift trigger fired as designed |
| pre-mortem light | both | `docs/risk-ledgers/2026-10-25-cli-444-*`, `2026-10-26-cli-453-*` — 3 lenses each |
| luminary | both | Thread 1 lead `linus-torvalds`; audit lead `alan-cooper` |
| verify | Thread 1 | 28/28, shellcheck rc=0, live run checked under a HOME override |
| lead-lens sign-off | both | markers cite the findings cleared, not a rubber stamp |
| loop | both | iteration 1 each |

The pre-commit gate blocked the audit commit for missing three markers on a substrate path. It was right, and the markers were written rather than overridden.

## What did not work

**I filed #454 without grepping first.** It asked for a new run-based check. The persona test tier already exists here — `persona-assert.sh` with three Cooper-level assertions, `claude-chain.sh`, 20 drivers, 7 fixtures. The capture format already splits what a person reads from what the process returned, which is the hard part. Rewritten to describe three missing assertions instead of a tier.

**Four of my own claims needed correcting**, all caught in-session and all now written into the tickets rather than left in chat:

1. Three skill descriptions "show a unicode escape to the reader" — a YAML parse shows it decodes to an em-dash. No defect.
2. A split-count table derived by subtraction read 9 and 11; measured per group it is 7 and 9.
3. "One-line fix" on cli#425 — too small. Then "needs a small parser" — too big, and it ignored a reader that already ships. The right answer was neither.
4. "A test that already runs in CI" — true, but in the smoke workflows, not `pr-checks.yml`. Said without checking.

**A malformed `sed` prefixed all 230 lines of the audit** and left a file named after the broken expression. Both caught and repaired. The `sed` used `|` as a delimiter with `|` inside the pattern.

**Turn budget overran.** 55-95 estimated, ~100 actual. The overrun came from the jargon thread, which was not in scope and was worth following.

## What worked

**Stopping Thread 2 instead of building it.** Four separate checks confirmed the surface was absent before giving up on it. A hook wired to a path that is never staged passes forever while catching nothing.

**The operator's two reframes.** Audit before build, and "why a parser if we ship the list". Each one removed work rather than adding it, and each landed on a better answer than the one I was defending.

**Verifying before asserting.** The unicode finding would have shipped as real. The YAML parse took one command.

## Next session

Plan at `docs/next-session-plan-2026-10-26-session-x-persona-assertions.md`.

`cli#425` first — now a source line, not a parser. Then the three assertions on `#454`. The audit continues with the 7 recurring skills and a one-command sweep of the other 59.

No release until the upstream fix lands.
