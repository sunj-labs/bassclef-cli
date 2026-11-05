#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md; test mtime <= source mtime)
# Tier 0 tests for scripts/publish-gate.sh
# Parent ticket: sunj-labs/bassclef-cli#462
# Design chain: docs/use-cases/UC-script-cli-462-publish-gate.md
# Decision: docs/adrs/ADR-004-publish-pipeline-safety-contract.md §Amendment 2026-11-05
# Pre-mortem folds: docs/risk-ledgers/2026-11-05-cli-462-publish-gate.md
#   (S1 restore-verified, S2 explicit-authorization, S3 fail-to-UNKNOWN,
#    S4 env-exists-first, S5 login-echo, S6 gh-auth-precondition,
#    N1 empty-is-off, N2 idempotent, N4 bypass-surfaced, N5 audit-line,
#    H2 on-postcondition-read-back, H3 off-postcondition-read-back, H4 status-pure)

# test-list:
# [x] T01 gh_not_authenticated — exit 3; stderr names gh auth; no write
# [x] T02 environment_absent — exit 3; stderr names npm-publish; no write
# [x] T03 status_rules_empty — stdout says OFF; exit 0
# [x] T04 status_reviewer_present — stdout says ON + the login; exit 0
# [x] T05 status_garbage_response — stdout says UNKNOWN; exit 2 (never reports ON)
# [x] T06 status_surfaces_admin_bypass — stdout names can_admins_bypass value
# [x] T07 on_writes_and_verifies — PUT fired; read-back confirms; exit 0
# [x] T08 on_readback_shows_no_rule — exit 2; stderr names postcondition
# [x] T09 on_idempotent_when_already_on — exit 0; no error text
# [x] T10 off_without_authorization — exit 3; no PUT fired
# [x] T11 off_with_authorization — PUT fired; read-back empty; exit 0
# [x] T12 off_prints_restore_command — stdout names "publish-gate on"
# [x] T13 mutation_appends_audit_line — audit file gains verb + login + ISO stamp
# [x] T14 off_readback_still_has_rule — exit 2; stderr names postcondition
# [x] T15 unknown_verb — exit 3; stderr names usage
# [x] T16 status_is_pure — no PUT fired; audit file unchanged

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/publish-gate.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "SETUP: script not yet at $SCRIPT (Beck RED phase — expected)" >&2
fi

_tests_total=0; _tests_passed=0; _tests_failed=0; _failures=()
pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }
assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1] got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] not in [${1:0:300}]"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] && pass "$3" || fail "$3" "unexpected needle [$2] in [${1:0:300}]"; }
assert_file_absent() { [[ ! -f "$1" ]] && pass "$2" || fail "$2" "file unexpectedly exists: $1"; }

# ---------- fake gh builder ----------
# FAKE_GH_MODE drives behavior:
#   authed-on        env exists, required_reviewers present
#   authed-off       env exists, protection_rules empty
#   unauthed         gh auth status fails
#   no-env           environments/npm-publish returns 404
#   garbage          env read returns unparseable body
#   put-then-off     starts ON; after a PUT the read-back reports empty
#   put-then-on      starts OFF; after a PUT the read-back reports a reviewer
#   put-stays-off    starts OFF and stays OFF after a PUT (write silently lost)
# PUT calls are appended to $FAKE_GH_PUTLOG.
make_fake_gh() {
  local bindir="$1"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<'FAKE'
#!/usr/bin/env bash
set -uo pipefail
log_put() { echo "$*" >> "${FAKE_GH_PUTLOG:-/dev/null}"; }
mode="${FAKE_GH_MODE:-authed-off}"

env_on='{"name":"npm-publish","can_admins_bypass":true,"protection_rules":[{"type":"required_reviewers","reviewers":[{"type":"User","reviewer":{"login":"kingofrock","id":4242}}]}]}'
env_off='{"name":"npm-publish","can_admins_bypass":true,"protection_rules":[]}'

if [[ "${1:-}" == "auth" ]]; then
  [[ "$mode" == "unauthed" ]] && { echo "not logged in" >&2; exit 1; }
  echo "Logged in to github.com as kingofrock"; exit 0
fi

if [[ "${1:-}" == "api" ]]; then
  target="${2:-}"
  is_put=0
  for a in "$@"; do [[ "$a" == "PUT" ]] && is_put=1; done

  if [[ "$target" == "user" ]]; then
    for a in "$@"; do
      [[ "$a" == ".id" ]] && { echo 4242; exit 0; }
    done
    echo "kingofrock"; exit 0
  fi

  if [[ "$target" == *"environments/npm-publish"* ]]; then
    if [[ "$is_put" == 1 ]]; then
      log_put "PUT $target $*"
      touch "${FAKE_GH_PUTMARK:-/dev/null}"
      exit 0
    fi
    case "$mode" in
      unauthed) echo "gh: not authenticated" >&2; exit 1 ;;
      no-env)   echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
      garbage)  echo "<<<not json>>>"; exit 0 ;;
      authed-on) echo "$env_on"; exit 0 ;;
      authed-off) echo "$env_off"; exit 0 ;;
      put-then-off)
        if [[ -f "${FAKE_GH_PUTMARK:-/nonexistent}" ]]; then echo "$env_off"; else echo "$env_on"; fi
        exit 0 ;;
      put-then-on)
        if [[ -f "${FAKE_GH_PUTMARK:-/nonexistent}" ]]; then echo "$env_on"; else echo "$env_off"; fi
        exit 0 ;;
      put-stays-off) echo "$env_off"; exit 0 ;;
    esac
  fi
  echo "{}"; exit 0
