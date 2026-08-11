// @verifies: R-NPM-012
//
// Requirements traceability enforcement — iteration d.
//
// Phase 1.5 of the Traceability Subsystem promote at
// docs/promotes/2026-08-11-traceability-subsystem.md. Adds mechanical
// enforcement to the static requirement diagram shipped in iteration f
// at docs/requirements/2026-08-11-npm-distribution.md.
//
// Contract:
// - Registry lives in docs/requirements/2026-08-11-npm-distribution.md.
// - Source files annotate satisfaction via `@requirement R-NPM-XXX`.
// - Test files annotate verification via `@verifies R-NPM-XXX` (or
//   `@verifies: R-NPM-XXX`; both accepted).
// - Every requirement whose registry status is `satisfied` must have at
//   least one satisfy edge AND at least one verify edge.
// - Every ID referenced in code or tests must exist in the registry.
//
// Test-list per Beck TDD:
//   [x] Registry parses — 13 R-NPM-* IDs found
//   [x] Every satisfied requirement has at least one @requirement annotation
//   [x] Every satisfied requirement has at least one @verifies annotation
//   [x] Every referenced ID exists in the registry (no orphans)
//   [x] parseRegistry unit — malformed markdown yields empty array

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const REGISTRY_DOC = resolve(
  REPO_ROOT,
  'docs/requirements/2026-08-11-npm-distribution.md'
);

interface RegistryEntry {
  id: string;
  title: string;
  status: 'satisfied' | 'GAP';
}

// Parse the requirement registry table. Format per the doc:
//   | R-NPM-XXX | Title | Source | Status |
// Status cell either starts with "satisfied" (with optional qualifier)
// or starts with "gap". Rows whose 4th cell matches neither are
// treated as non-registry rows and skipped — the same doc also has a
// traceability matrix table with the same ID column but downstream
// columns that name ADRs, files, and tests instead of a status word.
export function parseRegistry(md: string): RegistryEntry[] {
  const lines = md.split('\n');
  const out: RegistryEntry[] = [];
  const rowRe = /^\|\s*(R-NPM-\d{3})\s*\|([^|]*?)\|([^|]*?)\|([^|]*?)\|/;
  for (const line of lines) {
    const m = rowRe.exec(line);
    if (!m) continue;
    const id = m[1]!;
    const title = m[2]!.trim();
    const statusCell = m[4]!.trim().toLowerCase();
    let status: 'satisfied' | 'GAP';
    if (statusCell.startsWith('satisfied')) {
      status = 'satisfied';
    } else if (statusCell.startsWith('gap')) {
      status = 'GAP';
    } else {
      // Non-registry row (traceability matrix). Skip.
      continue;
    }
    out.push({ id, title, status });
  }
  return out;
}

// Walk a directory recursively; collect files matching any extension.
function walkFiles(dir: string, exts: readonly string[]): string[] {
  if (!existsSync(dir)) return [];
  const out: string[] = [];
  const stack = [dir];
  while (stack.length) {
    const current = stack.pop()!;
    const entries = readdirSync(current);
    for (const name of entries) {
      const full = join(current, name);
      const st = statSync(full);
      if (st.isDirectory()) {
        if (
          name === 'node_modules' ||
          name === 'dist' ||
          name === '__snapshots__'
        )
          continue;
        stack.push(full);
        continue;
      }
      if (exts.some((e) => full.endsWith(e))) out.push(full);
    }
  }
  return out;
}

// Extract R-NPM-* IDs annotated with a specific directive.
// Accepts both `@requirement R-NPM-XXX` and `@requirement: R-NPM-XXX`.
export function extractIds(
  content: string,
  directive: 'requirement' | 'verifies'
): string[] {
  const pattern = new RegExp(`@${directive}[:\\s]+(R-NPM-\\d{3})`, 'g');
  const ids = new Set<string>();
  let m: RegExpExecArray | null;
  while ((m = pattern.exec(content)) !== null) {
    ids.add(m[1]!);
  }
  return [...ids];
}

// R-NPM-012 is a meta-requirement — "All Tier 0 tests GREEN". It is
// satisfied by the workflow running vitest and verified by the same
// step. Exempted from per-file annotation checks; the workflow itself
// carries the annotation via `.github/workflows/publish.yml`.
const META_EXEMPT = new Set<string>(['R-NPM-012']);

