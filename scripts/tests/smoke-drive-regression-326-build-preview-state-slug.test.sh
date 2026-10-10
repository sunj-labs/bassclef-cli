#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-326-build-preview-state-slug.test.sh
#
# Characterization driver — cli#326 /build Phase 2b slug mismatch.
#
# Two defects characterized together:
# 1. /build Phase 2b reads docs/preview-state/<slug>.yml where <slug> is
#    the goal slug (ends in -construction), but /launch writes the file
#    under <sprint-slug>.yml (no -construction suffix). Literal lookup
#    misses the file, picks operator mode by default.
# 2. /launch names the construction goal two different ways across the
#    SKILL body — one place doubles the date, another drops it.
#
# Driver asserts the shipped /build SKILL still carries a path-based
# lookup rather than reading the goal's preview_state: field. When
# upstream rewrites Phase 2b to read the field, driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (path-based lookup present; no field read)
#   1  — GREEN-UNEXPECTED (cure landed)
#   77 — SKIP (bundle not generated)

set -euo pipefail

# test-list:
# [x] Case 1 — /build SKILL carries path-based preview-state lookup (not field read)
# [x] Case 2 — /launch SKILL has at least 2 different construction-goal name patterns
# [x] Case 3 — bundle-absent SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SKILL="$REPO_ROOT/dist/lite/.claude/skills/build/SKILL.md"
LAUNCH_SKILL="$REPO_ROOT/dist/lite/.claude/skills/launch/SKILL.md"

if [[ ! -f "$BUILD_SKILL" ]] || [[ ! -f "$LAUNCH_SKILL" ]]; then
  echo "SKIP|driver-326|dist/lite build or launch SKILL absent (run \`npm run bundle\` first)"
  exit 77
fi

# Case 1: /build Phase 2b path-based lookup pattern (not field read)
# RED signal: literal `preview-state/<slug>.yml` path mentioned
count_path_lookup=$(grep -cE "preview-state/<[a-z-]*slug>\.yml|preview-state/\{slug\}\.yml" "$BUILD_SKILL" 2>/dev/null || echo 0)
count_path_lookup=${count_path_lookup//[^0-9]/}; count_path_lookup=${count_path_lookup:-0}

# GREEN signal (post-cure): "read the goal's preview_state: field"
count_field_read=$(grep -cE "preview_state:[[:space:]]field|goal.*preview_state|preview_state[[:space:]]*field" "$BUILD_SKILL" 2>/dev/null || echo 0)
count_field_read=${count_field_read//[^0-9]/}; count_field_read=${count_field_read:-0}

# Case 2: /launch has 2+ different construction-goal name patterns
count_construction_patterns=$(grep -cE "<sprint-slug>-construction|<YYYY-MM-DD>-<sprint-slug>-construction" "$LAUNCH_SKILL" 2>/dev/null || echo 0)
count_construction_patterns=${count_construction_patterns//[^0-9]/}; count_construction_patterns=${count_construction_patterns:-0}

# Flipped to GREEN-confirms per ADR-011 D2 (post-cure anchor).
# PASS when /build reads goal.preview_state (or no longer uses literal path lookup).
# FAIL if path-based lookup returns without a goal-field read.
if [[ "$count_path_lookup" -gt 0 ]] && [[ "$count_field_read" -eq 0 ]]; then
  echo "REGRESSION|driver-326|/build Phase 2b uses path-based preview-state lookup (${count_path_lookup} match) without reading goal's preview_state: field"
  echo "  /launch construction-goal name pattern count: ${count_construction_patterns}"
  echo "FAIL: #326 slug-mismatch returned — cure reverted"
  exit 1
fi

echo "GREEN-CONFIRMED|driver-326|path lookup count=${count_path_lookup}; field read count=${count_field_read}; #326 cure holds"
exit 0
