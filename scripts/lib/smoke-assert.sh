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
  # Any-match semantics per bassclef-cli#187:
  #   - All paths exist (0 missing) → PASS
  #   - At least 1 path exists (missing < total) → PASS (OR-fallback hooks
  #     like bassclef-sync log "trying candidate A, using candidate B" —
  #     the fallthrough is intentional; ALL-must-exist over-strict).
  #   - No paths exist (all missing) → FAIL
  if [ "$missing" -eq 0 ]; then
    echo "PASS|paths-exist|${total} paths checked"
    return 0
  fi
  if [ "$missing" -lt "$total" ]; then
    local exists=$((total - missing))
    echo "PASS|paths-exist|${exists} of ${total} exists (any-match; ${missing} missing: ${missing_list})"
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

# check_no_unknown_command — capture must not carry "Unknown command:"
# lines. Per bassclef-cli#217: `claude -p "/slashname"` routes leading-
# slash strings to Claude Code's CLI slash-command matcher (not the
# Skill tool). The failure message is "Unknown command: /X" with exit 0.
# The other content checks (no-not-found, no-crash) all pass; nothing
# catches this class today. RFC S2 fold: exact grep "Unknown command:"
# anchored to line start OR word boundary to avoid false-positives on
# prose that mentions "unknown" or "unknown command" in general.
check_no_unknown_command() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local matches
  matches=$(grep -cE '(^|[[:space:]])Unknown command:' "$capture_file" 2>/dev/null | tr -d '\n' || echo 0)
  [ -z "$matches" ] && matches=0
  if [ "$matches" -eq 0 ]; then
    echo "PASS|no-unknown-command|0 matches"
    return 0
  fi
  echo "FAIL|no-unknown-command|${matches} match(es) — cli #217 class"
  return 1
}

# check_output_contains — generic positive-artifact check. Capture must
# contain the given needle. Callers pass a label so the STATUS row
# names which check fired. Per bassclef-cli#217 decomposition: sits
# behind per-skill wrappers that name concrete phrases.
check_output_contains() {
  local capture_file="$1"
  local needle="$2"
  local label="${3:-generic}"
  _smoke_assert_precheck "$capture_file" || return 1
  if grep -qF "$needle" "$capture_file" 2>/dev/null; then
    echo "PASS|contains-${label}|${needle} found"
    return 0
  fi
  echo "FAIL|contains-${label}|${needle} missing"
  return 1
}

# check_temperance_marker — /temperance skill's positive artifact.
# When the skill fires, it writes a marker under state/markers/temperance/
# in the CWD it ran from. This check inspects the given workdir for
# any *.marker file under state/markers/temperance/.
# Per RFC S1 fold: fail-safe when marker dir does not exist (missing
# dir = no marker = FAIL, not PASS-by-skip).
check_temperance_marker() {
  local capture_file="$1"
  local workdir="${2:-.}"
  _smoke_assert_precheck "$capture_file" || return 1
  local marker_dir="${workdir}/state/markers/temperance"
  if [ ! -d "$marker_dir" ]; then
    echo "FAIL|temperance-marker|marker dir absent: ${marker_dir}"
    return 1
  fi
  local marker_count
  marker_count=$(find "$marker_dir" -maxdepth 1 -type f -name '*.marker' 2>/dev/null | wc -l | tr -d ' \n' || echo 0)
  [ -z "$marker_count" ] && marker_count=0
  if [ "$marker_count" -gt 0 ]; then
    echo "PASS|temperance-marker|${marker_count} marker(s) in ${marker_dir}"
    return 0
  fi
  echo "FAIL|temperance-marker|no marker in ${marker_dir}"
  return 1
}

# check_luminary_norman_artifact — /luminary don-norman positive artifact.
# The skill loads Norman's lens; output should reference him by name.
# Case-insensitive grep for "Norman".
check_luminary_norman_artifact() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  if grep -qiE '(don norman|norman)' "$capture_file" 2>/dev/null; then
    echo "PASS|luminary-norman-artifact|Norman referenced"
    return 0
  fi
  echo "FAIL|luminary-norman-artifact|no Norman reference"
  return 1
}

# check_kiss_words_artifact — /kiss words --rewrite positive artifact.
# Per RFC N3 fold: requires ≥2 of [rewritten, grade, words] (AND-semantics)
# because any one token alone false-positives on natural prose.
check_kiss_words_artifact() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  local hits=0
  grep -qi 'rewritten' "$capture_file" 2>/dev/null && hits=$((hits + 1))
  grep -qi 'grade' "$capture_file" 2>/dev/null && hits=$((hits + 1))
  grep -qi 'words' "$capture_file" 2>/dev/null && hits=$((hits + 1))
  if [ "$hits" -ge 2 ]; then
    echo "PASS|kiss-words-artifact|${hits} of 3 tokens matched"
    return 0
  fi
  echo "FAIL|kiss-words-artifact|only ${hits} of 3 tokens (need ≥2)"
  return 1
}

# check_state_a_problem_artifact — /state-a-problem brief positive artifact.
# Framework tokens: Problem:, Who:, What:. Any one matches.
check_state_a_problem_artifact() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  if grep -qE '(Problem:|Who:|What:)' "$capture_file" 2>/dev/null; then
    echo "PASS|state-a-problem-artifact|framework token present"
    return 0
  fi
  echo "FAIL|state-a-problem-artifact|no framework token (Problem:/Who:/What:)"
  return 1
}

# check_whats_the_plan_artifact — /whats-the-plan positive artifact.
# Tokens: Plan:, Step, chain. Any one matches.
check_whats_the_plan_artifact() {
  local capture_file="$1"
  _smoke_assert_precheck "$capture_file" || return 1
  if grep -qE '(Plan:|Step|chain)' "$capture_file" 2>/dev/null; then
    echo "PASS|whats-the-plan-artifact|plan token present"
    return 0
  fi
  echo "FAIL|whats-the-plan-artifact|no plan token (Plan:/Step/chain)"
  return 1
}
