// Sort an adopter-relative path into one catalog family.
//
// Per ADR-010 D8: one classifier, three readers. The banner, the JSON
// report, and the init manifest all call this. Before cli 1.1.1 the rule
// lived inline in init.ts, was used once to print the banner, and was
// then discarded — so the JSON report and the manifest each counted a
// different, smaller slice of the same run.
//
// Prefixes mirror ADR-057 D1 exactly. They are built from the
// CLAUDE_TARGET_ROOT constant so the single-source-of-truth check stays
// green: no hard-coded directory names live outside paths.ts.

import { CLAUDE_TARGET_ROOT } from './paths.js';

export type Family =
  | 'skills'
  | 'rules'
  | 'agents'
  | 'luminaries'
  | 'hooks'
  | 'libs'
  | 'adrs'
  | 'standards'
  | 'templates'
  | 'presence-templates'
  | 'scripts'
  | 'root-docs'
  | 'other';

export const FAMILIES: readonly Family[] = [
  'skills', 'rules', 'agents', 'luminaries', 'hooks', 'libs', 'adrs',
  'standards', 'templates', 'presence-templates', 'scripts', 'root-docs',
  'other',
] as const;

const UNDER_CLAUDE = `${CLAUDE_TARGET_ROOT}/`;

// Ordered because the first match wins. Every prefix ends in a slash, so
// a near-miss directory name cannot match the skills rule (RFC-0004 M-2).
const PREFIX_RULES: ReadonlyArray<readonly [string, Family]> = [
  [`${UNDER_CLAUDE}skills/`, 'skills'],
  [`${UNDER_CLAUDE}rules/`, 'rules'],
  [`${UNDER_CLAUDE}agents/`, 'agents'],
  [`${UNDER_CLAUDE}luminaries/`, 'luminaries'],
  [`${UNDER_CLAUDE}hooks/`, 'hooks'],
  ['lib/', 'libs'],
  ['architecture/decisions/', 'adrs'],
  ['standards/', 'standards'],
  ['templates/', 'templates'],
  ['presence/install/', 'presence-templates'],
  ['scripts/', 'scripts'],
];

/**
 * Classify one adopter-relative path.
 *
 * Precondition: `path` is relative to the adopter repo root, not absolute.
 * Postcondition: returns exactly one family. Never throws. A path this
 * function does not recognize returns `other` rather than being dropped,
 * so the per-family counts always sum to the number of files.
 */
export function classifyEntry(path: string): Family {
  for (const [prefix, family] of PREFIX_RULES) {
    if (path.startsWith(prefix)) return family;
  }
  // Root doc: a file at the repo root whose name starts with a capital
  // letter (README.md, AGENTS.md, CONTRIBUTING.md). The capital is what
  // separates a shipped document from `.gitignore` and `whereami.md`.
  // This rule is a heuristic; it lives here so one fix corrects every
  // caller, and the tests pin the files it must and must not catch.
  if (!path.includes('/') && /^[A-Z]/.test(path)) return 'root-docs';
  return 'other';
}

/** Zeroed count-per-family, for callers that tally. */
export function emptyCatalogCounts(): Record<Family, number> {
  const out = {} as Record<Family, number>;
  for (const f of FAMILIES) out[f] = 0;
  return out;
}
