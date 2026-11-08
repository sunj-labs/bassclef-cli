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
#
# cli#489 — the audit log is tracked, so a git reset erases authorizations.
# [x] T19 mutation writes the line to BOTH the tracked mirror and the local record
# [x] T20 local record's parent directory is created when absent
# [x] T21 audit verb on a paired log — exit 0, says paired
# [x] T22 audit verb on a log ending in off — exit 2, names the open window
# [x] T23 audit verb on a mid-log `on` with no preceding off — exit 2, names it
# [x] T24 audit verb on off,off — exit 2, names the double clear
# [x] T25 audit verb walks order, not counts — equal counts in the wrong order fail
# [x] T26 status surfaces the pairing result without being asked
# [x] T27 mirror and local record diverge — reported
# [x] T28 audit verb on a missing log — exit 0, says nothing recorded
# [x] T29 a log whose FIRST line is `on` reads as a record that begins mid-window
# [x] T30 that same log still catches a lone restore later in the file
# [x] T31 with no override set, the record lands at $HOME/.bassclef/
#
# cli#488 — a real trust verb that re-arms the gate itself.
# [x] T32 trust without --authorized-by — exit 3, no write fired
# [x] T33 trust with authorization — clears the gate, read-back OFF, exit 0
# [x] T34 trust writes the marker with who authorized it and a deadline
# [x] T35 trust's audit line records the deadline
# [x] T36 rearm with no marker — exit 0, says there is nothing to re-arm
# [x] T37 rearm inside the window — leaves the gate clear, says it is open
# [x] T38 rearm past the deadline — restores the gate, exit 0
# [x] T39 rearm on a spent marker — restores the gate, exit 0
# [x] T40 rearm consumes the marker — a second run has nothing to do
# [x] T41 status names an open window and its deadline
# [x] T42 status says so when the window is past its deadline (cli#506 — now names the reason)
# [x] T43 trust --ttl 5 records a five-minute deadline
# [x] T44 trust refuses while a window is already open
#
# cli#507 — the gate, the marker and the log each answered on their own.
# [x] T45 `on` after `trust` consumes the marker — one owner, not four
# [x] T46 `on` when the gate is ALREADY on still consumes a stale marker
# [x] T47 gate ON with a marker present — status calls it stale, not open
# [x] T48 the audit line claims only what its log measures
#
# cli#506 — the window closes when the publish it paid for lands.
# [x] T49 a successful publish after opened_at — rearm restores the gate
# [x] T50 the only publish predates opened_at — rearm leaves the gate clear
# [x] T51 a failed publish after opened_at — rearm leaves the gate clear
# [x] T52 the run query fails — rearm restores the gate and says why
# [x] T53 status names why a window reads closed

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

# cli#506 — `rearm` now asks whether a publish landed, so the stub answers.
# FAKE_GH_RUNS holds the JSON array `gh run list --json` would return.
# FAKE_GH_RUNS_FAIL=1 makes the query fail, which is the path that has to
# fail toward "approval required".
if [[ "${1:-}" == "run" ]]; then
  [[ "${FAKE_GH_RUNS_FAIL:-}" == "1" ]] && { echo "gh: could not reach the API" >&2; exit 1; }
  runs="${FAKE_GH_RUNS:-[]}"
  # The script passes --jq, so filter here the way gh would.
  jq_expr=""
  prev=""
  for a in "$@"; do
    [[ "$prev" == "--jq" ]] && jq_expr="$a"
    prev="$a"
  done
  if [[ -n "$jq_expr" ]]; then
    printf '%s' "$runs" | jq -r "$jq_expr" 2>/dev/null
  else
    printf '%s' "$runs"
  fi
  exit 0
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
      # cli#481. This stub used to accept any body and exit 0, which is
      # exactly how `-F "reviewers=[]"` shipped and stayed broken for
      # weeks: the test checked that the script reached the call, never
      # what the call carried. Now it refuses what GitHub refuses.
      for a in "$@"; do
        if [[ "$a" == reviewers=* ]]; then
          echo "gh: Invalid request. Invalid value for reviewers (HTTP 422)" >&2
          exit 1
        fi
      done
      body=""
      for a in "$@"; do
        [[ "$a" == "--input" ]] && { body="$(cat)"; break; }
      done
      log_put "PUT $target $* ${body}"
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
  AUDIT_LOCAL="$WORK/local-audit.log"
  # cli#489 — HOME is redirected as well as the two log paths. The script's
  # local record defaults to $HOME/.bassclef/, so a test that sets only
  # PUBLISH_GATE_AUDIT writes into the operator's real record. That happened
  # while this change was being written: 24 lines of fixture traffic landed
  # in the live log before `status` surfaced it. Setting HOME means a future
  # test that forgets the variable still cannot reach outside its temp dir.
  OUT="$(PATH="$WORK/bin:$PATH" \
        HOME="$WORK/home" \
        PUBLISH_GATE_AUDIT="$AUDIT" \
        PUBLISH_GATE_AUDIT_LOCAL="$AUDIT_LOCAL" \
        bash "$SCRIPT" "$@" 2>&1)"
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

