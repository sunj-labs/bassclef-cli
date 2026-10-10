#!/usr/bin/env bash
# tier: upstream
#
# scripts/tests/smoke-drive-adopter-323-save-state-prototype-exclude.test.sh
#
# Characterization driver — cli#323 save-state.sh auto-save commits
# unreviewed prototype edits.
#
# dist/lite/.claude/hooks/save-state.sh L211-212 stages tracked modified
# files + docs/ paths without excluding docs/prototypes/. The L216 line
# excludes state/markers/ with the ':!state/markers' pathspec idiom; the
# prototype path needs the same treatment.
#
# .claude/rules/prototype-workflow.md: "They MUST NOT enter git history
# until the operator has confirmed the rendered output."
#
# Driver asserts the shipped hook still stages docs/ broadly without a
# docs/prototypes exclusion. When upstream applies the exclusion pattern,
# driver flips.
#
# @pattern patterns/code/feathers/characterization-test.md
#
# Exit codes:
#   0  — RED-CONFIRMED (hook stages docs/ without prototypes exclusion)
#   1  — GREEN-UNEXPECTED (exclusion present — cure reached adopters)
#   77 — SKIP (bundle not generated)

set -euo pipefail

# test-list:
# [x] Case 1 — hook stages docs/ broadly (git add docs/ present)
# [x] Case 2 — hook lacks docs/prototypes exclusion pathspec
# [x] Case 3 — bundle-absent SKIP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/dist/lite/.claude/hooks/save-state.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "SKIP|driver-323|$HOOK absent (run \`npm run bundle\` first)"
  exit 77
fi

# Case 1: hook adds docs/ broadly
count_add_docs=$(grep -cE "^[[:space:]]*git add[[:space:]].*docs/" "$HOOK" 2>/dev/null || echo 0)
count_add_docs=${count_add_docs//[^0-9]/}; count_add_docs=${count_add_docs:-0}

# Case 2: hook lacks docs/prototypes exclusion
# Pattern expected after cure: ':!docs/prototypes' OR ':(exclude)docs/prototypes'
count_exclude=$(grep -cE "[':]!docs/prototypes|:\(exclude\)docs/prototypes" "$HOOK" 2>/dev/null || echo 0)
count_exclude=${count_exclude//[^0-9]/}; count_exclude=${count_exclude:-0}

# Flipped to GREEN-confirms per ADR-011 D2 (post-cure anchor).
# PASS when docs/prototypes exclusion is present OR broad docs/ staging is gone.
# FAIL if both the broad staging returns AND the exclusion is missing.
if [[ "$count_add_docs" -gt 0 ]] && [[ "$count_exclude" -eq 0 ]]; then
  echo "REGRESSION|driver-323|shipped hook stages docs/ broadly (${count_add_docs} git add docs/ lines) without docs/prototypes exclusion"
  echo "FAIL: #323 auto-save-prototype-leak returned — cure reverted"
  exit 1
fi

echo "GREEN-CONFIRMED|driver-323|docs/prototypes exclusion present (count=${count_exclude}) OR docs/ staging removed (count=${count_add_docs}); #323 cure holds"
exit 0
