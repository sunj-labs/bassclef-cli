// Zero-state nudge tests for cold adopters — ticket #55 reconciled scope.
//
// Reading src at Step 1 of goal 2026-09-11 discovered the ticket #55 spec
// conflicts with ADR-008 Decision 2 (migrate no-manifest → Path B, not nudge).
// Scope reconciled to: polish --help + characterize current sync + migrate.
// See docs/use-cases/UC-cold-adopter-init-nudge.md § Reconciliation.
//
// @verifies UC-cold-adopter-init-nudge
//
// test-list (Beck):
//   [ ] `bassclef --help` contains "Start here: `bassclef init`" line (RED)
//   [x] `bassclef sync` in no-manifest dir refuses; exit 1; stderr names `bassclef init` (characterization)
//   [x] `bassclef migrate` in no-manifest dir dispatches Path B; stdout names full init (characterization; per ADR-008 D2)
//   [x] `bassclef init` in fresh dir works (regression pin)

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

function runCli(args: readonly string[], opts?: { cwd?: string }) {
  return spawnSync(process.execPath, [CLI, ...args], {
    encoding: 'utf8',
    timeout: 8000,
    cwd: opts?.cwd,
  });
}

beforeEach(() => {
  workDir = mkdtempSync(join(HOME, '.bassclef-init-nudge-test-'));
});

afterEach(() => {
  try {
    rmSync(workDir, { recursive: true, force: true });
  } catch {
    /* ignore */
  }
});

describe('bassclef --help first-run hint (Beck RED for #55 reconciled scope)', () => {
  it('names `bassclef init` as the first-run verb via a "Start here" line', () => {
    const r = runCli(['--help']);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('Start here: cd to your project');
    expect(r.stdout).toContain('`bassclef init`');
  });

  it('also fires on bare invocation (no args)', () => {
    const r = runCli([]);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('Start here: cd to your project');
    expect(r.stdout).toContain('`bassclef init`');
  });
});

describe('bassclef sync no-manifest — characterization (already Cooper-good)', () => {
  it('refuses with exit 1 and names `bassclef init` in stderr', () => {
    const r = runCli(['sync'], { cwd: workDir });
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('not initialized');
    expect(r.stderr).toContain('bassclef init');
  });
});

describe('bassclef migrate no-manifest — characterization (Path B per ADR-008 D2)', () => {
  it('dispatches Path B; stdout names the full init', () => {
    // Path B triggers runInit which prompts; use --yes to auto-confirm
    // and --dry-run to avoid writing files. This pins the opener message
    // without side effects on the test host.
    const r = runCli(['migrate', '--yes', '--dry-run'], { cwd: workDir });
    // Path B opener lands in stdout regardless of dry-run outcome
    expect(r.stdout).toContain('no prior manifest detected');
  });
});

describe('bassclef init in fresh dir — regression pin', () => {
  it('runs to completion with exit 0', () => {
    const r = runCli(['init'], { cwd: workDir });
    expect(r.status).toBe(0);
  });
});
