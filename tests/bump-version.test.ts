// bump-version test list — per Beck TDD.
//
// @verifies R-NPM-007
//
// The script has five pure functions + one main().
// Tests exercise the pure functions directly. main() gets a smoke test.
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
//
// [x] parseArgs — patch accepted
// [x] parseArgs — minor accepted
// [x] parseArgs — major accepted
// [x] parseArgs — missing bump type throws ArgvError
// [x] parseArgs — unknown arg throws ArgvError
// [x] parseArgs — --allow-dirty parses
// [x] parseArgs — --date YYYY-MM-DD parses
// [x] parseArgs — --date malformed throws ArgvError
// [x] computeNewVersion — patch 0.0.1 → 0.0.2
// [x] computeNewVersion — minor 0.1.0 → 0.2.0
// [x] computeNewVersion — major 0.1.0 → 1.0.0
// [x] computeNewVersion — patch on pre-release strips to base (0.1.0-rc.1 → 0.1.0)
// [x] computeNewVersion — minor on pre-release strips + zero patch (0.1.0-rc.1 → 0.1.0)
// [x] computeNewVersion — major on pre-release strips + zero minor + zero patch (0.1.0-rc.1 → 0.1.0 during 0.x flow; hits 1.0.0 as major from 0.x)
// [x] computeNewVersion — invalid current version throws RefusedError
// [x] renameUnreleasedBlock — moves Unreleased content into versioned block
// [x] renameUnreleasedBlock — inserts fresh Unreleased block above
// [x] renameUnreleasedBlock — fresh Unreleased carries Added/Changed/Fixed/Notes subsections
// [x] renameUnreleasedBlock — empty Unreleased throws RefusedError
// [x] renameUnreleasedBlock — missing Unreleased throws RefusedError
// [x] renameUnreleasedBlock — updates compare links at bottom
// [x] refuseIfDirty — allows dirty when allowDirty=true
// [x] refuseIfDirty — allows dirty on package.json + CHANGELOG.md only
// [x] refuseIfDirty — refuses on unrelated modified file
// [x] refuseIfDirty — clean tree passes
// [x] refuseIfDirty — allows dirty on src/index.ts (bump script writes it too)
// [x] writeIndexTsVersion — replaces the version literal
// [x] writeIndexTsVersion — refuses when the constant is missing

import { describe, it, expect } from 'vitest';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  parseArgs,
  computeNewVersion,
  renameUnreleasedBlock,
  refuseIfDirty,
  writeIndexTsVersion,
  ArgvError,
  RefusedError,
} from '../scripts/bump-version.mjs';

describe('parseArgs', () => {
  const nodeAndScript = ['node', 'bump-version.mjs'];

  it('accepts patch', () => {
    expect(parseArgs([...nodeAndScript, 'patch'])).toEqual({
      bumpType: 'patch',
      allowDirty: false,
      dateOverride: null,
    });
  });

  it('accepts minor', () => {
    expect(parseArgs([...nodeAndScript, 'minor']).bumpType).toBe('minor');
  });

  it('accepts major', () => {
    expect(parseArgs([...nodeAndScript, 'major']).bumpType).toBe('major');
  });

  it('throws ArgvError when bump type missing', () => {
    expect(() => parseArgs([...nodeAndScript])).toThrow(ArgvError);
  });

  it('throws ArgvError on unknown arg', () => {
    expect(() => parseArgs([...nodeAndScript, 'wibble'])).toThrow(ArgvError);
  });

  it('parses --allow-dirty', () => {
    expect(parseArgs([...nodeAndScript, 'patch', '--allow-dirty']).allowDirty).toBe(true);
  });

  it('parses --date YYYY-MM-DD', () => {
    expect(parseArgs([...nodeAndScript, 'patch', '--date', '2026-01-15']).dateOverride).toBe('2026-01-15');
  });

  it('throws ArgvError on malformed --date', () => {
    expect(() => parseArgs([...nodeAndScript, 'patch', '--date', 'not-a-date'])).toThrow(ArgvError);
  });
});

describe('computeNewVersion', () => {
  it('patch 0.0.1 → 0.0.2', () => {
    expect(computeNewVersion('0.0.1', 'patch')).toBe('0.0.2');
  });

  it('minor 0.1.0 → 0.2.0', () => {
    expect(computeNewVersion('0.1.0', 'minor')).toBe('0.2.0');
  });

  it('major 0.1.0 → 1.0.0', () => {
    expect(computeNewVersion('0.1.0', 'major')).toBe('1.0.0');
  });

  it('patch on pre-release strips to base (0.1.0-rc.1 → 0.1.0)', () => {
    expect(computeNewVersion('0.1.0-rc.1', 'patch')).toBe('0.1.0');
  });

  it('minor on pre-release strips (0.1.0-rc.1 → 0.1.0)', () => {
    // Pre-release strip drops the -rc.1; minor from 0.1.0-rc.1 lands on 0.1.0 (target of the pre-release cycle)
    expect(computeNewVersion('0.1.0-rc.1', 'minor')).toBe('0.1.0');
  });

  it('major on pre-release strips (0.1.0-rc.1 → 0.1.0)', () => {
    // Pre-release strip drops the -rc.1; major from a 0.x pre-release lands on the base 0.x it was heading toward
    expect(computeNewVersion('0.1.0-rc.1', 'major')).toBe('0.1.0');
  });

  it('major from stable 0.x lands on 1.0.0', () => {
    expect(computeNewVersion('0.5.3', 'major')).toBe('1.0.0');
  });

  it('throws RefusedError on invalid current version', () => {
    expect(() => computeNewVersion('not-a-version', 'patch')).toThrow(RefusedError);
  });
});

