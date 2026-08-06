// resolveTargetDir test list — per Beck TDD.
//
// The resolver turns a --dir value (or cwd fallback) into an absolute
// safe path, applying the two independent scope checks. Errors are typed;
// the caller maps them to exit codes.
//
// [x] no --dir passed, cwd under $HOME + owned by uid → returns realpath(cwd)
// [x] --dir passed with abs path under $HOME + owned → returns realpath(dir)
// [x] --dir passed with relative path → resolved against cwd
// [x] --dir pointing at nonexistent path → typed error
// [x] --dir outside $HOME, allowAnyDir=false → typed error naming --allow-any-dir
// [x] --dir outside $HOME, allowAnyDir=true → returns path
// [x] --dir with symlink chain → returns realpath (canonicalized)
//
// Deferred:
// - --dir under $HOME but not owned by uid — needs a chown fixture that
//   only root can create; covered by a manual test in staging. Ownership
//   check is exercised by unit-level tests that stub statSync in a
//   follow-on WU.
// - Windows path semantics — POSIX first.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync, realpathSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join, resolve as pathResolve } from 'node:path';
import { resolveTargetDir, ResolveError } from '../src/lib/resolve-target-dir.js';

const HOME = homedir();

let workDir: string;
let workDirReal: string; // realpath canonicalization for macOS /var vs /private/var

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'bassclef-resolve-test-'));
  workDirReal = realpathSync(workDir);
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('resolveTargetDir', () => {
  it('resolves cwd (under HOME) when no --dir passed', () => {
    // Assume the test runner cwd is under HOME (typical dev + CI).
    const cwd = process.cwd();
    if (!cwd.startsWith(HOME)) {
      // Skip the assertion on hosts where cwd isn't under HOME.
      return;
    }
    const out = resolveTargetDir({ cwd, cliArg: undefined, allowAnyDir: false });
    expect(out).toBe(cwd);
  });

  it('resolves --dir with absolute path under HOME', () => {
    const target = mkdtempSync(join(HOME, '.bassclef-test-'));
    try {
      const out = resolveTargetDir({ cwd: HOME, cliArg: target, allowAnyDir: false });
      expect(out).toBe(target);
    } finally {
      rmSync(target, { recursive: true, force: true });
    }
  });

  it('resolves --dir with relative path against cwd', () => {
    const rel = 'child';
    const abs = join(workDir, rel);
    mkdirSync(abs);
    // workDir may be outside HOME (it's under tmpdir). Use allowAnyDir.
    const out = resolveTargetDir({ cwd: workDir, cliArg: rel, allowAnyDir: true });
    expect(out).toBe(realpathSync(abs));
  });

  it('errors on nonexistent --dir path', () => {
    const nonexistent = join(workDir, 'does-not-exist');
    expect(() =>
      resolveTargetDir({ cwd: workDir, cliArg: nonexistent, allowAnyDir: true })
    ).toThrow(ResolveError);
  });

  it('errors on --dir outside HOME without --allow-any-dir', () => {
    // workDir is under tmpdir, typically outside HOME.
    if (workDir.startsWith(HOME)) {
      // Skip on hosts where tmpdir happens to be under HOME.
      return;
    }
    expect(() =>
      resolveTargetDir({ cwd: HOME, cliArg: workDir, allowAnyDir: false })
    ).toThrow(/--allow-any-dir/);
  });

  it('accepts --dir outside HOME with --allow-any-dir', () => {
    if (workDirReal.startsWith(HOME)) return;
    const out = resolveTargetDir({ cwd: HOME, cliArg: workDir, allowAnyDir: true });
    expect(out).toBe(workDirReal);
  });

  it('canonicalizes symlinks', () => {
    const real = join(workDir, 'real');
    const link = join(workDir, 'link');
    mkdirSync(real);
    symlinkSync(real, link);
    const out = resolveTargetDir({ cwd: workDir, cliArg: link, allowAnyDir: true });
    expect(out).toBe(realpathSync(real));
  });
});
