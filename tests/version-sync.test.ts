// version-sync test — pins the invariant that src/index.ts's version
// constant matches package.json.
//
// @verifies R-NPM-007
//
// The `bassclef --version` CLI + programmatic API both read from the
// constant in src/index.ts. If it drifts from package.json (e.g. bump
// script updates one but not the other), tags ship broken. This test
// fires at every commit so the drift class cannot recur.
//
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
//
// [x] src/index.ts version constant matches package.json version

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');

describe('version constant sync', () => {
  it('src/index.ts version matches package.json version', () => {
    const pkg = JSON.parse(readFileSync(resolve(REPO_ROOT, 'package.json'), 'utf8'));
    const indexTs = readFileSync(resolve(REPO_ROOT, 'src/index.ts'), 'utf8');
    const match = indexTs.match(/export const version = '([^']+)' as const;/);
    expect(match, 'src/index.ts must export `version` as a string literal').not.toBeNull();
    expect(match![1]).toBe(pkg.version);
  });
});
