#!/usr/bin/env bash
# tier: upstream
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
# Tier 0 tests for scripts/lib/smoke-assert.sh drift cure per cli #253.
# Covers check_no_silent_skip loud-skip filter + check_no_unexpected_blocked
# banner-shape refinement. Ships alongside the source amendments.
#
# Anchor luminaries:
#   @luminary michael-feathers — characterization tests pin v1.6.1 substrate
#     output shape before the check amendment lands.
#   @luminary kent-beck — RED-first; every test fails against unmodified source.
#   @luminary michael-nygard — loud-skip stderr IS the correct stability signal;
#     the check preserves it as PASS.

# test-list:
# [ ] T01 check_no_silent_skip PASS — capture has no skip lines
# [ ] T02 check_no_silent_skip FAIL — capture has silent "skip —" line (no prefix)
# [ ] T03 check_no_silent_skip PASS — capture has ONLY loud-skip lines carrying [bassclef-hook-connect] prefix
# [ ] T04 check_no_silent_skip FAIL — capture has mixed loud + silent (silent still counted)
# [ ] T05 check_no_silent_skip MISSING — capture file does not exist
# [ ] T06 check_no_unexpected_blocked PASS — no BLOCKED text anywhere
# [ ] T07 check_no_unexpected_blocked FAIL — line-start `🛑 BLOCKED:` banner
# [ ] T08 check_no_unexpected_blocked FAIL — line-start `BLOCKED:` banner (bare shape)
# [ ] T09 check_no_unexpected_blocked PASS — prose mentions `BLOCKED:` inside backticks / rule reference (not a banner)
# [ ] T10 check_no_unexpected_blocked PASS — allowlisted BLOCKED banner counted as allowed
# [ ] T11 check_no_unexpected_blocked FAIL — banner + prose reference; only banner counts as unexpected
# [ ] T12 check_no_unexpected_blocked MISSING — capture file does not exist

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/smoke-assert.sh"

# shellcheck disable=SC1090
source "$LIB"

_tests_total=0
_tests_passed=0
_tests_failed=0
_failures=()

pass() { _tests_total=$((_tests_total+1)); _tests_passed=$((_tests_passed+1)); echo "  PASS  $1"; }
fail() { _tests_total=$((_tests_total+1)); _tests_failed=$((_tests_failed+1)); _failures+=("$1 :: $2"); echo "  FAIL  $1 — $2"; }

assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1] got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "needle [$2] not in output"; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ============================================================
# check_no_silent_skip
# ============================================================

# T01 — clean capture, no skip lines
CAP="$WORK/t01-clean.txt"
cat > "$CAP" <<'EOF'
=== command: /some-skill
some ordinary output
=== exit: 0
EOF
OUT=$(check_no_silent_skip "$CAP" 2>&1)
RC=$?
assert_eq "0" "$RC" "T01 rc"
assert_contains "$OUT" "PASS|no-silent-skip|0 matches" "T01 msg"

# T02 — silent skip (bare "skip —" without loud-skip prefix)
CAP="$WORK/t02-silent.txt"
cat > "$CAP" <<'EOF'
=== command: /some-skill
hook fired
skip — nothing to do
=== exit: 0
EOF
OUT=$(check_no_silent_skip "$CAP" 2>&1)
RC=$?
assert_eq "1" "$RC" "T02 rc (silent skip must FAIL)"
assert_contains "$OUT" "FAIL|no-silent-skip|1" "T02 msg"

# T03 — loud-skip only (v1.6.1 signal per bassclef-upstream#1954 PR #1956)
CAP="$WORK/t03-loud.txt"
cat > "$CAP" <<'EOF'
=== command: /some-skill
[bassclef-hook-connect] session-reflection.d: attempting merge for CWD=<workdir>
[bassclef-hook-connect] tier=lite but manifest missing/empty — merging all wires
[bassclef-hook-connect] skip — target missing at <workdir>/.claude/hooks/bassclef-sync.sh
[bassclef-hook-connect] skip — target missing at <workdir>/.claude/hooks/session-reflection.sh
=== exit: 0
EOF
OUT=$(check_no_silent_skip "$CAP" 2>&1)
RC=$?
assert_eq "0" "$RC" "T03 rc (loud skip must PASS after cure)"
assert_contains "$OUT" "PASS|no-silent-skip" "T03 msg"

# T04 — mixed loud + silent; silent still counted as fail
CAP="$WORK/t04-mixed.txt"
cat > "$CAP" <<'EOF'
=== command: /some-skill
[bassclef-hook-connect] skip — target missing at <workdir>/.claude/hooks/bassclef-sync.sh
some prose
skip — bare silent skip
=== exit: 0
EOF
OUT=$(check_no_silent_skip "$CAP" 2>&1)
RC=$?
assert_eq "1" "$RC" "T04 rc (silent skip in mixed must FAIL)"
assert_contains "$OUT" "FAIL|no-silent-skip|1" "T04 msg"

