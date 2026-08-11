// CLI shell tests. Init command tests live in tests/init.test.ts.
//
// Beck: test-list first, then implementation.
//
//   [x] `bassclef --version` prints the pinned version + exits 0
//   [x] `bassclef --help` prints usage + exits 0
//   [x] `bassclef` (no args) prints usage + exits 0
//   [x] `bassclef init --help` prints init usage + exits 0
//   [x] `bassclef sync` prints a "later work" message + exits non-zero
//   [x] `bassclef nonsense` prints unknown-command + usage + exits 3 (invalid args per ADR-002)
//   [x] `version` export from index equals package.json version
//
// Init behavior tests are in tests/init.test.ts. Sync stub still lives
// here until the sync workunit replaces it.

import { describe, it, expect } from 'vitest';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');

const pkg = JSON.parse(
  readFileSync(resolve(REPO_ROOT, 'package.json'), 'utf8')
) as { version: string };

function runCli(args: readonly string[]) {
  return spawnSync(process.execPath, [CLI, ...args], {
    encoding: 'utf8',
    timeout: 5000,
  });
}

describe('bassclef CLI shell (WU-1)', () => {
  it('prints the version + exits 0 on --version', () => {
    const r = runCli(['--version']);
    expect(r.status).toBe(0);
    expect(r.stdout.trim()).toBe(pkg.version);
    expect(r.stderr).toBe('');
  });

  it('prints usage + exits 0 on --help', () => {
    const r = runCli(['--help']);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('Usage:');
    expect(r.stdout).toContain('bassclef init');
    expect(r.stdout).toContain('bassclef sync');
  });

  it('prints usage + exits 0 on no arguments', () => {
    const r = runCli([]);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('Usage:');
  });

  it('prints init-specific usage on `init --help`', () => {
    const r = runCli(['init', '--help']);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('bassclef init');
    expect(r.stdout).toContain('--force');
    expect(r.stdout).toContain('--dry-run');
  });

  it('prints sync-specific usage on `sync --help`', () => {
    const r = runCli(['sync', '--help']);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('bassclef sync');
    expect(r.stdout).toContain('--force');
    expect(r.stdout).toContain('--replace-edits');
  });

  it('rejects an unknown command with usage + exit 3 (invalid args per ADR-002 §Exit codes)', () => {
    const r = runCli(['nonsense']);
    expect(r.status).toBe(3);
    expect(r.stderr).toContain('nonsense');
    expect(r.stderr).toContain('Usage:');
  });
});

describe('programmatic API (WU-1)', () => {
  it('exposes `version` matching package.json', async () => {
    const { version } = await import(resolve(REPO_ROOT, 'dist/index.js'));
    expect(version).toBe(pkg.version);
  });
});
