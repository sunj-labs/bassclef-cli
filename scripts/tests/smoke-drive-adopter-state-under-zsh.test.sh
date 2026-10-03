#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter was trying to: run any bassclef skill that reads project
# state (/sprint, /whereami, /temperance, /verify) from their zsh
# shell without the first state call wiping PATH and breaking every
# subsequent subprocess.
#
# Pins Kunal #2036 finding #6 (zsh PATH kill — zsh ties `path` and
# `PATH` as linked variables; `local path="..."` inside a function
# wiped PATH for the function scope under zsh, invisible under bash).
#
# Upstream cure: bassclef-upstream PRs #2043 + #2045 (part of
# release-2026-10-03-89ceaa15, tag v1.7.0). PR #2043 renamed
# `local path=` → `local p=` across 7 functions in lib/state.sh.
# PR #2045 closed the full class across 10 more lib files (24 more
# occurrences). All four zsh-magic variable names (`path`, `cdpath`,
# `fpath`, `manpath`) covered by the sweep.
#
# Pre-cure characterization: at parent of upstream PR #2043,
# `grep -c "local path=" lib/state.sh` returns 7.
# Current cured state (post-v1.7.0): zero matches across the lib tree.
#
# UC: docs/use-cases/UC-script-cli-294-driver-3-state-under-zsh.md
# Risk ledger: docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md
# Parent: cli#294 Step 5

# test-list:
# [x] T01 bundled dist/lite/lib has zero matches for `local path=`
# [x] T02 bundled dist/lite/lib has zero matches for `local cdpath=` / `local fpath=` / `local manpath=`
# [x] T03 sibling lib (if available) has zero matches for all four patterns
# [x] T04 SKIP cleanly if no lib dir reachable (dist/lite/ + sibling both absent)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Patterns — the four zsh-magic linked variable names
ZSH_PATTERNS='local path=|local cdpath=|local fpath=|local manpath='

# Scan a lib dir for the patterns; return hit count
scan_lib_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    echo "0"
    return
  fi
  grep -rEcl "$ZSH_PATTERNS" "$dir"/*.sh 2>/dev/null | wc -l | tr -d ' '
}

count_hits_detail() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    return
  fi
  grep -rnE "$ZSH_PATTERNS" "$dir"/*.sh 2>/dev/null || true
}

# Resolve lib dirs — bundled first, sibling cross-check
BUNDLED_LIB="$REPO_ROOT/dist/lite/lib"
SIBLING_LIB=""

if [ -n "${BASSCLEF_SIBLING_ROOT:-}" ] && [ -d "$BASSCLEF_SIBLING_ROOT/lib" ]; then
  SIBLING_LIB="$BASSCLEF_SIBLING_ROOT/lib"
elif [ -d "$HOME/src/sunj-labs/bassclef/lib" ]; then
  SIBLING_LIB="$HOME/src/sunj-labs/bassclef/lib"
fi

if [ ! -d "$BUNDLED_LIB" ] && [ -z "$SIBLING_LIB" ]; then
  echo "SKIP (T04): no lib dir reachable at dist/lite/lib or sibling" >&2
  exit 77
fi

# T01 + T02 — bundled dist/lite/lib
if [ -d "$BUNDLED_LIB" ]; then
  BUNDLED_HITS="$(count_hits_detail "$BUNDLED_LIB")"
  if [ -z "$BUNDLED_HITS" ]; then
    PASS=$((PASS + 2))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("T01/T02 FAIL: dist/lite/lib carries zsh-magic matches:")
    FAIL_MSGS+=("$BUNDLED_HITS")
  fi
else
  echo "NOTE: dist/lite/lib absent; T01/T02 skipped (run prepublish-bundle-substrate.mjs to populate)" >&2
fi

# T03 — sibling lib
if [ -n "$SIBLING_LIB" ]; then
  SIBLING_HITS="$(count_hits_detail "$SIBLING_LIB")"
  if [ -z "$SIBLING_HITS" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("T03 FAIL: sibling lib ($SIBLING_LIB) carries zsh-magic matches:")
    FAIL_MSGS+=("$SIBLING_HITS")
  fi
fi

# Summary
echo "driver-3 state-under-zsh: $PASS pass / $FAIL fail (bundled=$BUNDLED_LIB sibling=$SIBLING_LIB)"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