# --- cli#481 ---------------------------------------------------------------
# The bug was never in the control flow. `off` reached the PUT every time;
# the PUT carried the two-character string "[]" where the API wanted an
# array, so GitHub answered 422 and the gate stayed ON since it shipped.
#
# These pin the wire format. T17 would have failed on the old code.

run put-then-off off --authorized-by operator
assert_eq 0 "$RC" "T17 off succeeds when the body is well formed"
assert_contains "$PUTS" '{"reviewers":[]}' "T17 off sends reviewers as a JSON array"
assert_contains "$PUTS" "--input" "T17 off sends a JSON body, not -F typed fields"

run put-then-off off --authorized-by operator
case "$PUTS" in
  *"reviewers=[]"*)
    assert_eq "unreachable" "reviewers=[] on the wire" \
      "T18 off must never send reviewers as an -F string — that is cli#481" ;;
  *)
    assert_eq 1 1 "T18 off sends no -F reviewers string" ;;
esac

# ---------------------------------------------------------------------------
# cli#489 — the audit log is tracked, so a git reset erases authorizations
#
# What happened: `off` wrote its line to state/publish-gate-audit.log in the
# working tree, the commit that followed carried only the script, and a
# `git reset --hard origin/main` reverted the log. The authorization for an
# unattended publish was gone. The log then showed a restore with no matching
# clear — the one shape an audit trail must never have.
#
# The cure is the ticket's option 3: an untracked local file is the record of
# truth, the tracked file is the view. Plus a check that reads the log in
# order and reports unpaired entries, which would have surfaced the hole the
# same night instead of needing someone to notice the tail looked wrong.
#
# Per the pre-mortem (Saltzer 2, and the fold on counting): the check walks
# state transitions. A check that counted `on` lines against `off` lines
# would pass on a log with two of each in the wrong order.
# ---------------------------------------------------------------------------

# run_audit <mode> <seeded-log-contents> <args...>
#   Seeds BOTH logs with the same content, then runs the script.
#   Sets RC, OUT, and leaves the two paths in AUDIT and AUDIT_LOCAL.
run_audit() {
  local mode="$1"; local seed="$2"; shift 2
  WORK="$(mktemp -d)"
  make_fake_gh "$WORK/bin"
  export FAKE_GH_MODE="$mode"
  export FAKE_GH_PUTLOG="$WORK/puts.log"
  export FAKE_GH_PUTMARK="$WORK/put.mark"
  : > "$FAKE_GH_PUTLOG"
  AUDIT="$WORK/audit.log"
  AUDIT_LOCAL="$WORK/local/audit.log"
  mkdir -p "$WORK/local"
  if [[ -n "$seed" ]]; then
    printf '%s\n' "$seed" > "$AUDIT"
    printf '%s\n' "$seed" > "$AUDIT_LOCAL"
  fi
  OUT="$(PATH="$WORK/bin:$PATH" \
        HOME="$WORK/home" \
        PUBLISH_GATE_AUDIT="$AUDIT" \
        PUBLISH_GATE_AUDIT_LOCAL="$AUDIT_LOCAL" \
        bash "$SCRIPT" "$@" 2>&1)"
  RC=$?
  PUTS="$(cat "$FAKE_GH_PUTLOG" 2>/dev/null)"
  return 0
}

