---
tier: lite
date: 2026-10-03
goal: cli#294 Step 4
code-class: new adopter-facing script (brief UC per .claude/rules/oo-ad-entry-point.md matrix row 7)
---

# UC-script-cli-294-driver-2 — build-against-template

## Primary actor

Smoke harness (CI docker-smoke OR local `bash scripts/tests/*.test.sh`).

## Goal

Assert that `/build` reads step enumerations from BOTH the new heading form (`## Steps enumerated` + `### Step-N`) and the legacy form (`## Workunits enumerated` + `### WU-N`) during the ADR-040 D1 grace window through 2026-10-31.

## Main success scenario

1. Harness writes a fixture spec at `/tmp/driver-2-$$/new.md` carrying `## Steps enumerated` + two `### Step-N` entries
2. Harness runs the awk extractor pulled from the bundled build SKILL
3. Harness pipes awk output through `grep -E '^### (Step|WU)-'`
4. Harness asserts >= 2 lines matched
5. Harness writes a second fixture at `/tmp/driver-2-$$/legacy.md` carrying `## Workunits enumerated` + two `### WU-N` entries
6. Harness runs the same awk extractor against the legacy fixture
7. Harness asserts >= 2 lines matched
8. Harness greps the bundled SKILL body for the dual-form pattern `## (Steps|Workunits) enumerated`
9. Exit 0

## Extensions

- 4a. New-form extractor returns < 2 lines → exit 1 naming the regression (awk range closes on own start, prior defect class)
- 7a. Legacy-form extractor returns < 2 lines → exit 1 naming grace-window drop
- 8a. SKILL body missing dual-form pattern → exit 1 naming the character of the regression

## Preconditions

- Bundled SKILL body reachable at `dist/lite/.claude/skills/build/SKILL.md` OR via `BASSCLEF_SIBLING_ROOT` OR via `~/src/sunj-labs/bassclef/`
- Bash 3.2+ with awk (macOS BSD awk works)

## Postconditions

- Current main: driver exits 0 (both heading forms resolve + SKILL carries dual-form)
- Pre-cure commit (parent of upstream PR #2043): driver exits 1 (awk range closes on `## Steps enumerated` self-match → 0 lines)

## Pattern

Characterization test per @luminary michael-feathers. The driver reads the actual cure (awk pattern) from the bundled SKILL body. Pre-cure characterization: at the parent commit of upstream PR #2043, the awk range form `/^## Steps enumerated/,/^## /` returns zero lines because `^## ` matches `^## Steps enumerated` and closes the range on its own start line.

## Covers

- Kunal #2036 finding #2 (/build Phase 1 awk range closes on own start)
- Kunal #2036 finding #3 (template heading mismatch — WU → step vocab rename grace window)

Adopter was trying to: run `/build` on their spec authored from the bundled template, see a non-zero step count, and advance the build cycle without re-authoring the spec headers by hand.
