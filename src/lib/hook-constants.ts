// Shared constants for hook file mode bits.
//
// Per DRY discipline (P1 fold from RFC-0002) — the executable-bit
// value and mask live in one module. ExecutableBitEnforcer sets the
// mode. Tier 0 tests assert the mode. Both read from here.
//
// @verifies P1-fold (RFC-0002 Hunt & Thomas — DRY on HOOK_EXECUTABLE_MODE)

/** Mode bits set on every copied hook binary — owner rwx, group rx, other rx. */
export const HOOK_EXECUTABLE_MODE = 0o755;

/** Mask that tests "any execute bit set" on a file mode. */
export const HOOK_EXECUTABLE_MASK = 0o111;