# T05 — missing capture
OUT=$(check_no_silent_skip "$WORK/does-not-exist.txt" 2>&1)
RC=$?
assert_eq "1" "$RC" "T05 rc"
assert_contains "$OUT" "MISSING|precheck" "T05 msg"

# ============================================================
# check_no_unexpected_blocked
# ============================================================

# T06 — no BLOCKED anywhere
CAP="$WORK/t06-clean.txt"
cat > "$CAP" <<'EOF'
=== command: /temperance
temperance fired; scope declared.
=== exit: 0
EOF
OUT=$(check_no_unexpected_blocked "$CAP" 2>&1)
RC=$?
assert_eq "0" "$RC" "T06 rc"
assert_contains "$OUT" "PASS|no-unexpected-blocked|0 BLOCKED" "T06 msg"

# T07 — 🛑 BLOCKED banner at line start
CAP="$WORK/t07-emoji-banner.txt"
cat > "$CAP" <<'EOF'
=== command: /temperance
🛑 BLOCKED: SESSION_LOCK exists and is 0 minutes old
=== exit: 0
EOF
OUT=$(check_no_unexpected_blocked "$CAP" 2>&1)
RC=$?
assert_eq "1" "$RC" "T07 rc (emoji banner must FAIL)"
assert_contains "$OUT" "FAIL|no-unexpected-blocked|1" "T07 msg"

# T08 — bare BLOCKED: at line start (no emoji)
CAP="$WORK/t08-bare-banner.txt"
cat > "$CAP" <<'EOF'
=== command: /temperance
BLOCKED: some banner shape without emoji
=== exit: 0
EOF
OUT=$(check_no_unexpected_blocked "$CAP" 2>&1)
RC=$?
assert_eq "1" "$RC" "T08 rc (bare line-start banner must FAIL)"
assert_contains "$OUT" "FAIL|no-unexpected-blocked|1" "T08 msg"

# T09 — prose mentions BLOCKED: inside backticks / rule reference (NOT a banner)
# This is the real Fail 2 shape from run 36247931882.
CAP="$WORK/t09-prose-ref.txt"
cat > "$CAP" <<'EOF'
=== command: /temperance
Per `.claude/rules/blocked-items.md`, first the mandatory echo: session-start
hook surfaced no `BLOCKED:` items other than the orientation-gate note (which
says "nothing to do yet — this becomes a gate once a goal is in flight"). No
blocked items require resolution before proceeding.
=== exit: 0
EOF
OUT=$(check_no_unexpected_blocked "$CAP" 2>&1)
RC=$?
assert_eq "0" "$RC" "T09 rc (prose ref must PASS after cure)"
assert_contains "$OUT" "PASS|no-unexpected-blocked" "T09 msg"

# T10 — allowlisted BLOCKED banner
CAP="$WORK/t10-allowlisted.txt"
cat > "$CAP" <<'EOF'
=== command: /temperance
🛑 BLOCKED: SESSION_LOCK exists and is 0 minutes old
=== exit: 0
EOF
ALLOWLIST="$WORK/t10-allowlist.txt"
cat > "$ALLOWLIST" <<'EOF'
SESSION_LOCK exists
EOF
OUT=$(check_no_unexpected_blocked "$CAP" "$ALLOWLIST" 2>&1)
RC=$?
assert_eq "0" "$RC" "T10 rc"
assert_contains "$OUT" "PASS|no-unexpected-blocked" "T10 msg"

# T11 — banner + prose reference; only banner counts as unexpected
CAP="$WORK/t11-banner-plus-prose.txt"
cat > "$CAP" <<'EOF'
=== command: /temperance
Per `.claude/rules/blocked-items.md`, my job is to echo BLOCKED items.
🛑 BLOCKED: SESSION_LOCK exists and is 0 minutes old
The word `BLOCKED:` appears here as a rule reference, not a banner.
=== exit: 0
EOF
OUT=$(check_no_unexpected_blocked "$CAP" 2>&1)
RC=$?
assert_eq "1" "$RC" "T11 rc (real banner must FAIL; prose ref filtered)"
assert_contains "$OUT" "FAIL|no-unexpected-blocked|1" "T11 msg"

# T12 — missing capture
OUT=$(check_no_unexpected_blocked "$WORK/does-not-exist.txt" 2>&1)
RC=$?
assert_eq "1" "$RC" "T12 rc"
assert_contains "$OUT" "MISSING|precheck" "T12 msg"

# ============================================================
echo ""
echo "==============================="
echo "  Total:  $_tests_total"
echo "  Passed: $_tests_passed"
echo "  Failed: $_tests_failed"
echo "==============================="
if [[ $_tests_failed -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for f in "${_failures[@]}"; do echo "  - $f"; done
  exit 1
fi
exit 0
