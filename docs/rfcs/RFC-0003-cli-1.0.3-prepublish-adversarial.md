---
tier: lite
id: RFC-0003
slug: 2026-09-16-cli-1.0.3-prepublish-adversarial
type: rfc
kind: adversarial
bet: docs/iteration-bets/2026-09-16-cli-1.0.3-prepublish-recursive-hook-copy.md
outside_luminaries: [hunt-thomas, stephen-toulmin, hyrum-wright, rich-hickey, saltzer-schroeder]
matcher_confidence: 0.82
matcher_mode: LIVE (voyage-3-lite+haiku-4-5-1.0)
authoring_council: 5 luminaries not in the primary+supporting set
---

# RFC-0003 — Adversarial review of cli 1.0.3 prepublish recursive hook copy

## Sources read

- `docs/input-artifacts/2026-09-16-cli-1.0.3-adversarial-grounding.json` — live-matcher outside-lens picks (Hunt-Thomas + Toulmin, 0.82)
- `docs/luminary-consults/2026-09-16-cli-1.0.3-primary-consult.md` — the argument this RFC adversarially reviews
- `docs/use-cases/UC-prepublish-recursive-hook-copy.md`
- `docs/decompositions/2026-09-16-cli-1.0.3-prepublish-domain.md`
- Luminary bodies at `~/src/sunj-labs/bassclef-upstream/.claude/luminaries/{hunt-thomas,stephen-toulmin,hyrum-wright,rich-hickey,saltzer-schroeder}.md`

## Purpose

Council of 5 luminaries NOT in the primary set (Linus + Cockburn + Nygard + Feathers + Beck). Adversarial task — find what the primary consult missed. Each lens produces 1-3 findings with severity + disposition.

## Severity scale

- **HIGH** — must fix before ship OR document a compensating control
- **MEDIUM** — should fix in this goal OR file a follow-on
- **LOW** — worth noting; may defer

---

## Lens 1 — Hunt & Thomas (Pragmatic Programmers)

**Signature:** *"Every piece of knowledge must have a single, unambiguous, authoritative representation."*

### Finding HT-1 (HIGH) — settings.json vs tree is a duplication risk

The fix relies on TWO sources of truth about "what ships": the sibling `dist/lite/.claude/hooks/` tree AND the filtered `settings.json.hooks[].command` list. Postflight asserts they agree — but the fact that they CAN disagree is the design smell.

**Fold:** Postflight is not enough. Add a note in the goal doc naming "upstream owns both the tree and the manifest; if they drift there, cli surfaces the drift loudly" so the responsibility split is explicit. Update ADR-007 amendment to document the invariant.

**Disposition:** Accept — document the split, keep the postflight as the runtime check.

### Finding HT-2 (MEDIUM) — no single place tells you what a lite tarball contains

A reader looking at cli's repo cannot tell what will end up in a tarball without cloning the pinned sibling. That knowledge lives at upstream.

**Fold:** Add a line to the ADR-007 amendment: "the tarball's content is fully determined by the sibling tag pinned in `.github/workflows/publish.yml` — read that tag's `dist/lite/.claude/hooks/` for the truth."

**Disposition:** Accept — one-line doc addition.

---

## Lens 2 — Stephen Toulmin (argument as whole organism)

**Signature:** *"An argument is a whole organism. Take out one part and the rest collapses."*

### Finding ST-1 (HIGH) — the safety argument has 3 parts; take one out and the whole ship falls

The claim "the tarball contents are correct" rests on: (a) the sibling checkout is at the right tag, (b) the recursive copy preserves the tree, (c) postflight catches drift. Remove any one and the argument collapses.

- (a) is enforced by `.github/workflows/publish.yml` `Assert pinned bassclef tag resolves` step (L130-143)
- (b) is enforced by the new recursive copy shape (this fix)
- (c) is enforced by the new `assertDeclaredCommandsHaveBinaries` (this fix)

**Fold:** Add explicit assertions to the CHANGELOG under 1.0.3 so a future reader can trace the whole argument. Update the risk ledger to name all three parts as invariants.

**Disposition:** Accept — 1 CHANGELOG bullet + 3 risk ledger rows for the argument's three parts.

### Finding ST-2 (MEDIUM) — postflight cannot detect a stale settings.json

If upstream's settings.json gets out of sync with its own tree (a stale command referring to a removed hook), postflight would catch it as a declared-command miss. But if settings.json OMITS a command that SHOULD be there, postflight cannot detect it.

**Fold:** Add a risk ledger row naming this asymmetry. Cli cannot solve it; upstream must.

**Disposition:** Accept — document; no code change in cli.

---

## Lens 3 — Hyrum Wright (observable behavior contract)

**Signature:** *"With a sufficient number of users of an API, it does not matter what you promise; every observable behavior of your system will be depended on."*

### Finding HW-1 (HIGH) — every file the tarball ships is now a de facto adopter contract

Once 1.0.3 ships every file in the sibling tree, adopters may inspect the tarball, notice `trace-helper.sh`, and source it from their own custom hooks. Removing `trace-helper.sh` later would break those adopters.

**Fold:** Explicitly document in the goal doc's "Ratchet" section (via risk ledger) that the tarball's file list is a Hyrum-contract with adopters. Removal of any file requires ADR-031 compat window. Sister ticket bassclef-upstream#1684 (shared-construct amendment discipline) applies.

