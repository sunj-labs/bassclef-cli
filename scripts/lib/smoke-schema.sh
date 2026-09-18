#!/usr/bin/env bash
# tier: upstream
#
# lib/smoke-schema.sh — AssertionResult shape helpers.
#
# Sourced by scripts/smoke-assert-hooks.sh and scripts/smoke-assert-skills.sh
# (pre-mortem F6 fold — one schema owner, per docs/decompositions/
# smoke-evidence-capture.md § Cross-cutting concerns).
#
# Design refs:
#   docs/use-cases/UC-lib-smoke-assert.md
#   docs/decompositions/smoke-evidence-capture.md § AssertionResult entity
#
# AssertionResult shape (one JSON object per check per source):
#   {source, check, status, message, capture_path}

# Emit one AssertionResult as a JSON object on stdout.
# Args: source_name check_name status message capture_path
assertion_result_json() {
  local source_name="$1"
  local check="$2"
  local status="$3"
  local message="$4"
  local capture_path="$5"
  jq -n \
    --arg source "$source_name" \
    --arg check "$check" \
    --arg status "$status" \
    --arg message "$message" \
    --arg capture_path "$capture_path" \
    '{source: $source, check: $check, status: $status, message: $message, capture_path: $capture_path}'
}
