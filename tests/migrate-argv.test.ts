// bassclef migrate argv reducer — Tier 0 tests per Beck TDD.
//
// The reducer parses a slice of argv into a flag object. It knows about
// five boolean flags (--dry-run, --verbose, --yes, --allow-root,
// --allow-any-dir) and one string flag (--dir). Anything unknown throws.
//
// RED signal — parseMigrateArgs does not exist yet in src/commands/.
// Every test in this file fails at import until Step 5 ships
// src/commands/migrate-argv.ts.
//
// Ledger tie: R1 (Ousterhout — argv reducer accepts malformed flags
// silently → wrong-intent dispatch). Compensator: typed return with
// error thrown by name of the offending token.
//
// test-list (Beck):
// [ ] // @risk: R1 — empty argv → all defaults
// [ ] // @risk: R1 — --dry-run → dryRun: true
// [ ] // @risk: R1 — --verbose → verbose: true
// [ ] // @risk: R1 — --yes → yes: true (skips prompt)
// [ ] // @risk: R1 — --allow-root → allowRoot: true
// [ ] // @risk: R1 — --dir /path → dir: '/path'
// [ ] // @risk: R1 — --dir=value → dir: 'value'
// [ ] // @risk: R1 — unknown flag → throws naming the flag
// [ ] // @risk: R1 — --dir missing value → throws
// [ ] // @risk: R1 — combines multiple flags cleanly

import { describe, it, expect } from 'vitest';
import { parseMigrateArgs } from '../src/commands/migrate-argv.js';

describe('parseMigrateArgs', () => {
  it('// @risk: R1 — returns all defaults for empty argv', () => {
    const out = parseMigrateArgs([]);
    expect(out).toEqual({
      dryRun: false,
      verbose: false,
      yes: false,
      allowRoot: false,
      allowAnyDir: false,
      dir: undefined,
    });
  });

  it('// @risk: R1 — parses --dry-run as boolean true', () => {
    expect(parseMigrateArgs(['--dry-run']).dryRun).toBe(true);
  });

  it('// @risk: R1 — parses --verbose as boolean true', () => {
    expect(parseMigrateArgs(['--verbose']).verbose).toBe(true);
  });

  it('// @risk: R1 — parses --yes as boolean true (skips prompt)', () => {
    expect(parseMigrateArgs(['--yes']).yes).toBe(true);
  });

  it('// @risk: R1 — parses --allow-root as boolean true', () => {
    expect(parseMigrateArgs(['--allow-root']).allowRoot).toBe(true);
  });

  it('// @risk: R1 — parses --dir with space-separated value', () => {
    expect(parseMigrateArgs(['--dir', '/tmp/test']).dir).toBe('/tmp/test');
  });

  it('// @risk: R1 — parses --dir=value form', () => {
    expect(parseMigrateArgs(['--dir=/tmp/test']).dir).toBe('/tmp/test');
  });

  it('// @risk: R1 — throws on unknown flag naming the flag', () => {
    expect(() => parseMigrateArgs(['--nope'])).toThrow(/--nope/);
  });

  it('// @risk: R1 — throws on --dir with missing value', () => {
    expect(() => parseMigrateArgs(['--dir'])).toThrow(/--dir requires a value/);
  });

  it('// @risk: R1 — combines multiple flags cleanly', () => {
    const out = parseMigrateArgs(['--dry-run', '--yes', '--verbose', '--dir', '/a']);
    expect(out.dryRun).toBe(true);
    expect(out.yes).toBe(true);
    expect(out.verbose).toBe(true);
    expect(out.dir).toBe('/a');
  });
});
