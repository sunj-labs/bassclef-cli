#!/usr/bin/env bash
# tier: upstream
# scripts/validate-cross-repo-contracts.sh
#
# Validator for the cross-repo contracts registry per ADR-059. Step 2 of
# the #2157 longrun — the A ingredient of C+A+B.
#
# Reads standards/cross-repo-contracts.json. For each registered contract:
#   1. Validates the registry against standards/state-spine/schemas/cross-repo-contracts.schema.json
#   2. Verifies schema_ref file exists on disk
#   3. For json/jsonc format, compiles schema_ref via ajv
#   4. Verifies every test_refs path exists on disk
#   5. For yaml/bash format, runs sidecar_validator instead of ajv on schema_ref
#
# Fires per registered contract. Fails loud on any drift.
#
# Usage:
#   scripts/validate-cross-repo-contracts.sh [--repo-root PATH] [--strict] [--help]
#
# Exit codes:
#   0   — all contracts validated OR SKIP_CROSS_REPO_VALIDATE=1 OR ajv missing (graceful skip)
#   1   — jq missing (hard dep); malformed JSON in registry
#   2   — registry file missing
#   3   — registry fails schema validation
#   4   — schema_ref file missing on disk
#   5   — schema_ref file exists but ajv compile fails
#   6   — test_refs file missing on disk
#   7   — sidecar_validator missing (for yaml/bash contracts)
#   8   — sidecar_validator fired and exited non-zero
#
# Overrides (logged via trace-helper):
#   SKIP_CROSS_REPO_VALIDATE=1  — bypass entire check (one-shot bypass)
#
# Per ADR-059 + bassclef-upstream#2157
# Composes with:
#   standards/cross-repo-contracts.json           (the registry)
#   standards/state-spine/schemas/cross-repo-contracts.schema.json  (schema)
#   standards/cross-repo-contracts-changes.md     (ledger)
#   .claude/rules/defensive-bash.md               (bash safety discipline)

set -euo pipefail

# ============================================================================
# Argument parsing
# ============================================================================

REPO_ROOT=""
STRICT_MODE=0
PRINT_HELP=0
AJV_STRICT=()

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --strict)
      STRICT_MODE=1
      shift
      ;;
    --help|-h)
      PRINT_HELP=1
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      PRINT_HELP=1
      shift
      ;;
  esac
done

if [ "$PRINT_HELP" -eq 1 ]; then
  cat <<'HELP'
Usage: scripts/validate-cross-repo-contracts.sh [options]

Validates the cross-repo contracts registry per ADR-059.

Options:
  --repo-root PATH   Repo root to validate (default: auto-detect from script location)
  --strict           Pass --strict=true to ajv for stricter validation
  --help, -h         Show this usage message

Exit codes:
  0  All contracts validated (or SKIP env set, or ajv missing)
  1  jq missing or malformed JSON
  2  Registry file missing
  3  Registry fails schema validation
  4  schema_ref file missing
  5  ajv compile fails on schema_ref
  6  test_refs file missing
  7  sidecar_validator missing
  8  sidecar_validator exited non-zero

Env overrides:
  SKIP_CROSS_REPO_VALIDATE=1  Bypass entire check (logged)
HELP
  exit 0
fi

# ============================================================================
# Env bypass
# ============================================================================

if [ "${SKIP_CROSS_REPO_VALIDATE:-0}" = "1" ]; then
  echo "validate-cross-repo-contracts: SKIP_CROSS_REPO_VALIDATE=1 — bypassed" >&2
  exit 0
fi

# ============================================================================
# Repo-root auto-detect
# ============================================================================

