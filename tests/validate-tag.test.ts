// validate-tag test list — per Beck TDD.
//
// The script does three checks:
//   1. String-equal tag (stripped of `v`) to package.json version
//   2. Semver-format regex on the tag
//   3. Ancestor check via git — SKIPPED in unit tests (git subprocess);
//      covered by manual + workflow-integration tests
//
// The functions this test file exercises are exported from
// scripts/validate-tag.mjs. The script is written in Node ESM (no
// TypeScript) so it runs directly in the workflow without a build.
//
// [x] accepts v0.0.2 when package.json is 0.0.2
// [x] rejects v0.0.2 when package.json is 0.0.3
// [x] accepts v1.0.0-rc.1 (semver pre-release)
// [x] rejects tag without v prefix
// [x] rejects non-semver tag (v0.0.2.4)
// [x] rejects v0.0.2 vs beta.01 (string not equal)
// [x] pickDistTag returns 'latest' for stable + 'next' for pre-release

import { describe, it, expect } from 'vitest';
import { validateTagMatch, isSemverTag, pickDistTag } from '../scripts/validate-tag.mjs';

describe('validateTagMatch', () => {
  it('accepts v0.0.2 when package.json is 0.0.2', () => {
    expect(() => validateTagMatch('v0.0.2', '0.0.2')).not.toThrow();
  });

  it('rejects v0.0.2 when package.json is 0.0.3', () => {
    expect(() => validateTagMatch('v0.0.2', '0.0.3')).toThrow(/mismatch/i);
  });

  it('accepts semver pre-release v1.0.0-rc.1', () => {
    expect(() => validateTagMatch('v1.0.0-rc.1', '1.0.0-rc.1')).not.toThrow();
  });

  it('rejects tag without v prefix', () => {
    expect(() => validateTagMatch('0.0.2', '0.0.2')).toThrow(/prefix/i);
  });

  it('rejects string-unequal pre-releases (beta.1 vs beta.01)', () => {
    expect(() => validateTagMatch('v0.0.2-beta.1', '0.0.2-beta.01'))
      .toThrow(/mismatch/i);
  });
});

describe('isSemverTag', () => {
  it('accepts standard MAJOR.MINOR.PATCH', () => {
    expect(isSemverTag('v0.0.2')).toBe(true);
    expect(isSemverTag('v1.2.3')).toBe(true);
    expect(isSemverTag('v10.20.30')).toBe(true);
  });

  it('accepts pre-release', () => {
    expect(isSemverTag('v0.0.2-rc.1')).toBe(true);
    expect(isSemverTag('v1.0.0-beta.3')).toBe(true);
  });

  it('rejects four-segment version', () => {
    expect(isSemverTag('v0.0.2.4')).toBe(false);
  });

  it('rejects tags without v prefix', () => {
    expect(isSemverTag('0.0.2')).toBe(false);
  });

  it('rejects tags with trailing garbage', () => {
    expect(isSemverTag('v0.0.2extra')).toBe(false);
  });
});

describe('pickDistTag', () => {
  it('returns latest for stable semver', () => {
    expect(pickDistTag('v0.0.2')).toBe('latest');
    expect(pickDistTag('v1.2.3')).toBe('latest');
  });

  it('returns next for any pre-release', () => {
    expect(pickDistTag('v0.0.2-rc.1')).toBe('next');
    expect(pickDistTag('v1.0.0-beta.3')).toBe('next');
    expect(pickDistTag('v0.5.0-alpha.0')).toBe('next');
  });
});
