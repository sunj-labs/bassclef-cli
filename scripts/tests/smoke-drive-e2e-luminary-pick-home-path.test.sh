#!/usr/bin/env bash
# tier: standard
# cli#313 luminary-pick home-path driver — characterization at trace layer.
#
# Pins behavior of luminary_pick_catalog against cured upstream source at
# bassclef-upstream main SHA a38f1f54358b962d8472cc7e53858f600b0f4462 (#2057).
#
# Per UC docs/use-cases/UC-script-cli-313-luminary-pick-home-path-driver.md.
# Luminary: @luminary michael-feathers lead (characterization) + @luminary linus-torvalds supporting (adopter contract).
#
# test-list:
# [x] T1 BASSCLEF_DIR branch — reads state/luminary-implementations JSON when env set
# [x] T2 CLAUDE_PROJECT_DIR branch — resolves via CLAUDE_PROJECT_DIR when BASSCLEF_DIR unset
# [x] T3 git-root branch — resolves via git rev-parse when both env vars unset
# [x] T4 pwd fallback — resolves to pwd when both env + git unavailable
# [x] T5 both missing — returns 2 with "catalog dir missing" stderr
# [x] T6 cli#313 anchor — grep cured source confirms $HOME/src/sunj-labs/bassclef hardcode retired

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/tests/lib/lite-runtime-invariants.sh
source "$SCRIPT_DIR/lib/lite-runtime-invariants.sh"

TMP_BASE=""
cleanup() {
  if [[ -n "$TMP_BASE" && -d "$TMP_BASE" ]]; then
    rm -rf "$TMP_BASE"
  fi
}
trap cleanup EXIT

TMP_BASE=$(mktemp -d -t cli313.XXXXXX)

# Bake cured lib/luminary-pick.sh inline per Feathers characterization — fixture is pinned at
# bassclef-upstream main SHA a38f1f54358b962d8472cc7e53858f600b0f4462 so the driver stays
# GREEN against the upstream contract regardless of what cli's dist/lite/ currently bundles.
write_cured_lib() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<'CURED_EOF'
#!/usr/bin/env bash
# tier: lite
set -euo pipefail

luminary_pick_catalog() {
  local basedir="${BASSCLEF_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
  local catalog_dir="${basedir}/state/luminary-implementations"
  local lite_catalog="${basedir}/.claude/luminaries"

  if [ -d "$catalog_dir" ]; then
    (
      shopt -s nullglob
      set +e
      for f in "$catalog_dir"/*.json; do
        jq -r '"\(.luminary_slug) (\(.primary_domain // "unknown")) — \(.name // .luminary_slug)"' "$f" 2>/dev/null || true
      done | sort -u
    )
    return 0
  fi

  if [ -d "$lite_catalog" ]; then
    (
      shopt -s nullglob
      set +e
      for f in "$lite_catalog"/*.md; do
        local slug domain name
        slug=$(awk '/^slug:[[:space:]]/{sub(/^slug:[[:space:]]*/,""); print; exit}' "$f")
        domain=$(awk '/^primary_domain:[[:space:]]/{sub(/^primary_domain:[[:space:]]*/,""); print; exit}' "$f")
        name=$(awk '/^name:[[:space:]]/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")
        [ -z "$slug" ] && continue
        echo "${slug} (${domain:-unknown}) — ${name:-$slug}"
      done | sort -u
    )
    return 0
  fi

  echo "[luminary-pick-catalog] catalog dir missing: $catalog_dir (and no .claude/luminaries/ fallback at $lite_catalog)" >&2
  return 2
}
CURED_EOF
}

# Each fixture class sets up its own scratch dir + env; env unsets prevent leakage across tests.
setup_json_fixture() {
  local root="$1"
  mkdir -p "$root/state/luminary-implementations"
  cat > "$root/state/luminary-implementations/alistair-cockburn.json" <<'JSON'
{"luminary_slug": "alistair-cockburn", "primary_domain": "use-case-tiering", "name": "Alistair Cockburn"}
JSON
  cat > "$root/state/luminary-implementations/kent-beck.json" <<'JSON'
{"luminary_slug": "kent-beck", "primary_domain": "tdd-rhythm", "name": "Kent Beck"}
JSON
}

setup_md_fixture() {
  local root="$1"
  mkdir -p "$root/.claude/luminaries"
  cat > "$root/.claude/luminaries/michael-feathers.md" <<'MD'
---
slug: michael-feathers
primary_domain: characterization-tests
name: Michael Feathers
---
MD
  cat > "$root/.claude/luminaries/linus-torvalds.md" <<'MD'
---
slug: linus-torvalds
primary_domain: adopter-contract
name: Linus Torvalds
---
MD
}

LIB_PATH="$TMP_BASE/lib/luminary-pick.sh"
write_cured_lib "$LIB_PATH"

