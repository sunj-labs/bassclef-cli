#!/usr/bin/env bash
# tier: upstream
#
# smoke-report.sh — build one markdown report from the two assertion
# JSONs; optionally post as a GitHub issue with idempotency.
#
# Design refs (must-read):
#   docs/specs/smoke-evidence-capture.md § Interfaces § smoke-report.sh
#   docs/use-cases/UC-smoke-run.md § Main flow Step 16 + Extensions 15a/b/c/d
#   docs/decompositions/smoke-evidence-capture.md § ReportBuilder + PublisherController
#   docs/risk-ledgers/2026-09-18-smoke-evidence-capture-pre-mortem.md
#
# Pre-mortem folds baked in this step:
#   D1 (retry-once-with-backoff on gh) + D2 (progress print) +
#   D5 (SMOKE_REPO_TARGET env override) + D6 (capture gh auth status) +
#   V5 (markdown fence-escape on captured content)
#
# Pre-mortem folds deferred to follow-on (noted below):
#   D3 (cap body at 60KB + gist for large captures) —
#     TODO once a report body exceeds 60KB in practice
#   V4 (upstream commit hash in report body) — TODO Step 6+
#   V6 (gh --json for parse-stable idempotency search) —
#     TODO once the current text-based search misbehaves
#
# Flags:
#   --captures-dir DIR      dir with hooks-assertions.json + skills-assertions.json
#                           (default: docs/smoke-captures/<date>)
#   --out FILE              report path (default: <captures-dir>/report.md)
#   --publish               post the report as a GitHub issue
#   --publish-only          skip report build; post the existing report file
#   --new                   with --publish: force a new issue even if one exists
#   --version-tag VER       tag the report body with the package version
#                           (default: reads @thebassclef/lite from `npm view`)
#   --gh BIN                use BIN instead of `gh` (used by tests with a mock)
#   --help                  print this help
#
# Env:
#   SMOKE_REPO_TARGET       gh repo target (default: sunj-labs/bassclef-cli)
#
# Exit codes:
#   0  report built + all assertions pass (or publish succeeded)
#   1  usage or config error
#   2  assertion JSON files missing
#   3  one or more assertions failed
#   4  publish failed after retry

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
echo ">>> ${SCRIPT_NAME} starting" >&2
trap 'echo "<<< ${SCRIPT_NAME} done (exit $?)" >&2' EXIT

CAPTURES_DIR=""
OUT_FILE=""
DO_PUBLISH=0
PUBLISH_ONLY=0
FORCE_NEW=0
VERSION_TAG=""
GH_BIN="gh"

REPO_TARGET="${SMOKE_REPO_TARGET:-sunj-labs/bassclef-cli}"

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --captures-dir) CAPTURES_DIR="$2"; shift 2 ;;
    --out) OUT_FILE="$2"; shift 2 ;;
    --publish) DO_PUBLISH=1; shift ;;
    --publish-only) DO_PUBLISH=1; PUBLISH_ONLY=1; shift ;;
    --new) FORCE_NEW=1; shift ;;
    --version-tag) VERSION_TAG="$2"; shift 2 ;;
    --gh) GH_BIN="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

ISO_DATE=$(date -u +"%Y-%m-%d")
[ -z "$CAPTURES_DIR" ] && CAPTURES_DIR="docs/smoke-captures/${ISO_DATE}"
[ -z "$OUT_FILE" ] && OUT_FILE="${CAPTURES_DIR}/report.md"

command -v jq >/dev/null 2>&1 || { echo "smoke-report: jq required" >&2; exit 1; }

# ---- helpers -----------------------------------------------------------------

# V5 fold — fence-escape a capture snippet for inclusion in report body.
# Wrap in ``` and replace any ``` inside with ` ` `.
escape_snippet() {
  local file="$1"
  local max_lines="${2:-20}"
  echo '```'
  head -n "$max_lines" "$file" | sed 's/```/` ` `/g'
  echo '```'
}

