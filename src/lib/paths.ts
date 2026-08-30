// Single source of truth for bassclef-cli path constants.
//
// @requirement R-NPM-lite-006
// @risk R6 — path literals live in one place; every consumer imports from here.
//
// Contract per docs/pre-mortem-mappings/2026-08-28-npm-lite-bundling.md R6:
// no `.claude/(hooks|skills|rules)` string literal exists anywhere in src/
// outside this file. The grep audit in tests/harness/paths.test.ts enforces it.
//
// The values are the two roots the copy-substrate module walks over:
// - SUBSTRATE_ROOT — the folder inside the npm package that holds the
//   146-file substrate tree (bundled at prepublish time per ADR-007 D1).
// - CLAUDE_TARGET_ROOT — the folder inside the adopter project where
//   Claude Code loads skills, rules, hooks, and other substrate assets.
//
// If either name changes, EVERY consumer inherits the change via a single
// import edit. That is the whole point of the constants module.

export const SUBSTRATE_ROOT = 'substrate' as const;
export const CLAUDE_TARGET_ROOT = '.claude' as const;

// The three config files an adopter edits between init and migrate.
// Path A migration preserves these via SHA-256 hash comparison per
// ADR-008 D3. List sourced from tests/fixtures/v0.0.2-init-manifest.json
// (v0.0.2 legacy shape). Adding a file here is a MINOR bump; removing
// one is MAJOR (breaks adopter contract).
//
// @risk R2 — one source of truth for the config-file list; every
// consumer imports from here.
export const CONFIG_FILES = [
  '.claude/settings.json',
  'substrate.config.md',
  'substrate.secrets.md',
] as const;

// The expected file count for a current-shape init manifest. Used by
// detectAdopterState to distinguish current from unknown shapes. Value
// tracks the bundled substrate size shipped by scope-b1 (146 substrate
// files + 3 config files = 149).
//
// @risk R4 — a manifest with neither 3 entries (legacy) nor
// CURRENT_ENTRY_COUNT entries triggers the Nygard exit-5 branch.
export const CURRENT_ENTRY_COUNT = 149;