# Log lines are tab-separated: stamp, verb, login, detail.
_line() { printf '%s\t%s\tkingofrock\t%s' "$1" "$2" "${3:-}"; }

PAIRED="$(_line 2026-11-07T18:24:41Z off authorized_by=operator)
$(_line 2026-11-07T18:28:50Z on reviewer=kingofrock)"

ENDS_OFF="$(_line 2026-11-07T18:24:41Z off authorized_by=operator)"

# Last night's shape: a restore with no clear before it.
#
# The lone restore has to sit mid-log. A single `on` as the only line in a
# file is a different thing -- a record that begins mid-window, which is what
# this log really does (T29). This fixture opens with a paired clear and
# restore so the third line is unambiguously a restore of nothing.
LONE_ON="$(_line 2026-11-07T18:24:41Z off authorized_by=operator)
$(_line 2026-11-07T18:28:50Z on reviewer=kingofrock)
$(_line 2026-11-08T02:25:49Z on reviewer=kingofrock)"

DOUBLE_OFF="$(_line 2026-11-07T14:51:25Z off authorized_by=operator)
$(_line 2026-11-07T18:24:41Z off authorized_by=operator)
$(_line 2026-11-07T18:28:50Z on reviewer=kingofrock)"

# Two of each verb. A counting check passes. The order is wrong: the first
# entry restores a gate nothing had cleared.
EQUAL_COUNTS_WRONG_ORDER="$(_line 2026-11-07T10:00:00Z on reviewer=kingofrock)
$(_line 2026-11-07T11:00:00Z off authorized_by=operator)
$(_line 2026-11-07T12:00:00Z off authorized_by=operator)
$(_line 2026-11-07T13:00:00Z on reviewer=kingofrock)"

run_audit put-then-off "" off --authorized-by operator
assert_eq 0 "$RC" "T19 mutation exits 0"
if [[ -s "$AUDIT" && -s "$AUDIT_LOCAL" ]]; then
  pass "T19 mutation writes the line to BOTH logs"
else
  fail "T19 mutation writes the line to BOTH logs" "mirror=$(wc -c <"$AUDIT" 2>/dev/null) local=$(wc -c <"$AUDIT_LOCAL" 2>/dev/null)"
fi

# T20 — the local record's directory does not exist yet.
WORK="$(mktemp -d)"
make_fake_gh "$WORK/bin"
export FAKE_GH_MODE=put-then-off FAKE_GH_PUTLOG="$WORK/puts.log" FAKE_GH_PUTMARK="$WORK/put.mark"
: > "$FAKE_GH_PUTLOG"
DEEP="$WORK/no/such/dir/audit.log"
OUT="$(PATH="$WORK/bin:$PATH" HOME="$WORK/home" PUBLISH_GATE_AUDIT="$WORK/audit.log" PUBLISH_GATE_AUDIT_LOCAL="$DEEP" bash "$SCRIPT" off --authorized-by operator 2>&1)"
RC=$?
[[ -s "$DEEP" ]] && pass "T20 local record's parent directory is created when absent" \
                 || fail "T20 local record's parent directory is created when absent" "no file at $DEEP (rc=$RC)"

run_audit authed-on "$PAIRED" audit
assert_eq 0 "$RC" "T21 audit on a paired log exits 0"
assert_contains "$OUT" "paired" "T21 says paired"

run_audit authed-off "$ENDS_OFF" audit
assert_eq 2 "$RC" "T22 audit on a log ending in off exits 2"
assert_contains "$OUT" "open" "T22 names the open window"

