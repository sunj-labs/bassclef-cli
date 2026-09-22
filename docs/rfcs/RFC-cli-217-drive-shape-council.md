---
tier: upstream
rfc_id: RFC-cli-217-drive-shape-council
parent_goal: 2026-09-22c-cli-217-drive-shape-cure
council: adversarial (outside lenses challenge cure design)
lenses: [hyrum-wright, linus-torvalds, jerome-saltzer-and-michael-schroeder, don-norman]
disposition: Revised A (fold 4 findings inline; defer 1)
---

# RFC council — cli #217 drive-shape cure

## Sources read

- `docs/goals/2026-09-22c-cli-217-drive-shape-cure.md`
- `docs/use-cases/UC-hook-docker-smoke-drive-shape.md`
- `docs/decompositions/2026-09-22c-cli-217-drive-shape-cure.md`
- `docs/risk-ledgers/2026-09-22c-cli-217-drive-shape-pre-mortem.md`
- `scripts/lib/smoke-assert.sh` — current Strategy set
- `scripts/smoke-drive-skills.sh` — current invocation

## Method

Four outside luminaries not in the authoring set challenge the cure design. Each lens surfaces 1-3 findings. Findings get folded (Revised A), folded-with-follow-up (Revised B), or deferred.

---

## Lens 1 — Hyrum Wright (Hyrum's Law)

**H1** — The 6 existing check functions are a **shipped contract** with every downstream harness that sources `smoke-assert.sh`. Adding new checks is safe (additive); RENAMING or CHANGING the signature of any existing check would break unknown consumers. Cure: additions only; do not touch existing signatures.
- **Disposition:** FOLD — decomposition already says "6 existing checks stay unchanged"; RFC surfaces the constraint explicitly.

**H2** — The stderr TAG lines (`smoke-drive-riff: PASS`, `FAIL:no-html`, etc.) are shipped shape. Downstream `smoke-report.sh` greps them. Cure: any new tag from new asserts MUST match the existing `<script>: <STATUS>:<sub-class>` pattern.
- **Disposition:** FOLD — new asserts emit tags following the existing pattern (`smoke-drive-skills: FAIL:unknown-command`).

---

## Lens 2 — Linus Torvalds (we don't break userspace)

**L1** — Existing `scripts/smoke-drive-skills.sh` may be sourced or invoked by downstream operator scripts that hardcode the 5-skill list. Changing the DEFAULT skill list breaks those. Cure: keep the DEFAULT_SKILLS list; only change the PROMPT SHAPE.
- **Disposition:** FOLD — cure changes the invocation, not the list. Slug parsing at L100 still works because the prompt template still begins with a slash-prefixed skill name embedded in it.

**L2** — Docker container's cached tarballs on adopter machines may hold prior smoke-drive-skills.sh with the old shape. When cli republishes, container caches invalidate. Test this — the cure is behind a cli publish, not a hot-reload.
- **Disposition:** FOLD (informational) — the cure is a cli change; adopters get it on next `npm install`. No new bindings; adopter upgrade path is standard.

**L3** — cli #212 sister PR merged `70450fe` extended `docker-smoke.yml` case statement for exit codes 20-25. My new exit codes (from `FAIL:unknown-command`) must fit within that range OR I need to extend the case again. Cure: use exit 3 (existing `FAIL:*` code) — no new exit codes.
- **Disposition:** FOLD — cure emits exit 3 for the new fail class; docker-smoke.yml already handles exit 3.

---

## Lens 3 — Jerome Saltzer & Michael Schroeder (complete mediation + fail-safe defaults)

**S1** — Positive-artifact assertions must fail-SAFE. If the marker directory doesn't exist (fresh container, first run), assertion should FAIL (no marker = no dispatch), not PASS (missing dir = "check skipped"). Cure: check_temperance_marker checks for marker file existence; missing dir counts as FAIL.
- **Disposition:** FOLD — asserts emit `FAIL|check-temperance-marker|no marker in <path>` on missing.

**S2** — The new `check_no_unknown_command` grep pattern must be exact ("Unknown command:") not partial ("Unknown") — partial matches false-positive on prose about unknown things ("The unknown command class was traced..."). Cure: exact grep `Unknown command:`.
- **Disposition:** FOLD — grep pattern is `'^Unknown command:|[^A-Za-z]Unknown command:'` — anchored to line start or word boundary.

**S3** — Every check function's failure MUST be surfaced to the operator with enough info to act (per complete-mediation). Fail messages include file path + first matching line for greppability.
- **Disposition:** FOLD — new checks follow existing `FAIL|<check>|<message>` format; message names offending line or missing artifact.

---

## Lens 4 — Don Norman (feedback + signifiers)

**N1** — When an assertion fails, the operator on the smoke report page sees `smoke-drive-skills: FAIL:unknown-command`. Norman: this doesn't tell them WHAT to do next. Cure: add one line of remediation to the fail output — "cure at scripts/smoke-drive-skills.sh L130; use natural-language prompt shape".
- **Disposition:** DEFER — remediation prose fits better in `smoke-report.sh` render, not in the check. File follow-on ticket after cure lands.

**N2** — Natural-language prompts differ from adopter's actual `/temperance` interactive usage. Norman: the drive should say so upfront in its help text — "drives use natural-language prompts to test skill dispatch; real adopters type slash-prefix interactively".
- **Disposition:** FOLD (light) — add one line to `scripts/smoke-drive-skills.sh` help text explaining the prompt shape choice.

**N3** — Positive-artifact for /kiss ("contains 'words' OR 'grade' OR 'rewritten'") — any of the 3 words fires PASS. Norman: this is too loose; a real /kiss output should contain ALL three, or at least a substrate marker (kiss doesn't produce filesystem side-effects unless run in `--rewrite` mode, which the drive passes). Cure: prompt calls `--rewrite` explicitly + assertion requires ≥2 of the 3 phrases.
- **Disposition:** FOLD — assert requires ≥2 of ["rewritten", "grade", "words"] via AND-semantics helper.

---

## Folded (7 findings)

1. **H1** — additive-only to smoke-assert.sh (recorded)
2. **H2** — new tag lines match existing `<script>: <STATUS>:<sub-class>` pattern
3. **L1** — DEFAULT_SKILLS list unchanged; only prompt shape swaps
4. **L3** — exit 3 for new fail class (no new exit codes)
5. **S1** — fail-safe on missing marker dir
6. **S2** — exact grep on `Unknown command:`
7. **N3** — /kiss assert requires ≥2 phrases (AND-semantics)

## Deferred (1 finding)

- **N1** — remediation prose in smoke-report → file follow-on `cli #218` (or attach to existing #215 evidence-row ticket) after cure lands

## Council disposition: Revised A

All 4 lenses raised at least one HIGH-value finding. 7 of 8 folded inline. Cure ships with the RFC folds baked in from the RED test phase.

## Refs

- `.claude/skills/rfc/SKILL.md`
- `.claude/luminaries/hyrum-wright.md`
- `.claude/luminaries/linus-torvalds.md`
- `.claude/luminaries/jerome-saltzer-and-michael-schroeder.md`
- `.claude/luminaries/don-norman.md`
