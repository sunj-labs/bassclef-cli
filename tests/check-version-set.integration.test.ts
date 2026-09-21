// Integration test for scripts/check-version-set.mjs.
//
// Spawns the mjs script against fixture repos + real repo. Verifies:
//   - Exit 0 on clean repo
//   - Exit 2 on drift (v1.5.0 shape characterization)
//   - Exit 2 on missing marker
//   - stderr carries the operator-facing message on drift
//
// Serves as the divergence-catch net between src/lib/version-markers.ts
// (canonical TS lib for the test suite) and scripts/check-version-set.mjs
// (self-contained JS mirror for the pre-commit hook + CLI use).
//
// @verifies R-NPM-007 (extension per Epic #194 Stories 1-3)
//
// test-list:
// [x] real repo (all 4 sources at HEAD) exits 0
// [x] fixture with v1.5.0 shape (package.json ahead of siblings) exits 2 + names drift
// [x] fixture with missing package.json .version key exits 2 + names package.json
// [x] fixture with missing README marker exits 2 + names README.md

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const SCRIPT = resolve(REPO_ROOT, 'scripts/check-version-set.mjs');

function makeFixtureRepo(shape: {
  packageVersion?: string | null;
  indexVersion?: string | null;
  readmeVersion?: string | null;
  changelogVersion?: string | null;
}): string {
  const dir = mkdtempSync(resolve(tmpdir(), 'check-version-set-'));
  mkdirSync(resolve(dir, 'src'), { recursive: true });

  // package.json
  if (shape.packageVersion === null) {
    writeFileSync(
      resolve(dir, 'package.json'),
      JSON.stringify({ name: 'x' }, null, 2),
    );
  } else {
    writeFileSync(
      resolve(dir, 'package.json'),
      JSON.stringify(
        { name: 'x', version: shape.packageVersion ?? '1.5.1' },
        null,
        2,
      ),
    );
  }

  // src/index.ts
  if (shape.indexVersion === null) {
    writeFileSync(resolve(dir, 'src/index.ts'), 'export let version = "1.5.1";');
  } else {
    writeFileSync(
      resolve(dir, 'src/index.ts'),
      `export const version = '${shape.indexVersion ?? '1.5.1'}' as const;\n`,
    );
  }

  // README.md
  if (shape.readmeVersion === null) {
    writeFileSync(resolve(dir, 'README.md'), '# README\n\nNo marker.\n');
  } else {
    writeFileSync(
      resolve(dir, 'README.md'),
      `# README\n<!-- version-start -->${shape.readmeVersion ?? '1.5.1'}<!-- version-end -->\n`,
    );
  }

  // CHANGELOG.md
  if (shape.changelogVersion === null) {
    writeFileSync(
      resolve(dir, 'CHANGELOG.md'),
      '# Changelog\n\n## [Unreleased]\n\n### Added\n',
    );
  } else {
    writeFileSync(
      resolve(dir, 'CHANGELOG.md'),
      `# Changelog\n\n## [Unreleased]\n\n## [${shape.changelogVersion ?? '1.5.1'}] - 2026-09-21\n`,
    );
  }

  return dir;
}

describe('scripts/check-version-set.mjs — integration', () => {
  const fixtures: string[] = [];

  afterAll(() => {
    for (const dir of fixtures) {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('real repo exits 0 (all four sources agree at HEAD)', () => {
    const result = spawnSync('node', [SCRIPT, REPO_ROOT], { encoding: 'utf8' });
    expect(result.status).toBe(0);
  });

  it('v1.5.0-shape fixture exits 2 with drift message', () => {
    const dir = makeFixtureRepo({
      packageVersion: '1.5.0',
      indexVersion: '1.4.1',
      readmeVersion: '1.4.1',
      changelogVersion: '1.4.1',
    });
    fixtures.push(dir);

    const result = spawnSync('node', [SCRIPT, dir], { encoding: 'utf8' });
    expect(result.status).toBe(2);
    expect(result.stderr).toContain('Version drift');
    expect(result.stderr).toContain('package.json=1.5.0');
    expect(result.stderr).toContain('src/index.ts=1.4.1');
    expect(result.stderr).toContain('npm run bump');
  });

  it('missing package.json .version key exits 2 and names package.json', () => {
    const dir = makeFixtureRepo({
      packageVersion: null,
      indexVersion: '1.5.1',
      readmeVersion: '1.5.1',
      changelogVersion: '1.5.1',
    });
    fixtures.push(dir);

    const result = spawnSync('node', [SCRIPT, dir], { encoding: 'utf8' });
    expect(result.status).toBe(2);
    expect(result.stderr).toContain('package.json');
  });

  it('missing README marker exits 2 and names README.md', () => {
    const dir = makeFixtureRepo({
      packageVersion: '1.5.1',
      indexVersion: '1.5.1',
      readmeVersion: null,
      changelogVersion: '1.5.1',
    });
    fixtures.push(dir);

    const result = spawnSync('node', [SCRIPT, dir], { encoding: 'utf8' });
    expect(result.status).toBe(2);
    expect(result.stderr).toContain('README.md');
  });
});