run_audit authed-on "$LONE_ON" audit
assert_eq 2 "$RC" "T23 audit on a lone restore exits 2"
assert_contains "$OUT" "2026-11-08T02:25:49Z" "T23 names the unpaired line"

run_audit authed-on "$DOUBLE_OFF" audit
assert_eq 2 "$RC" "T24 audit on off,off exits 2"
assert_contains "$OUT" "2026-11-07T18:24:41Z" "T24 names the second clear"

run_audit authed-on "$EQUAL_COUNTS_WRONG_ORDER" audit
assert_eq 2 "$RC" "T25 audit walks order, not counts"
assert_contains "$OUT" "2026-11-07T10:00:00Z" "T25 names the first bad transition"

run_audit authed-off "$ENDS_OFF" status
assert_contains "$OUT" "open" "T26 status surfaces the pairing result"

# T27 — the two logs disagree. The local record is the one to trust, and the
# operator needs to hear that they differ.
run_audit authed-on "$PAIRED" audit
printf '%s\n' "$(_line 2026-11-08T09:00:00Z off authorized_by=someone-else)" >> "$AUDIT"
OUT="$(PUBLISH_GATE_AUDIT="$AUDIT" PUBLISH_GATE_AUDIT_LOCAL="$AUDIT_LOCAL" HOME="$WORK/home" PATH="$WORK/bin:$PATH" bash "$SCRIPT" audit 2>&1)"
RC=$?
assert_contains "$OUT" "diverge" "T27 divergence between mirror and local record is reported"

run_audit authed-on "" audit
assert_eq 0 "$RC" "T28 audit on a missing log exits 0"
assert_contains "$OUT" "nothing recorded" "T28 says nothing recorded"

# T29 + T30 — calibrated against the real log, 2026-11-08.
#
# The first line of state/publish-gate-audit.log is an `on` from
# 2026-11-05T10:37:13Z. The clear that preceded it was made with a raw API
# call, because the script's `off` never worked until #481 was fixed, so no
# `off` line could have been written. The record simply begins mid-window.
#
# A check that reports its own first line as a defect on every run gets
# ignored, and then it is not a check. So a leading `on` reads as
# informational. Every restore after the first line is still held to the
# rule -- T30 pins that, using the real shape of the night the
# authorization was lost.
FIRST_LINE_ON="$(_line 2026-11-05T10:37:13Z on reviewer=kingofrock)
$(_line 2026-11-07T14:46:49Z off authorized_by=operator)
$(_line 2026-11-07T14:50:00Z on reviewer=kingofrock)"

FIRST_LINE_ON_THEN_LONE_ON="${FIRST_LINE_ON}
$(_line 2026-11-08T02:25:49Z on reviewer=kingofrock)"

run_audit authed-on "$FIRST_LINE_ON" audit
assert_eq 0 "$RC" "T29 a leading on is not a finding"
assert_contains "$OUT" "begins" "T29 says the record begins mid-window"

run_audit authed-on "$FIRST_LINE_ON_THEN_LONE_ON" audit
assert_eq 2 "$RC" "T30 a lone restore later in the file is still a finding"
assert_contains "$OUT" "2026-11-08T02:25:49Z" "T30 names the lone restore"

# T31 — the default path, pinned.
#
# With no PUBLISH_GATE_AUDIT_LOCAL set, the record has to land under
# $HOME/.bassclef/. This is the assertion that makes the runners' HOME
# redirect meaningful: it proves the default really does follow HOME, so a
# redirected HOME really does contain the writes.
WORK="$(mktemp -d)"
make_fake_gh "$WORK/bin"
export FAKE_GH_MODE=put-then-off FAKE_GH_PUTLOG="$WORK/puts.log" FAKE_GH_PUTMARK="$WORK/put.mark"
: > "$FAKE_GH_PUTLOG"
OUT="$(PATH="$WORK/bin:$PATH" HOME="$WORK/home" PUBLISH_GATE_AUDIT="$WORK/audit.log" \
      bash "$SCRIPT" off --authorized-by operator 2>&1)"
