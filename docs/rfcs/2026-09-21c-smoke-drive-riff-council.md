---
tier: lite
slug: 2026-09-21c-smoke-drive-riff-council
date: 2026-09-21
scope: Epic #199 Story 1 — smoke-drive-riff
authoring_set: [alistair-cockburn, andreas-zeller, michael-feathers]
council: [michael-nygard, alan-cooper, saltzer-schroeder, donald-norman, linus-torvalds]
disposition: Revised A — accept scope, cure 1 HIGH + 3 MEDIUM inline, defer 2 LOW
preflight_skip: architect-review fires AFTER code per operator direction (nothing to review pre-code); goal doc fields are in spec + decomp + luminary marker
references:
  - docs/specs/2026-09-21c-smoke-drive-riff.md
  - docs/use-cases/UC-smoke-drive-riff.md
  - docs/decompositions/2026-09-21c-smoke-drive-riff.md
  - docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md
---

# RFC — outside-luminary council review for smoke-drive-riff

## Sources read

- `docs/specs/2026-09-21c-smoke-drive-riff.md`
- `docs/use-cases/UC-smoke-drive-riff.md`
- `docs/decompositions/2026-09-21c-smoke-drive-riff.md`
- `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md`
- `scripts/smoke-drive-onboard-repo.sh` (the template)

## What I'm NOT reading (with reason)

- `/architect-review` marker — pre-code review has nothing to review; deferred to after code lands

---

## Council

| Luminary | Lens role |
|---|---|
| Michael Nygard | Stability patterns — exit-code map + Playwright BLOCK detection robustness |
| Alan Cooper | Operator experience — reading the drive output in harness reports |
| Saltzer & Schroeder | Complete mediation — scratch-dir teardown + path safety |
| Donald Norman | Signifier + feedback loop — capture readability + exit-code meanings |
| Linus Torvalds | Adopter contract — the cold-adopter harness IS the adopter contract |

None appear in the authoring set (Cockburn + Zeller + Feathers).

---

## Findings

### F1 [HIGH · Saltzer & Schroeder] — scratch dir path traversal

**Artifact:** `docs/decompositions/2026-09-21c-smoke-drive-riff.md` § Interface 2 (env vars) + the reset block that runs `rm -rf "$SCRATCH_DIR"`.

`RIFF_SCRATCH` accepts an arbitrary path. If the operator (or a misconfigured harness) sets it to `/` or `$HOME` directly, the reset step's `rm -rf` deletes far more than a scratch dir. The template `smoke-drive-onboard-repo.sh` inherits the same risk — but does not mitigate it either. Complete mediation says validate every input at the boundary.

**Cure inline (Revised A):** Add a `_validate_scratch_dir()` function. Canonicalize the path via `realpath`. Assert it is under `$HOME` or `/tmp` (case-insensitive prefix). Assert it is NOT one of {`/`, `$HOME`, `$HOME/`, `/tmp`, `/tmp/`}. Exit 1 with a clear message if any check fails. Also propose the same cure back at the onboard-repo template as a follow-on.

### F2 [MEDIUM · Nygard] — assertion sub-classes collapse to exit 3

**Artifact:** `docs/decompositions/2026-09-21c-smoke-drive-riff.md` § Interface 3 (exit code map).

Exit 3 covers three distinct failure modes: no HTML file, empty HTML file, HTML file without `<h2>`. Each suggests a different cure — no HTML means `/riff` did not author variants; empty means author aborted mid-write; no `<h2>` means the SKILL body shape changed. Rolling them into one exit hides the signal.

**Cure inline (Revised A):** Keep exit 3 for all three. Add stderr detail before exit — one of `FAIL:no-html`, `FAIL:empty-html`, `FAIL:no-h2`. The exit code stays stable for scripts; the message tells the reader which sub-class fired.

### F3 [MEDIUM · Nygard] — Playwright detection via grep is fragile

**Artifact:** `docs/decompositions/2026-09-21c-smoke-drive-riff.md` § Interface 4 (`check_env_miss`).

Grep for `playwright|mcp not enabled|cannot screenshot` catches today's `/riff` BLOCK message. A future SKILL rewrite could change the wording. Silent classification miss — env-degraded reports as skill regression.

**Cure inline (Revised A):** Expand the token list: `playwright|mcp|screenshot|puppeteer|chromium|browser` (case-insensitive). Add a Tier 0 test that a canonical Playwright BLOCK signature (from `~/.claude/skills/riff/SKILL.md` L98-99) matches the detector. Document the check as "signature-based, expand as new BLOCK messages surface."

### F4 [MEDIUM · Cooper] — exit codes are not human-readable

