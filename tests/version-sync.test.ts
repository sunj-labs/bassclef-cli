// version-sync test — pins the invariant that all four version-bearing
// files in this repo carry the same version string.
//
// @verifies R-NPM-007
//
// The `bassclef --version` CLI + programmatic API + README badge +
// CHANGELOG history all read the version from different places. If any
// drifts (e.g. bump script updates one but not the others), tags ship
// broken. This test fires at every commit so the drift class cannot
// recur.
//
// v1.5.0 (2026-09-21) shipped exactly this drift — package.json bumped
// but src/index.ts + README + CHANGELOG stayed stale. The pre-publish
// check caught it too late (at release: published, after the tag).
// Epic #194 Stories 1-3 move the check to PR time.
//
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
// Spec:     docs/specs/2026-09-21-pre-tag-version-sync.md.
// Lib:      src/lib/version-markers.ts (pure functions).
//
// test-list:
// [x] readVersionSet reads all four real files without throwing
// [x] all four sources agree at HEAD (no drift on the current repo state)
// [x] the version returned matches package.json exactly

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  readVersionSet,
  checkVersionSet,
  formatDriftMessage,
} from '../src/lib/version-markers.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');

describe('version sync across all four sources', () => {
  it('readVersionSet reads all four real files without throwing', () => {
    const set = readVersionSet(REPO_ROOT);
    expect(set['package.json']).toMatch(/^\d+\.\d+\.\d+/);
    expect(set['src/index.ts']).toMatch(/^\d+\.\d+\.\d+/);
    expect(set['README.md']).toMatch(/^\d+\.\d+\.\d+/);
    expect(set['CHANGELOG.md']).toMatch(/^\d+\.\d+\.\d+/);
  });

  it('all four sources agree at HEAD (no drift on repo state)', () => {
    const set = readVersionSet(REPO_ROOT);
    const finding = checkVersionSet(set);
    if (finding.drift) {
      // Print the drift message so failure output tells the operator what to fix.
      throw new Error(formatDriftMessage(finding));
    }
    expect(finding.drift).toBe(false);
  });

  it('version returned matches package.json exactly', () => {
    const pkg = JSON.parse(
      readFileSync(resolve(REPO_ROOT, 'package.json'), 'utf8'),
    );
    const set = readVersionSet(REPO_ROOT);
    expect(set['package.json']).toBe(pkg.version);
  });
});