# D6 fold — capture gh auth status for report body.
gh_auth_line() {
  local user
  if user=$("$GH_BIN" api user --jq .login 2>/dev/null); then
    echo "gh auth: authenticated as \`${user}\`"
  else
    echo "gh auth: unauthenticated or not on PATH"
  fi
}

# D1 fold — retry once with backoff on gh calls that matter.
gh_with_retry() {
  local attempts=0
  local max=2
  while [ "$attempts" -lt "$max" ]; do
    if "$@"; then
      return 0
    fi
    attempts=$((attempts + 1))
    [ "$attempts" -lt "$max" ] && sleep 2
  done
  return 1
}

# ---- build the report --------------------------------------------------------

build_report() {
  local hooks_json="${CAPTURES_DIR}/hooks-assertions.json"
  local skills_json="${CAPTURES_DIR}/skills-assertions.json"

  # At least one of the two must exist.
  if [ ! -f "$hooks_json" ] && [ ! -f "$skills_json" ]; then
    echo "smoke-report: neither hooks-assertions.json nor skills-assertions.json in ${CAPTURES_DIR}" >&2
    exit 2
  fi

  local pass_count=0
  local fail_count=0
  local hooks_body=""
  local skills_body=""

  if [ -f "$hooks_json" ]; then
    local hp hf
    hp=$(jq '[.[] | select(.status == "PASS")] | length' "$hooks_json")
    hf=$(jq '[.[] | select(.status == "FAIL")] | length' "$hooks_json")
    pass_count=$((pass_count + hp))
    fail_count=$((fail_count + hf))
    hooks_body=$(jq -r '.[] | "| \(.source) | \(.check) | \(.status) | \(.message) |"' "$hooks_json")
  fi

  if [ -f "$skills_json" ]; then
    local sp sf
    sp=$(jq '[.[] | select(.status == "PASS")] | length' "$skills_json")
    sf=$(jq '[.[] | select(.status == "FAIL")] | length' "$skills_json")
    pass_count=$((pass_count + sp))
    fail_count=$((fail_count + sf))
    skills_body=$(jq -r '.[] | "| \(.source) | \(.check) | \(.status) | \(.message) |"' "$skills_json")
  fi

  local total=$((pass_count + fail_count))
  local overall="PASS"
  [ "$fail_count" -gt 0 ] && overall="FAIL"

  # Resolve version tag.
  local ver="$VERSION_TAG"
  [ -z "$ver" ] && ver="(unspecified)"

  mkdir -p "$(dirname "$OUT_FILE")"

  {
    echo "---"
    echo "report_shape_version: 1"
    echo "generated_at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "package_version: ${ver}"
    echo "overall: ${overall}"
    echo "totals: {pass: ${pass_count}, fail: ${fail_count}, total: ${total}}"
    echo "---"
    echo ""
    echo "# Smoke report — @thebassclef/lite@${ver} · ${ISO_DATE}"
    echo ""
    echo "**Overall: ${overall}** — ${pass_count} pass, ${fail_count} fail, ${total} total."
    echo ""
    echo "$(gh_auth_line)"
    echo ""

    if [ -n "$hooks_body" ]; then
      echo "## Hooks"
      echo ""
      echo "| source | check | status | message |"
      echo "|---|---|---|---|"
      printf '%s\n' "$hooks_body"
      echo ""
    fi

    if [ -n "$skills_body" ]; then
      echo "## Skills"
      echo ""
      echo "| source | check | status | message |"
      echo "|---|---|---|---|"
      printf '%s\n' "$skills_body"
      echo ""
    fi

    # RED-row detail sections with escaped snippets.
    if [ "$fail_count" -gt 0 ]; then
      echo "## RED rows"
      echo ""
      if [ -f "$hooks_json" ]; then
        jq -r '.[] | select(.status == "FAIL") | "\(.source)|\(.check)|\(.capture_path)"' "$hooks_json" \
          | while IFS='|' read -r src chk cap; do
              echo "### ${src} — ${chk}"
              echo ""
              echo "Capture: \`${cap}\`"
              echo ""
              if [ -f "$cap" ]; then
                escape_snippet "$cap" 20
              fi
              echo ""
            done
      fi
      if [ -f "$skills_json" ]; then
        jq -r '.[] | select(.status == "FAIL") | "\(.source)|\(.check)|\(.capture_path)"' "$skills_json" \
          | while IFS='|' read -r src chk cap; do
              echo "### ${src} — ${chk}"
              echo ""
              echo "Capture: \`${cap}\`"
              echo ""
              if [ -f "$cap" ]; then
                escape_snippet "$cap" 20
              fi
              echo ""
            done
      fi
    fi
  } > "$OUT_FILE"

  echo "smoke-report: wrote $OUT_FILE (${pass_count} pass, ${fail_count} fail)" >&2

  # Set exit code — publish path reads this to decide 0 vs 3.
  if [ "$fail_count" -gt 0 ]; then
    LOCAL_EXIT=3
  else
    LOCAL_EXIT=0
  fi
}