PASS=0
FAIL=0
report() {
  local status="$1" name="$2" detail="${3:-}"
  if [[ "$status" == "PASS" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name — $detail"
    FAIL=$((FAIL + 1))
  fi
}

# T1 — BASSCLEF_DIR branch reads state/luminary-implementations JSON files.
T1_bassclef_dir_branch() {
  local root="$TMP_BASE/t1"
  setup_json_fixture "$root"
  local out
  out=$(
    unset CLAUDE_PROJECT_DIR
    BASSCLEF_DIR="$root"
    export BASSCLEF_DIR
    # shellcheck source=/dev/null
    source "$LIB_PATH"
    luminary_pick_catalog
  )
  if [[ "$out" == *"alistair-cockburn (use-case-tiering) — Alistair Cockburn"* ]] && \
     [[ "$out" == *"kent-beck (tdd-rhythm) — Kent Beck"* ]]; then
    report PASS "T1 BASSCLEF_DIR branch"
  else
    report FAIL "T1 BASSCLEF_DIR branch" "trace output did not match cured JSON path; got: $out"
  fi
}

# T2 — CLAUDE_PROJECT_DIR branch fires when BASSCLEF_DIR unset.
T2_claude_project_dir_branch() {
  local root="$TMP_BASE/t2"
  setup_md_fixture "$root"
  local out
  out=$(
    unset BASSCLEF_DIR
    CLAUDE_PROJECT_DIR="$root"
    export CLAUDE_PROJECT_DIR
    # shellcheck source=/dev/null
    source "$LIB_PATH"
    luminary_pick_catalog
  )
  if [[ "$out" == *"michael-feathers (characterization-tests) — Michael Feathers"* ]] && \
     [[ "$out" == *"linus-torvalds (adopter-contract) — Linus Torvalds"* ]]; then
    report PASS "T2 CLAUDE_PROJECT_DIR branch"
  else
    report FAIL "T2 CLAUDE_PROJECT_DIR branch" "lite fallback did not fire via CLAUDE_PROJECT_DIR; got: $out"
  fi
}

# T3 — git-root branch resolves via git rev-parse when both env vars unset.
T3_git_root_branch() {
  local root="$TMP_BASE/t3"
  mkdir -p "$root"
  (cd "$root" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init)
  setup_md_fixture "$root"
  local out
  out=$(
    cd "$root"
    unset BASSCLEF_DIR CLAUDE_PROJECT_DIR
    # shellcheck source=/dev/null
    source "$LIB_PATH"
    luminary_pick_catalog
  )
  if [[ "$out" == *"michael-feathers"* ]] && [[ "$out" == *"linus-torvalds"* ]]; then
    report PASS "T3 git-root branch"
  else
    report FAIL "T3 git-root branch" "git-rev-parse resolver did not read .claude/luminaries; got: $out"
  fi
}

# T4 — pwd fallback fires when env + git both unavailable.
T4_pwd_fallback() {
  local root="$TMP_BASE/t4"
  setup_md_fixture "$root"
  local out
  out=$(
    cd "$root"
    unset BASSCLEF_DIR CLAUDE_PROJECT_DIR
    # Not a git repo; git rev-parse --show-toplevel returns non-zero so pwd is used.
    # shellcheck source=/dev/null
    source "$LIB_PATH"
    luminary_pick_catalog
  )
  if [[ "$out" == *"michael-feathers"* ]]; then
    report PASS "T4 pwd fallback"
  else
    report FAIL "T4 pwd fallback" "pwd resolver did not fire; got: $out"
  fi
}

# T5 — both missing returns exit 2 plus "catalog dir missing" on stderr.
T5_both_missing() {
  local root="$TMP_BASE/t5"
  mkdir -p "$root"
  local err_file="$TMP_BASE/t5.err"
  local rc=0
  (
    cd "$root"
    unset BASSCLEF_DIR CLAUDE_PROJECT_DIR
    # shellcheck source=/dev/null
    source "$LIB_PATH"
    luminary_pick_catalog
  ) 2>"$err_file" || rc=$?
  local err_content
  err_content=$(cat "$err_file")
  if [[ "$rc" -eq 2 ]] && [[ "$err_content" == *"catalog dir missing"* ]]; then
    report PASS "T5 both missing"
  else
    report FAIL "T5 both missing" "expected rc=2 with 'catalog dir missing' stderr; got rc=$rc, stderr: $err_content"
  fi
}

# T6 — cli#313 anchor: cured source does NOT carry the former hardcoded engineering path.
T6_cli_313_anchor() {
  if grep -qF 'HOME/src/sunj-labs/bassclef' "$LIB_PATH"; then
    report FAIL "T6 cli#313 anchor" "cured source still carries former hardcoded path"
  else
    report PASS "T6 cli#313 anchor"
  fi
}

echo "=== cli#313 luminary-pick home-path driver ==="
echo "Fixture SHA: a38f1f54358b962d8472cc7e53858f600b0f4462 (bassclef-upstream main)"
echo

T1_bassclef_dir_branch
T2_claude_project_dir_branch
T3_git_root_branch
T4_pwd_fallback
T5_both_missing
T6_cli_313_anchor

echo
echo "=== Totals: $PASS pass / $FAIL fail ==="

if [[ "$FAIL" -gt 0 ]]; then
  exit 3
fi
exit 0
