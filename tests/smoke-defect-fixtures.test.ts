// smoke-defect-fixtures.test.ts — coverage-walk test per pre-mortem F1 fold
//                                   (Fowler — adding a fifth check must extend fixtures)
//
// @verifies spec § Acceptance item 3 (each fixture fails exactly one assertion)
// @verifies pre-mortem F1 (Fowler — fixture coverage-walk)
// @verifies decompose § Fixture entity
//
// Method: each fixture reproduces one known defect from the 2026-09-17
// cold-adopter smoke. The test walks the fixture dir, runs smoke-assert-
// hooks against each, and asserts:
//   1. exactly one check fails per fixture
//   2. the failing check matches the expected check named in this table
//
// Coverage walk (pre-mortem F1): the FIXTURE_MAP names the check per
// fixture. If someone adds a fifth check without extending fixtures, this
// test does not fire an alarm — the test list must be updated in the
// same commit. Enforcement is by review + this test-list block.
//
// # test-list:
// [x] cli-101 fixture fails no-unexpected-blocked (only)
// [x] cli-102 fixture fails no-unexpected-blocked (only)
// [x] cli-103 fixture fails no-not-found (only)
// [x] cli-104 fixture fails no-not-found (only)
// [x] cli-105 fixture fails no-silent-skip (only)
// [x] cli-108 fixture fails no-unexpected-blocked (only)
// [x] all six fixtures collectively cover 3 of 4 checks
// [x] paths-exist check has at least one fail-pin somewhere in the suite

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, cpSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const FIXTURES_DIR = resolve(__dirname, 'fixtures/smoke-defect-fixtures');
const SCRIPT = resolve(__dirname, '../scripts/smoke-assert-hooks.sh');

interface FixtureExpectation {
  cli: number;
  file: string;
  expected_fail_check: 'no-not-found' | 'no-silent-skip' | 'no-unexpected-blocked' | 'paths-exist';
}

const FIXTURE_MAP: FixtureExpectation[] = [
  { cli: 101, file: 'cli-101/onboard-repo-blocks.out', expected_fail_check: 'no-unexpected-blocked' },
  { cli: 102, file: 'cli-102/orientation-gate-blocks.out', expected_fail_check: 'no-unexpected-blocked' },
  { cli: 103, file: 'cli-103/whereami-not-found.out', expected_fail_check: 'no-not-found' },
  { cli: 104, file: 'cli-104/configs-not-found.out', expected_fail_check: 'no-not-found' },
  { cli: 105, file: 'cli-105/bassclef-dir-skip.out', expected_fail_check: 'no-silent-skip' },
  { cli: 108, file: 'cli-108/abrupt-stop-false-fire.out', expected_fail_check: 'no-unexpected-blocked' },
];

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-fixtures-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function runAssertOne(fixturePath: string): { status: number | null; results: Array<{ source: string; check: string; status: string }> } {
  const captureDir = join(workDir, 'captures');
  mkdirSync(captureDir, { recursive: true });
  cpSync(fixturePath, join(captureDir, 'defect.out'));
  const outFile = join(workDir, 'result.json');
  const r = spawnSync('bash', [SCRIPT, '--capture-dir', captureDir, '--out', outFile], { encoding: 'utf8' });
  const results = JSON.parse(readFileSync(outFile, 'utf8'));
  return { status: r.status, results };
}

describe('smoke defect fixtures — each pins one defect against one check', () => {
  for (const fx of FIXTURE_MAP) {
    it(`cli#${fx.cli} fixture fails exactly ${fx.expected_fail_check}`, () => {
      const fixturePath = join(FIXTURES_DIR, fx.file);
      const { status, results } = runAssertOne(fixturePath);
      expect(status).toBe(3);
      const failed = results.filter(r => r.status === 'FAIL');
      const failedChecks = failed.map(r => r.check).sort();
      expect(failedChecks, `cli#${fx.cli} should fail only ${fx.expected_fail_check}; got ${JSON.stringify(failedChecks)}`).toEqual([fx.expected_fail_check]);
    });
  }
});

describe('smoke defect fixtures — coverage walk (pre-mortem F1)', () => {
  it('the six shipped fixtures cover 3 of 4 checks', () => {
    const covered = new Set(FIXTURE_MAP.map(f => f.expected_fail_check));
    // 3 of 4: no-not-found, no-silent-skip, no-unexpected-blocked
    expect(covered.size).toBeGreaterThanOrEqual(3);
    expect(covered.has('no-not-found')).toBe(true);
    expect(covered.has('no-silent-skip')).toBe(true);
    expect(covered.has('no-unexpected-blocked')).toBe(true);
  });

  it('paths-exist check has at least one fail-pin (constructed inline; no cli-# fixture pins this class)', () => {
    // Build a minimal capture with a nonexistent path.
    const captureDir = join(workDir, 'captures');
    mkdirSync(captureDir, { recursive: true });
    writeFileSync(join(captureDir, 'dangling.out'),
      '=== output ===\nreading /tmp/definitely-not-here-99999/foo\n=== exit: 0\n');
    const outFile = join(workDir, 'result.json');
    const r = spawnSync('bash', [SCRIPT, '--capture-dir', captureDir, '--out', outFile], { encoding: 'utf8' });
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    expect(r.status).toBe(3);
    const failed = results.filter(r => r.status === 'FAIL');
    expect(failed.map(r => r.check)).toContain('paths-exist');
  });
});
