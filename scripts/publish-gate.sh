#!/usr/bin/env bash
# tier: standard
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# publish-gate.sh — read or set the approval gate on the npm-publish environment.
#
# Parent ticket: sunj-labs/bassclef-cli#462
# Decision: docs/adrs/ADR-004-publish-pipeline-safety-contract.md
#           §Amendment 2026-11-05 — the gate is operator-held, default ON.
# Design chain: docs/use-cases/UC-script-cli-462-publish-gate.md
# Pre-mortem folds: docs/risk-ledgers/2026-11-05-cli-462-publish-gate.md
#
# Usage:
#   publish-gate.sh status
#   publish-gate.sh on
#   publish-gate.sh off --authorized-by <who>
#   publish-gate.sh audit
#   publish-gate.sh trust --authorized-by <who> [--ttl <minutes>]
#   publish-gate.sh rearm
#
# Why `off` needs an argument: the gate's whole value is that it cannot be
# cleared by accident or by an agent acting on its own read of the room. The
# argument is the record of who decided, and it lands in the audit log.
#
# The resting state is ON. Every failure path here leans toward "approval
# required" rather than "publish freely" (Saltzer fail-safe defaults), and
# every write is verified by reading the environment back, because a zero
# exit from `gh api` is not evidence that the rule landed (Hoare).
#
# Exit codes:
#   0  the requested state holds, verified by read-back
#   2  postcondition failed, or the gate's state could not be determined
#   3  precondition failed (no gh auth, no environment, bad arguments)

set -uo pipefail

REPO="${PUBLISH_GATE_REPO:-sunj-labs/bassclef-cli}"
ENV_NAME="${PUBLISH_GATE_ENV:-npm-publish}"
ENV_PATH="repos/${REPO}/environments/${ENV_NAME}"
# cli#489 — two logs, one record of truth.
#
# `state/publish-gate-audit.log` is tracked in git. On 2026-11-08 an `off`
# wrote its authorization line there, the commit that followed carried only
# the script, and a `git reset --hard origin/main` reverted the log. The
# authorization for an unattended publish was gone, and what remained was a
# restore with no matching clear.
#
# So the tracked file is the view, and an untracked local file is the record.
# A reset rewrites the view; the record survives, and `audit` reports when
# the two disagree. Per the ticket's option 3.
# cli#506 — the workflow whose success spends a trust window.
PUBLISH_WORKFLOW="${PUBLISH_GATE_WORKFLOW:-publish.yml}"
PUBLISH_RUN_SCAN="${PUBLISH_GATE_RUN_SCAN:-20}"

AUDIT="${PUBLISH_GATE_AUDIT:-state/publish-gate-audit.log}"
AUDIT_LOCAL="${PUBLISH_GATE_AUDIT_LOCAL:-${HOME}/.bassclef/publish-gate-audit.log}"

# cli#488 — the trust window's marker.
#
# `trust` used to mean `off`, and the only thing restoring the gate afterwards
# was a sentence in SKILL.md telling the agent to do it. On 2026-11-07 the
# sentence was read. A promise kept by prose is kept as often as the prose is
# read, which is not a mechanism.
#
# The marker carries who authorized the window and when it closes. `rearm`
# restores the gate from it without needing the publish to have finished, and
# consumes it on use -- one authorization, one publish.
#
# It sits beside the record, outside any repository, for the same reason the
# record does: a marker a `git reset` can erase would fail to re-arm, and
# that fails unsafe.
TRUST_MARKER="${PUBLISH_GATE_TRUST_MARKER:-${HOME}/.bassclef/publish-trust.marker}"
TRUST_TTL_DEFAULT=60