# ---- publish path (D1 + D2 + D5 + D6 folds; --new for F4 opt-out) ----------

publish_report() {
  if ! command -v "$GH_BIN" >/dev/null 2>&1; then
    echo "smoke-report: gh binary not found: $GH_BIN" >&2
    exit 4
  fi

  # Require --version-tag when publishing so the label + title stay stable.
  # Missing --version-tag would yield "(unspecified)" — not a valid label.
  if [ -z "$VERSION_TAG" ]; then
    echo "smoke-report: --version-tag required for --publish" >&2
    echo "  pass e.g. --version-tag \"\${LITE_VER}\"" >&2
    exit 1
  fi

  local ver="$VERSION_TAG"

  local title="smoke: @thebassclef/lite@${ver} · ${ISO_DATE}"
  # Derived label — one per release. Auto-created below, no operator setup.
  local label="smoke-run-${ver}"

  # Idempotent auto-create so the first run on a fresh target repo works.
  # --force updates description on re-run; silent on race.
  "$GH_BIN" label create "$label" --repo "$REPO_TARGET" \
    --description "smoke test report for @thebassclef/lite@${ver}" \
    --color 0E8A16 --force >/dev/null 2>&1 || true

  # D2 fold — progress print.
  echo "smoke-report: posting to GitHub (${REPO_TARGET}, label ${label})..." >&2

  # Idempotency check (RFC F4 fold — same-day-same-version).
  local existing=""
  if [ "$FORCE_NEW" -eq 0 ]; then
    existing=$("$GH_BIN" issue list --repo "$REPO_TARGET" --label "$label" --state open \
      --search "\"${ver}\" ${ISO_DATE}" --limit 1 --json number \
      2>/dev/null | jq -r '.[0].number // empty' || echo "")
  fi

  if [ -n "$existing" ]; then
    echo "smoke-report: updating existing issue #${existing} (idempotent)" >&2
    if gh_with_retry "$GH_BIN" issue edit "$existing" --repo "$REPO_TARGET" \
         --body-file "$OUT_FILE" >/dev/null; then
      echo "${existing} (updated)"
      return 0
    fi
    echo "smoke-report: publish failed after retry (see gh error above)" >&2
    exit 4
  fi

  local new_number
  if new_number=$(gh_with_retry "$GH_BIN" issue create --repo "$REPO_TARGET" \
    --title "$title" --label "$label" --body-file "$OUT_FILE" \
    | tail -1 | grep -oE '[0-9]+$'); then
    echo "$new_number"
    return 0
  fi

  echo "smoke-report: publish failed after retry (see gh error above)" >&2
  exit 4
}

# ---- main --------------------------------------------------------------------

LOCAL_EXIT=0

if [ "$PUBLISH_ONLY" -eq 0 ]; then
  build_report
fi

if [ "$DO_PUBLISH" -eq 1 ]; then
  if [ ! -f "$OUT_FILE" ]; then
    echo "smoke-report: --publish-only requires an existing report at $OUT_FILE" >&2
    exit 1
  fi
  publish_report
fi

exit "$LOCAL_EXIT"
