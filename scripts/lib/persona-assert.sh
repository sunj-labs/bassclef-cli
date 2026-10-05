#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# scripts/lib/persona-assert.sh — Cooper 3-level goal assertions
# over a dynamic-driver capture.
#
# @pattern patterns/code/vernon/anticorruption-layer.md
#
# Walking skeleton for Tier A chain-driver assertions per docs/plans/
# tier-a-dynamic-driver-roadmap.md.
#
# Three assertion functions, one per Cooper goal level:
#
#   persona_assert_end_goal <capture_file> <expected_artifact_glob> [<expected_exit>]
#     — chain completes; expected artifact landed; exit code matches
#
#   persona_assert_experience_goal <capture_file> [<jargon_file>]
#     — output carries no BLOCK terms from standards/bassclef-internal-jargon.md
#
#   persona_assert_life_goal <capture_file> [<max_output_lines>]
#     — artifact is scannable (default ≤40 output lines between === markers)
#
# All three return 0 on PASS, 1 on FAIL. FAIL prints a one-line reason
# to stderr.
#
# Called by scripts/tests/smoke-drive-e2e-*.test.sh — the per-skill
# persona drivers (walking skeleton: Sam × /onboard-repo).

set -euo pipefail

# ----- Helpers -----

_persona_extract_output_block() {
  # Extract the `=== output ===` to `=== exit:` body (what the adopter actually sees)
  local file="$1"
  awk '/^=== output ===/{flag=1; next} /^=== exit:/{flag=0} flag' "$file"
}

_persona_extract_exit_code() {
  local file="$1"
  grep -oE '^=== exit: [0-9]+' "$file" 2>/dev/null | awk '{print $NF}' | head -1
}

# ----- End goal: chain completes + artifact lands + exit OK -----

persona_assert_end_goal() {
  local capture="$1"
  local artifact_glob="${2:-}"
  local expected_exit="${3:-0}"

  if [[ ! -f "$capture" ]]; then
    echo "end-goal FAIL: capture file missing: $capture" >&2
    return 1
  fi

  local actual_exit
  actual_exit=$(_persona_extract_exit_code "$capture")
  if [[ "$actual_exit" != "$expected_exit" ]]; then
    echo "end-goal FAIL: exit=$actual_exit; expected $expected_exit" >&2
    return 1
  fi

  if [[ -n "$artifact_glob" ]]; then
    # Check the capture mentions the artifact landing — adopter-visible evidence
    local output
    output=$(_persona_extract_output_block "$capture")
    if ! echo "$output" | grep -qF "$artifact_glob"; then
      echo "end-goal FAIL: capture does not mention expected artifact: $artifact_glob" >&2
      return 1
    fi
  fi

  return 0
}

# ----- Experience goal: output has no bassclef jargon BLOCK terms -----

persona_assert_experience_goal() {
  local capture="$1"
  local jargon_file="${2:-}"

  if [[ -z "$jargon_file" ]]; then
    # Default to a built-in minimal jargon list (walking skeleton)
    local terms=(
      "operationalize"
      "load-bearing"
      "composer"
      "primitive"
      "tier-preset"
      "blast radius"
      "compose-with"
      "scope-bounded"
      "substrate primitive"
    )
    local output
    output=$(_persona_extract_output_block "$capture")
    local hit
    for term in "${terms[@]}"; do
      if echo "$output" | grep -qiF "$term"; then
        hit="${hit:+${hit}, }${term}"
      fi
    done
    if [[ -n "${hit:-}" ]]; then
      echo "experience-goal FAIL: output carries jargon: ${hit}" >&2
      return 1
    fi
    return 0
  fi

  # jargon_file path — use its contents when supplied
  local output
  output=$(_persona_extract_output_block "$capture")
  local hits=""
  while IFS= read -r term; do
    [[ -z "$term" ]] && continue
    [[ "$term" =~ ^# ]] && continue
    if echo "$output" | grep -qiF "$term"; then
      hits="${hits:+${hits}, }${term}"
    fi
  done < "$jargon_file"
  if [[ -n "$hits" ]]; then
    echo "experience-goal FAIL: output carries jargon from $jargon_file: $hits" >&2
    return 1
  fi
  return 0
}

# ----- Life goal: artifact is scannable (output body stays short) -----

persona_assert_life_goal() {
  local capture="$1"
  local max_lines="${2:-40}"

  local output_lines
  output_lines=$(_persona_extract_output_block "$capture" | wc -l | tr -d ' ')
  output_lines=${output_lines:-0}

  if [[ "$output_lines" -gt "$max_lines" ]]; then
    echo "life-goal FAIL: output has $output_lines lines; adopter scan ceiling $max_lines" >&2
    return 1
  fi
  return 0
}