**Disposition:** Accept — risk ledger row + reference to bassclef-upstream#1684.

### Finding HW-2 (LOW) — the executable bit is now depended on

Some adopters may `source` a helper by relying on shebang + exec bit rather than explicit `bash <path>`. If a future upstream commit strips the exec bit off a helper, adopters break.

**Fold:** Add a risk ledger row. Cli preserves the exec bit already; the risk is upstream drift.

**Disposition:** Accept — document; no cli change needed.

---

## Lens 4 — Rich Hickey (simple vs easy)

**Signature:** *"Simple is objective. Easy is subjective. Prefer simple even when it is not easy."*

### Finding RH-1 (MEDIUM) — the primary consult calls the tree-copy shape "simpler" without defining simple

Rich would push back on the word. The command-filter shape was one thing (a filter). The tree-copy shape is one thing (a recursive walk). Both are single-purpose. What makes tree-copy simpler?

**Answer:** Tree-copy is simpler because it has ONE input (the sibling tree) and ONE output (the cli tree). Command-filter had TWO inputs (the tree AND the settings.json commands list) that had to agree. Two-input shapes are more complex than one-input shapes — Rich would agree with that framing.

**Fold:** Reword the goal doc's "Fix" section to name the input-count reduction explicitly rather than just calling the new shape "simpler."

**Disposition:** Accept — goal doc reword.

### Finding RH-2 (LOW) — postflight adds back a two-input coupling

Postflight compares the tree AND the settings.json. That is the same two-input coupling Rich just complained about, moved from the walker to the last-check.

**Answer:** Yes — but the coupling now lives at a boundary, not in the walk itself. That is defensible per Rich's own "complected" discourse: keeping the coupling out of the primary computation.

**Fold:** No change. Rich's critique is noted but the postflight lives at the correct layer.

**Disposition:** Reject — the split is intentional.

---

## Lens 5 — Saltzer & Schroeder (defensive design)

**Signature:** *"Complete mediation — every access is checked against the authority mechanism."*

### Finding SS-1 (HIGH) — symlink refusal must fire on EVERY entry, not just top-level

The recursive walk must `lstat` every entry — top-level AND nested. A symlink hidden inside `session-reflection.d/` must fail the same way a top-level symlink fails.

**Fold:** Test list adds "symlink at nested depth fails loud". Fixture includes a nested symlink case.

**Disposition:** Accept — add fixture + test row.

### Finding SS-2 (MEDIUM) — postflight only asserts declared commands; helpers pass silently

If an adopter's hook depends on a helper that gets renamed at upstream (say, `trace-helper.sh` → `trace.sh`), the tarball ships both under the new name, but the adopter's hook breaks at runtime with the old name.

**Fold:** Cannot solve at cli. Add a risk ledger row: "helper renames upstream break adopters silently." Reference bassclef-upstream#1684 (shared-construct amendment discipline).

**Disposition:** Accept — document; upstream ticket already exists.

### Finding SS-3 (LOW) — no signature check on the tree

The cli trusts the sibling checkout's file contents implicitly. A malicious commit to public bassclef between pin-time and publish-time could inject content. The `Assert pinned bassclef tag resolves` step (workflow L130-143) catches tag drift but not intra-tag content mutation.

**Fold:** Cannot solve at cli without signed commits or content-hash verification. Add a risk ledger row: "trust sibling contents implicitly; no signature check." Reference the sibling-repo trust boundary in ADR-004.

**Disposition:** Accept — document; deferred to a future signed-commits ADR.

---

## Council summary

| ID | Severity | Disposition | Action in this goal |
|---|---|---|---|
| HT-1 | HIGH | Accept | ADR-007 amendment names the two-source split |
| HT-2 | MEDIUM | Accept | One-line addition to ADR-007 amendment |
| ST-1 | HIGH | Accept | CHANGELOG bullet + 3 risk ledger rows |
| ST-2 | MEDIUM | Accept | Risk ledger row |
| HW-1 | HIGH | Accept | Risk ledger row + bassclef-upstream#1684 reference |
| HW-2 | LOW | Accept | Risk ledger row |
| RH-1 | MEDIUM | Accept | Goal doc reword |
| RH-2 | LOW | Reject | Split is intentional |
| SS-1 | HIGH | Accept | Test list + fixture add nested-symlink case |
| SS-2 | MEDIUM | Accept | Risk ledger row |
| SS-3 | LOW | Accept | Risk ledger row |

## Findings roll into risk ledger v2

Every accepted finding produces a risk ledger row with fold + disposition. Ledger jumps from v1 (~8 primary risks) to v2 (~15+ once RFC folds land).

## Falsification of the primary consult

The primary consult claimed the fix was "contract-first + walking-skeleton first + fail-fast at the boundary." The adversarial council did NOT overturn that framing. Every HIGH finding either:
- Strengthens the framing (HT-1, ST-1 make the contract more explicit)
- Extends the framing to a new dimension the primary missed (HW-1 makes the file-list itself a contract; SS-1 extends the mediation to nested depth)

No adversarial lens argued for keeping the command-filter shape. The direction is confirmed.

## Deferred to a future goal

- Signed-commits verification on sibling checkout (SS-3)
- Adopter-facing helper-rename discipline (SS-2; upstream owns via bassclef-upstream#1684)
