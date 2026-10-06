#!/usr/bin/env bash
# tier: upstream
#
# scripts/lib/claude-chain.sh — claude -c multi-turn chain helper.
#
# Ships cli#383 scaffold. Tier A persona drivers source this lib and
# call claude_chain_capture (turn 1) + claude_chain_continue (turn N+1).
# Captures land per-turn with a 5-line header. Helper preserves claude's
# exit code and respects the CLAUDE_PERMISSIONS + CLAUDE_CHAIN_TIMEOUT_SEC
# env-var contract.
#
# Interface (narrow per @luminary john-ousterhout — one lookup covers
# both turn classes):
#
#   source scripts/lib/claude-chain.sh
#   claude_chain_capture  <prompt> <out-file>   # turn 1 (fresh session)
#   claude_chain_continue <prompt> <out-file>   # turn N+1 (continues last)
#
# Env-var contract (@luminary vaughn-vernon anticorruption layer):
#
#   CLAUDE_BIN                — claude binary path (default: claude)
#   CLAUDE_CHAIN_TIMEOUT_SEC  — per-turn timeout seconds (default: 180)
#   CLAUDE_PERMISSIONS        — strict suppresses --dangerously-skip-permissions
#                               (default: unset -> flag passed)
#
# Exit codes (@luminary tony-hoare postcondition contract):
#
#   0    turn captured, claude exit 0
#   N    turn captured, claude exit N preserved
#   127  claude binary not on PATH
#   5    turn timed out (SIGALRM 142 mapped per harness convention)
#
# @pattern patterns/code/gof/facade.md

# NOTE: `set -e` deliberately omitted. This lib is sourced into test
# harnesses that capture non-zero exits from claude_chain_capture/continue
# via `RC=$?` for assertion. Enabling `-e` kills the harness shell on the
# first expected-error test case. Every error site in this lib uses
# explicit `|| rc=$?` or `return N` so `-e` adds no safety here. Defensive-
# bash discipline (.claude/rules/defensive-bash.md discipline 1) deviation
# documented per architect-review 2026-10-07 F3 conditional guidance.
set -uo pipefail

# ---------------------------------------------------------------------
# _claude_chain_resolve_bin — locate claude binary
# Precondition: CLAUDE_BIN set or default
# Postcondition: prints resolved path on stdout OR returns 127
# ---------------------------------------------------------------------
_claude_chain_resolve_bin() {
  local bin="${CLAUDE_BIN:-claude}"
  if [[ -x "$bin" ]]; then
    echo "$bin"
    return 0
  fi
  if command -v "$bin" >/dev/null 2>&1; then
    command -v "$bin"
    return 0
  fi
  return 127
}

# ---------------------------------------------------------------------
# _claude_chain_write_header — 5-line fixture header
# ---------------------------------------------------------------------
_claude_chain_write_header() {
  local out_file="$1"
  local prompt="$2"
  local resolved_bin="$3"
  local timeout_sec="$4"
  local mode="$5"

  {
    printf '=== skill: %s\n' "$prompt"
    printf '=== claude_bin: %s\n' "$resolved_bin"
    printf '=== timeout_sec: %s\n' "$timeout_sec"
    printf '=== mode: %s\n' "$mode"
    printf '=== output ===\n'
  } > "$out_file"
}

# ---------------------------------------------------------------------
# _claude_chain_invoke — core invocation + capture
# $1 = prompt, $2 = out-file, $3 = mode (capture|continue)
# ---------------------------------------------------------------------
_claude_chain_invoke() {
  local prompt="$1"
  local out_file="$2"
  local mode="$3"

  local resolved_bin
  resolved_bin="$(_claude_chain_resolve_bin)" || {
    echo "claude-chain: claude binary not on PATH (CLAUDE_BIN=${CLAUDE_BIN:-claude})" >&2
    return 127
  }

  local timeout_sec="${CLAUDE_CHAIN_TIMEOUT_SEC:-180}"

  # Write header FIRST so partial captures carry provenance even on crash
  _claude_chain_write_header "$out_file" "$prompt" "$resolved_bin" "$timeout_sec" "$mode"

  # Build claude args per mode + CLAUDE_PERMISSIONS contract
  local -a args=()
  if [[ "${CLAUDE_PERMISSIONS:-}" != "strict" ]]; then
    args+=("--dangerously-skip-permissions")
  fi
  if [[ "$mode" == "continue" ]]; then
    args+=("-c")
  fi
  args+=("-p" "$prompt")

  # Invoke with per-turn timeout. perl SIGALRM is portable across macOS +
  # linux containers (per smoke-drive-onboard-repo.sh precedent).
  # F1 fix (architect-review 2026-10-07): declare $child_pid in closure scope
  # so SIGALRM handler kills the actual child, not signal-name-coerced-to-0
  # (which would send SIGTERM to the entire process group).
  local rc=0
  perl -e '
    use strict; use warnings;
    my $timeout = shift @ARGV;
    my @cmd = @ARGV;
    my $child_pid;
    $SIG{ALRM} = sub { kill 15, $child_pid if $child_pid; exit 142 };
    alarm $timeout;
    $child_pid = fork();
    if ($child_pid == 0) { exec @cmd or die "exec failed: $!"; }
    waitpid($child_pid, 0);
    exit($? >> 8);
  ' "$timeout_sec" "$resolved_bin" "${args[@]}" >> "$out_file" 2>&1 || rc=$?

  # Map SIGALRM 142 -> harness convention exit 5 (timeout)
  if [[ "$rc" == "142" ]]; then
    rc=5
  fi

  # Write exit trailer so persona-assert.sh can read exit code from capture
  printf '=== exit: %s\n' "$rc" >> "$out_file"

  return "$rc"
}

# ---------------------------------------------------------------------
# claude_chain_capture — turn 1 (fresh session)
# ---------------------------------------------------------------------
claude_chain_capture() {
  if [[ "$#" -ne 2 ]]; then
    echo "usage: claude_chain_capture <prompt> <out-file>" >&2
    return 1
  fi
  _claude_chain_invoke "$1" "$2" "capture"
}

# ---------------------------------------------------------------------
# claude_chain_continue — turn N+1 (continues last session via -c)
# ---------------------------------------------------------------------
claude_chain_continue() {
  if [[ "$#" -ne 2 ]]; then
    echo "usage: claude_chain_continue <prompt> <out-file>" >&2
    return 1
  fi
  _claude_chain_invoke "$1" "$2" "continue"
}