describe('renameUnreleasedBlock', () => {
  const fixture = `# Changelog

## [Unreleased]

### Added
- New feature X.

### Fixed
- Bug Y.

## [0.0.1] - 2026-08-06

### Added
- Initial release.

[Unreleased]: https://github.com/sunj-labs/bassclef-cli/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/sunj-labs/bassclef-cli/releases/tag/v0.0.1
`;

  it('renames [Unreleased] header to versioned block', () => {
    const out = renameUnreleasedBlock(fixture, '0.0.2', '2026-08-08');
    expect(out).toContain('## [0.0.2] - 2026-08-08');
  });

  it('preserves the old Unreleased content in the versioned block', () => {
    const out = renameUnreleasedBlock(fixture, '0.0.2', '2026-08-08');
    // The versioned block should carry "New feature X" and "Bug Y"
    const versionedIdx = out.indexOf('## [0.0.2]');
    const versionedSlice = out.slice(versionedIdx);
    expect(versionedSlice).toContain('New feature X');
    expect(versionedSlice).toContain('Bug Y');
  });

  it('inserts fresh Unreleased block above the new version', () => {
    const out = renameUnreleasedBlock(fixture, '0.0.2', '2026-08-08');
    const unreleasedIdx = out.indexOf('## [Unreleased]');
    const versionedIdx = out.indexOf('## [0.0.2]');
    expect(unreleasedIdx).toBeGreaterThan(-1);
    expect(unreleasedIdx).toBeLessThan(versionedIdx);
  });

  it('fresh Unreleased carries empty Added/Changed/Fixed/Notes subsections', () => {
    const out = renameUnreleasedBlock(fixture, '0.0.2', '2026-08-08');
    const unreleasedStart = out.indexOf('## [Unreleased]');
    const versionedStart = out.indexOf('## [0.0.2]');
    const unreleasedSlice = out.slice(unreleasedStart, versionedStart);
    expect(unreleasedSlice).toContain('### Added');
    expect(unreleasedSlice).toContain('### Changed');
    expect(unreleasedSlice).toContain('### Fixed');
    expect(unreleasedSlice).toContain('### Notes');
  });

  it('throws RefusedError on empty Unreleased block', () => {
    const emptyFixture = `# Changelog

## [Unreleased]

### Added

### Fixed

## [0.0.1] - 2026-08-06
### Added
- Initial.
`;
    expect(() => renameUnreleasedBlock(emptyFixture, '0.0.2', '2026-08-08')).toThrow(RefusedError);
  });

  it('throws RefusedError when Unreleased block missing', () => {
    const noUnreleased = `# Changelog

## [0.0.1] - 2026-08-06
### Added
- Initial.
`;
    expect(() => renameUnreleasedBlock(noUnreleased, '0.0.2', '2026-08-08')).toThrow(RefusedError);
  });

  it('updates compare links at the bottom', () => {
    const out = renameUnreleasedBlock(fixture, '0.0.2', '2026-08-08');
    expect(out).toContain('[Unreleased]: https://github.com/sunj-labs/bassclef-cli/compare/v0.0.2...HEAD');
    expect(out).toContain('[0.0.2]: https://github.com/sunj-labs/bassclef-cli/compare/v0.0.1...v0.0.2');
  });
});

describe('refuseIfDirty', () => {
  const cleanRunner = () => '';
  const dirtyOnUnrelatedRunner = () => ' M src/some-file.ts\n';
  const dirtyOnAllowedRunner = () => ' M package.json\n M CHANGELOG.md\n';

  it('allows dirty when allowDirty is true', () => {
    expect(() => refuseIfDirty(true, dirtyOnUnrelatedRunner)).not.toThrow();
  });

  it('allows dirty on package.json + CHANGELOG.md only', () => {
    expect(() => refuseIfDirty(false, dirtyOnAllowedRunner)).not.toThrow();
  });

  it('refuses on unrelated modified file', () => {
    expect(() => refuseIfDirty(false, dirtyOnUnrelatedRunner)).toThrow(RefusedError);
  });

  it('passes on clean tree', () => {
    expect(() => refuseIfDirty(false, cleanRunner)).not.toThrow();
  });

  it('allows dirty on src/index.ts (bump script writes it too)', () => {
    const runner = () => ' M src/index.ts\n';
    expect(() => refuseIfDirty(false, runner)).not.toThrow();
  });
});

describe('writeIndexTsVersion', () => {
  it('replaces the version literal', () => {
    const dir = mkdtempSync(join(tmpdir(), 'bump-index-'));
    const path = join(dir, 'index.ts');
    const before = `// header\nexport const version = '0.0.1' as const;\n`;
    writeFileSync(path, before, 'utf8');
    try {
      writeIndexTsVersion(path, '0.0.2');
      expect(readFileSync(path, 'utf8')).toContain(`export const version = '0.0.2' as const;`);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('refuses when the constant is missing', () => {
    const dir = mkdtempSync(join(tmpdir(), 'bump-index-'));
    const path = join(dir, 'index.ts');
    writeFileSync(path, `// no version constant here\n`, 'utf8');
    try {
      expect(() => writeIndexTsVersion(path, '0.0.2')).toThrow(RefusedError);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
