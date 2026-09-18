// smoke-assert lib new checks — bassclef-cli#117 (TIMEOUT/CRASH) + #118 (paths-exist regex fix).
//
// Per @luminary werner-vogels (pre-mortem V1 lens filed with #117):
// assertion suite must read `=== exit: N`. Empty captures passed every
// content check on the 2026-09-18 cold-adopter smoke because the exit
// line was ignored.
//
// Per @luminary alan-cooper (operator experience): fragment paths like
// /agents/x.md must not false-positive as missing filesystem targets.
// Anchor paths-exist to known-absolute prefixes only.
//
// # test-list:
// [x] check_no_timeout FAILS on capture with `=== exit: 142`
// [x] check_no_timeout PASSES on capture with `=== exit: 0`
// [x] check_no_timeout PASSES on capture with no exit header (legacy)
// [x] check_no_crash FAILS on capture with `=== exit: 7`
// [x] check_no_crash PASSES on capture with `=== exit: 0`
// [x] check_no_crash PASSES on capture with `=== exit: 142` (delegated to check_no_timeout)
// [x] check_no_crash PASSES on legacy capture (no exit header)
// [x] check_paths_exist PASSES on capture with only fragment paths (/agents/x.md)
// [x] check_paths_exist FAILS on capture with a missing absolute path (/Users/nonexistent/...)

import { describe, it, expect } from 'vitest';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const LIB = resolve(REPO_ROOT, 'scripts/lib/smoke-assert.sh');
const TIMEOUT_FIX = resolve(__dirname, 'fixtures/smoke-check-timeout-crash');
const PATHS_FIX = resolve(__dirname, 'fixtures/smoke-check-paths-exist');

// Source the lib and run one check function against a capture file.
function runCheck(checkName: string, captureFile: string): { rc: number; out: string } {
  const script = `source "${LIB}" && ${checkName} "${captureFile}"`;
  const r = spawnSync('bash', ['-c', script], { encoding: 'utf8' });
  return { rc: r.status ?? -1, out: (r.stdout ?? '').trim() };
}

describe('bassclef-cli#117 — check_no_timeout', () => {
  it('FAILS on capture with exit 142 (SIGALRM)', () => {
    const r = runCheck('check_no_timeout', `${TIMEOUT_FIX}/timeout-142.out`);
    expect(r.rc).toBe(1);
    expect(r.out).toMatch(/^FAIL\|no-timeout\|/);
    expect(r.out).toMatch(/exit 142/);
  });

  it('PASSES on capture with exit 0', () => {
    const r = runCheck('check_no_timeout', `${TIMEOUT_FIX}/success-0.out`);
    expect(r.rc).toBe(0);
    expect(r.out).toMatch(/^PASS\|no-timeout\|/);
  });

  it('PASSES on legacy capture with no exit header', () => {
    const r = runCheck('check_no_timeout', `${TIMEOUT_FIX}/legacy-no-header.out`);
    expect(r.rc).toBe(0);
    expect(r.out).toMatch(/^PASS\|no-timeout\|no exit header/);
  });
});

describe('bassclef-cli#117 — check_no_crash', () => {
  it('FAILS on capture with exit 7', () => {
    const r = runCheck('check_no_crash', `${TIMEOUT_FIX}/crash-7.out`);
    expect(r.rc).toBe(1);
    expect(r.out).toMatch(/^FAIL\|no-crash\|/);
    expect(r.out).toMatch(/exited 7/);
  });

  it('PASSES on capture with exit 0', () => {
    const r = runCheck('check_no_crash', `${TIMEOUT_FIX}/success-0.out`);
    expect(r.rc).toBe(0);
    expect(r.out).toMatch(/^PASS\|no-crash\|/);
  });

  it('PASSES on capture with exit 142 (timeout — delegated to check_no_timeout)', () => {
    const r = runCheck('check_no_crash', `${TIMEOUT_FIX}/timeout-142.out`);
    expect(r.rc).toBe(0);
    expect(r.out).toMatch(/^PASS\|no-crash\|/);
  });

  it('PASSES on legacy capture with no exit header', () => {
    const r = runCheck('check_no_crash', `${TIMEOUT_FIX}/legacy-no-header.out`);
    expect(r.rc).toBe(0);
    expect(r.out).toMatch(/^PASS\|no-crash\|no exit header/);
  });
});

describe('bassclef-cli#118 — check_paths_exist regex anchored to absolute prefixes', () => {
  it('PASSES on capture with only fragment paths (/agents/, /rules/)', () => {
    const r = runCheck('check_paths_exist', `${PATHS_FIX}/fragment-paths.out`);
    expect(r.rc).toBe(0);
    expect(r.out).toMatch(/^PASS\|paths-exist\|/);
  });

  it('FAILS on capture with a missing absolute path (/Users/nonexistent/...)', () => {
    const r = runCheck('check_paths_exist', `${PATHS_FIX}/missing-absolute.out`);
    expect(r.rc).toBe(1);
    expect(r.out).toMatch(/^FAIL\|paths-exist\|/);
    expect(r.out).toMatch(/nonexistent-adopter/);
  });
});