usage() {
  cat >&2 <<EOF
Usage:
  publish-gate.sh status
  publish-gate.sh on
  publish-gate.sh off --authorized-by <who>
  publish-gate.sh audit
  publish-gate.sh trust --authorized-by <who> [--ttl <minutes>]
  publish-gate.sh rearm

status  read the gate without changing it
on      require operator approval before npm publish (the resting state)
off     clear the requirement for one publish; restore it with \`on\` after
audit   read the log in order and report any clear without a restore
trust   clear the gate for one publish, with a deadline it re-arms itself by
rearm   restore the gate once the trust window is over -- its publish
        landed, its deadline passed, or it was marked spent

Repo: ${REPO}   Environment: ${ENV_NAME}
EOF
}

die_precondition() { echo "publish-gate: $1" >&2; exit 3; }
die_postcondition() { echo "publish-gate: postcondition failed — $1" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Preconditions. Checked, never assumed.
# ---------------------------------------------------------------------------

require_gh_auth() {
  command -v gh >/dev/null 2>&1 || die_precondition "gh not on PATH. Install the GitHub CLI, then run \`gh auth login\`."
  gh auth status >/dev/null 2>&1 || die_precondition "gh auth is not active. Run \`gh auth login\` and retry."
}

# Reads the environment. Echoes its JSON. Exits 3 when the environment is not
# there, because a PUT against a missing environment creates a fresh one with
# no rules — a silent downgrade that reads like success.
# NOTE: this returns non-zero rather than exiting. An `exit` here would run
# inside the caller's command substitution and kill only that subshell, so the
# caller would carry on with an empty body and report the wrong exit code.
# Caught by T02. Callers must use `if ! body="$(read_env)"; then ... fi`.
read_env() {
  gh api "$ENV_PATH" 2>/dev/null
}

env_unreadable() {
  die_precondition "environment ${ENV_NAME} not readable on ${REPO}. Create it in Settings → Environments first; a write against a missing environment would create one with no protection at all."
}

operator_login() { gh api user --jq '.login' 2>/dev/null; }
operator_id()    { gh api user --jq '.id' 2>/dev/null; }

# ---------------------------------------------------------------------------
# Reading the gate. Three outcomes only: ON, OFF, UNKNOWN.
# UNKNOWN is a failure, not a pass — an unparseable response must never be
# reported as protected.
# ---------------------------------------------------------------------------

# gate_state <json> → prints "ON <logins>" | "OFF" | "UNKNOWN"
gate_state() {
  local body="$1"
  python3 - "$body" <<'PY' 2>/dev/null || echo "UNKNOWN"
import json, sys
try:
    d = json.loads(sys.argv[1])
    rules = d.get("protection_rules")
    if not isinstance(rules, list):
        print("UNKNOWN"); sys.exit(0)
    for r in rules:
        if r.get("type") == "required_reviewers":
            logins = []
            for rv in r.get("reviewers") or []:
                who = rv.get("reviewer") or {}
                login = who.get("login") or who.get("slug")
                if login:
                    logins.append(login)
            print("ON " + (",".join(logins) if logins else "(no reviewer named)"))
            sys.exit(0)
    print("OFF")
except Exception:
    print("UNKNOWN")
PY
}

admin_bypass() {
  python3 - "$1" <<'PY' 2>/dev/null || echo "unknown"
import json, sys
try:
    print(str(json.loads(sys.argv[1]).get("can_admins_bypass", "unknown")).lower())
except Exception:
    print("unknown")
PY
}

# Appends one line to both logs. The local record is the one that has to
# land, so a failure there is said out loud rather than swallowed -- but it
# does not fail the command, because by this point the gate's state has
# already changed and reporting failure would be the larger lie.
audit() {
  local verb="$1" who="$2" detail="$3"
  local stamp; stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local line; line="$(printf '%s\t%s\t%s\t%s' "$stamp" "$verb" "$who" "$detail")"

  local mirror_dir; mirror_dir="$(dirname "$AUDIT")"
  if [ -d "$mirror_dir" ] || mkdir -p "$mirror_dir" 2>/dev/null; then
    printf '%s\n' "$line" >> "$AUDIT" 2>/dev/null || true
  fi

  local local_dir; local_dir="$(dirname "$AUDIT_LOCAL")"
  if [ -d "$local_dir" ] || mkdir -p "$local_dir" 2>/dev/null; then
    if ! printf '%s\n' "$line" >> "$AUDIT_LOCAL" 2>/dev/null; then
      echo "publish-gate: could not write the record at ${AUDIT_LOCAL}." >&2
      echo "  The gate state changed; the record of it did not. Write this down:" >&2
      echo "    ${line}" >&2
    fi
  else
    echo "publish-gate: could not create $(dirname "$AUDIT_LOCAL") for the record." >&2
    echo "  The gate state changed; the record of it did not. Write this down:" >&2
    echo "    ${line}" >&2
  fi
}

# Which file to believe. The local record survives a reset; the mirror does
# not, so the mirror is read only when there is no record.
audit_source() {
  if [ -s "$AUDIT_LOCAL" ]; then
    printf '%s' "$AUDIT_LOCAL"
  elif [ -s "$AUDIT" ]; then
    printf '%s' "$AUDIT"
  else
    printf '%s' ""
  fi
}

# Walks the log in order and reports the first transition that cannot happen.
#
# It walks rather than counts on purpose. A check that compared the number of
# `on` lines against the number of `off` lines would pass on a log holding two
# of each in the wrong order -- which is a log whose first entry restores a
# gate nothing had cleared. Pinned by T25.
#
# The resting state is ON, per ADR-004 §Amendment 2026-11-05.
#
# Prints findings. Returns 0 when every clear has its restore and the window
# is closed; 2 otherwise.
audit_pairing() {
  local src; src="$(audit_source)"
  if [ -z "$src" ]; then
    echo "  audit: nothing recorded yet."
    return 0
  fi

  local findings; findings="$(
    awk -F'\t' '
      BEGIN { state = "ON"; seen = 0 }
      $2 == "off" {
        if (state == "OFF") {
          printf "  audit: %s clears a gate that was already clear -- the clear before it has no restore.\n", $1
          bad = 1
        }
        state = "OFF"
        last_off = $1
        seen = 1
        next
      }
      $2 == "on" {
        # A restore on the first logged line means the clear that preceded it
        # is older than the record. That is the real shape of this log: its
        # first entry is an `on` from 2026-11-05, and the clear before it was
        # a raw API call made while the script`s `off` was broken (cli#481),
        # so no `off` line could have been written. Reported, not flagged --
        # a check that calls its own opening line a defect on every run stops
        # being read. Every later restore is still held to the rule (T30).
        if (seen == 0) {
          printf "  audit: the record begins at %s with a restore, so the clear before it is older than this log.\n", $1
          state = "ON"
          seen = 1
          next
        }
        if (state == "ON") {
          printf "  audit: %s restores a gate that was not clear -- this restore has no matching clear.\n", $1
          bad = 1
        }
        state = "ON"
        seen = 1
        next
      }
      END {
        if (state == "OFF") {
          printf "  audit: the window opened at %s is still open -- no restore follows it.\n", last_off
          bad = 1
        }
        # cli#507 -- this used to end "and the window is closed." This log
        # records gate transitions. It has no view of the trust marker, so
        # it had no evidence for that clause. `status` reports the window
        # from the marker; this line reports the pairing from the log.
        if (!bad) print "  audit: every clear is paired with a restore."
        else print "  audit: UNPAIRED"
      }
    ' "$src" 2>/dev/null
  )"

  printf '%s\n' "$findings"
  case "$findings" in
    *"audit: UNPAIRED"*) return 2 ;;
    *) return 0 ;;
  esac
}

