// smoke-capture.test.ts — Tier 0 test for scripts/smoke-capture.sh
//
// @verifies spec-smoke-evidence-capture § Acceptance item 1
// @verifies spec-smoke-evidence-capture § Interfaces § scripts/smoke-capture.sh
// @verifies UC-smoke-run § Main flow Step 8
// @verifies UC-smoke-run § Extension 7a (no wired hooks)
// @verifies pre-mortem V2 (Vogels — df check; not exercised here since we
//           cannot simulate a full disk cross-platform)
//
// # test-list:
// [x] --help prints usage and exits 0
// [x] exit 1 when settings.json is missing
// [x] exit 2 when settings.json has no SessionStart hooks
// [x] writes one file per wired hook
// [x] captured output contains the hook stdout
// [x] captured output records the exit code
// [x] --dry-run writes no files
// [x] --out custom-dir places captures under the custom root
// [x] multi-hook settings.json produces one file per hook without collision
// [x] captures non-zero hook exit without aborting the run

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import {
  mkdtempSync, writeFileSync, readdirSync, readFileSync,
  rmSync, existsSync, chmodSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT = resolve(__dirname, '../scripts/smoke-capture.sh');

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-capture-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function writeHook(name: string, body: string): string {
  const hookPath = join(workDir, name);
  writeFileSync(hookPath, body);
  chmodSync(hookPath, 0o755);
  return hookPath;
}

function writeSettings(commands: string[]): string {
  const settings = {
    hooks: {
      SessionStart: [
        {
          matcher: '',
          hooks: commands.map(cmd => ({ type: 'command', command: cmd }))
        }
      ]
    }
  };
  const settingsPath = join(workDir, 'settings.json');
  writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  return settingsPath;
}

function runCapture(args: string[]): { status: number | null; stdout: string; stderr: string } {
  const result = spawnSync('bash', [SCRIPT, ...args], {
    cwd: workDir,
    encoding: 'utf8',
  });
  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

describe('smoke-capture — usage and preconditions', () => {
  it('--help prints usage and exits 0', () => {
    const r = spawnSync('bash', [SCRIPT, '--help'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('smoke-capture.sh');
  });

  it('exits 1 when settings file is missing', () => {
    const r = runCapture([]);
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/settings file not found/);
  });

  it('exits 2 when settings.json has no SessionStart hooks', () => {
    const settings = writeSettings([]);
    const r = runCapture(['--settings', settings]);
    expect(r.status).toBe(2);
    expect(r.stderr).toMatch(/no wired SessionStart hooks/);
  });
});

describe('smoke-capture — happy path', () => {
  it('writes one capture file per wired hook', () => {
    const hook = writeHook('h1.sh', '#!/bin/bash\necho "from hook 1"\n');
    const settings = writeSettings([`bash ${hook}`]);
    const outDir = join(workDir, 'out');
    const r = runCapture(['--settings', settings, '--out', outDir]);
    expect(r.status).toBe(0);
    const files = readdirSync(outDir);
    expect(files.length).toBe(1);
    expect(files[0]).toBe('h1.out');
  });

  it('captured output contains the hook stdout', () => {
    const hook = writeHook('h1.sh', '#!/bin/bash\necho "SIGNAL_STDOUT_MARKER"\n');
    const settings = writeSettings([`bash ${hook}`]);
    const outDir = join(workDir, 'out');
    runCapture(['--settings', settings, '--out', outDir]);
    const captured = readFileSync(join(outDir, 'h1.out'), 'utf8');
    expect(captured).toContain('SIGNAL_STDOUT_MARKER');
  });

  it('captured output records the exit code', () => {
    const hook = writeHook('h1.sh', '#!/bin/bash\necho "ok"\nexit 0\n');
    const settings = writeSettings([`bash ${hook}`]);
    const outDir = join(workDir, 'out');
    runCapture(['--settings', settings, '--out', outDir]);
    const captured = readFileSync(join(outDir, 'h1.out'), 'utf8');
    expect(captured).toMatch(/=== exit: 0/);
  });

  it('captures non-zero hook exit without aborting the run', () => {
    const hookOk = writeHook('ok.sh', '#!/bin/bash\necho "ok"\n');
    const hookFail = writeHook('fail.sh', '#!/bin/bash\necho "before fail"\nexit 7\n');
    const settings = writeSettings([`bash ${hookOk}`, `bash ${hookFail}`]);
    const outDir = join(workDir, 'out');
    const r = runCapture(['--settings', settings, '--out', outDir]);
    expect(r.status).toBe(0);
    const failCap = readFileSync(join(outDir, 'fail.out'), 'utf8');
    expect(failCap).toContain('before fail');
    expect(failCap).toMatch(/=== exit: 7/);
    const okCap = readFileSync(join(outDir, 'ok.out'), 'utf8');
    expect(okCap).toContain('ok');
  });
});

describe('smoke-capture — flags', () => {
  it('--dry-run writes no files', () => {
    const hook = writeHook('h1.sh', '#!/bin/bash\necho "should not run"\n');
    const settings = writeSettings([`bash ${hook}`]);
    const outDir = join(workDir, 'out');
    const r = runCapture(['--dry-run', '--settings', settings, '--out', outDir]);
    expect(r.status).toBe(0);
    expect(r.stderr).toMatch(/would run/);
    expect(existsSync(outDir)).toBe(false);
  });

  it('--out custom-dir places captures under the custom root', () => {
    const hook = writeHook('h1.sh', '#!/bin/bash\necho hi\n');
    const settings = writeSettings([`bash ${hook}`]);
    const custom = join(workDir, 'custom-out-dir');
    runCapture(['--settings', settings, '--out', custom]);
    expect(existsSync(join(custom, 'h1.out'))).toBe(true);
  });

  it('multi-hook settings.json produces one file per hook without collision', () => {
    const h1 = writeHook('h1.sh', '#!/bin/bash\necho ONE\n');
    const h2 = writeHook('h2.sh', '#!/bin/bash\necho TWO\n');
    const h3 = writeHook('h3.sh', '#!/bin/bash\necho THREE\n');
    const settings = writeSettings([`bash ${h1}`, `bash ${h2}`, `bash ${h3}`]);
    const outDir = join(workDir, 'out');
    const r = runCapture(['--settings', settings, '--out', outDir]);
    expect(r.status).toBe(0);
    const files = readdirSync(outDir).sort();
    expect(files).toEqual(['h1.out', 'h2.out', 'h3.out']);
    expect(readFileSync(join(outDir, 'h1.out'), 'utf8')).toContain('ONE');
    expect(readFileSync(join(outDir, 'h2.out'), 'utf8')).toContain('TWO');
    expect(readFileSync(join(outDir, 'h3.out'), 'utf8')).toContain('THREE');
  });
});
