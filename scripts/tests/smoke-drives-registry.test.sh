#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/lib/smoke-drives-registry.sh

# test-list:
# [x] File exists
# [x] Sources cleanly (no side effects)
# [x] Registers onboard-repo drive
# [x] Registers riff drive
# [x] Registers launch drive
# [x] smoke_drives_list emits 3 slugs sorted
# [x] smoke_drives_get_script returns non-empty path per slug
# [x] smoke_drives_get_timeout returns positive integer per slug
# [x] smoke_drives_get_artifacts returns non-empty CSV per slug
# [x] Missing slug returns exit 1

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/smoke-drives-registry.sh"

PASS=0
FAIL=0
FAIL_MSGS=()

assert_true() {
  if eval "$2" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $1")
  fi
}

assert_eq() {
  local desc="$1"; local expected="$2"; local actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("FAIL: $desc  (expected '$expected', got '$actual')")
  fi
}

assert_true "file exists" "[ -f '$LIB' ]"
assert_true "sources cleanly" "source '$LIB'"

source "$LIB"

for slug in onboard-repo riff launch; do
  assert_true "registers $slug" "smoke_drives_get_script '$slug'"
done

list_output=$(smoke_drives_list)
expected_list=$'launch\nonboard-repo\nriff'
assert_eq "smoke_drives_list emits sorted slugs" "$expected_list" "$list_output"

for slug in onboard-repo riff launch; do
  script=$(smoke_drives_get_script "$slug")
  assert_true "smoke_drives_get_script $slug returns non-empty" "[ -n '$script' ]"

  timeout=$(smoke_drives_get_timeout "$slug")
  assert_true "smoke_drives_get_timeout $slug returns positive integer" "[[ '$timeout' =~ ^[0-9]+$ ]] && [ '$timeout' -gt 0 ]"

  artifacts=$(smoke_drives_get_artifacts "$slug")
  assert_true "smoke_drives_get_artifacts $slug returns non-empty" "[ -n '$artifacts' ]"
done

set +e
smoke_drives_get_script "does-not-exist" >/dev/null 2>&1
rc=$?
set -e
assert_eq "missing slug returns exit 1" "1" "$rc"

echo ""
echo "smoke-drives-registry.sh Tier 0 tests: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  printf '  %s\n' "${FAIL_MSGS[@]}"
  exit 1
fi
exit 0
