#!/usr/bin/env bash
# tier: standard
# scripts/tests/bassclef-pin.test.sh — Tier 0 tests for cli#188
# dynamic substrate pin.
#
# Validates two invariants:
#   1. `.bassclef-pin` at repo root exists, holds exactly one trimmed
#      line, matches the shape `v[0-9]+.[0-9]+.[0-9]+`.
#   2. NO workflow under `.github/workflows/` carries a hardcoded tag
#      like `ref: v1.X.Y` after a sibling checkout of
#      `sunj-labs/bassclef`. All such refs come from `${{ env.BASSCLEF_PIN }}`.
#
# T9 + T10 widen the scope from publish.yml to every workflow. Added for
# cli#482. This file read publish.yml alone, so `pr-checks.yml` sat on a
# hardcoded `ref: v1.1.1` while the pin named v1.11.1 -- a different tag,
# 27 days older. The full suite ran against one substrate version while
# publish shipped another, and the test that existed to catch exactly
# this was pointed at one file.
#
# Anchors:
#   @luminary tony-hoare — the pin file + its shape is a precondition
#                          contract for the publish workflow
#   @luminary michael-feathers — characterization test on the workflow
#                                shape so a regression is immediately
#                                visible
#   @luminary kent-beck — Tier 0 strict TDD on cli#188 primitive
#
# test-list:
# [x] T1: .bassclef-pin exists
# [x] T2: .bassclef-pin holds exactly one line
# [x] T3: pin value matches shape v<digits>.<digits>.<digits>
# [x] T4: pin value has no leading or trailing whitespace
# [x] T5: publish.yml has no hardcoded ref:v<N>.<N>.<N> after sibling repo
# [x] T6: publish.yml has at least one ref:${{ env.BASSCLEF_PIN }} after sibling repo
# [x] T7: both jobs read .bassclef-pin via a "Read" step
# [x] T8: assertion step uses $BASSCLEF_PIN env var not hardcoded
# [x] T9: EVERY workflow that checks out sunj-labs/bassclef reads the pin
# [x] T10: no workflow carries a hardcoded ref: v<N>.<N>.<N> after that repo

set -euo pipefail

PASS=0
FAIL=0
FAILED_NAMES=""

