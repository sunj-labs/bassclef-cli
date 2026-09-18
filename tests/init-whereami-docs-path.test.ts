// bassclef init writes whereami.md at docs/whereami.md — bassclef-cli#103.
//
// Per @luminary linus-torvalds: bundle and rule must name the same path.
// The whereami rule reads docs/whereami.md; init used to write root; skills
// guessed. This test pins the path fix.
//
// # test-list:
// [x] fresh init writes docs/whereami.md (not root whereami.md)
// [x] docs/whereami.md contains the version placeholder substitution
// [x] no root-level whereami.md is created

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, existsSync, readFileSync, rmSync } from 'node:fs';
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
  fakeHome = mkdtempSync(join(HOME, '.bassclef-wa-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-wa-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef-cli#103 — whereami.md ships at docs/whereami.md', () => {
  it('writes docs/whereami.md at adopter target', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'docs/whereami.md'))).toBe(true);
  });

  it('does not write a root-level whereami.md', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'whereami.md'))).toBe(false);
  });

  it('docs/whereami.md still gets placeholder substitution', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const body = readFileSync(join(workDir, 'docs/whereami.md'), 'utf8');
    // ISO_TIMESTAMP placeholder gets replaced with real timestamp per
    // src/commands/init.ts PLACEHOLDER_FILES set (line 72 covers docs/).
    expect(body).not.toMatch(/\[ISO_TIMESTAMP\]/);
  });
});
