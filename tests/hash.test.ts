// hashContent test list — per Beck TDD.
//
// SHA-256 of UTF-8 bytes with CRLF normalized to LF.
//
// [x] known-input SHA-256 vector
// [x] CRLF → LF normalization: `"a\r\nb"` hashes same as `"a\nb"`
// [x] mixed line endings normalize consistently
// [x] empty string hashes to SHA-256(empty)
// [x] hash is deterministic (same input → same output)

import { describe, it, expect } from 'vitest';
import { hashContent } from '../src/lib/hash.js';

describe('hashContent', () => {
  it('produces the known SHA-256 for a known string', () => {
    // sha256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
    expect(hashContent('hello')).toBe(
      '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
    );
  });

  it('normalizes CRLF to LF before hashing', () => {
    expect(hashContent('a\r\nb')).toBe(hashContent('a\nb'));
  });

  it('handles mixed line endings consistently', () => {
    const winStyle = 'line1\r\nline2\r\nline3';
    const unixStyle = 'line1\nline2\nline3';
    expect(hashContent(winStyle)).toBe(hashContent(unixStyle));
  });

  it('hashes the empty string to the empty-input digest', () => {
    // sha256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    expect(hashContent('')).toBe(
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    );
  });

  it('is deterministic', () => {
    const input = 'the quick brown fox';
    expect(hashContent(input)).toBe(hashContent(input));
  });

  it('strips a leading UTF-8 BOM before hashing', () => {
    const withBom = '﻿{"a":1}';
    const withoutBom = '{"a":1}';
    expect(hashContent(withBom)).toBe(hashContent(withoutBom));
  });

  it('does NOT normalize trailing whitespace (edits are signal)', () => {
    expect(hashContent('a\n')).not.toBe(hashContent('a  \n'));
  });
});