fi
exit 0
FAKE
  chmod +x "$bindir/gh"
}

# ---------- runner ----------
# run <mode> <args...>  → sets RC, OUT (stdout+stderr), PUTLOG contents
run() {
  local mode="$1"; shift
  WORK="$(mktemp -d)"
  make_fake_gh "$WORK/bin"
  export FAKE_GH_MODE="$mode"
  export FAKE_GH_PUTLOG="$WORK/puts.log"
  export FAKE_GH_PUTMARK="$WORK/put.mark"
  : > "$FAKE_GH_PUTLOG"
  AUDIT="$WORK/audit.log"
  OUT="$(PATH="$WORK/bin:$PATH" PUBLISH_GATE_AUDIT="$AUDIT" bash "$SCRIPT" "$@" 2>&1)"
  RC=$?
  PUTS="$(cat "$FAKE_GH_PUTLOG" 2>/dev/null)"
  return 0
}

echo "publish-gate.sh — Tier 0"

run unauthed status
assert_eq 3 "$RC" "T01 gh_not_authenticated exit 3"
assert_contains "$OUT" "gh auth" "T01 stderr names gh auth"
assert_eq "" "$PUTS" "T01 no write fired"

run no-env status
assert_eq 3 "$RC" "T02 environment_absent exit 3"
assert_contains "$OUT" "npm-publish" "T02 stderr names the environment"
assert_eq "" "$PUTS" "T02 no write fired"

run authed-off status
assert_eq 0 "$RC" "T03 status_rules_empty exit 0"
assert_contains "$OUT" "OFF" "T03 stdout says OFF"

run authed-on status
assert_eq 0 "$RC" "T04 status_reviewer_present exit 0"
assert_contains "$OUT" "ON" "T04 stdout says ON"
assert_contains "$OUT" "kingofrock" "T04 stdout names the login"

run garbage status
assert_eq 2 "$RC" "T05 status_garbage_response exit 2"
assert_contains "$OUT" "UNKNOWN" "T05 stdout says UNKNOWN"
assert_not_contains "$OUT" "gate: ON" "T05 never reports ON"

run authed-on status
assert_contains "$OUT" "can_admins_bypass" "T06 status surfaces admin bypass"

run put-then-on on
assert_eq 0 "$RC" "T07 on_writes_and_verifies exit 0"
assert_contains "$PUTS" "PUT" "T07 PUT fired"
assert_contains "$OUT" "ON" "T07 read-back confirms ON"

run put-stays-off on
assert_eq 2 "$RC" "T08 on_readback_shows_no_rule exit 2"
assert_contains "$OUT" "postcondition" "T08 stderr names postcondition"

run authed-on on
assert_eq 0 "$RC" "T09 on_idempotent_when_already_on exit 0"

run authed-on off
assert_eq 3 "$RC" "T10 off_without_authorization exit 3"
assert_eq "" "$PUTS" "T10 no PUT fired"

run put-then-off off --authorized-by operator
assert_eq 0 "$RC" "T11 off_with_authorization exit 0"
assert_contains "$PUTS" "PUT" "T11 PUT fired"
assert_contains "$OUT" "OFF" "T11 read-back confirms OFF"

run put-then-off off --authorized-by operator
assert_contains "$OUT" "publish-gate.sh on" "T12 off prints the restore command"

run put-then-off off --authorized-by operator
assert_contains "$(cat "$AUDIT" 2>/dev/null)" "off" "T13 audit line names the verb"
assert_contains "$(cat "$AUDIT" 2>/dev/null)" "kingofrock" "T13 audit line names the login"
assert_contains "$(cat "$AUDIT" 2>/dev/null)" "20" "T13 audit line carries a timestamp"

run put-then-on off --authorized-by operator
assert_eq 2 "$RC" "T14 off_readback_still_has_rule exit 2"
assert_contains "$OUT" "postcondition" "T14 stderr names postcondition"

run authed-on frobnicate
assert_eq 3 "$RC" "T15 unknown_verb exit 3"
assert_contains "$OUT" "Usage" "T15 stderr names usage"

run authed-on status
assert_eq "" "$PUTS" "T16 status fired no PUT"
assert_file_absent "$AUDIT" "T16 status wrote no audit line"

echo ""
echo "  total=$_tests_total passed=$_tests_passed failed=$_tests_failed"
if (( _tests_failed > 0 )); then
  printf '  %s\n' "${_failures[@]}"
  exit 1
fi
exit 0
