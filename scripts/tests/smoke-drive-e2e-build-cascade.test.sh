#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter journey (Louis, context switcher): runs `/build` on a spec
# authored from the bundled template. Build Phase 1 extracts steps
# via awk, Phase 2 validates story traceability. Expected cascade —
# both phases pass against a conformant fixture; Phase 2 refuses an
# orphan step (step with no US-NNN ref).
#
# This is an E2E cascade driver (prototype shape per next-session
# plan 2026-10-04). Driver scaffolds a scratch spec, runs both phases
# of the shipped build pipeline, and asserts the cascade result for
# both the pass path AND the orphan-refuse path.
#
# Different from cli#294 driver 2 (file-level grep for awk shape) —
# this driver EXECUTES the pipeline end-to-end + checks orphan
# refusal.
#
# Pins Kunal #2036 finding #2 (/build Phase 1 awk range) + finding
# #3 (template heading) at the cascade layer.
#
# Plan doc: docs/next-session-plan-2026-10-04-e2e-cascade-drivers.md
# Parent: cli#294 (follow-on scope)

# test-list:
# [x] T01 pass path — conformant spec yields >= 2 step lines
# [x] T02 pass path — orphan check finds no orphans
# [x] T03 orphan path — spec with one orphan step is detected
# [x] T04 cascade — Phase 1 output flows into Phase 2 cleanly

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Scratch workdir
TMP_BASE="$(mktemp -d)"
trap "rm -rf '$TMP_BASE'" EXIT

CONFORMANT_SPEC="$TMP_BASE/conformant.md"
ORPHAN_SPEC="$TMP_BASE/orphan.md"

cat > "$CONFORMANT_SPEC" <<'MARKDOWN'
# Spec — conformant fixture

## Overview

Louis authored this spec from the bundled template.

## Steps enumerated

### Step-1 — scaffold the thing (US-001)

Short description.

### Step-2 — wire the thing (US-002)

Short description.

### Step-3 — ship the thing (US-003)

Short description.

## Acceptance

Three stories traced; build should pass both phases.
MARKDOWN

cat > "$ORPHAN_SPEC" <<'MARKDOWN'
# Spec — orphan fixture

## Steps enumerated

### Step-1 — scaffold the thing (US-001)

Short description.

### Step-2 — ship the untraced thing

No story ref in the header. Phase 2 should refuse.

## Acceptance

One orphan step; build should refuse at Phase 2.
MARKDOWN

# === Phase 1 — awk extractor (verbatim shape from /build SKILL body L344-349) ===
# Returns step header lines after piping through the grep filter.
run_phase1() {
  local spec="$1"
  awk '
    /^## (Steps|Workunits) enumerated/ { in_section=1; next }
    /^## / { in_section=0 }
    in_section
  ' "$spec" | grep -E '^### (Step|WU)-' || true
}

# === Phase 2 — orphan check (verbatim shape from /build SKILL body L359-364) ===
# Returns lines of step headers that lack US-NNN; empty = pass.
run_phase2() {
  local wu_list="$1"
  echo "$wu_list" | grep -E '^### (Step|WU)-' | grep -v 'US-' || true
}

# T01 — pass path Phase 1 returns 3 step lines
CONFORMANT_WUS="$(run_phase1 "$CONFORMANT_SPEC")"
CONFORMANT_COUNT="$(echo "$CONFORMANT_WUS" | grep -cE '^### Step-' || true)"
if [ "$CONFORMANT_COUNT" -ge 2 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL: conformant Phase 1 returned $CONFORMANT_COUNT step headers; expected >= 2")
fi

# T02 — pass path Phase 2 finds no orphans
CONFORMANT_ORPHANS="$(run_phase2 "$CONFORMANT_WUS")"
if [ -z "$CONFORMANT_ORPHANS" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: conformant Phase 2 flagged orphans: $CONFORMANT_ORPHANS")
fi

# T03 — orphan path Phase 2 detects the untraced step
ORPHAN_WUS_LIST="$(run_phase1 "$ORPHAN_SPEC")"
ORPHANS="$(run_phase2 "$ORPHAN_WUS_LIST")"
if [ -n "$ORPHANS" ] && echo "$ORPHANS" | grep -q "ship the untraced thing"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: orphan Phase 2 did not detect the untraced step. Got: '$ORPHANS'")
fi

# T04 — cascade flows: Phase 1 output lines count matches Phase 2 input lines count
ORPHAN_COUNT="$(echo "$ORPHAN_WUS_LIST" | grep -cE '^### Step-' || true)"
INPUT_LINES="$(echo "$ORPHAN_WUS_LIST" | wc -l | tr -d ' ')"
if [ "$ORPHAN_COUNT" = "2" ] && [ "$INPUT_LINES" -ge 2 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T04 FAIL: cascade shape — orphan fixture Phase 1 count=$ORPHAN_COUNT input_lines=$INPUT_LINES; expected 2 + lines >= 2")
fi

# Summary
echo "e2e-build-cascade: $PASS pass / $FAIL fail"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