# The two logs should hold the same lines. When they do not, the mirror has
# been rewritten -- which is the whole reason the record lives elsewhere.
audit_divergence() {
  [ -s "$AUDIT_LOCAL" ] || return 0
  [ -s "$AUDIT" ] || return 0
  if ! diff -q "$AUDIT_LOCAL" "$AUDIT" >/dev/null 2>&1; then
    echo "  audit: the two logs diverge." >&2
    echo "    record: ${AUDIT_LOCAL}" >&2
    echo "    mirror: ${AUDIT}" >&2
    echo "    The record is the one to trust. A reset or a branch switch rewrites the mirror." >&2
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Verbs
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# The trust window
# ---------------------------------------------------------------------------

now_stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Reads one key=value from the marker. Missing key prints nothing.
marker_field() {
  [ -f "$TRUST_MARKER" ] || return 0
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, "", $0); print; exit }' "$TRUST_MARKER" 2>/dev/null
}

# ISO-8601 UTC with a fixed width sorts correctly as a string, so the
# comparison needs no `date -d` and works the same on BSD and GNU. That
# matters: a portability bug here would leave the gate open on one platform
# and not the other.
# cli#506 — did a publish land since this window opened?
#
# Why this is a read and not a write. `spent` was read in three places and
# written in none, so the deadline was the only thing that ever closed a
# window. The write was never possible: the marker is a local file under
# $HOME, and the publish runs on a GitHub runner that cannot reach it. The
# only way the laptop learns the publish happened is to go and ask.
#
# Returns 0 = a successful publish landed at or after $1
#         1 = none did
#         2 = the history could not be read
#
# The timestamps are ISO-8601 UTC at a fixed width, so jq compares them as
# strings and the result does not depend on the platform's `date`. Same
# reasoning as the deadline comparison below it.
publish_landed_since() {
  local since="$1" hits
  [ -n "$since" ] || return 1
  if ! hits="$(gh run list --repo "$REPO" --workflow="$PUBLISH_WORKFLOW" \
        --limit "$PUBLISH_RUN_SCAN" --json conclusion,createdAt \
        --jq ".[] | select(.conclusion == \"success\") | select(.createdAt >= \"${since}\") | .createdAt" \
        2>/dev/null)"; then
    return 2
  fi
  [ -n "$hits" ] || return 1
  # gh lists newest first, so the last match is the earliest publish that
  # could have spent this window. That is the one worth naming.
  PUBLISH_LANDED_AT="$(printf '%s\n' "$hits" | tail -1)"
  return 0
}