RC=$?
if [[ -s "$WORK/home/.bassclef/publish-gate-audit.log" ]]; then
  pass "T31 with no override set, the record lands at \$HOME/.bassclef/"
else
  fail "T31 with no override set, the record lands at \$HOME/.bassclef/" "nothing at $WORK/home/.bassclef/ (rc=$RC)"
fi

# ---------------------------------------------------------------------------
# cli#488 — a real trust verb that re-arms the gate itself
#
# `trust` worked only because the skill routed it to `off`, and the only thing
# restoring the gate afterwards was a sentence in SKILL.md telling the agent
# to do it at Step 7. On 2026-11-07 that sentence was read. That is not a
# mechanism: a promise kept by prose is kept as often as the prose is read.
#
# So `trust` now writes a marker carrying who authorized it and a deadline,
# and `rearm` restores the gate from that marker without needing the publish
# to have finished. The marker is consumed on use -- one authorization, one
# publish (pre-mortem, Saltzer 4).
#
# The marker lives beside the record, outside any repository, for the same
# reason the record does: a marker a `git reset` can erase would fail to
# re-arm, which fails unsafe.
# ---------------------------------------------------------------------------

# run_trust <mode> <marker-contents-or-empty> <args...>
run_trust() {
  local mode="$1"; local marker_body="$2"; shift 2
  WORK="$(mktemp -d)"
  make_fake_gh "$WORK/bin"
  export FAKE_GH_MODE="$mode"
  export FAKE_GH_PUTLOG="$WORK/puts.log"
  export FAKE_GH_PUTMARK="$WORK/put.mark"
  : > "$FAKE_GH_PUTLOG"
  AUDIT="$WORK/audit.log"
  AUDIT_LOCAL="$WORK/local-audit.log"
  MARKER="$WORK/trust.marker"
  [[ -n "$marker_body" ]] && printf '%s\n' "$marker_body" > "$MARKER"
  OUT="$(PATH="$WORK/bin:$PATH" \
        HOME="$WORK/home" \
        PUBLISH_GATE_AUDIT="$AUDIT" \
        PUBLISH_GATE_AUDIT_LOCAL="$AUDIT_LOCAL" \
        PUBLISH_GATE_TRUST_MARKER="$MARKER" \
        bash "$SCRIPT" "$@" 2>&1)"
  RC=$?
  PUTS="$(cat "$FAKE_GH_PUTLOG" 2>/dev/null)"
  return 0
}

# A marker body. `expires_at` in the past means the window has closed.
_marker() {
  printf 'authorized_by=%s\nopened_at=%s\nexpires_at=%s\nspent=%s\n' "$1" "$2" "$3" "$4"
}

_future() { date -u -v+30M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+30 minutes' +%Y-%m-%dT%H:%M:%SZ; }
_past()   { date -u -v-30M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '-30 minutes' +%Y-%m-%dT%H:%M:%SZ; }

run_trust authed-on "" trust
assert_eq 3 "$RC" "T32 trust without --authorized-by exits 3"
assert_eq "" "$PUTS" "T32 no write fired"

run_trust put-then-off "" trust --authorized-by operator
assert_eq 0 "$RC" "T33 trust with authorization exits 0"
assert_contains "$PUTS" "PUT" "T33 the write fired"
assert_contains "$OUT" "OFF" "T33 read-back confirms the gate is clear"

run_trust put-then-off "" trust --authorized-by operator
if grep -q 'authorized_by=operator' "$MARKER" 2>/dev/null && grep -q 'expires_at=' "$MARKER" 2>/dev/null; then
  pass "T34 trust writes the marker with who authorized it and a deadline"
else
  fail "T34 trust writes the marker with who authorized it and a deadline" "marker: $(cat "$MARKER" 2>/dev/null | tr '\n' ' ')"
fi

run_trust put-then-off "" trust --authorized-by operator
assert_contains "$(cat "$AUDIT_LOCAL" 2>/dev/null)" "expires_at=" "T35 trust's audit line records the deadline"

run_trust authed-on "" rearm
assert_eq 0 "$RC" "T36 rearm with no marker exits 0"
assert_contains "$OUT" "nothing to re-arm" "T36 says there is nothing to re-arm"

run_trust authed-off "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" no)" rearm
assert_eq 0 "$RC" "T37 rearm inside the window exits 0"
assert_eq "" "$PUTS" "T37 leaves the gate clear"
assert_contains "$OUT" "open" "T37 says the window is open"

