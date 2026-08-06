// WU-1 Tier 0 tests — CLI shell.
//
// Beck: test-list first, then implementation.
// Tests that MUST pass before WU-1 ships:
//
//   [x] `bassclef --version` prints the pinned version + exits 0
//   [x] `bassclef --help` prints usage + exits 0
//   [x] `bassclef` (no args) prints usage + exits 0
//   [x] `bassclef init` prints "WU-2 will land" + exits non-zero
//   [x] `bassclef sync` prints "WU-3 will land" + exits non-zero
//   [x] `bassclef nonsense` prints unknown-command + usage + exits non-zero
//   [x] `version` export from index equals package.json version
//
// Deferred to WU-2/3 (real command tests): idempotent init, sync from
// stale version, sync error paths.

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

  it('stubs `init` with a WU-2 message + non-zero exit', () => {
    const r = runCli(['init']);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain('WU-2');
  });

  it('stubs `sync` with a WU-3 message + non-zero exit', () => {
    const r = runCli(['sync']);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain('WU-3');
  });

  it('rejects an unknown command with usage + non-zero exit', () => {
    const r = runCli(['nonsense']);
    expect(r.status).not.toBe(0);
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