# ISO-8601 UTC with a fixed width sorts correctly as a string, so the
# comparison needs no `date -d` and works the same on BSD and GNU. That
# matters: a portability bug here would leave the gate open on one platform
# and not the other.
#
# cli#506 — sets TRUST_CLOSED_REASON so callers can say WHY a window reads
# closed. "It is closed" and "it is closed because the publish landed" are
# different messages to an operator deciding whether to look further.
trust_window_closed() {
  local expires spent
  TRUST_CLOSED_REASON=""
  spent="$(marker_field spent)"
  if [ "$spent" = "yes" ]; then
    TRUST_CLOSED_REASON="it was marked spent by hand"
    return 0
  fi
  expires="$(marker_field expires_at)"
  if [ -z "$expires" ]; then
    TRUST_CLOSED_REASON="the marker carries no deadline"
    return 0
  fi
  if [[ "$(now_stamp)" > "$expires" ]]; then
    TRUST_CLOSED_REASON="the deadline passed at ${expires}"
    return 0
  fi

  # Inside the deadline. The window can still be over, if its publish landed.
  publish_landed_since "$(marker_field opened_at)"
  case $? in
    0) TRUST_CLOSED_REASON="a publish landed at ${PUBLISH_LANDED_AT}"; return 0 ;;
    2)
      # Fail-safe (Saltzer). A query that cannot be answered must not hold
      # the gate open. Nothing fires `rearm` on a schedule, so the cost of
      # closing early is one extra approval, never an unattended publish.
      TRUST_CLOSED_REASON="the publish history could not be read, so this leans toward approval"
      return 0 ;;
  esac
  return 1
}

trust_window_open() {
  [ -f "$TRUST_MARKER" ] || return 1
  trust_window_closed && return 1
  return 0
}

# cli#507 — one owner for the marker.
#
# Four functions used to touch it: `trust` opened it, `rearm` closed it, `on`
# ignored it, `status` read it. `restore_gate` was factored out of `rearm` so
# the write to production config lived once -- but only the write moved. The
# consume stayed behind in `rearm`, so `on` put the gate back and left a
# marker claiming an open window. `status` then printed both as facts.
#
# The invariant this holds: a gate that reads ON has no open marker beside it.
# Every path that restores the gate calls this (Hoare -- the postcondition is
# the same whichever verb got there).
#
# Fail-soft on the remove, and say so. A delete that silently failed would put
# the two back out of step, which is the defect this closes.
consume_marker() {
  [ -f "$TRUST_MARKER" ] || return 0
  rm -f "$TRUST_MARKER" 2>/dev/null || true
  if [ -f "$TRUST_MARKER" ]; then
    echo "publish-gate: the gate is ON but the marker at ${TRUST_MARKER} could not be removed." >&2
    echo "  Delete it by hand, or \`status\` will keep naming a window that is over." >&2
    return 1
  fi
  return 0
}

