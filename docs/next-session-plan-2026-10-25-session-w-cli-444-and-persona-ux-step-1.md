---
session_id: 2026-10-25-session-w
project: bassclef-cli
status: planned
tags: [cli-444, cli-448, persona-ux, nuke-script, pre-commit-hook, cold-adopter]
---

# Next-session plan — Session W: cli#444 cure + persona-UX Step 1 (Prong B)

## Context

Session V shipped `@thebassclef/lite@1.9.19` bundling bassclef v1.11.1 (4 upstream cold-adopter cures). Session V plan Ask 3 — cold-adopter smoke on `giveisusfree` — fired on 2026-10-25 and surfaced 5 defects. 4 route upstream (filed as `bassclef-upstream#2267-#2270`); peer `bassclef-upstream-d2` holds those and is running `/eisenhower` against them. 1 is cli-side: `cli#444` nuke-script scope-fail. Already filed with /diagnose + cold-adopter evidence in-comment.

Session W runs two threads in parallel. Both are cli-side only, no upstream dependency.

## Recommended session sequence

### Thread 1 — cli#444 nuke-and-fresh-install.sh --purge-adopter cure

Hard-stop on `delete_repo` scope miss. Print the exact fix line `gh auth refresh -h github.com -s delete_repo` + exit non-zero. Cold adopter reruns after refresh, gets clean purge.

**Scope class:** b (script extension) per `/longrun` Step 0.86 taxonomy.

- **Steps:** brief use case + `/luminary consult` (lead + 1 supporting) + `/pre-mortem light` + Beck RED-first + impl + `/verify` + PR + merge + release cycle.
- **Produces:** `scripts/nuke-and-fresh-install.sh` cure + Tier 0 test (new).
- **Consumes:** cli#444 ticket body + comment thread + the adopter's log (quoted in comment).
- **Risk:** 🟢 low — one script, one bash branch. Rollback is a one-line revert.
- **Time:** 20-40 turns.
- **Lead luminary:** Linus Torvalds — the flag name promises a postcondition the script must honor. Adopter contract shape.
- **Supporting:** Donald Norman — signifier + feedback (print the fix line, don't just report the error).

### Thread 2 — persona-UX canvas Step 1 (Prong B)

Pre-commit hook that fires WARN when a Y/n prompt lands in `.claude/skills/onboard-repo/**` without ≥2 sentences of body prose above it. Per canvas at `docs/canvases/2026-10-25-persona-ux-test-tier.md` — Prong B is the mechanical floor. Prongs A + C ride later cycles.

**Scope class:** c (new building block) per `/longrun` Step 0.86 taxonomy — a new hook.

- **Steps:** fully-dressed use case + `/decompose` + `/luminary consult` (lead + 2 supporting) + `/pre-mortem light` + bootstrap pair (hook + Tier 0 test + settings.json wire + rule body cross-ref) + Beck RED-first + impl + `/verify` + PR + merge.
- **Produces:** `.claude/hooks/pre-commit-naked-prompt-check.sh` + Tier 0 test at `.claude/hooks/tests/pre-commit-naked-prompt-check.test.sh` + settings.json wire + canvas Step 1 marked `[x]`.
- **Consumes:** canvas thesis + `.claude/rules/plain-english-discipline.md` (grade-8 wordlist) + persona definitions at `docs/personas/` (Sam specifically).
- **Risk:** 🟢 low — pre-commit hook with regex scan. WARN never blocks shipping. Narrow matcher scope (onboard-repo SKILL only).
- **Time:** 30-50 turns.
- **Lead luminary:** Kent Beck — test the structural invariant mechanically. The hook IS the test; the test IS a Beck list of what naked prompts look like.
- **Supporting:** Michael Feathers (characterization — pin the real naked-Y/n shapes from upstream#2256 + upstream#2268 as fixtures) + Alan Cooper (the goal is Sam's informed consent).

### Order + decision

Thread 1 first — smallest, highest-value, closes a known defect that bit a real adopter today. 20-40 turns.

Thread 2 second — larger (new hook ships bootstrap pair + Tier 0 tests), compounds across every future SKILL edit. 30-50 turns.

**Decision queued for operator at prep:**

- **Option a** — ship both as one PR (both small, both 🟢 low; one release cycle)
- **Option b** — ship as two atomic PRs (cleaner revert path per Thread; one more release cycle)

Recommend **a** — scope is bounded, both touch different file surfaces, review burden is small. Session U + V already proved the one-atomic-PR release-cycle shape works.

## Peer coord state

- `bassclef-upstream-d2` (busy; current longrun paused per 2026-10-25 ping): running `/eisenhower` on upstream#2267-#2270 with Sam-Louis-5-10-min-friction anchor. Reply expected before they reshape.
- `bassclef-upstream-c7` (idle 11d; last shipped v1.11.1): can pick up any upstream slop d2 drops.
- No cross-repo coordination required for Session W — both threads are cli-side only. The release cascade after Session W will pull latest bassclef (v1.11.1 unchanged OR whatever d2's /eisenhower result ships).

## Time budget

Combined: 50-90 turns. Session V ran ~45 in similar converged shape; Session W adds one new hook (Beck RED-first) which costs ~10-15 extra for the test list.

Grounded range cites Session V actuals (45 turns, converged preset, two threads folded clean) + Session U (140 turns, release cycle with mid-flight andon trip; serves as upper bound even though andon shouldn't fire this cycle).

## Entry state

- Branch: `main` at HEAD after Session V-tail commit `c56a07a` (whereami + canvas vocab fix)
- Open cli-side tickets: cli#441 (bump postcondition), cli#444 (nuke-script — PRIMARY this session), cli#445-#448 (persona-UX etc.), cli#199 (epic parent)
- Open cli-side PRs: #449 (ADR-012 cold-adopter smoke gate — strategic, defer), #423 (Dependabot node 25-slim — triage)
- @thebassclef/lite@1.9.19 LIVE on npm as `latest` (sha512 rNMtu2c+)

## Reference artifacts

- Session V chronicle: `docs/chronicle/2026-10-18-session-v-v1-9-19-republish.md`
- Session V plan: `docs/next-session-plan-2026-10-18-session-v-v1.9.19-republish.md`
- Persona-UX canvas: `docs/canvases/2026-10-25-persona-ux-test-tier.md`
- Test topology artifact: https://claude.ai/code/artifact/abe070b6-5620-4bcf-b642-23a57800f5af
- cli#444 ticket + 2026-10-25 comment: https://github.com/sunj-labs/bassclef-cli/issues/444
- cli#448 ticket: https://github.com/sunj-labs/bassclef-cli/issues/448
- Upstream tickets filed this cycle: #2267, #2268, #2269, #2270