// The traceability test file itself contains R-NPM-* IDs as string
// literals inside its unit tests (extractIds unit case). Exclude it
// from the walk so those literals do not false-match as annotations.
const TRACEABILITY_TEST_FILE = 'requirements-traceability.test.ts';

describe('requirements traceability enforcement (iteration d)', () => {
  const registryDoc = readFileSync(REGISTRY_DOC, 'utf8');
  const registry = parseRegistry(registryDoc);
  const registryIds = new Set(registry.map((e) => e.id));
  const satisfiedIds = new Set(
    registry.filter((e) => e.status === 'satisfied').map((e) => e.id)
  );
  const checkedIds = new Set(
    [...satisfiedIds].filter((id) => !META_EXEMPT.has(id))
  );

  const sourceFiles = [
    ...walkFiles(resolve(REPO_ROOT, 'src'), ['.ts']),
    ...walkFiles(resolve(REPO_ROOT, 'scripts'), ['.mjs', '.js']),
    resolve(REPO_ROOT, 'vite.config.ts'),
  ];
  const testFiles = walkFiles(resolve(REPO_ROOT, 'tests'), ['.ts']).filter(
    (f) => !f.endsWith(TRACEABILITY_TEST_FILE)
  );

  const satisfyMap = new Map<string, string[]>();
  for (const file of sourceFiles) {
    if (!existsSync(file)) continue;
    const content = readFileSync(file, 'utf8');
    const ids = extractIds(content, 'requirement');
    for (const id of ids) {
      if (!satisfyMap.has(id)) satisfyMap.set(id, []);
      satisfyMap.get(id)!.push(file);
    }
  }

  const verifyMap = new Map<string, string[]>();
  for (const file of testFiles) {
    const content = readFileSync(file, 'utf8');
    const ids = extractIds(content, 'verifies');
    for (const id of ids) {
      if (!verifyMap.has(id)) verifyMap.set(id, []);
      verifyMap.get(id)!.push(file);
    }
  }

  it('registry parses 13 R-NPM-* IDs', () => {
    expect(registry.length).toBe(13);
    expect(registryIds.has('R-NPM-001')).toBe(true);
    expect(registryIds.has('R-NPM-013')).toBe(true);
  });

  it('registry marks 8 requirements as satisfied and 5 as GAP', () => {
    const gapCount = registry.filter((e) => e.status === 'GAP').length;
    expect(satisfiedIds.size).toBe(8);
    expect(gapCount).toBe(5);
  });

  it('every satisfied non-meta requirement has at least one @requirement annotation on source', () => {
    const missing: string[] = [];
    for (const id of checkedIds) {
      if (!satisfyMap.has(id) || satisfyMap.get(id)!.length === 0) {
        missing.push(id);
      }
    }
    expect(missing).toEqual([]);
  });

  it('every satisfied non-meta requirement has at least one @verifies annotation on a test', () => {
    const missing: string[] = [];
    for (const id of checkedIds) {
      if (!verifyMap.has(id) || verifyMap.get(id)!.length === 0) {
        missing.push(id);
      }
    }
    expect(missing).toEqual([]);
  });

  it('every ID referenced in @requirement or @verifies exists in the registry', () => {
    const orphans = new Set<string>();
    for (const id of satisfyMap.keys()) {
      if (!registryIds.has(id)) orphans.add(id);
    }
    for (const id of verifyMap.keys()) {
      if (!registryIds.has(id)) orphans.add(id);
    }
    expect([...orphans]).toEqual([]);
  });

  it('parseRegistry unit — empty markdown yields empty array', () => {
    expect(parseRegistry('')).toEqual([]);
  });

  it('parseRegistry unit — markdown without registry table yields empty array', () => {
    expect(parseRegistry('# Just a heading\n\nSome prose.\n')).toEqual([]);
  });

  it('extractIds unit — recognizes both space and colon forms', () => {
    expect(extractIds('// @requirement R-NPM-001\n', 'requirement')).toEqual([
      'R-NPM-001',
    ]);
    expect(extractIds('// @verifies: R-NPM-002\n', 'verifies')).toEqual([
      'R-NPM-002',
    ]);
  });
});
