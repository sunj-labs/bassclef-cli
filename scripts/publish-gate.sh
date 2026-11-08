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
AUDIT="${PUBLISH_GATE_AUDIT:-state/publish-gate-audit.log}"

usage() {
  cat >&2 <<EOF
Usage:
  publish-gate.sh status
  publish-gate.sh on
  publish-gate.sh off --authorized-by <who>

status  read the gate without changing it
on      require operator approval before npm publish (the resting state)
off     clear the requirement for one publish; restore it with \`on\` after

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

audit() {
  local verb="$1" who="$2" detail="$3"
  local dir; dir="$(dirname "$AUDIT")"
  [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null || return 0
  printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$verb" "$who" "$detail" >> "$AUDIT" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Verbs
# ---------------------------------------------------------------------------

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
  exit 0
}

do_on() {
  require_gh_auth
  local before login uid
  if ! before="$(read_env)"; then env_unreadable; fi
  login="$(operator_login)"
  uid="$(operator_id)"
  [ -n "$login" ] && [ -n "$uid" ] || die_precondition "could not resolve the authenticated user from \`gh api user\`."


  # Idempotent: already ON is success, not an error.
  case "$(gate_state "$before")" in
    ON*)
      echo "${ENV_NAME}: already ON ($(gate_state "$before" | cut -d' ' -f2-)) — nothing to do"
      echo "  can_admins_bypass: $(admin_bypass "$before")"
      exit 0
      ;;
  esac

  gh api "$ENV_PATH" --method PUT \
    -F "reviewers[][type]=User" \
    -F "reviewers[][id]=${uid}" >/dev/null 2>&1 \
    || die_postcondition "the write to ${ENV_NAME} was rejected. Run \`gh api ${ENV_PATH}\` to see the current state."

  local after state
  if ! after="$(read_env)"; then env_unreadable; fi
  state="$(gate_state "$after")"
  case "$state" in
    ON*) : ;;
    *) die_postcondition "wrote the reviewer but the read-back says ${state}. The gate is NOT protecting publish. Retry, or set it in Settings → Environments." ;;
  esac

  audit "on" "$login" "reviewer=${login} id=${uid}"
  echo "${ENV_NAME}: ${state} — publish waits for approval"
  echo "  can_admins_bypass: $(admin_bypass "$after")"
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
  ""|-h|--help) usage; exit 3 ;;
  *) echo "publish-gate: unknown verb '${1}'" >&2; usage; exit 3 ;;
esac