# Restores the gate. Shared by `on` and `rearm` so the two cannot drift.
# Prints the resulting state. Dies on a failed read-back (Hoare).
restore_gate() {
  local login uid before after state
  if ! before="$(read_env)"; then env_unreadable; fi
  login="$(operator_login)"
  uid="$(operator_id)"
  [ -n "$login" ] && [ -n "$uid" ] || die_precondition "could not resolve the authenticated user from \`gh api user\`."

  gh api "$ENV_PATH" --method PUT \
    -F "reviewers[][type]=User" \
    -F "reviewers[][id]=${uid}" >/dev/null 2>&1 \
    || die_postcondition "the write to ${ENV_NAME} was rejected. Run \`gh api ${ENV_PATH}\` to see the current state."

  if ! after="$(read_env)"; then env_unreadable; fi
  state="$(gate_state "$after")"
  case "$state" in
    ON*) : ;;
    *) die_postcondition "wrote the reviewer but the read-back says ${state}. The gate is NOT protecting publish." ;;
  esac
  RESTORE_LOGIN="$login"
  RESTORE_UID_OUT="$uid"
  RESTORE_STATE="$state"
  RESTORE_BYPASS="$(admin_bypass "$after")"
}

do_trust() {
  local who="" ttl="$TRUST_TTL_DEFAULT"
  while [ $# -gt 0 ]; do
    case "$1" in
      --authorized-by) shift; who="${1:-}" ;;
      --ttl)           shift; ttl="${1:-}" ;;
      *) usage; exit 3 ;;
    esac
    shift
  done

  if [ -z "$who" ]; then
    echo "publish-gate: refusing to open a trust window without --authorized-by <who>." >&2
    echo "" >&2
    echo "  The argument is the record of who decided. It lands in the log and in" >&2
    echo "  the marker, and the marker is what re-arms the gate afterwards." >&2
    echo "" >&2
    echo "  bash scripts/publish-gate.sh trust --authorized-by operator" >&2
    exit 3
  fi

  case "$ttl" in
    ''|*[!0-9]*) die_precondition "--ttl wants a whole number of minutes; got \"${ttl}\"." ;;
  esac

  # One window at a time. Two open windows mean two authorizations and one
  # marker, and the second would overwrite the first's record.
  if trust_window_open; then
    echo "publish-gate: a trust window is already open." >&2
    echo "  authorized by: $(marker_field authorized_by)" >&2
    echo "  expires:       $(marker_field expires_at)" >&2
    echo "" >&2
    echo "  Use it, or close it first:" >&2
    echo "    bash scripts/publish-gate.sh rearm" >&2
    exit 3
  fi

  require_gh_auth
  local before login
  if ! before="$(read_env)"; then env_unreadable; fi
  login="$(operator_login)"

  # Same JSON body as `off`, for the reason written there: `gh api -F` types
  # its value and sent `[]` as a two-character string, which the API refused
  # every time (cli#481).
  printf '{"reviewers":[]}' \
    | gh api "$ENV_PATH" --method PUT --input - >/dev/null 2>&1 \
    || die_postcondition "the write to ${ENV_NAME} was rejected; the gate state is unchanged."

  local after state
  if ! after="$(read_env)"; then env_unreadable; fi
  state="$(gate_state "$after")"
  if [ "$state" != "OFF" ]; then
    die_postcondition "cleared the reviewer but the read-back says ${state}. Treat the gate as still ON and retry."
  fi

  local opened expires dir
  opened="$(now_stamp)"
  expires="$(date -u -v+"${ttl}"M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -d "+${ttl} minutes" +%Y-%m-%dT%H:%M:%SZ)"
  dir="$(dirname "$TRUST_MARKER")"
  if [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null; then
    printf 'authorized_by=%s\nopened_at=%s\nexpires_at=%s\nttl_minutes=%s\nspent=no\n' \
      "$who" "$opened" "$expires" "$ttl" > "$TRUST_MARKER" 2>/dev/null || true
  fi
  if [ ! -s "$TRUST_MARKER" ]; then
    echo "publish-gate: the gate is clear but the marker did not land at ${TRUST_MARKER}." >&2
    echo "  Nothing will re-arm it on its own. Run \`publish-gate.sh on\` when the publish lands." >&2
  fi

  audit "off" "${login:-unknown}" "authorized_by=${who} via=trust expires_at=${expires}"
  echo "${ENV_NAME}: OFF — the next publish runs unattended"
  echo "  authorized by: ${who}"
  echo "  expires:       ${expires} (${ttl} min)"
  echo "  can_admins_bypass: $(admin_bypass "$after")"
  echo ""
  echo "  The gate re-arms itself from the marker:"
  echo "    bash scripts/publish-gate.sh rearm"
  exit 0
}