**Artifact:** `docs/decompositions/2026-09-21c-smoke-drive-riff.md` § Interface 3.

The reader glancing at a harness log sees "exit 3" or "exit 6" and has to look up which is which. Cooper says the interface should announce its meaning in the same breath as the number.

**Cure inline (Revised A):** Prepend a labeled stderr tag line before each exit:

- `smoke-drive-riff: PASS`
- `smoke-drive-riff: FAIL:<sub-class>` (per F2)
- `smoke-drive-riff: TIMEOUT`
- `smoke-drive-riff: ENV_DEGRADED:<token>` (per F3)
- `smoke-drive-riff: SETUP_FAIL:<reason>`

Same shape the harness's `smoke-report.sh` can grep. The exit code stays numeric.

### F5 [MEDIUM · Cooper] — exit 6 semantics need smoke-report awareness

**Artifact:** `harness/docker/entry.sh` V2 Step 7 wire-in + `scripts/smoke-report.sh` (the aggregator).

Exit 6 is a new signal. If `scripts/smoke-report.sh` rolls everything non-zero into a "fail" bucket, environment-degraded reports as skill-regression at the report level. This defeats F3's whole purpose.

**Cure inline (Revised A):** Add to the spec acceptance list: verify `scripts/smoke-report.sh` distinguishes exit 6. If it does not today, either amend the report script OR file a follow-on ticket in the same PR. Ship whichever comes cheapest.

### F6 [LOW · Norman] — exit codes lack semantic prefix

**Artifact:** Same as F4.

Subsumed by F4's tag-line cure. The tag names the class in words alongside the number.

**Disposition:** Absorbed into F4.

### F7 [LOW · Linus] — env-miss detection could false-positive

**Artifact:** `docs/decompositions/2026-09-21c-smoke-drive-riff.md` § Interface 4.

If Playwright IS present in a future adopter setup AND fails for a non-BLOCK reason that mentions the word "Playwright", the detector fires exit 6 (env-degraded) instead of exit 3 (real skill regression). Low probability today. Higher risk if Playwright ships in Docker later.

**Disposition:** DEFER. Note in the drive header. File a follow-on ticket if Playwright ships in the container.

---

## Disposition — Revised A

Accept the scope. Cure the HIGH + 3 MEDIUM findings inline. Defer 1 LOW to follow-on; absorb 1 LOW into another cure.

**Inline cures (this session):**

- F1 (Saltzer-Schroeder) — add `_validate_scratch_dir()` with path canonicalization + assertion. Propose the same cure to onboard-repo template as follow-on.
- F2 (Nygard) — assertion function returns REASON code; stderr message names the sub-class before exit 3.
- F3 (Nygard) — expand env-miss token list; add Tier 0 fixture test for known Playwright BLOCK signature.
- F4 (Cooper) — precede every exit with a labeled tag line. Consistent shape across pass/fail/timeout/env/setup.
- F5 (Cooper) — add acceptance-list item: verify `scripts/smoke-report.sh` distinguishes exit 6, or file follow-on.

**Deferrals (follow-on tickets at closeout):**

- F7 (Linus) — env-miss false-positive if Playwright present + non-BLOCK error. Low probability; document in drive header; file ticket when Playwright ships in Docker.

**Absorbed:**

- F6 (Norman) — semantic prefix on exit codes; F4's tag lines cover this.

---

## Amendments to source artifacts

The following inline edits ship in the same PR as this RFC:

1. `docs/specs/2026-09-21c-smoke-drive-riff.md` — add F1 path-validation acceptance; F2 sub-class stderr; F3 expanded token list; F4 tag-line contract; F5 acceptance item.
2. `docs/decompositions/2026-09-21c-smoke-drive-riff.md` — Interface 3 amended with tag-line spec + F2 sub-classes; Interface 4 expanded token list.
3. `docs/risk-ledgers/2026-09-21c-smoke-drive-riff.md` — add "RFC council absorbed" note referencing this file.

---

## Refs

- Spec, UC, decomp, risk ledger — this goal's ceremony chain
- `~/.claude/skills/riff/SKILL.md` L96-100 — the Playwright MUST + BLOCK tension F3 addresses
- `scripts/smoke-drive-onboard-repo.sh` — sibling template; F1 cure should propagate as follow-on
- `scripts/smoke-report.sh` — F5's report-side dependency
- @luminary michael-nygard — stability + fail-loud earlier
- @luminary alan-cooper — operator experience
- @luminary saltzer-schroeder — complete mediation
- @luminary donald-norman — signifier + feedback
- @luminary linus-torvalds — adopter contract
