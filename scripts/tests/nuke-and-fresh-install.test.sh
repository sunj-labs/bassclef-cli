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
# [x] cli#444 — scope pre-check passes when token carries delete_repo
# [x] cli#444 — dry-run + --purge-adopter without delete_repo names the fix command
# [x] cli#444 — dry-run wording says "would stop", not "stopping"
# [x] cli#444 — dry-run without delete_repo still exits 0 (preview contract)
# [x] cli#444 — live + --delete-github without delete_repo exits 4
# [x] cli#444 — live hard-stop changes nothing (HOME/.claude untouched)
# [x] cli#444 — no delete flag means no scope pre-check (unchanged behavior)
# [x] cli#444 — unreadable scope list fails soft (proceeds, no hard-stop)
# [x] cli#444 — live hard-stop message says nothing was changed
# [x] cli#444 — scope error inside the delete loop hard-stops with exit 4
#
# Anchors: @luminary alan-cooper (CLI shape) + @luminary michael-feathers
# (characterization tests on stable observable output).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/nuke-and-fresh-install.sh"

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

echo "==> nuke-and-fresh-install.sh tests"

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
touch /tmp/nuke-and-fresh-install-sentinel-do-not-delete-me
out=$(bash "$SCRIPT" --dry-run 2>&1 || true)
ec=$(bash "$SCRIPT" --dry-run >/dev/null 2>&1 && echo 0 || echo $?)
assert "T4a: --dry-run exit 0" "0" "$ec"
assert_contains "T4b: --dry-run mentions DRY-RUN" "DRY-RUN" "$out"
if [ -f /tmp/nuke-and-fresh-install-sentinel-do-not-delete-me ]; then
  printf '  [PASS] T4c: --dry-run touches no real files\n'
  PASS=$((PASS + 1))
  rm -f /tmp/nuke-and-fresh-install-sentinel-do-not-delete-me
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

# ---------------------------------------------------------------------------
# cli#444 — --purge-adopter must stop before it starts when the gh token
# cannot delete repos. Tests stub gh / npm / bassclef on PATH and override
# HOME so a live-path run touches no real state.
# ---------------------------------------------------------------------------

FIX_CMD="gh auth refresh -h github.com -s delete_repo"

# Build a sandbox: fake HOME, fake bin dir with stubs.
# $1 = scope line body ("with" | "without" | "none")
# $2 = delete behavior ("ok" | "scope-error")
make_sandbox() {
  local scopes="$1"
  local delete_mode="${2:-ok}"
  local box
  box="$(mktemp -d)"
  mkdir -p "$box/home/.claude" "$box/bin"
  printf 'sentinel\n' > "$box/home/.claude/settings.json"

  case "$scopes" in
    with)    scope_line="  - Token scopes: 'delete_repo', 'gist', 'repo', 'workflow'" ;;
    without) scope_line="  - Token scopes: 'gist', 'repo', 'workflow'" ;;
    none)    scope_line="" ;;
  esac

  cat > "$box/bin/gh" <<GHSTUB
#!/usr/bin/env bash
case "\$1 \$2" in
  "auth status")
    echo "github.com"
    echo "  ✓ Logged in to github.com account stubuser (keyring)"
    [ -n "${scope_line}" ] && echo "${scope_line}"
    exit 0
    ;;
  "api user")
    echo "stubuser"
    exit 0
    ;;
  "repo list")
    echo '[{"nameWithOwner":"stubuser/bassclef-smoke-test-1"}]'
    exit 0
    ;;
  "repo delete")
    if [ "${delete_mode}" = "scope-error" ]; then
      echo "HTTP 403: Must have admin rights to Repository. (missing scope? requires 'delete_repo' PAT scope)" >&2
      exit 1
    fi
    exit 0
    ;;
esac
exit 0
GHSTUB

  cat > "$box/bin/npm" <<'NPMSTUB'
#!/usr/bin/env bash
exit 0
NPMSTUB

  cat > "$box/bin/bassclef" <<'BCSTUB'
#!/usr/bin/env bash
[ "$1" = "--version" ] && { echo "0.0.0-stub"; exit 0; }
exit 0
BCSTUB

  chmod +x "$box/bin/gh" "$box/bin/npm" "$box/bin/bassclef"
  printf '%s' "$box"
}

# T12: scope pre-check passes when the token carries delete_repo
box=$(make_sandbox with)
out=$(HOME="$box/home" PATH="$box/bin:$PATH" \
      bash "$SCRIPT" --dry-run --purge-adopter --workdir "$box/wd" 2>&1 || true)
