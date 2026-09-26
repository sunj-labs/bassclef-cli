#!/usr/bin/env bash
# tier: upstream
# shadow-detection.sh — shared function detect_stale_bassclef_shadows.
#
# Purpose: refuse to init smoke test when a stale bassclef checkout at
#          $(dirname WORK_DIR)/bassclef would shadow the npm install via
#          resolver Check 1 in lib/bassclef-dir-resolver.sh.
#
# Root cause: peer's upstream#1954 fixes the resolver precedence. This lib
#             is defense-in-depth at the smoke harness surface.
#
# Sourced by: scripts/smoke-reset.sh, harness/docker/entry.sh
# Inherited by: scripts/smoke-one-shot.sh (via smoke-reset --cold call path)
#
# Function: detect_stale_bassclef_shadows <workdir>
# Behavior:
#   - Computes shadow path = $(dirname workdir)/bassclef
#   - If shadow dir does NOT exist → return 0 silently
#   - If shadow dir exists BUT sentinel file
#     ($shadow/presence/install/bassclef-hook-connect.sh) absent → return 0
#     silently (S1 fold — no false positive on coincidental dir names)
#   - If sentinel present + SMOKE_ALLOW_SHADOW=1 → emit bypass log + return 0
#   - If sentinel present + no bypass → emit warning naming path + three
#     options + return 1
#
# Warning message names (per N2 fold):
#   1. The exact shadow path
#   2. mv aside — recover later
#   3. rm -rf — destroy stale
#   4. SMOKE_ALLOW_SHADOW=1 — bypass this run
#
# Design refs:
#   - docs/use-cases/UC-247-shadow-detection.md
#   - docs/risk-ledgers/2026-09-26-247-shadow-detection.md
#   - bassclef-cli#247, bassclef-upstream#1954

detect_stale_bassclef_shadows() {
  local workdir="${1:-${HOME}/tmp/bassclef-smoke-test}"

  # Strip trailing slash for reliable dirname (S5 sanity)
  workdir="${workdir%/}"

  local parent
  parent="$(dirname "$workdir")"

  local shadow="$parent/bassclef"
  local sentinel="$shadow/presence/install/bassclef-hook-connect.sh"

  # S1 fold — silently pass when the shadow dir is absent
  if [[ ! -d "$shadow" ]]; then
    return 0
  fi

  # S1 fold — silently pass when the dir exists but is not a bassclef checkout
  if [[ ! -f "$sentinel" ]]; then
    return 0
  fi

  # Sentinel present — check bypass
  if [[ "${SMOKE_ALLOW_SHADOW:-0}" == "1" ]]; then
    echo "shadow-detection: SMOKE_ALLOW_SHADOW=1 bypass — proceeding despite shadow at $shadow" >&2
    return 0
  fi

  # Sentinel present + no bypass — refuse
  echo "shadow-detection: WARN — adjacent bassclef checkout at $shadow shadows the npm install." >&2
  echo "  This will corrupt settings.json when Claude opens (see bassclef-upstream#1954)." >&2
  echo "  Options:" >&2
  echo "    1. mv $shadow ${shadow}.aside   — recover the checkout later" >&2
  echo "    2. rm -rf $shadow                — destroy the stale checkout" >&2
  echo "    3. SMOKE_ALLOW_SHADOW=1 <cmd>    — bypass this run (accept the risk)" >&2
  return 1
}
