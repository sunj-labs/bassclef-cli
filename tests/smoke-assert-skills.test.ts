// smoke-assert-skills.test.ts — Tier 0 test for scripts/smoke-assert-skills.sh
//
// The four-check logic itself is proven by tests/smoke-assert-hooks.test.ts +
// tests/smoke-defect-fixtures.test.ts (same shared lib). This file proves the
// skills variant uses skills-specific defaults and output paths.
//
// @verifies spec § Acceptance item 5 (assert-skills runs same checks per skill)
// @verifies UC-smoke-run § Main flow Step 14 + Extension 13b
//
// Updated for bassclef-cli#117 (2026-09-18) — the skill check set now
// includes no-timeout + no-crash, extending the base 4 checks to 6.
// The base check names + skill-specific paths remain the contract; the
// row count assertion updates to reflect the two new checks.
//
// # test-list:
// [x] --help exits 0
// [x] happy path: single skill capture; exits 0; JSON has 6 rows (base 4 + no-timeout + no-crash per bassclef-cli#117)
// [x] default OUT_FILE is skills-assertions.json (not hooks-)
// [x] --only <check> writes skills-assertions-<check>.json

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT = resolve(__dirname, '../scripts/smoke-assert-skills.sh');

let workDir: string;
let captureDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-assert-skills-test-'));
  captureDir = join(workDir, 'captures');
  mkdirSync(captureDir, { recursive: true });
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function writeCapture(name: string, body: string): void {
  writeFileSync(join(captureDir, `${name}.out`), body);
}

describe('smoke-assert-skills — uses skills-specific paths', () => {
  it('--help exits 0', () => {
    const r = spawnSync('bash', [SCRIPT, '--help'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('smoke-assert-skills.sh');
  });

  it('happy path — clean skill capture; exits 0; JSON has 6 rows (base 4 + timeout + crash per bassclef-cli#117)', () => {
    writeCapture('temperance', '=== skill: /temperance\n=== output ===\nok\n=== exit: 0\n');
    const outFile = join(workDir, 'skills-assertions.json');
    const r = spawnSync('bash', [SCRIPT, '--capture-dir', captureDir, '--out', outFile], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    expect(results).toHaveLength(6);
    for (const row of results) {
      expect(row.source).toBe('temperance');
      expect(row.status).toBe('PASS');
    }
    // Assert the new checks are named per bassclef-cli#117
    const checkNames = results.map((r: { check: string }) => r.check).sort();
    expect(checkNames).toContain('no-timeout');
    expect(checkNames).toContain('no-crash');
  });

  it('default OUT_FILE lands as skills-assertions.json under captures parent', () => {
    // Run without --out to check the default path shape.
    // Give a --capture-dir under a "skills" subfolder so parent dir is well-known.
    const capParent = join(workDir, 'today');
    const skillsCaptureDir = join(capParent, 'skills');
    mkdirSync(skillsCaptureDir, { recursive: true });
    writeFileSync(join(skillsCaptureDir, 'temperance.out'), '=== output ===\nok\n=== exit: 0\n');
    const r = spawnSync('bash', [SCRIPT, '--capture-dir', skillsCaptureDir], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    const defaultOut = join(capParent, 'skills-assertions.json');
    expect(existsSync(defaultOut)).toBe(true);
  });

  it('--only <check> writes skills-assertions-<check>.json', () => {
    writeCapture('temperance', '=== output ===\nok\n=== exit: 0\n');
    const outFile = join(workDir, 'skills-assertions.json');
    const r = spawnSync('bash', [SCRIPT, '--capture-dir', captureDir, '--out', outFile, '--only', 'no-not-found'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    const expectedPath = join(workDir, 'skills-assertions-no-not-found.json');
    expect(existsSync(expectedPath)).toBe(true);
    const results = JSON.parse(readFileSync(expectedPath, 'utf8'));
    expect(results).toHaveLength(1);
    expect(results[0].check).toBe('no-not-found');
  });
});
