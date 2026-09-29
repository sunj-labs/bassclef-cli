#!/usr/bin/env bash
# test-list:
# [x] --help prints usage + exits 0
# [x] --help without other args exits 0
# [x] -h alias works
# [x] unknown flag exits non-zero with error message
# [x] --dry-run prints planned steps + exits 0 without writing
# [x] --dry-run --version 1.2.3 shows version in plan
# [x] --dry-run --workdir /tmp/custom shows workdir in plan
# [x] --dry-run --keep-claude omits ~/.claude backup step from plan
# [x] --version requires an argument (bare --version exits non-zero)
# [x] --workdir requires an argument
# [x] script has execute bit
# [x] script starts with #!/usr/bin/env bash
#
# Anchors: @luminary alan-cooper (CLI shape) + @luminary michael-feathers
# (characterization tests on stable observable output).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/nuke-install.sh"

PASS=0
FAIL=0

assert() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf '  [PASS] %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s\n' "$name"
    printf '         expected: %q\n' "$expected"
    printf '         actual:   %q\n' "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1"
  local needle="$2"
  local haystack="$3"
  if printf '%s' "$haystack" | grep -q -- "$needle"; then
    printf '  [PASS] %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s\n' "$name"
    printf '         needle: %q\n' "$needle"
    printf '         haystack (first 200 chars): %q\n' "${haystack:0:200}"
    FAIL=$((FAIL + 1))
  fi
}

echo "==> nuke-install.sh tests"

# T1: --help prints usage + exits 0
out=$(bash "$SCRIPT" --help 2>&1 || true)
ec=$(bash "$SCRIPT" --help >/dev/null 2>&1 && echo 0 || echo $?)
assert "T1a: --help exit 0" "0" "$ec"
assert_contains "T1b: --help mentions Usage" "Usage" "$out"

# T2: -h alias
ec=$(bash "$SCRIPT" -h >/dev/null 2>&1 && echo 0 || echo $?)
assert "T2: -h exit 0" "0" "$ec"

# T3: unknown flag exits non-zero
ec=$(bash "$SCRIPT" --nope >/dev/null 2>&1 && echo 0 || echo $?)
if [ "$ec" != "0" ]; then
  printf '  [PASS] T3: --nope exits non-zero (%s)\n' "$ec"
  PASS=$((PASS + 1))
else
  printf '  [FAIL] T3: --nope exited 0 (expected non-zero)\n'
  FAIL=$((FAIL + 1))
fi

# T4: --dry-run prints plan + exit 0 without writing
touch /tmp/nuke-install-sentinel-do-not-delete-me
out=$(bash "$SCRIPT" --dry-run 2>&1 || true)
ec=$(bash "$SCRIPT" --dry-run >/dev/null 2>&1 && echo 0 || echo $?)
assert "T4a: --dry-run exit 0" "0" "$ec"
assert_contains "T4b: --dry-run mentions DRY-RUN" "DRY-RUN" "$out"
if [ -f /tmp/nuke-install-sentinel-do-not-delete-me ]; then
  printf '  [PASS] T4c: --dry-run touches no real files\n'
  PASS=$((PASS + 1))
  rm -f /tmp/nuke-install-sentinel-do-not-delete-me
else
  printf '  [FAIL] T4c: sentinel got deleted; dry-run did real work\n'
  FAIL=$((FAIL + 1))
fi

# T5: --dry-run --version 1.2.3 shows version
out=$(bash "$SCRIPT" --dry-run --version 1.2.3 2>&1 || true)
assert_contains "T5: --version shows in plan" "1.2.3" "$out"

# T6: --dry-run --workdir /tmp/custom-workdir shows workdir
out=$(bash "$SCRIPT" --dry-run --workdir /tmp/custom-workdir 2>&1 || true)
assert_contains "T6: --workdir shows in plan" "/tmp/custom-workdir" "$out"

# T7: --keep-claude omits backup step
out=$(bash "$SCRIPT" --dry-run --keep-claude 2>&1 || true)
if printf '%s' "$out" | grep -qE "would (back|move).*\.claude"; then
  printf '  [FAIL] T7: --keep-claude still mentions backup step\n'
  FAIL=$((FAIL + 1))
else
  printf '  [PASS] T7: --keep-claude omits backup step\n'
  PASS=$((PASS + 1))
fi

# T8: --version requires argument
ec=$(bash "$SCRIPT" --version >/dev/null 2>&1 && echo 0 || echo $?)
if [ "$ec" != "0" ]; then
  printf '  [PASS] T8: bare --version exits non-zero (%s)\n' "$ec"
  PASS=$((PASS + 1))
else
  printf '  [FAIL] T8: bare --version exited 0 (expected non-zero)\n'
  FAIL=$((FAIL + 1))
fi

# T9: --workdir requires argument
ec=$(bash "$SCRIPT" --workdir >/dev/null 2>&1 && echo 0 || echo $?)
if [ "$ec" != "0" ]; then
  printf '  [PASS] T9: bare --workdir exits non-zero (%s)\n' "$ec"
  PASS=$((PASS + 1))
else
  printf '  [FAIL] T9: bare --workdir exited 0 (expected non-zero)\n'
  FAIL=$((FAIL + 1))
fi

# T10: script has execute bit
if [ -x "$SCRIPT" ]; then
  printf '  [PASS] T10: script is executable\n'
  PASS=$((PASS + 1))
else
  printf '  [FAIL] T10: script missing execute bit\n'
  FAIL=$((FAIL + 1))
fi

# T11: shebang
first=$(head -1 "$SCRIPT")
assert "T11: shebang" "#!/usr/bin/env bash" "$first"

echo
echo "==> $PASS pass / $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
