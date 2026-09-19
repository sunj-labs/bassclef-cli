// package.json `os` field shape test.
//
// @verifies bassclef-cli#151 Phase 1 acceptance — OS support contract declared
//
// Pins the "os" field to ["darwin", "linux"] per the launch decision.
// A future edit that changes the shape or drops a value trips this test.
// Cure for regression class: read comment 5742446859 on #151.
//
// [x] package.json.os equals ["darwin", "linux"]
// [x] package.json.os is present (guards silent removal)

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pkgPath = join(__dirname, '..', 'package.json');

describe('package.json os field', () => {
  it('is present', () => {
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    expect(pkg.os).toBeDefined();
    expect(Array.isArray(pkg.os)).toBe(true);
  });

  it('equals ["darwin", "linux"]', () => {
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    expect(pkg.os).toEqual(['darwin', 'linux']);
  });
});
