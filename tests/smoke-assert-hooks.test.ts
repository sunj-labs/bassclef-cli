// smoke-assert-hooks.test.ts — Tier 0 test for scripts/smoke-assert-hooks.sh
//                                and lib/smoke-assert.sh + lib/smoke-schema.sh
//
// @verifies spec-smoke-evidence-capture § Acceptance items 2 + 10
// @verifies spec § Four checks table
// @verifies UC-smoke-run § Main flow Step 10 + Extensions 9a + 9b
// @verifies UC-lib-smoke-assert (subfunction UC)
// @verifies pre-mortem F4 + F6 (shared contract + schema)
//
// # test-list:
// [x] --help exits 0
// [x] exit 1 when capture dir missing
// [x] exit 2 when capture dir empty
// [x] clean capture passes all 4 checks; exit 0
// [x] capture with "not found" fails no-not-found
// [x] capture with "No such file or directory" fails no-not-found
// [x] capture with "skip —" fails no-silent-skip
// [x] capture with "BLOCKED:" fails no-unexpected-blocked
// [x] allowlist entry lets a BLOCKED line pass
// [x] capture naming a nonexistent path fails paths-exist
// [x] capture naming an existing path passes paths-exist
// [x] --only no-not-found runs only that check (single result per hook)
// [x] --only rejects unknown check name (exit 1)
// [x] output JSON is a valid array of AssertionResult objects
// [x] any failure sets exit 3

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import {
  mkdtempSync, writeFileSync, readFileSync, rmSync, mkdirSync, existsSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT = resolve(__dirname, '../scripts/smoke-assert-hooks.sh');

let workDir: string;
let captureDir: string;
let outFile: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-assert-hooks-test-'));
  captureDir = join(workDir, 'captures');
  outFile = join(workDir, 'hooks-assertions.json');
  mkdirSync(captureDir, { recursive: true });
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function writeCapture(name: string, body: string): string {
  const path = join(captureDir, `${name}.out`);
  writeFileSync(path, body);
  return path;
}

function run(extraArgs: string[] = []): { status: number | null; stdout: string; stderr: string } {
  const args = ['--capture-dir', captureDir, '--out', outFile, ...extraArgs];
  const r = spawnSync('bash', [SCRIPT, ...args], { encoding: 'utf8' });
  return { status: r.status, stdout: r.stdout, stderr: r.stderr };
}

describe('smoke-assert-hooks — usage and preconditions', () => {
  it('--help exits 0', () => {
    const r = spawnSync('bash', [SCRIPT, '--help'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('smoke-assert-hooks.sh');
  });

  it('exit 1 when capture dir missing', () => {
    const r = spawnSync('bash', [SCRIPT, '--capture-dir', join(workDir, 'nope'), '--out', outFile], { encoding: 'utf8' });
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/capture dir not found/);
  });

  it('exit 2 when capture dir empty', () => {
    const r = run();
    expect(r.status).toBe(2);
    expect(r.stderr).toMatch(/no capture files/);
  });

  it('--only rejects unknown check name', () => {
    writeCapture('h1', '=== output ===\nhi\n=== exit: 0');
    const r = run(['--only', 'not-a-check']);
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/unknown check/);
  });
});

describe('smoke-assert-hooks — happy path', () => {
  it('clean capture passes all four checks; exit 0', () => {
    writeCapture('h1', '=== command: bash h1.sh\n=== output ===\nhi world\n=== exit: 0\n');
    const r = run();
    expect(r.status).toBe(0);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    expect(results).toHaveLength(4);
    for (const row of results) {
      expect(row.status).toBe('PASS');
      expect(row.source).toBe('h1');
    }
  });
});

describe('smoke-assert-hooks — per-check FAIL cases', () => {
  it('capture with "not found" fails no-not-found', () => {
    writeCapture('h1', '=== output ===\nbash: foo.sh: not found\n=== exit: 1\n');
    const r = run();
    expect(r.status).toBe(3);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'no-not-found');
    expect(row.status).toBe('FAIL');
  });

  it('capture with "No such file or directory" fails no-not-found', () => {
    writeCapture('h1', '=== output ===\n/tmp/x: No such file or directory\n=== exit: 1\n');
    const r = run();
    expect(r.status).toBe(3);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'no-not-found');
    expect(row.status).toBe('FAIL');
  });

  it('capture with "skip —" fails no-silent-skip', () => {
    writeCapture('h1', '=== output ===\nfoo.sh: skip — nothing to do\n=== exit: 0\n');
    const r = run();
    expect(r.status).toBe(3);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'no-silent-skip');
    expect(row.status).toBe('FAIL');
  });

  it('capture with unexpected BLOCKED fails no-unexpected-blocked', () => {
    writeCapture('h1', '=== output ===\nBLOCKED: something went wrong\n=== exit: 1\n');
    const r = run();
    expect(r.status).toBe(3);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'no-unexpected-blocked');
    expect(row.status).toBe('FAIL');
  });

  it('allowlist lets a BLOCKED line pass', () => {
    writeCapture('h1', '=== output ===\nBLOCKED: expected-thing here\n=== exit: 0\n');
    const allowDir = join(workDir, 'allow');
    mkdirSync(allowDir);
    writeFileSync(join(allowDir, 'no-unexpected-blocked.txt'), 'expected-thing\n');
    const r = run(['--allowlist-dir', allowDir]);
    expect(r.status).toBe(0);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'no-unexpected-blocked');
    expect(row.status).toBe('PASS');
  });
});

describe('smoke-assert-hooks — paths-exist check', () => {
  it('capture naming a nonexistent path fails paths-exist', () => {
    writeCapture('h1', '=== output ===\nreading /tmp/definitely-not-here-9876543/foo\n=== exit: 0\n');
    const r = run();
    expect(r.status).toBe(3);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'paths-exist');
    expect(row.status).toBe('FAIL');
  });

  it('capture naming an existing path passes paths-exist', () => {
    // Use /tmp — exists on every unix-like system
    writeCapture('h1', '=== output ===\nreading /tmp\n=== exit: 0\n');
    const r = run();
    expect(r.status).toBe(0);
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    const row = results.find((r: { check: string }) => r.check === 'paths-exist');
    expect(row.status).toBe('PASS');
  });
});

describe('smoke-assert-hooks — --only flag', () => {
  it('--only no-not-found runs only that check', () => {
    writeCapture('h1', '=== output ===\nhi\n=== exit: 0\n');
    const r = run(['--only', 'no-not-found']);
    expect(r.status).toBe(0);
    // Output file goes to a different path when --only fires
    const onlyOutFile = join(workDir, 'hooks-assertions-no-not-found.json');
    expect(existsSync(onlyOutFile)).toBe(true);
    const results = JSON.parse(readFileSync(onlyOutFile, 'utf8'));
    expect(results).toHaveLength(1);
    expect(results[0].check).toBe('no-not-found');
  });
});

describe('smoke-assert-hooks — output shape', () => {
  it('output JSON is a valid array of AssertionResult objects', () => {
    writeCapture('h1', '=== output ===\nhi\n=== exit: 0\n');
    writeCapture('h2', '=== output ===\nhi\n=== exit: 0\n');
    run();
    const results = JSON.parse(readFileSync(outFile, 'utf8'));
    expect(Array.isArray(results)).toBe(true);
    expect(results.length).toBe(8); // 2 hooks × 4 checks
    for (const row of results) {
      expect(row).toHaveProperty('source');
      expect(row).toHaveProperty('check');
      expect(row).toHaveProperty('status');
      expect(row).toHaveProperty('message');
      expect(row).toHaveProperty('capture_path');
    }
  });
});
