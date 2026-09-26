#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/template-method.md
# @pattern patterns/code/vernon/anticorruption-layer.md
#
# smoke-expect.sh — anticorruption layer between drive scripts and expect(1).
#
# Callers stay in bash. This lib hides expect's Tcl syntax quirks and
# exposes 5 bash-friendly verbs: drive_start, drive_send, drive_expect,
# drive_capture, drive_end.
#
# WALKING SKELETON — Beck TDD RED phase for cli#254.
# Interface functions exist and return sentinel exit code 42 ("unimplemented").
# Real bodies land in follow-on commits per docs/decompositions/2026-09-26-cli-254-interactive-drives.md § "Next — Beck TDD RED phase".
#
# Exit code vocabulary (per DriveScript interface in decompose doc):
#   0    — success
#   10   — expect script bug
#   11   — claude timeout
#   12   — assertion fail
#   13   — missing prereq
#   14   — INFRA fail (disk full, container issue)
#   15-19 — reserved
#   42   — walking-skeleton sentinel (this stub not yet implemented)

set -euo pipefail

# Re-source guard — safe to source multiple times per session.
if [[ -n "${_SMOKE_EXPECT_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SMOKE_EXPECT_LOADED=1

# Constants — versioned per Hyrum's Law fold H1
readonly SMOKE_EXPECT_VERSION="0.1.0-skeleton"
readonly SMOKE_EXPECT_UNIMPLEMENTED=42

# drive_start — initialize a drive session against a scratch directory.
# Arguments:
#   $1 — SCRATCH_DIR (absolute path; must exist)
# Postconditions:
#   Session state file written at $SCRATCH_DIR/.smoke-drive-session
#   Fresh capture log opened at $SCRATCH_DIR/drive.log
# Returns:
#   0 on success; 10 on expect bug; 13 if SCRATCH_DIR missing
drive_start() {
  echo "smoke-expect: drive_start — unimplemented (skeleton)" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

# drive_send — send a natural-language prompt to the interactive claude session.
# Arguments:
#   $1 — TEXT (bash string; will be escaped for expect send)
# Returns:
#   0 on success; 10 on expect bug; 11 on timeout
drive_send() {
  echo "smoke-expect: drive_send — unimplemented (skeleton)" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

# drive_expect — wait for a pattern in the claude session output.
# Arguments:
#   $1 — PATTERN (regex; anchored)
#   $2 — TIMEOUT (seconds; default 180)
# Returns:
#   0 on match; 11 on timeout
drive_expect() {
  echo "smoke-expect: drive_expect — unimplemented (skeleton)" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

# drive_capture — dump the captured session output to a file.
# Arguments:
#   $1 — DEST_FILE (absolute path; parent dir must exist)
# Postconditions:
#   $DEST_FILE contains stdout + stderr from the session
# Returns:
#   0 on success; 14 on write failure
drive_capture() {
  echo "smoke-expect: drive_capture — unimplemented (skeleton)" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

# drive_end — teardown the drive session.
# Postconditions:
#   Session state file removed
#   Expect subprocess terminated
# Returns:
#   0 always
drive_end() {
  echo "smoke-expect: drive_end — unimplemented (skeleton)" >&2
  return $SMOKE_EXPECT_UNIMPLEMENTED
}

# smoke_expect_version — return the current lib version string.
# Used by drive scripts to assert compatibility.
smoke_expect_version() {
  echo "$SMOKE_EXPECT_VERSION"
}
