#!/usr/bin/env bash
# tier: upstream
#
# lib/smoke-assert.sh — 4 check functions per Saltzer-Schroeder complete
# mediation (docs/specs/smoke-evidence-capture.md § Four checks).
#
# Sourced by scripts/smoke-assert-hooks.sh and scripts/smoke-assert-skills.sh
# (pre-mortem F4 fold — one contract for both consumers).
#
# Design refs:
#   docs/use-cases/UC-lib-smoke-assert.md
#   docs/decompositions/smoke-evidence-capture.md § AssertionSuite Control
#
# Check function contract:
#   check_<name> <capture_file> [<allowlist_file>]
#   Emits: <STATUS>|<check-name>|<message>  on stdout
#   Returns: 0 on PASS, 1 on FAIL
#
# @pattern patterns/code/gof/strategy.md — one function per check;
# same signature; caller swaps at will.

# Guard against sourcing a missing capture file.
_smoke_assert_precheck() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "MISSING|precheck|file not found: $file"
    return 1
  fi
  return 0
}

# check_no_not_found — capture must not carry "not found" or
# "No such file or directory" lines.
check_no_not_found() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local matches
  matches=$(grep -cE '(not found|No such file or directory)' "$capture_file" 2>/dev/null | tr -d '\n' || echo 0)
  [ -z "$matches" ] && matches=0
  if [ "$matches" -eq 0 ]; then
    echo "PASS|no-not-found|0 matches"
    return 0
  fi
  echo "FAIL|no-not-found|${matches} match(es)"
  return 1
}

# check_no_silent_skip — capture must not carry "skip —" lines
# (a fragment reporting doing nothing).
check_no_silent_skip() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local matches
  matches=$(grep -c 'skip —' "$capture_file" 2>/dev/null | tr -d '\n' || echo 0)
  [ -z "$matches" ] && matches=0
  if [ "$matches" -eq 0 ]; then
    echo "PASS|no-silent-skip|0 matches"
    return 0
  fi
  echo "FAIL|no-silent-skip|${matches} match(es)"
  return 1
}

# check_no_unexpected_blocked — capture must not carry BLOCKED blocks
# except those declared in the allowlist file (one grep-E pattern per
# line; empty lines skipped).
check_no_unexpected_blocked() {
  local capture_file="$1"
  local allowlist_file="${2:-}"
  _smoke_assert_precheck "$capture_file" || return 1
  local blocked
  blocked=$(grep -cE '(^|[^A-Za-z])BLOCKED:' "$capture_file" 2>/dev/null | tr -d '\n' || echo 0)
  [ -z "$blocked" ] && blocked=0
  if [ "$blocked" -eq 0 ]; then
    echo "PASS|no-unexpected-blocked|0 BLOCKED"
    return 0
  fi

  local allowed=0
  if [ -n "$allowlist_file" ] && [ -f "$allowlist_file" ]; then
    while IFS= read -r pattern; do
      [ -z "$pattern" ] && continue
      case "$pattern" in \#*) continue ;; esac
      local m
      m=$(grep -cE "(^|[^A-Za-z])BLOCKED:.*${pattern}" "$capture_file" 2>/dev/null | tr -d '\n' || echo 0)
      [ -z "$m" ] && m=0
      allowed=$((allowed + m))
    done < "$allowlist_file"
  fi

  local unexpected=$((blocked - allowed))
  if [ "$unexpected" -le 0 ]; then
    echo "PASS|no-unexpected-blocked|${blocked} BLOCKED (all allowlisted)"
    return 0
  fi
  echo "FAIL|no-unexpected-blocked|${unexpected} unexpected BLOCKED"
  return 1
}

# check_paths_exist — every filesystem path the capture names must
# exist on disk. Per bassclef-cli#118 Option A — only extract paths
# that start with a known-absolute prefix (/Users/, /opt/, /etc/, /tmp/,
# /var/, /private/, /home/, /root/). Fragment paths like /agents/x.md
# are relative-path tails, not filesystem targets, and were false-
# positive-failing on the 2026-09-18 cold-adopter smoke.
check_paths_exist() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local total=0
  local missing=0
  local missing_list=""
  local paths
  # Skip capture-header lines (start with ===). Anchor to known-absolute
  # prefixes only. The prefix union covers macOS ($HOME under /Users/,
  # /private/var, /opt/homebrew), Linux (/home/, /var/, /etc/, /opt/, /root/),
  # and shared tmp (/tmp/). Fragment paths (/agents/, /rules/) skip.
  paths=$(grep -v '^===' "$capture_file" 2>/dev/null \
    | grep -oE '(/Users|/opt|/etc|/tmp|/var|/private|/home|/root)/[A-Za-z0-9_/.-]+' 2>/dev/null \
    | sort -u || echo "")
  if [ -z "$paths" ]; then
    echo "PASS|paths-exist|0 paths named"
    return 0
  fi
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    total=$((total + 1))
    if [ ! -e "$p" ]; then
      missing=$((missing + 1))
      if [ -z "$missing_list" ]; then
        missing_list="$p"
      else
        missing_list="${missing_list}, $p"
      fi
    fi
  done <<< "$paths"
  if [ "$missing" -eq 0 ]; then
    echo "PASS|paths-exist|${total} paths checked"
    return 0
  fi
  echo "FAIL|paths-exist|${missing} of ${total} missing: ${missing_list}"
  return 1
}

# check_no_timeout — capture must not report exit 142 (SIGALRM). Per
# bassclef-cli#117: smoke-drive-skills wraps each `claude -p` call in a
# perl timeout; on hit the wrapper exits 142. Empty captures then passed
# every content check, so assert suite reported PASS on timed-out runs.
# This check reads the '=== exit: N' header line and fails on 142.
check_no_timeout() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local exit_line
  exit_line=$(grep '^=== exit: ' "$capture_file" 2>/dev/null | tail -1)
  if [ -z "$exit_line" ]; then
    # No exit line at all — captures without a header are legacy; pass
    # to keep the check additive. Sister check_no_crash covers non-zero
    # exits when the header is present.
    echo "PASS|no-timeout|no exit header (legacy capture)"
    return 0
  fi
  local exit_code
  exit_code=$(printf '%s' "$exit_line" | awk '{print $NF}')
  if [ "$exit_code" = "142" ]; then
    echo "FAIL|no-timeout|skill killed by timeout (exit 142)"
    return 1
  fi
  echo "PASS|no-timeout|exit ${exit_code}"
  return 0
}

# check_no_crash — capture must not report a non-zero exit other than
# 142 (which check_no_timeout covers). Per bassclef-cli#117: a skill
# exiting 7 or 1 means the run crashed before finishing; the capture
# body may look OK but the run failed. Zero exits pass here; timeouts
# also pass (delegated to check_no_timeout so the failure message stays
# specific per check).
check_no_crash() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local exit_line
  exit_line=$(grep '^=== exit: ' "$capture_file" 2>/dev/null | tail -1)
  if [ -z "$exit_line" ]; then
    echo "PASS|no-crash|no exit header (legacy capture)"
    return 0
  fi
  local exit_code
  exit_code=$(printf '%s' "$exit_line" | awk '{print $NF}')
  if [ "$exit_code" = "0" ] || [ "$exit_code" = "142" ]; then
    echo "PASS|no-crash|exit ${exit_code}"
    return 0
  fi
  echo "FAIL|no-crash|skill exited ${exit_code}"
  return 1
}