do_rearm() {
  if [ ! -f "$TRUST_MARKER" ]; then
    echo "${ENV_NAME}: nothing to re-arm — no trust window is recorded."
    exit 0
  fi

  if ! trust_window_closed; then
    echo "${ENV_NAME}: the trust window is still open — leaving the gate clear."
    echo "  authorized by: $(marker_field authorized_by)"
    echo "  expires:       $(marker_field expires_at)"
    echo ""
    echo "  No successful ${PUBLISH_WORKFLOW} run has landed since it opened."
    echo "  Re-run this after the publish lands, or after the deadline passes."
    exit 0
  fi

  # cli#506 — `trust_window_closed` just ran and set the reason. Read it
  # before anything else touches the marker.
  local who expires why
  who="$(marker_field authorized_by)"
  expires="$(marker_field expires_at)"
  why="${TRUST_CLOSED_REASON:-the deadline passed at ${expires}}"

  require_gh_auth
  restore_gate

  rm -f "$TRUST_MARKER" 2>/dev/null || true

  audit "on" "${RESTORE_LOGIN:-unknown}" "restored_by=rearm reason=${why// /-} authorized_by=${who}"
  echo "${ENV_NAME}: ${RESTORE_STATE} — publish waits for approval"
  echo "  re-armed because ${why}"
  echo "  the window authorized by ${who} is closed, and its marker is gone"
  echo "  can_admins_bypass: ${RESTORE_BYPASS}"
  exit 0
}

do_audit() {
  audit_divergence
  if audit_pairing; then
    exit 0
  fi
  exit 2
}

do_status() {
  require_gh_auth
  local body state bypass
  if ! body="$(read_env)"; then env_unreadable; fi
  state="$(gate_state "$body")"
  bypass="$(admin_bypass "$body")"

  if [ "$state" = "UNKNOWN" ]; then
    echo "${ENV_NAME}: UNKNOWN — could not read the protection rules." >&2
    echo "  Treat this as unprotected until it reads cleanly. Check: gh api ${ENV_PATH}" >&2
    exit 2
  fi

  if [ "${state#ON}" != "$state" ]; then
    echo "${ENV_NAME}: ${state} — publish waits for approval"
  else
    echo "${ENV_NAME}: OFF — publish runs unattended"
    echo "  Restore with: bash scripts/publish-gate.sh on"
  fi
  # Part of the gate's real strength, so it prints every time, not only on
  # request. An admin can click through regardless of the reviewer list.
  echo "  can_admins_bypass: ${bypass}"

  # cli#488 -- a window nobody is told about is a window nobody closes.
  #
  # cli#507 -- and a window reported next to a contradicting gate state is
  # worse than one not reported at all. This used to print the gate, then the
  # marker, with nothing comparing them, so one call could say "publish waits
  # for approval" and "trust window: open" together. Only one of those can be
  # true. The gate is the authority: it is what GitHub enforces. A marker
  # beside an ON gate is a leftover, so say that.
  if [ -f "$TRUST_MARKER" ]; then
    if [ "${state#ON}" != "$state" ]; then
      echo "  trust window: stale — the gate is ON, so the window authorized by $(marker_field authorized_by) is over"
      echo "    clear the leftover marker with: bash scripts/publish-gate.sh on"
    elif trust_window_closed; then
      echo "  trust window: over — ${TRUST_CLOSED_REASON} — run \`publish-gate.sh rearm\`"
    else
      echo "  trust window: open, authorized by $(marker_field authorized_by), expires $(marker_field expires_at)"
    fi
  fi

  # cli#489 -- say whether the log pairs up, without being asked. An `on`
  # with no `off` before it is the shape a lost authorization leaves, and
  # nobody goes looking for it.
  audit_divergence
  audit_pairing || true
  exit 0
}

