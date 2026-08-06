// writeSafely test list — per Beck TDD.
//
// The atomic write. `O_CREAT | O_EXCL | O_NOFOLLOW | O_WRONLY` gives:
//   - existence check (EEXIST if file exists)
//   - refuses to follow a symlink at the final path
// Combined with a force flag that unlinks first (also refusing symlinks
// via unlink semantics on the final path), this covers the safety cases.
//
// [x] happy path — writes new file, size + content match
// [x] file exists, force=false → typed error (Refused)
// [x] file exists, force=true → overwrites, size + content match
// [x] target path is a symlink, force=false → typed error (SymlinkRefused)
// [x] target path is a symlink, force=true → still refuses (unconditional)
// [x] parent dir does not exist → typed error (ParentMissing)
// [x] parent dir not writable → typed error (ParentNotWritable)
//
// Deferred: post-write verify (mtime + size re-read) added below as a
// separate test suite when writeSafely gets a verify option.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import {
  mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync, readFileSync, chmodSync, existsSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { writeSafely, WriteError } from '../src/lib/write-safely.js';

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'bassclef-write-test-'));
});

afterEach(() => {
  try {
    // Restore permissions before removal.
    chmodSync(workDir, 0o755);
    rmSync(workDir, { recursive: true, force: true });
  } catch { /* ignore */ }
});

describe('writeSafely — happy path', () => {
  it('writes a new file with the exact content', () => {
    const target = join(workDir, 'hello.txt');
    writeSafely(target, 'hi\n');
    expect(readFileSync(target, 'utf8')).toBe('hi\n');
  });
});

describe('writeSafely — existence', () => {
  it('refuses to overwrite when force=false', () => {
    const target = join(workDir, 'exists.txt');
    writeFileSync(target, 'original');
    expect(() => writeSafely(target, 'new content'))
      .toThrow(WriteError);
    expect(readFileSync(target, 'utf8')).toBe('original');
  });

  it('overwrites when force=true', () => {
    const target = join(workDir, 'exists.txt');
    writeFileSync(target, 'original');
    writeSafely(target, 'new content', { force: true });
    expect(readFileSync(target, 'utf8')).toBe('new content');
  });
});

describe('writeSafely — symlink', () => {
  it('refuses when target path is a symlink (force=false)', () => {
    const decoy = join(workDir, 'decoy');
    const target = join(workDir, 'sym');
    writeFileSync(decoy, 'decoy content');
    symlinkSync(decoy, target);
    expect(() => writeSafely(target, 'evil'))
      .toThrow(/symlink|refused/i);
    expect(readFileSync(decoy, 'utf8')).toBe('decoy content');
  });

  it('refuses when target path is a symlink even with force=true', () => {
    const decoy = join(workDir, 'decoy');
    const target = join(workDir, 'sym');
    writeFileSync(decoy, 'decoy content');
    symlinkSync(decoy, target);
    expect(() => writeSafely(target, 'evil', { force: true }))
      .toThrow(/symlink|refused/i);
    expect(readFileSync(decoy, 'utf8')).toBe('decoy content');
  });
});

describe('writeSafely — parent dir', () => {
  it('errors when parent dir does not exist', () => {
    const target = join(workDir, 'missing', 'file.txt');
    expect(() => writeSafely(target, 'x'))
      .toThrow(WriteError);
  });

  it('errors when parent dir is not writable', () => {
    if (process.getuid && process.getuid() === 0) {
      // Root ignores mode bits; skip on root.
      return;
    }
    const readonly = join(workDir, 'readonly');
    mkdirSync(readonly);
    chmodSync(readonly, 0o555);
    try {
      const target = join(readonly, 'file.txt');
      expect(() => writeSafely(target, 'x')).toThrow(WriteError);
    } finally {
      chmodSync(readonly, 0o755);
    }
  });
});