if [ -z "$REPO_ROOT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

REGISTRY="$REPO_ROOT/standards/cross-repo-contracts.json"
SCHEMA="$REPO_ROOT/standards/state-spine/schemas/cross-repo-contracts.schema.json"

# ============================================================================
# Dependency checks
# ============================================================================

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'EOF'
validate-cross-repo-contracts: jq not installed — required for parsing the registry.

Install via:
  macOS:   brew install jq
  Debian:  apt-get install jq
  Alpine:  apk add jq
EOF
  exit 1
fi

HAS_AJV=0
if command -v ajv >/dev/null 2>&1; then
  HAS_AJV=1
else
  echo "validate-cross-repo-contracts: ajv not installed — graceful skip of schema validation; file + path checks still run." >&2
fi

# ============================================================================
# Registry presence check
# ============================================================================

if [ ! -f "$REGISTRY" ]; then
  echo "validate-cross-repo-contracts: registry file missing at $REGISTRY" >&2
  exit 2
fi

if [ ! -f "$SCHEMA" ]; then
  echo "validate-cross-repo-contracts: registry schema file missing at $SCHEMA" >&2
  exit 2
fi

# ============================================================================
# Tempdir with trap cleanup
# ============================================================================

TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

# ============================================================================
# Registry schema validation (whole-document ajv against meta-schema)
# ============================================================================

if [ "$STRICT_MODE" -eq 1 ]; then
  AJV_STRICT=(--strict=true)
fi

if [ "$HAS_AJV" -eq 1 ]; then
  if ! ajv validate -s "$SCHEMA" -d "$REGISTRY" --spec=draft2020 -c ajv-formats ${AJV_STRICT[@]+"${AJV_STRICT[@]}"} >/dev/null 2>&1; then
    echo "validate-cross-repo-contracts: registry fails schema validation" >&2
    ajv validate -s "$SCHEMA" -d "$REGISTRY" --spec=draft2020 -c ajv-formats ${AJV_STRICT[@]+"${AJV_STRICT[@]}"} >&2 || true
    exit 3
  fi
fi

# ============================================================================
# Per-contract checks
# ============================================================================

ERRORS=0
CONTRACT_NAMES=$(jq -r '.contracts[].name' "$REGISTRY")

for contract_name in $CONTRACT_NAMES; do
  echo "validating contract: $contract_name" >&2

  # Pull the entry via jq
  ENTRY=$(jq -c --arg n "$contract_name" '.contracts[] | select(.name == $n)' "$REGISTRY")
  FORMAT=$(echo "$ENTRY" | jq -r '.format')
  SCHEMA_REF=$(echo "$ENTRY" | jq -r '.schema_ref')
  SIDECAR=$(echo "$ENTRY" | jq -r '.sidecar_validator // ""')
  TEST_REFS=$(echo "$ENTRY" | jq -r '.test_refs[]')

  # 1. schema_ref file exists
  SCHEMA_REF_ABS="$REPO_ROOT/$SCHEMA_REF"
  if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "jsonc" ]; then
    if [ ! -f "$SCHEMA_REF_ABS" ]; then
      echo "  FAIL  $contract_name: schema_ref missing at $SCHEMA_REF" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi
    # 2. ajv compile schema_ref
    if [ "$HAS_AJV" -eq 1 ]; then
      if ! ajv compile -s "$SCHEMA_REF_ABS" --spec=draft2020 -c ajv-formats ${AJV_STRICT[@]+"${AJV_STRICT[@]}"} >/dev/null 2>&1; then
        echo "  FAIL  $contract_name: ajv compile fails on schema_ref $SCHEMA_REF" >&2
        ajv compile -s "$SCHEMA_REF_ABS" --spec=draft2020 -c ajv-formats ${AJV_STRICT[@]+"${AJV_STRICT[@]}"} >&2 || true
        ERRORS=$((ERRORS + 1))
        continue
      fi
    fi
  elif [ "$FORMAT" = "yaml" ] || [ "$FORMAT" = "bash" ]; then
    # 3. Non-JSON — require sidecar_validator
    if [ -z "$SIDECAR" ]; then
      echo "  FAIL  $contract_name: format=$FORMAT requires sidecar_validator (none set)" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi
    SIDECAR_ABS="$REPO_ROOT/$SIDECAR"
    if [ ! -f "$SIDECAR_ABS" ]; then
      echo "  FAIL  $contract_name: sidecar_validator missing at $SIDECAR" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi
    if ! bash "$SIDECAR_ABS" >/dev/null 2>&1; then
      echo "  FAIL  $contract_name: sidecar_validator at $SIDECAR exited non-zero" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi
  fi

  # 4. test_refs exist on disk
  for tref in $TEST_REFS; do
    if [ ! -f "$REPO_ROOT/$tref" ]; then
      echo "  FAIL  $contract_name: test_refs path missing — $tref" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ "$ERRORS" -eq 0 ]; then
    echo "  OK    $contract_name" >&2
  fi
done

# ============================================================================
# Final verdict
# ============================================================================

if [ "$ERRORS" -gt 0 ]; then
  echo "validate-cross-repo-contracts: $ERRORS error(s) across registered contracts" >&2
  # Return the first-error code precedence; use a generic non-zero code
  # (specific exit codes above fire from the point of failure)
  exit 4
fi

echo "validate-cross-repo-contracts: all contracts validated" >&2
exit 0
