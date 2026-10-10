#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter was trying to: paste the `SKIP_FOO=1 git commit -m "..."`
# recipe from a BLOCK banner, have the hook actually honor the
# override, and move past the gate without having to export the var
# at shell level.
#
# Pins Kunal #2036 finding #4 (SKIP_* env-reach override recipes).
# Pre-cure defect: inline `SKIP_FOO=1 cmd` set the var in git's
# subshell env, not the hook's env; hooks reading `${SKIP_FOO:-0}`
# missed the override.
#
# Upstream cure: bassclef-upstream PR #2042 (part of release-2026-10-03-89ceaa15, tag v1.7.0).
# Cure shape — `lib/skip-env-inline-check.sh` exports `skip_var_set`
# which parses `tool_input.command` for inline prefix + falls back
# to process env. Applied across 6 PreToolUse Bash hooks.
#
# UC: docs/use-cases/UC-script-cli-294-driver-4-env-reach-override.md
# Risk ledger: docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md
# Parent: cli#294 Step 6

# test-list:
# [x] T01 lib file exists at dist/lite/lib/skip-env-inline-check.sh or sibling
# [x] T02 skip_var_set returns 0 on inline prefix `SKIP_FOO=1 cmd`
# [x] T03 skip_var_set returns 1 when no prefix + no env
# [x] T04 skip_var_set returns 0 on process env fallback (SKIP_FOO=1 exported)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Locate the lib
SKIP_LIB=""
if [ -f "$REPO_ROOT/dist/lite/lib/skip-env-inline-check.sh" ]; then
  SKIP_LIB="$REPO_ROOT/dist/lite/lib/skip-env-inline-check.sh"
elif [ -n "${BASSCLEF_SIBLING_ROOT:-}" ] && [ -f "$BASSCLEF_SIBLING_ROOT/lib/skip-env-inline-check.sh" ]; then
  SKIP_LIB="$BASSCLEF_SIBLING_ROOT/lib/skip-env-inline-check.sh"
elif [ -f "$HOME/src/sunj-labs/bassclef/lib/skip-env-inline-check.sh" ]; then
  SKIP_LIB="$HOME/src/sunj-labs/bassclef/lib/skip-env-inline-check.sh"
fi

# T01 — lib exists (not SKIP; cure requires the file)
if [ -z "$SKIP_LIB" ]; then
  echo "T01 FAIL: lib/skip-env-inline-check.sh unreachable at dist/lite/, BASSCLEF_SIBLING_ROOT, or ~/src/sunj-labs/bassclef/" >&2
  echo "driver-4 env-reach-override: 0 pass / 1 fail (lib missing — pre-cure state)"
  exit 1
fi
PASS=$((PASS + 1))

# Source the lib (uses `local`, so wrap in a function scope)
# shellcheck disable=SC1090
source "$SKIP_LIB"

if ! declare -f skip_var_set >/dev/null 2>&1; then
  echo "T01b FAIL: skip_var_set function not exported after sourcing $SKIP_LIB" >&2
  exit 1
fi

# T02 — inline prefix returns 0
unset SKIP_FOO 2>/dev/null || true
if skip_var_set "SKIP_FOO" "SKIP_FOO=1 git commit -m test"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: skip_var_set did not detect inline prefix 'SKIP_FOO=1 git commit -m test'")
fi

# T03 — no prefix + no env returns 1
unset SKIP_FOO 2>/dev/null || true
if skip_var_set "SKIP_FOO" "git commit -m test"; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: skip_var_set returned 0 on bare command without env (false positive)")
else
  PASS=$((PASS + 1))
fi

# T04 — process env fallback returns 0
export SKIP_FOO=1
if skip_var_set "SKIP_FOO" "git commit -m test"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T04 FAIL: skip_var_set did not read process env SKIP_FOO=1 fallback")
fi
unset SKIP_FOO 2>/dev/null || true

# Summary
echo "driver-4 env-reach-override: $PASS pass / $FAIL fail (source: $SKIP_LIB)"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