_pass() { PASS=$((PASS+1)); echo "  [PASS] $1"; }
_fail() { FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES $1"; echo "  [FAIL] $1"; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIN_FILE="$ROOT/.bassclef-pin"
WORKFLOW="$ROOT/.github/workflows/publish.yml"

echo "==> cli#188 dynamic substrate pin tests"

# T1
if [ -f "$PIN_FILE" ]; then
  _pass "T1: .bassclef-pin exists"
else
  _fail "T1: .bassclef-pin missing at $PIN_FILE"
fi

# T2
if [ -f "$PIN_FILE" ]; then
  LINE_COUNT=$(grep -cv '^[[:space:]]*$' "$PIN_FILE" || true)
  if [ "$LINE_COUNT" = "1" ]; then
    _pass "T2: .bassclef-pin holds exactly one non-empty line"
  else
    _fail "T2: .bassclef-pin has $LINE_COUNT non-empty lines (expected 1)"
  fi
fi

# T3
if [ -f "$PIN_FILE" ]; then
  PIN=$(tr -d '[:space:]' < "$PIN_FILE")
  if echo "$PIN" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    _pass "T3: pin value matches shape v<N>.<N>.<N> ($PIN)"
  else
    _fail "T3: pin value '$PIN' does not match shape v<N>.<N>.<N>"
  fi
fi

# T4
if [ -f "$PIN_FILE" ]; then
  RAW=$(head -1 "$PIN_FILE")
  if [ "$RAW" = "$(echo "$RAW" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" ]; then
    _pass "T4: pin value has no leading or trailing whitespace"
  else
    _fail "T4: pin value has whitespace padding"
  fi
fi

# T5 — no hardcoded ref:v<N>.<N>.<N> inside the sibling bassclef checkout steps
if [ -f "$WORKFLOW" ]; then
  # Look for lines like: `          ref: v1.8.0` under a checkout step
  # whose `repository:` is `sunj-labs/bassclef`. Simpler shape: scan
  # for `ref: v<digits>` NOT followed by anything resembling an env
  # expression on the SAME line.
  HARDCODED=$(grep -nE "^[[:space:]]+ref:[[:space:]]+v[0-9]+\.[0-9]+\.[0-9]+" "$WORKFLOW" | grep -v "env.BASSCLEF_PIN" || true)
  if [ -z "$HARDCODED" ]; then
    _pass "T5: publish.yml has no hardcoded ref:v<N>.<N>.<N> under sibling checkouts"
  else
    _fail "T5: publish.yml still has hardcoded ref lines: $HARDCODED"
  fi
fi

# T6 — at least one ref uses ${{ env.BASSCLEF_PIN }}
if [ -f "$WORKFLOW" ]; then
  if grep -qE '^[[:space:]]+ref:[[:space:]]+\$\{\{[[:space:]]*env\.BASSCLEF_PIN[[:space:]]*\}\}' "$WORKFLOW"; then
    _pass "T6: publish.yml carries at least one ref: \${{ env.BASSCLEF_PIN }}"
  else
    _fail "T6: publish.yml missing ref:\${{ env.BASSCLEF_PIN }} in sibling checkouts"
  fi
fi

# T7 — both jobs read .bassclef-pin via a step with "Read" in its name
if [ -f "$WORKFLOW" ]; then
  READ_COUNT=$(grep -cE "^[[:space:]]+-[[:space:]]+name:[[:space:]]+Read.*\.bassclef-pin" "$WORKFLOW" || true)
  if [ "$READ_COUNT" -ge 2 ]; then
    _pass "T7: both jobs have a Read .bassclef-pin step ($READ_COUNT found)"
  else
    _fail "T7: expected 2+ Read .bassclef-pin steps (checks + publish jobs); found $READ_COUNT"
  fi
fi

# T8 — assertion step compares against $BASSCLEF_PIN not a hardcoded string
if [ -f "$WORKFLOW" ]; then
  if grep -qE 'RESOLVED_TAG.*BASSCLEF_PIN' "$WORKFLOW" || grep -qE '\$BASSCLEF_PIN.*RESOLVED_TAG' "$WORKFLOW"; then
    _pass "T8: assertion step compares RESOLVED_TAG against \$BASSCLEF_PIN"
  else
    _fail "T8: assertion step does not use \$BASSCLEF_PIN for comparison"
  fi
fi

# ---------------------------------------------------------------------------
# T9 + T10 — every workflow, not just publish.yml (cli#482)
# ---------------------------------------------------------------------------

# Each workflow that names `repository: sunj-labs/bassclef` must read the
# pin, and must not pin a literal tag next to it.
WF_DIR="$ROOT/.github/workflows"
if [ -d "$WF_DIR" ]; then
  MISSING_READ=""
  HARDCODED=""
  for wf in "$WF_DIR"/*.yml; do
    [ -f "$wf" ] || continue
    grep -qE "repository:[[:space:]]+sunj-labs/bassclef[[:space:]]*$" "$wf" || continue
    base="$(basename "$wf")"

    if ! grep -qE "\\.bassclef-pin" "$wf"; then
      MISSING_READ="$MISSING_READ $base"
    fi

    # A literal tag on a `ref:` line anywhere in a workflow that checks out
    # the sibling. Narrow on purpose: `ref: ${{ ... }}` never matches.
    if grep -qE "^[[:space:]]+ref:[[:space:]]+v[0-9]+\\.[0-9]+\\.[0-9]+[[:space:]]*$" "$wf"; then
      HARDCODED="$HARDCODED $base"
    fi
  done

  if [ -z "$MISSING_READ" ]; then
    _pass "T9: every workflow checking out sunj-labs/bassclef reads .bassclef-pin"
  else
    _fail "T9: these check out sunj-labs/bassclef without reading the pin:$MISSING_READ"
  fi

  if [ -z "$HARDCODED" ]; then
    _pass "T10: no workflow carries a hardcoded ref: v<N>.<N>.<N> beside that checkout"
  else
    _fail "T10: hardcoded sibling tag in:$HARDCODED"
  fi
fi

echo ""
echo "==> $PASS pass / $FAIL fail"
if [ -n "$FAILED_NAMES" ]; then
  echo "FAILED:$FAILED_NAMES"
  exit 1
fi
exit 0
