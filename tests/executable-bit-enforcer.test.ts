// executable-bit-enforcer test list — per Beck TDD + test-list-discipline.
//
// @verifies S3-fold (Saltzer-Schroeder — executable bit missing after copy)
// @verifies N3-fold (Nygard — chmod fails on non-POSIX; INFO stderr note)
// @verifies P1-fold (Hunt & Thomas — DRY on HOOK_EXECUTABLE_MODE constant)
// @verifies UC-init-walker-hook-routing Ext 6d
//
// RED phase — src/lib/executable-bit-enforcer.ts + src/lib/hook-constants.ts
// do not exist yet. Imports fail. Every test [ ] pending.
//
// # test-list:
// [ ] setExecutable on writable file sets mode 0755 on POSIX
// [ ] setExecutable on readonly file throws on POSIX
// [ ] setExecutable no-ops with INFO stderr on win32
// [ ] setExecutable preserves owner + group bits when adding execute
// [ ] setExecutable uses HOOK_EXECUTABLE_MODE constant
// [ ] setExecutable idempotent (running twice does not error)

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mkdtempSync, writeFileSync, statSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
// RED: these imports fail today; files authored in code phase.
import { setExecutable } from '../src/lib/executable-bit-enforcer.js';
import { HOOK_EXECUTABLE_MODE, HOOK_EXECUTABLE_MASK } from '../src/lib/hook-constants.js';

let workDir: string;
let target: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-exec-test-'));
  target = join(workDir, 'sample.sh');
  writeFileSync(target, '#!/bin/sh\necho hi\n');
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('setExecutable — POSIX happy path', () => {
  it('sets mode 0755 on a writable file', () => {
    if (process.platform === 'win32') return;
    setExecutable(target);
    const mode = statSync(target).mode & 0o777;
    expect(mode).toBe(0o755);
  });

  it('leaves the execute bit set when run twice', () => {
    if (process.platform === 'win32') return;
    setExecutable(target);
    setExecutable(target);
    const mode = statSync(target).mode & HOOK_EXECUTABLE_MASK;
    expect(mode).not.toBe(0);
  });

  it('uses the shared HOOK_EXECUTABLE_MODE constant', () => {
    // Structural pin — the constant value must be 0o755.
    expect(HOOK_EXECUTABLE_MODE).toBe(0o755);
    expect(HOOK_EXECUTABLE_MASK).toBe(0o111);
  });
});

describe('setExecutable — POSIX failure path (Ext 6d POSIX)', () => {
  it('throws when the target file does not exist', () => {
    if (process.platform === 'win32') return;
    expect(() => setExecutable(join(workDir, 'does-not-exist.sh'))).toThrow();
  });
});

describe('setExecutable — win32 path (Ext 6d Windows)', () => {
  it('no-ops with INFO stderr note on win32', () => {
    if (process.platform !== 'win32') return;
    const stderrWrite = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);
    setExecutable(target);
    expect(stderrWrite).toHaveBeenCalled();
    const message = String(stderrWrite.mock.calls[0]?.[0] ?? '');
    expect(message.toLowerCase()).toContain('executable bit');
    stderrWrite.mockRestore();
  });
});
