#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/tests/validate-cross-repo-contracts.test.sh
#
# Tier 0 characterization test for scripts/validate-cross-repo-contracts.sh.
# Vendored from bassclef-upstream main 320f445b per cli#415 (ADR-059 step 4).
#
# Pins 10 behaviors across 7 test-sufficiency criteria:
#   - Exit code matrix (0, 1, 2, 4)
#   - Override path (SKIP_CROSS_REPO_VALIDATE)
#   - Dependency handling (jq hard, ajv graceful-missing)
#   - stderr format (contract name + reason)
#   - Registry schema validation (whole-file ajv)
#   - Positive + negative paths (current registry OK; bad schema_ref blocks)
#
# @pattern patterns/code/feathers/characterization-test.md

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-cross-repo-contracts.sh"
SCRATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_ROOT"' EXIT

# test-list:
# [x] T01 validator script exists at expected path + is executable
# [x] T02 --help prints usage and exits 0
# [x] T03 happy path: current registry validates (exit 0, OK line in stderr)
# [x] T04 SKIP_CROSS_REPO_VALIDATE=1 bypasses with exit 0
# [x] T05 missing registry file exits 2
# [x] T06 missing schema file exits 2
# [x] T07 bad schema_ref path in registry (RED) exits 4
# [x] T08 bad test_refs path in registry (RED) exits 4
# [x] T09 malformed registry JSON exits 1 (jq failure)
# [x] T10 ajv missing — graceful skip (schema check skipped; file + path checks run)

PASS=0
FAIL=0
FAIL_MSGS=()

fail() {
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("$1")
}

ok() {
  PASS=$((PASS + 1))
}

# ---------------------------------------------------------------------
# Fixture helper — scaffold a scratch repo with registry + schemas
# ---------------------------------------------------------------------
build_scratch_repo() {
  local scratch="$1"
  mkdir -p "$scratch/scripts" "$scratch/standards/state-spine/schemas" "$scratch/tests"
  cp "$VALIDATOR" "$scratch/scripts/validate-cross-repo-contracts.sh"
  cp "$REPO_ROOT/standards/state-spine/schemas/cross-repo-contracts.schema.json" \
     "$scratch/standards/state-spine/schemas/cross-repo-contracts.schema.json"
  cp "$REPO_ROOT/standards/state-spine/schemas/install-written-paths.schema.json" \
     "$scratch/standards/state-spine/schemas/install-written-paths.schema.json"
  cp "$REPO_ROOT/standards/cross-repo-contracts.json" "$scratch/standards/cross-repo-contracts.json"
  # Stub the test_refs file so the current registry validates clean
  touch "$scratch/tests/init-install-written-paths.test.ts"
}

# ---------------------------------------------------------------------
# T01 — script exists + executable
# ---------------------------------------------------------------------
if [ -x "$VALIDATOR" ]; then
  ok
else
  fail "T01: validator missing or not executable at $VALIDATOR"
fi

# ---------------------------------------------------------------------
# T02 — --help prints usage and exits 0
# ---------------------------------------------------------------------
help_out="$(bash "$VALIDATOR" --help 2>&1)"
help_rc=$?
if [ "$help_rc" -eq 0 ] && echo "$help_out" | grep -q "Usage:"; then
  ok
else
  fail "T02: --help should exit 0 and print Usage (got rc=$help_rc)"
fi

# ---------------------------------------------------------------------
# T03 — happy path: current registry validates
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t03"
build_scratch_repo "$scratch"
t03_out="$(bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t03_rc=$?
if [ "$t03_rc" -eq 0 ] && echo "$t03_out" | grep -q "OK    install-written-paths"; then
  ok
else
  fail "T03: happy path should exit 0 with OK line (rc=$t03_rc, out=$t03_out)"
fi

# ---------------------------------------------------------------------
# T04 — SKIP_CROSS_REPO_VALIDATE=1 bypasses with exit 0
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t04"
build_scratch_repo "$scratch"
rm "$scratch/standards/cross-repo-contracts.json"  # would normally fail with exit 2
t04_out="$(SKIP_CROSS_REPO_VALIDATE=1 bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t04_rc=$?
if [ "$t04_rc" -eq 0 ] && echo "$t04_out" | grep -q "SKIP_CROSS_REPO_VALIDATE=1 — bypassed"; then
  ok
else
  fail "T04: SKIP_CROSS_REPO_VALIDATE=1 should bypass + exit 0 (rc=$t04_rc, out=$t04_out)"
fi

