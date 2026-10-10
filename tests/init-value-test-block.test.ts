// cli#406 — bassclef init final output 5-min value test.
//
// @verifies R-NPM-lite-010 (Sam first-touch value-test block)
// @requirement bassclef-upstream#2006 (Sam-verbatim target shape)
//
// Beck RED-first. Before src/commands/init.ts emits the Sam-verbatim
// block + hides catalog counts behind --verbose, this file FAILS on
// every assertion. Each failure names the specific line missing.
//
// test-list:
// [x] default init prints "Bassclef is ready." as the final value-test block
// [x] default init prints the /riff + /launch + /build command cues
// [x] default init does NOT print catalog counts (skills, rules, agents, luminaries)
// [x] --verbose init prints catalog counts (skills, rules, agents, luminaries)
// [x] --verbose init still prints the Sam-verbatim block (both coexist with --verbose)
// [x] hook banner "Installed N of M hooks (lite tier)" still fires in default mode
//
// Anchor luminary: @luminary michael-feathers — characterization at
// Sam's first-touch surface. Anchor: @luminary kent-beck — RED before
// source. Anchor: @luminary alan-cooper — Sam 3-level goal.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { VALUE_TEST_BLOCK } from '../src/lib/init-value-test-block.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const DIST_LITE = resolve(REPO_ROOT, 'dist/lite');
const HOME = homedir();

function runCli(args: readonly string[], cwd: string, home: string) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 15000,
    cwd,
    env: { ...process.env, HOME: home },
  });
}

let workDir: string;
let fakeHome: string;

beforeEach(() => {
  // Self-heal the fixture if dist/lite/ is missing (first-run or after
  // a clean). Matches init-output-parity.test.ts §beforeAll pattern.
  if (!existsSync(DIST_LITE) || !existsSync(join(DIST_LITE, '.claude/settings.json'))) {
    const r = spawnSync(process.execPath, [
      resolve(REPO_ROOT, 'scripts/prepublish-bundle-substrate.mjs'),
    ], { encoding: 'utf8', timeout: 30000, env: { ...process.env } });
    if (r.status !== 0) {
      throw new Error(
        `prepublish failed to seed dist/lite/ fixture: ${r.stderr || r.stdout}`
      );
    }
  }
  fakeHome = mkdtempSync(join(HOME, '.bassclef-init-value-test-fakehome-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-init-value-test-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef init — Sam 5-min value test block (cli#406)', () => {
  it('default init prints "Bassclef is ready." Sam-verbatim block', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('Bassclef is ready.');
  });

  it('default init prints the /riff + /launch + /build command cues', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('/riff');
    expect(r.stdout).toContain('/launch');
    expect(r.stdout).toContain('/build');
  });

  it('default init prints the exact Sam-verbatim block from the shared constant', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    // Every non-blank line of the verbatim target appears in default stdout.
    for (const line of VALUE_TEST_BLOCK.split('\n')) {
      if (line.trim() === '') continue;
      expect(r.stdout).toContain(line);
    }
  });

  it('default init does NOT print catalog counts (hidden behind --verbose)', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    // Catalog counts move behind --verbose per cli#406 goal.
    expect(r.stdout).not.toMatch(/\d+ (skills|rules|agents|luminaries) under/);
    expect(r.stdout).not.toMatch(/\d+ (libs|ADRs|standards|scripts|templates|presence-templates|root-docs) under/);
  });

  it('--verbose init prints catalog counts (skills, rules, agents, luminaries)', () => {
    const r = runCli(['--verbose'], workDir, fakeHome);
    expect(r.status).toBe(0);
    // Lite tier always ships at least some skills + rules + agents +
    // luminaries, so one of these counts must appear with --verbose.
    expect(r.stdout).toMatch(/\d+ (skills|rules|agents|luminaries) under/);
  });

  it('--verbose init still prints the Sam-verbatim block (coexist)', () => {
    const r = runCli(['--verbose'], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('Bassclef is ready.');
    expect(r.stdout).toContain('/riff');
  });

  it('hook banner "Installed N of M hooks (lite tier)" still fires in default mode', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).toMatch(/Installed \d+ of \d+ hooks \(lite tier\)/);
  });
});