do_on() {
  require_gh_auth
  local before
  if ! before="$(read_env)"; then env_unreadable; fi

  # Idempotent: already ON is success, not an error.
  case "$(gate_state "$before")" in
    ON*)
      echo "${ENV_NAME}: already ON ($(gate_state "$before" | cut -d' ' -f2-)) — nothing to do"
      echo "  can_admins_bypass: $(admin_bypass "$before")"
      # cli#507 — this early return is the one path that could reach
      # ON-with-a-marker, because it never gets as far as the restore. A
      # marker sitting beside an ON gate names a window that is over.
      if [ -f "$TRUST_MARKER" ]; then
        if consume_marker; then
          echo "  cleared a stale trust window (authorized by $(marker_field authorized_by))"
        fi
      fi
      exit 0
      ;;
  esac

  # cli#488 — the write lives in restore_gate, which `rearm` also calls. Two
  # copies of a write to production config is the shape that drifts: one gets
  # a fix and the other does not. The encoding is unchanged from what shipped
  # (the `reviewers[][...]` bracket form gh expands correctly), per the note
  # in do_off about not rewriting a working write.
  restore_gate

  # cli#507 — only after the read-back says ON. The window a marker names is
  # over once approval is required again, so consuming it here cannot discard
  # an authorization that still has work to do.
  local had_marker=""
  [ -f "$TRUST_MARKER" ] && had_marker="$(marker_field authorized_by)"
  consume_marker || true

  audit "on" "$RESTORE_LOGIN" "reviewer=${RESTORE_LOGIN} id=${RESTORE_UID_OUT}"
  echo "${ENV_NAME}: ${RESTORE_STATE} — publish waits for approval"
  echo "  can_admins_bypass: ${RESTORE_BYPASS}"
  [ -n "$had_marker" ] && echo "  closed the trust window authorized by ${had_marker}"
  exit 0
}

do_off() {
  local who=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --authorized-by) shift; who="${1:-}" ;;
      *) usage; exit 3 ;;
    esac
    shift
  done

  if [ -z "$who" ]; then
    echo "publish-gate: refusing to clear the gate without --authorized-by <who>." >&2
    echo "" >&2
    echo "  The argument is the record of who decided. It lands in ${AUDIT}." >&2
    echo "  Per ADR-004 §Amendment 2026-11-05, clearing the gate is the operator's" >&2
    echo "  call for one publish — not a default and not an agent's to infer." >&2
    echo "" >&2
    echo "  bash scripts/publish-gate.sh off --authorized-by operator" >&2
    exit 3
  fi

  require_gh_auth
  local before login
  if ! before="$(read_env)"; then env_unreadable; fi
  login="$(operator_login)"

  # cli#481. This was `-F "reviewers=[]"`, and it never once worked.
  #
  # `gh api -F` types its value: it reads true/false/null and integers,
  # and treats everything else as a string. So `[]` went over the wire as
  # the two-character string "[]", the API wanted an array, and the PUT
  # came back 422 every time. The gate has never been clearable since it
  # shipped.
  #
  # Sending the body as JSON removes the guessing — `--input` passes the
  # bytes through and the array stays an array.
  #
  # do_on is NOT changed to match. It uses `-F "reviewers[][type]=User"`,
  # which is the bracket form gh expands into an array correctly, and it
  # works. Rewriting a working write to production config for the sake of
  # symmetry buys nothing and risks the one path that currently functions.
  #
  # Safe to send `reviewers` alone: the environment carries no
  # deployment_branch_policy and no wait_timer rule, so there is nothing
  # else in the body to preserve. Checked before writing, and the
  # read-back below is the real guard either way.
  printf '{"reviewers":[]}' \
    | gh api "$ENV_PATH" --method PUT --input - >/dev/null 2>&1 \
    || die_postcondition "the write to ${ENV_NAME} was rejected; the gate state is unchanged."

  local after state
  if ! after="$(read_env)"; then env_unreadable; fi
  state="$(gate_state "$after")"
  if [ "$state" != "OFF" ]; then
    die_postcondition "cleared the reviewer but the read-back says ${state}. Treat the gate as still ON and retry."
  fi

  audit "off" "${login:-unknown}" "authorized_by=${who}"
  echo "${ENV_NAME}: OFF — the next publish runs unattended"
  echo "  authorized by: ${who}"
  echo "  can_admins_bypass: $(admin_bypass "$after")"
  echo ""
  echo "  Restore as soon as the publish lands:"
  echo "    bash scripts/publish-gate.sh on"
  exit 0
}

# ---------------------------------------------------------------------------

case "${1:-}" in
  status) shift; do_status "$@" ;;
  on)     shift; do_on "$@" ;;
  off)    shift; do_off "$@" ;;
  audit)  shift; do_audit "$@" ;;
  trust)  shift; do_trust "$@" ;;
  rearm)  shift; do_rearm "$@" ;;
  ""|-h|--help) usage; exit 3 ;;
  *) echo "publish-gate: unknown verb '${1}'" >&2; usage; exit 3 ;;
esac
