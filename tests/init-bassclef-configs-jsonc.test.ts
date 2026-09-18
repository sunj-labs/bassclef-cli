// bassclef init writes .claude/bassclef-configs.jsonc — bassclef-cli#104.
//
// Per @luminary alan-cooper: adopters find the toggles surface without
// having to hand-write a file nobody told them about. Per @luminary
// don-norman: the file signals what's tunable via inline comments.
//
// # test-list:
// [x] fresh init writes .claude/bassclef-configs.jsonc at adopter target
// [x] the file parses as JSONC (JSON with // comments) after stripping comments
// [x] the file carries every block substrate rules read (tech_stack, prose_discipline, testing, longrun)

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

// Strip // line comments so JSON.parse can read the .jsonc body.
function stripJsonComments(src: string): string {
  return src
    .split('\n')
    .map((l) => l.replace(/^\s*\/\/.*$/, '').replace(/\s+\/\/.*$/, ''))
    .join('\n');
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(HOME, '.bassclef-cfg-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-cfg-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef-cli#104 — adopter gets .claude/bassclef-configs.jsonc on install', () => {
  it('writes .claude/bassclef-configs.jsonc at adopter target', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, '.claude/bassclef-configs.jsonc'))).toBe(true);
  });

  it('the file parses as valid JSONC (comments stripped)', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const raw = readFileSync(join(workDir, '.claude/bassclef-configs.jsonc'), 'utf8');
    const parsed = JSON.parse(stripJsonComments(raw));
    expect(typeof parsed).toBe('object');
    expect(parsed).not.toBeNull();
  });

  it('carries every block substrate rules read', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const raw = readFileSync(join(workDir, '.claude/bassclef-configs.jsonc'), 'utf8');
    const cfg = JSON.parse(stripJsonComments(raw));
    // Rules known to read from this file:
    // - .claude/rules/testing-tier-config.md → testing
    // - .claude/rules/plain-english-discipline.md → prose_discipline
    // - .claude/rules/skill-composition-declarations.md → tech_stack, longrun
    expect(cfg).toHaveProperty('tech_stack');
    expect(cfg).toHaveProperty('prose_discipline');
    expect(cfg).toHaveProperty('testing');
    expect(cfg).toHaveProperty('longrun');
  });
});
