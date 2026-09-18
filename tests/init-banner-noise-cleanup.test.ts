// bassclef init banner noise cleanup — bassclef-cli#120.
//
// Per @luminary don-norman (feedback loop discipline): a banner line
// earns its place when it names something the reader can act on.
//
// Per @luminary alan-cooper (CLI operator experience): the first-install
// signal should read as success, not a warning about zero refusals.
//
// Two cures pinned here:
//   A. hook line drops "N failed" phrasing when errored === 0 (was "N failed"
//      where N = refused + errored, misleading whenever refused > 0)
//   B. "N files refused (path collision)" line only emits when N > 0
//
// test-list:
// [x] fresh install has no "files refused (path collision)" line at all
// [x] fresh install has no "errored" or "failed" phrasing on the hook line
// [x] hook line ends with the scope suffix period on a fresh install

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

let workDir: string;
let fakeHome: string;

function run(cmd: string, args: readonly string[]) {
  return spawnSync(process.execPath, [CLI, cmd, ...args], {
    encoding: 'utf8',
    timeout: 30000,
    cwd: workDir,
    env: { ...process.env, HOME: fakeHome },
  });
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(HOME, '.bassclef-noise-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-noise-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef-cli#120 — banner reads as success on a fresh install', () => {
  it('does not emit the "files refused (path collision)" line', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
    expect(r.stdout).not.toMatch(/files refused \(path collision\)/);
  });

  it('does not use "failed" phrasing on the hook line when nothing errored', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
    const hookLine = r.stdout
      .split('\n')
      .find((l) => /Installed \d+ of \d+ hooks/.test(l));
    expect(hookLine, 'expected a hook-install line').toBeDefined();
    expect(hookLine).not.toMatch(/failed/);
    expect(hookLine).not.toMatch(/Rerun bassclef init/);
  });

  it('hook line ends with the scope-suffix period, no trailing failure clause', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
    const hookLine = r.stdout
      .split('\n')
      .find((l) => /Installed \d+ of \d+ hooks/.test(l));
    expect(hookLine).toMatch(/\.claude\/hooks\.\s*$/);
  });
});
