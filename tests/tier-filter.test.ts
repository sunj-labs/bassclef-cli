// tier-filter test list — per Beck TDD.
//
// scanFrontmatter takes (filename, content) and returns a hit when
// the YAML frontmatter block at BOF contains `tier: upstream` as a
// top-level key. Substring matches anywhere else pass.
//
// [x] file with frontmatter `tier: upstream` → refuse
// [x] file with frontmatter `tier: lite` → pass
// [x] file with frontmatter `tier: standard` → pass
// [x] file with frontmatter but no `tier` key → pass
// [x] file with no frontmatter → pass
// [x] file with `tier: upstream` in a Markdown table BELOW frontmatter → pass
// [x] non-markdown file (.ts, .js) → pass (only markdown-ish extensions scanned)
// [x] frontmatter with `tier: upstream_wrapper` → pass (not exact match)

import { describe, it, expect } from 'vitest';
import { scanFrontmatter } from '../scripts/tier-filter.mjs';

describe('tier-filter scanFrontmatter', () => {
  it('refuses a file with tier: upstream in the frontmatter', () => {
    const content = '---\ntier: upstream\n---\n\n# Doc\n';
    expect(scanFrontmatter('example.md', content)).toBe(true);
  });

  it('accepts tier: lite in the frontmatter', () => {
    const content = '---\ntier: lite\n---\n\n# Doc\n';
    expect(scanFrontmatter('example.md', content)).toBe(false);
  });

  it('accepts tier: standard in the frontmatter', () => {
    const content = '---\ntier: standard\n---\n\n# Doc\n';
    expect(scanFrontmatter('example.md', content)).toBe(false);
  });

  it('accepts frontmatter without a tier key', () => {
    const content = '---\ntitle: Example\n---\n\n# Doc\n';
    expect(scanFrontmatter('example.md', content)).toBe(false);
  });

  it('accepts a file with no frontmatter', () => {
    const content = '# Doc\n\nSome text.\n';
    expect(scanFrontmatter('example.md', content)).toBe(false);
  });

  it('accepts tier: upstream inside a Markdown table below the frontmatter', () => {
    const content = [
      '---',
      'tier: standard',
      '---',
      '',
      '# Tier system',
      '',
      '| Tier | Meaning |',
      '|---|---|',
      '| tier: upstream | internal only |',
      '| tier: lite | ships to adopters |',
      '',
    ].join('\n');
    expect(scanFrontmatter('example.md', content)).toBe(false);
  });

  it('skips non-markdown files (extensions .ts, .js)', () => {
    // Substring match anywhere would false-positive; the scanner only
    // parses .md/.mdx/.markdown.
    const content = 'const s = "tier: upstream";';
    expect(scanFrontmatter('src/x.ts', content)).toBe(false);
    expect(scanFrontmatter('src/x.js', content)).toBe(false);
  });

  it('does not treat tier: upstream_wrapper as a match (exact value)', () => {
    const content = '---\ntier: upstream_wrapper\n---\n';
    expect(scanFrontmatter('example.md', content)).toBe(false);
  });

  // Post-review additions per pattern-review item 6.

  it('catches CRLF-line-ending frontmatter with tier: upstream', () => {
    const content = '---\r\ntier: upstream\r\n---\r\n\r\n# Doc\r\n';
    expect(scanFrontmatter('example.md', content)).toBe(true);
  });

  it('catches frontmatter with a UTF-8 BOM at BOF', () => {
    const content = '﻿---\ntier: upstream\n---\n';
    expect(scanFrontmatter('example.md', content)).toBe(true);
  });

  it('catches frontmatter with a leading blank line', () => {
    const content = '\n---\ntier: upstream\n---\n';
    expect(scanFrontmatter('example.md', content)).toBe(true);
  });

  it('catches quoted tier: "upstream" (double quotes)', () => {
    const content = '---\ntier: "upstream"\n---\n';
    expect(scanFrontmatter('example.md', content)).toBe(true);
  });

  it("catches quoted tier: 'upstream' (single quotes)", () => {
    const content = "---\ntier: 'upstream'\n---\n";
    expect(scanFrontmatter('example.md', content)).toBe(true);
  });
});
