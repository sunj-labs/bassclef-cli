#!/usr/bin/env bash
# tier: lite
# testing-tier: 0 (strict TDD per .claude/rules/testing-tier-config.md)
#
# Adopter was trying to: run /build on their spec authored from the
# bundled template, see a non-zero step count, and advance the build
# cycle without re-authoring the spec headers by hand.
#
# Pins Kunal #2036 finding #2 (/build Phase 1 awk range closes on own
# start line) + finding #3 (template heading mismatch — WU → step
# vocab rename grace window).
#
# Upstream cure: bassclef-upstream PR #2043 (part of release-2026-10-03-89ceaa15, tag v1.7.0).
# Cure shape — flag-based extractor accepts both heading forms:
#   /^## (Steps|Workunits) enumerated/ { in_section=1; next }
#   /^## / { in_section=0 }
#   in_section
#
# Pre-cure characterization: at parent of PR #2043, the awk range
# `/^## Steps enumerated/,/^## /` returns zero lines because `^## `
# matches `^## Steps enumerated` and closes the range on its own
# start line.
#
# UC: docs/use-cases/UC-script-cli-294-driver-2-build-against-template.md
# Risk ledger: docs/risk-ledgers/2026-10-03-cli-294-smoke-drivers.md
# Parent: cli#294 Step 4

# test-list:
# [x] T01 new-form fixture (## Steps enumerated + ### Step-N) → awk returns >= 2 step lines
# [x] T02 legacy-form fixture (## Workunits enumerated + ### WU-N) → awk returns >= 2 step lines
# [x] T03 bundled build SKILL carries dual-form pattern `## (Steps|Workunits) enumerated`
# [x] T04 SKIP cleanly if build SKILL unreachable (dist/lite/ + sibling both absent)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_MSGS=()

# Locate build SKILL — adopter view first, sibling fallback
BUILD_SKILL=""

if [ -f "$REPO_ROOT/dist/lite/.claude/skills/build/SKILL.md" ]; then
  BUILD_SKILL="$REPO_ROOT/dist/lite/.claude/skills/build/SKILL.md"
elif [ -n "${BASSCLEF_SIBLING_ROOT:-}" ] && [ -f "$BASSCLEF_SIBLING_ROOT/.claude/skills/build/SKILL.md" ]; then
  BUILD_SKILL="$BASSCLEF_SIBLING_ROOT/.claude/skills/build/SKILL.md"
elif [ -f "$HOME/src/sunj-labs/bassclef/.claude/skills/build/SKILL.md" ]; then
  BUILD_SKILL="$HOME/src/sunj-labs/bassclef/.claude/skills/build/SKILL.md"
else
  echo "SKIP (T04): no build SKILL.md reachable at dist/lite/ or sibling or ~/src/sunj-labs/bassclef/" >&2
  exit 77
fi

# Scratch dir + fixtures
TMP_BASE="$(mktemp -d)"
trap "rm -rf '$TMP_BASE'" EXIT

NEW_FIXTURE="$TMP_BASE/new.md"
LEGACY_FIXTURE="$TMP_BASE/legacy.md"

cat > "$NEW_FIXTURE" <<'MARKDOWN'
# Spec — fixture (new heading form)

## Overview

Some overview content.

## Steps enumerated

### Step-1 — scaffold the thing

Pins US-001.

### Step-2 — ship the thing

Pins US-002.

## Acceptance

Some acceptance content.
MARKDOWN

cat > "$LEGACY_FIXTURE" <<'MARKDOWN'
# Spec — fixture (legacy heading form; grace window through 2026-10-31)

## Overview

Legacy content.

## Workunits enumerated

### WU-1 — scaffold the thing

Pins US-001.

### WU-2 — ship the thing

Pins US-002.

## Acceptance

Some acceptance content.
MARKDOWN

# T01 — new-form fixture
NEW_COUNT=$(awk '
  /^## (Steps|Workunits) enumerated/ { in_section=1; next }
  /^## / { in_section=0 }
  in_section
' "$NEW_FIXTURE" | grep -cE '^### (Step|WU)-' || true)

if [ "$NEW_COUNT" -ge 2 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T01 FAIL: new-form fixture awk returned $NEW_COUNT step lines; expected >= 2. Awk range likely closes on own start (pre-cure regression).")
fi

# T02 — legacy-form fixture
LEGACY_COUNT=$(awk '
  /^## (Steps|Workunits) enumerated/ { in_section=1; next }
  /^## / { in_section=0 }
  in_section
' "$LEGACY_FIXTURE" | grep -cE '^### (Step|WU)-' || true)

if [ "$LEGACY_COUNT" -ge 2 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T02 FAIL: legacy-form fixture awk returned $LEGACY_COUNT step lines; expected >= 2. Grace window dropped?")
fi

# T03 — bundled SKILL carries dual-form pattern
if grep -qE '## \(Steps\|Workunits\) enumerated' "$BUILD_SKILL"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("T03 FAIL: build SKILL ($BUILD_SKILL) missing dual-form regex pattern '## (Steps|Workunits) enumerated'")
fi

# Summary
echo "driver-2 build-against-template: $PASS pass / $FAIL fail (source: $BUILD_SKILL)"
if [ $FAIL -gt 0 ]; then
  printf '%s\n' "${FAIL_MSGS[@]}" >&2
  exit 1
fi

exit 0
