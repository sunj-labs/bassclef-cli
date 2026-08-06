// argv reducer test list — per Beck TDD.
//
// The reducer parses a slice of argv into a flag object. It knows about
// four boolean flags and one string flag. Anything unknown is an error.
// The output shape is fixed; consumers destructure from it.
//
// [x] boolean flag alone: parseArgv(['--force']) → {force: true, ...}
// [x] string flag with value: parseArgv(['--dir', '/tmp']) → {dir: '/tmp'}
// [x] string flag with equals: parseArgv(['--dir=/tmp']) → {dir: '/tmp'}
// [x] multiple flags: parseArgv(['--force', '--dry-run']) → both true
// [x] no flags: parseArgv([]) → all defaults (force=false, dryRun=false, ...)
// [x] unknown flag: parseArgv(['--nope']) → throws with the flag name
// [x] string flag missing value: parseArgv(['--dir']) → throws
// [x] positional argument (not a flag) → throws with the arg text
//
// Deferred to later WU: short flags (-f, -n), --key=value with = in value.

import { describe, it, expect } from 'vitest';
import { parseInitArgs } from '../src/commands/init-argv.js';

describe('parseInitArgs', () => {
  it('returns all defaults for empty argv', () => {
    const out = parseInitArgs([]);
    expect(out).toEqual({
      force: false,
      dryRun: false,
      verbose: false,
      allowRoot: false,
      allowAnyDir: false,
      dir: undefined,
    });
  });

  it('parses --force as boolean true', () => {
    expect(parseInitArgs(['--force']).force).toBe(true);
  });

  it('parses --dry-run as boolean true', () => {
    expect(parseInitArgs(['--dry-run']).dryRun).toBe(true);
  });

  it('parses --verbose as boolean true', () => {
    expect(parseInitArgs(['--verbose']).verbose).toBe(true);
  });

  it('parses --allow-root as boolean true', () => {
    expect(parseInitArgs(['--allow-root']).allowRoot).toBe(true);
  });

  it('parses --allow-any-dir as boolean true', () => {
    expect(parseInitArgs(['--allow-any-dir']).allowAnyDir).toBe(true);
  });

  it('parses --dir with space-separated value', () => {
    expect(parseInitArgs(['--dir', '/tmp/test']).dir).toBe('/tmp/test');
  });

  it('parses --dir=value form', () => {
    expect(parseInitArgs(['--dir=/tmp/test']).dir).toBe('/tmp/test');
  });

  it('combines multiple flags', () => {
    const out = parseInitArgs(['--force', '--dry-run', '--dir', '/a']);
    expect(out.force).toBe(true);
    expect(out.dryRun).toBe(true);
    expect(out.dir).toBe('/a');
  });

  it('throws on unknown flag', () => {
    expect(() => parseInitArgs(['--nope'])).toThrow(/--nope/);
  });

  it('throws on --dir with missing value', () => {
    expect(() => parseInitArgs(['--dir'])).toThrow(/--dir requires a value/);
  });

  it('throws on positional arg', () => {
    expect(() => parseInitArgs(['random'])).toThrow(/random/);
  });
});
