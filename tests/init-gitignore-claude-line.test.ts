// bassclef init writes a .gitignore that ignores .claude/ — bassclef-cli#99.
//
// Per @luminary linus-torvalds: adopters do not lose work to substrate.
// Synced substrate landing untracked plus `git add -A` sweeps hundreds
// of vendored files into an accidental commit. This test pins the fix.
//
// # test-list:
// [x] fresh init writes .gitignore that ignores .claude/
// [x] fresh init writes .gitignore that ignores .bassclef/
// [x] the ensured block is idempotent (re-running does not double-write)

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

let workDir: string;
let fakeHome: string;

function runInit() {
  return spawnSync(process.execPath, [CLI, 'init'], {
    encoding: 'utf8',
    timeout: 30000,
    cwd: workDir,
    env: { ...process.env, HOME: fakeHome },
  });
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(HOME, '.bassclef-gi-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-gi-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef-cli#99 — adopter .gitignore ignores synced substrate', () => {
  it('writes a .gitignore that contains a .claude/ line', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const gi = readFileSync(join(workDir, '.gitignore'), 'utf8');
    expect(gi).toMatch(/^\.claude\/?$/m);
  });

  it('writes a .gitignore that contains a .bassclef/ line', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const gi = readFileSync(join(workDir, '.gitignore'), 'utf8');
    expect(gi).toMatch(/^\.bassclef\/?$/m);
  });

  it('bassclef-managed lines appear exactly once (no double-write)', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const gi = readFileSync(join(workDir, '.gitignore'), 'utf8');
    const claudeLines = (gi.match(/^\.claude\/?$/gm) ?? []).length;
    const bassclefLines = (gi.match(/^\.bassclef\/?$/gm) ?? []).length;
    expect(claudeLines).toBe(1);
    expect(bassclefLines).toBe(1);
  });
});