run_trust put-then-on "$(_marker operator 2026-11-08T00:00:00Z "$(_past)" no)" rearm
assert_eq 0 "$RC" "T38 rearm past the deadline exits 0"
assert_contains "$PUTS" "PUT" "T38 the restore fired"
assert_contains "$OUT" "ON" "T38 read-back confirms the gate is back"

run_trust put-then-on "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" yes)" rearm
assert_eq 0 "$RC" "T39 rearm on a spent marker exits 0"
assert_contains "$PUTS" "PUT" "T39 the restore fired"

run_trust put-then-on "$(_marker operator 2026-11-08T00:00:00Z "$(_past)" no)" rearm
if [[ ! -f "$MARKER" ]]; then
  pass "T40 rearm consumes the marker"
else
  fail "T40 rearm consumes the marker" "marker still at $MARKER"
fi

run_trust authed-off "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" no)" status
assert_contains "$OUT" "trust" "T41 status names an open window"
assert_contains "$OUT" "expires" "T41 status names its deadline"

run_trust authed-off "$(_marker operator 2026-11-08T00:00:00Z "$(_past)" no)" status
assert_contains "$OUT" "the deadline passed at" "T42 status says so when the window has closed"

run_trust put-then-off "" trust --authorized-by operator --ttl 5
assert_contains "$(cat "$MARKER" 2>/dev/null)" "ttl_minutes=5" "T43 trust --ttl 5 records a five-minute deadline"

run_trust authed-on "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" no)" trust --authorized-by operator
assert_eq 3 "$RC" "T44 trust refuses while a window is already open"
assert_eq "" "$PUTS" "T44 no write fired"

# ---------------------------------------------------------------------------
# cli#507 — one owner for the marker
#
# These drive the script through real verb sequences rather than building the
# end state by hand. T40 already proves `rearm` consumes the marker; the gap
# was every OTHER path that puts the gate back ON (Feathers — the states the
# fixtures never reach are the states that break).
# ---------------------------------------------------------------------------

run_trust put-then-on "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" no)" on
assert_eq 0 "$RC" "T45 on with an open marker exits 0"
assert_file_absent "$MARKER" "T45 on consumes the marker"

run_trust authed-on "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" no)" on
assert_eq 0 "$RC" "T46 on when already ON exits 0"
assert_file_absent "$MARKER" "T46 the idempotent path still consumes a stale marker"

run_trust authed-on "$(_marker operator 2026-11-08T00:00:00Z "$(_future)" no)" status
assert_contains "$OUT" "stale" "T47 status calls an ON-gate marker stale"
assert_not_contains "$OUT" "trust window: open" "T47 status does not report it as open"

# A paired log, so the check reaches its closing sentence rather than the
# "nothing recorded yet" early return.
run_trust authed-on "" status
printf '%s\n' "$PAIRED" > "$AUDIT"
printf '%s\n' "$PAIRED" > "$AUDIT_LOCAL"
OUT="$(PATH="$WORK/bin:$PATH" HOME="$WORK/home" \
      PUBLISH_GATE_AUDIT="$AUDIT" PUBLISH_GATE_AUDIT_LOCAL="$AUDIT_LOCAL" \
      PUBLISH_GATE_TRUST_MARKER="$MARKER" bash "$SCRIPT" audit 2>&1)"
assert_contains "$OUT" "paired with a restore" "T48 audit still reports pairing"
assert_not_contains "$OUT" "the window is closed" "T48 audit claims only what its log measures"

