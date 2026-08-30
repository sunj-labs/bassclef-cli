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
