// Unit test for the root-refusal predicate.
//
// The predicate is pure, so we can exercise the uid=0 case without a
// root shell. This closes the architect-review gap where the semver-
// locked "refuse root by default" invariant only had a deferred manual
// test.

import { describe, it, expect } from 'vitest';
import { shouldRefuseRoot } from '../src/commands/init.js';

describe('shouldRefuseRoot', () => {
  it('refuses when uid=0 and allowRoot=false', () => {
    expect(shouldRefuseRoot(0, false)).toBe(true);
  });

  it('permits when uid=0 and allowRoot=true', () => {
    expect(shouldRefuseRoot(0, true)).toBe(false);
  });

  it('permits when uid>0 (any allowRoot value)', () => {
    expect(shouldRefuseRoot(1000, false)).toBe(false);
    expect(shouldRefuseRoot(1000, true)).toBe(false);
  });

  it('does not refuse when uid is undefined (Windows / non-POSIX)', () => {
    expect(shouldRefuseRoot(undefined, false)).toBe(false);
    expect(shouldRefuseRoot(undefined, true)).toBe(false);
  });
});