# ---------------------------------------------------------------------------
# cli#506 — a window closes when its publish lands, not only on the clock
#
# The marker is a local file; the publish runs on a GitHub runner. Nothing on
# the runner can write to the operator's home, so the window cannot be marked
# spent by a write. It has to be found by a read. These tests drive that read.
# ---------------------------------------------------------------------------

# run_runs <mode> <marker> <runs-json> <fail?> <args...>
run_runs() {
  local mode="$1" marker_body="$2" runs="$3" runs_fail="$4"; shift 4
  WORK="$(mktemp -d)"
  make_fake_gh "$WORK/bin"
  export FAKE_GH_MODE="$mode"
  export FAKE_GH_PUTLOG="$WORK/puts.log"
  export FAKE_GH_PUTMARK="$WORK/put.mark"
  export FAKE_GH_RUNS="$runs"
  export FAKE_GH_RUNS_FAIL="$runs_fail"
  : > "$FAKE_GH_PUTLOG"
  AUDIT="$WORK/audit.log"; AUDIT_LOCAL="$WORK/local-audit.log"; MARKER="$WORK/trust.marker"
  [[ -n "$marker_body" ]] && printf '%s\n' "$marker_body" > "$MARKER"
  OUT="$(PATH="$WORK/bin:$PATH" HOME="$WORK/home" \
        PUBLISH_GATE_AUDIT="$AUDIT" PUBLISH_GATE_AUDIT_LOCAL="$AUDIT_LOCAL" \
        PUBLISH_GATE_TRUST_MARKER="$MARKER" bash "$SCRIPT" "$@" 2>&1)"
  RC=$?
  PUTS="$(cat "$FAKE_GH_PUTLOG" 2>/dev/null)"
  unset FAKE_GH_RUNS FAKE_GH_RUNS_FAIL
  return 0
}

_OPENED=2026-11-08T12:00:00Z
_RUN_AFTER='[{"conclusion":"success","createdAt":"2026-11-08T12:05:00Z"}]'
_RUN_BEFORE='[{"conclusion":"success","createdAt":"2026-11-08T11:00:00Z"}]'
_RUN_FAILED='[{"conclusion":"failure","createdAt":"2026-11-08T12:05:00Z"}]'

run_runs put-then-on "$(_marker operator "$_OPENED" "$(_future)" no)" "$_RUN_AFTER" "" rearm
assert_eq 0 "$RC" "T49 rearm after a landed publish exits 0"
assert_contains "$PUTS" "PUT" "T49 the restore fired"
assert_contains "$OUT" "a publish landed at" "T49 says the landed publish is why"

run_runs authed-off "$(_marker operator "$_OPENED" "$(_future)" no)" "$_RUN_BEFORE" "" rearm
assert_eq 0 "$RC" "T50 rearm with only an older publish exits 0"
assert_eq "" "$PUTS" "T50 leaves the gate clear"
assert_contains "$OUT" "open" "T50 says the window is still open"

run_runs authed-off "$(_marker operator "$_OPENED" "$(_future)" no)" "$_RUN_FAILED" "" rearm
assert_eq "" "$PUTS" "T51 a failed publish does not close the window"

run_runs put-then-on "$(_marker operator "$_OPENED" "$(_future)" no)" "[]" 1 rearm
assert_eq 0 "$RC" "T52 rearm exits 0 when the run query fails"
assert_contains "$PUTS" "PUT" "T52 fails toward approval — the restore fired"
assert_contains "$OUT" "could not be read" "T52 says the publish history could not be read"

run_runs authed-off "$(_marker operator "$_OPENED" "$(_future)" no)" "$_RUN_AFTER" "" status
assert_contains "$OUT" "a publish landed at" "T53 status names the landed publish as the reason"

echo ""
echo "  total=$_tests_total passed=$_tests_passed failed=$_tests_failed"
if (( _tests_failed > 0 )); then
  printf '  %s\n' "${_failures[@]}"
  exit 1
fi
exit 0
