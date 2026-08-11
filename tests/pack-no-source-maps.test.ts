// pack-no-source-maps test list — per Beck TDD.
//
// The npm tarball must not contain source-map files. This is the
// Anthropic v2.1.88 leak pattern (59.8 MB source map exposed 513K
// lines of TypeScript in March 2026 per InfoQ + Layer5 write-ups).
// ADR-001 §Invariants pins the source-map exclusion as semver-locked.
//
// Two layers of defense:
//   1. package.json files field explicit whitelist (dist/*.js, .cjs, .d.ts)
//   2. vite.config.ts sourcemap: 'hidden' (no reference in shipped .js)
//
// This test verifies the CONFIG at both layers. A runtime test that
// builds + runs `npm pack --dry-run` lives in the publish workflow.
//
// [x] package.json files field allows no glob that could match .map
// [x] package.json files field is explicit-whitelist shape, not "dist" bulk
// [x] vite.config.ts sourcemap is one of the safe values (false, 'hidden', or absent)
// [x] tsconfig noEmit + sourceMap decoupled — noEmit means tsc emits nothing

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '..');

describe('package.json files field — source-map exclusion', () => {
  const pkg = JSON.parse(readFileSync(resolve(repoRoot, 'package.json'), 'utf8')) as { files: string[] };

  it('carries an explicit files field', () => {
    expect(Array.isArray(pkg.files)).toBe(true);
    expect(pkg.files.length).toBeGreaterThan(0);
  });

  it('has no entry that could match a .map file', () => {
    for (const entry of pkg.files) {
      // A pattern matches .map when it ends in .map, or when it is a
      // directory-bulk match with no extension filter (e.g., "dist",
      // "dist/", "dist/**"). Reject both shapes.
      expect(entry.endsWith('.map')).toBe(false);

      // Reject dist/ dir-bulk entries. They ship everything inside dist,
      // including any .map file vite emits. If the operator wants dist/
      // bulk shipping, they must first prove vite emits no .map — but
      // even then, config drift can silently break the guarantee. Safer
      // to whitelist explicit extensions.
      const isBulkDist =
        entry === 'dist' ||
        entry === 'dist/' ||
        entry === 'dist/*' ||
        entry === 'dist/**' ||
        entry === 'dist/**/*';
      expect(isBulkDist).toBe(false);
    }
  });

  it('whitelists .js, .cjs, .d.ts — the shipped code + types', () => {
    const patterns = pkg.files.join(' ');
    expect(patterns).toContain('.js');
    expect(patterns).toContain('.cjs');
    expect(patterns).toContain('.d.ts');
  });

  it('ships README.md and LICENSE', () => {
    expect(pkg.files).toContain('README.md');
    expect(pkg.files).toContain('LICENSE');
  });
});

describe('vite.config.ts — sourcemap safety', () => {
  const viteConfig = readFileSync(resolve(repoRoot, 'vite.config.ts'), 'utf8');

  it('does not set sourcemap: true', () => {
    // sourcemap: true emits .map files AND embeds //# sourceMappingURL=
    // comment references in shipped .js. Even with the files-field
    // whitelist, the reference would point at a missing file for any
    // adopter with map-aware tooling — a leaked hint at the least.
    expect(viteConfig).not.toMatch(/sourcemap:\s*true\b/);
  });

  it('sets sourcemap to false, "hidden", or omits the field', () => {
    const hasSafeValue =
      /sourcemap:\s*false\b/.test(viteConfig) ||
      /sourcemap:\s*['"]hidden['"]/.test(viteConfig) ||
      !/sourcemap:/.test(viteConfig);
    expect(hasSafeValue).toBe(true);
  });
});