# ---------------------------------------------------------------------
# T05 — missing registry exits 2
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t05"
build_scratch_repo "$scratch"
rm "$scratch/standards/cross-repo-contracts.json"
t05_out="$(bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t05_rc=$?
if [ "$t05_rc" -eq 2 ] && echo "$t05_out" | grep -q "registry file missing"; then
  ok
else
  fail "T05: missing registry should exit 2 (got rc=$t05_rc, out=$t05_out)"
fi

# ---------------------------------------------------------------------
# T06 — missing schema file exits 2
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t06"
build_scratch_repo "$scratch"
rm "$scratch/standards/state-spine/schemas/cross-repo-contracts.schema.json"
t06_out="$(bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t06_rc=$?
if [ "$t06_rc" -eq 2 ] && echo "$t06_out" | grep -q "registry schema file missing"; then
  ok
else
  fail "T06: missing registry schema should exit 2 (got rc=$t06_rc, out=$t06_out)"
fi

# ---------------------------------------------------------------------
# T07 — bad schema_ref path (RED) exits 4
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t07"
build_scratch_repo "$scratch"
# Rewrite registry schema_ref to point at a missing file
jq '.contracts[0].schema_ref = "standards/state-spine/schemas/does-not-exist.schema.json"' \
   "$scratch/standards/cross-repo-contracts.json" > "$scratch/standards/cross-repo-contracts.json.tmp"
mv "$scratch/standards/cross-repo-contracts.json.tmp" "$scratch/standards/cross-repo-contracts.json"
t07_out="$(bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t07_rc=$?
if [ "$t07_rc" -eq 4 ] && echo "$t07_out" | grep -q "schema_ref missing"; then
  ok
else
  fail "T07: bad schema_ref should exit 4 (got rc=$t07_rc, out=$t07_out)"
fi

# ---------------------------------------------------------------------
# T08 — bad test_refs path (RED) exits 4
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t08"
build_scratch_repo "$scratch"
jq '.contracts[0].test_refs = ["tests/does-not-exist.test.ts"]' \
   "$scratch/standards/cross-repo-contracts.json" > "$scratch/standards/cross-repo-contracts.json.tmp"
mv "$scratch/standards/cross-repo-contracts.json.tmp" "$scratch/standards/cross-repo-contracts.json"
t08_out="$(bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t08_rc=$?
if [ "$t08_rc" -eq 4 ] && echo "$t08_out" | grep -q "test_refs path missing"; then
  ok
else
  fail "T08: bad test_refs should exit 4 (got rc=$t08_rc, out=$t08_out)"
fi

# ---------------------------------------------------------------------
# T09 — malformed registry JSON exits 1 (jq fail)
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t09"
build_scratch_repo "$scratch"
echo "{ this is not json" > "$scratch/standards/cross-repo-contracts.json"
t09_out="$(bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t09_rc=$?
if [ "$t09_rc" -ne 0 ]; then
  ok
else
  fail "T09: malformed registry JSON should exit non-zero (got rc=$t09_rc, out=$t09_out)"
fi

# ---------------------------------------------------------------------
# T10 — ajv missing — graceful skip
# Simulate ajv absence by shadowing PATH to a dir with jq but not ajv.
# ---------------------------------------------------------------------
scratch="$SCRATCH_ROOT/t10"
build_scratch_repo "$scratch"
PATH_SHADOW="$SCRATCH_ROOT/t10-path"
mkdir -p "$PATH_SHADOW"
ln -sf "$(command -v jq)" "$PATH_SHADOW/jq"
ln -sf "$(command -v bash)" "$PATH_SHADOW/bash"
ln -sf "$(command -v mktemp)" "$PATH_SHADOW/mktemp"
ln -sf "$(command -v mkdir)" "$PATH_SHADOW/mkdir"
ln -sf "$(command -v rm)" "$PATH_SHADOW/rm"
ln -sf "$(command -v cat)" "$PATH_SHADOW/cat"
ln -sf "$(command -v echo)" "$PATH_SHADOW/echo"
# PATH contains only shadow dir — ajv not present
t10_out="$(PATH="$PATH_SHADOW" bash "$scratch/scripts/validate-cross-repo-contracts.sh" --repo-root "$scratch" 2>&1)"
t10_rc=$?
if [ "$t10_rc" -eq 0 ] && echo "$t10_out" | grep -q "ajv not installed — graceful skip"; then
  ok
else
  fail "T10: ajv-missing should graceful-skip + exit 0 (rc=$t10_rc, out=$t10_out)"
fi

# ---------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------
echo "pass=$PASS fail=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  %s\n' "${FAIL_MSGS[@]}"
  exit 1
fi
exit 0