if printf '%s' "$out" | grep -q -- "$FIX_CMD"; then
  printf '  [FAIL] T12: token has delete_repo but fix command still printed\n'
  FAIL=$((FAIL + 1))
else
  printf '  [PASS] T12: token with delete_repo triggers no scope warning\n'
  PASS=$((PASS + 1))
fi
rm -rf "$box"

# T13: dry-run + --purge-adopter without delete_repo names the fix command
box=$(make_sandbox without)
out=$(HOME="$box/home" PATH="$box/bin:$PATH" \
      bash "$SCRIPT" --dry-run --purge-adopter --workdir "$box/wd" 2>&1 || true)
ec=$(HOME="$box/home" PATH="$box/bin:$PATH" \
     bash "$SCRIPT" --dry-run --purge-adopter --workdir "$box/wd" >/dev/null 2>&1 && echo 0 || echo $?)
assert_contains "T13a: dry-run names the fix command" "$FIX_CMD" "$out"
assert_contains "T13b: dry-run names delete_repo in plain terms" "delete_repo" "$out"
# T14: dry-run wording is conditional, not a live stop
assert_contains "T14: dry-run says 'would stop'" "would stop" "$out"
# T15: dry-run keeps its exit-0 promise
assert "T15: dry-run without the permission still exits 0" "0" "$ec"
rm -rf "$box"

# T16: live + --delete-github without delete_repo exits 4
box=$(make_sandbox without)
ec=$(HOME="$box/home" PATH="$box/bin:$PATH" \
     bash "$SCRIPT" --delete-github --yes --workdir "$box/wd" >/dev/null 2>&1 && echo 0 || echo $?)
assert "T16: live run without the permission exits 4" "4" "$ec"
# T17: live hard-stop changed nothing
if [ -f "$box/home/.claude/settings.json" ]; then
  printf '  [PASS] T17: live hard-stop left HOME/.claude in place\n'
  PASS=$((PASS + 1))
else
  printf '  [FAIL] T17: live hard-stop moved HOME/.claude before checking scope\n'
  FAIL=$((FAIL + 1))
fi
# T18: message reassures that nothing changed
out=$(HOME="$box/home" PATH="$box/bin:$PATH" \
      bash "$SCRIPT" --delete-github --yes --workdir "$box/wd" 2>&1 || true)
assert_contains "T18a: live stop says nothing changed" "Nothing was changed" "$out"
assert_contains "T18b: live stop names the fix command" "$FIX_CMD" "$out"
assert_contains "T18c: live stop says 'stopping'" "stopping" "$out"
rm -rf "$box"

# T19: no delete flag means the scope pre-check never fires
box=$(make_sandbox without)
out=$(HOME="$box/home" PATH="$box/bin:$PATH" \
      bash "$SCRIPT" --dry-run --workdir "$box/wd" 2>&1 || true)
if printf '%s' "$out" | grep -q -- "$FIX_CMD"; then
  printf '  [FAIL] T19: scope warning fired without any delete flag\n'
  FAIL=$((FAIL + 1))
else
  printf '  [PASS] T19: no delete flag means no scope warning\n'
  PASS=$((PASS + 1))
fi
rm -rf "$box"

# T20: unreadable scope list fails soft
box=$(make_sandbox none)
ec=$(HOME="$box/home" PATH="$box/bin:$PATH" \
     bash "$SCRIPT" --delete-github --yes --workdir "$box/wd" >/dev/null 2>&1 && echo 0 || echo $?)
if [ "$ec" = "4" ]; then
  printf '  [FAIL] T20: unreadable scope list hard-stopped (expected fail-soft)\n'
  FAIL=$((FAIL + 1))
else
  printf '  [PASS] T20: unreadable scope list fails soft (exit %s)\n' "$ec"
  PASS=$((PASS + 1))
fi
rm -rf "$box"

# T21: a scope error inside the delete loop hard-stops with exit 4
box=$(make_sandbox with scope-error)
ec=$(HOME="$box/home" PATH="$box/bin:$PATH" \
     bash "$SCRIPT" --delete-github --yes --workdir "$box/wd" >/dev/null 2>&1 && echo 0 || echo $?)
assert "T21a: delete-loop scope error exits 4" "4" "$ec"
out=$(HOME="$box/home" PATH="$box/bin:$PATH" \
      bash "$SCRIPT" --delete-github --yes --workdir "$box/wd" 2>&1 || true)
assert_contains "T21b: delete-loop scope error names the fix command" "$FIX_CMD" "$out"
rm -rf "$box"

echo
echo "==> $PASS pass / $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
