// Fixture-based tests for the version-marker pure functions.
//
// @verifies R-NPM-007 (extension per Epic #194 Stories 1-3)
//
// The pure functions parse a single source, compare a version set, and
// format an operator-facing message. Real-file coverage lives in
// tests/version-sync.test.ts. This file uses in-memory string fixtures
// so the parser + comparator get tested without touching the repo.
//
// See docs/specs/2026-09-21-pre-tag-version-sync.md § Design notes for
// the readVersionSet error contract (RFC F1 · Hoare).
//
// test-list:
// [x] parseVersionMarker reads package.json .version
// [x] parseVersionMarker reads src/index.ts regex
// [x] parseVersionMarker reads README.md marker
// [x] parseVersionMarker reads CHANGELOG.md first non-Unreleased heading
// [x] parseVersionMarker throws VersionMarkerNotFound on missing package.json .version
// [x] parseVersionMarker throws VersionMarkerNotFound on missing src/index.ts regex match
// [x] parseVersionMarker throws VersionMarkerNotFound on missing README marker
// [x] parseVersionMarker throws VersionMarkerNotFound on missing CHANGELOG non-Unreleased heading
// [x] checkVersionSet returns drift=false when all 4 agree
// [x] checkVersionSet returns drift=true on v1.5.0 shape (characterization from commit 12d7153)
// [x] formatDriftMessage names all 4 sources on drift
// [x] formatDriftMessage points at `npm run bump`

import { describe, it, expect } from 'vitest';
import {
  parseVersionMarker,
  checkVersionSet,
  formatDriftMessage,
  VersionMarkerNotFound,
  type VersionSet,
} from '../src/lib/version-markers.js';

describe('parseVersionMarker', () => {
  it('reads package.json .version', () => {
    const content = JSON.stringify({ name: '@thebassclef/lite', version: '1.5.1' });
    expect(parseVersionMarker('package.json', content)).toBe('1.5.1');
  });

  it('reads src/index.ts version constant', () => {
    const content = `export const version = '1.5.1' as const;`;
    expect(parseVersionMarker('src/index.ts', content)).toBe('1.5.1');
  });

  it('reads README.md version marker', () => {
    const content = `Blurb.\n<!-- version-start -->1.5.1<!-- version-end -->\nMore prose.\n`;
    expect(parseVersionMarker('README.md', content)).toBe('1.5.1');
  });

  it('reads CHANGELOG.md first non-Unreleased heading', () => {
    const content = `# Changelog\n\n## [Unreleased]\n\n### Added\n\n## [1.5.1] - 2026-09-21\n\n## [1.5.0] - 2026-09-21\n`;
    expect(parseVersionMarker('CHANGELOG.md', content)).toBe('1.5.1');
  });

  it('throws VersionMarkerNotFound when package.json has no .version', () => {
    const content = JSON.stringify({ name: 'x' });
    expect(() => parseVersionMarker('package.json', content)).toThrow(VersionMarkerNotFound);
    try {
      parseVersionMarker('package.json', content);
    } catch (e) {
      expect(e).toBeInstanceOf(VersionMarkerNotFound);
      expect((e as VersionMarkerNotFound).source).toBe('package.json');
    }
  });

  it('throws VersionMarkerNotFound when src/index.ts regex fails', () => {
    const content = `export let version = '1.5.1';`; // wrong shape (let vs const, no `as const;`)
    expect(() => parseVersionMarker('src/index.ts', content)).toThrow(VersionMarkerNotFound);
  });

  it('throws VersionMarkerNotFound when README marker missing', () => {
    const content = `# README\n\nJust prose. No version marker delimiter.\n`;
    expect(() => parseVersionMarker('README.md', content)).toThrow(VersionMarkerNotFound);
  });

  it('throws VersionMarkerNotFound when CHANGELOG has no non-Unreleased heading', () => {
    const content = `# Changelog\n\n## [Unreleased]\n\n### Added\n`;
    expect(() => parseVersionMarker('CHANGELOG.md', content)).toThrow(VersionMarkerNotFound);
  });
});

describe('checkVersionSet', () => {
  it('returns drift=false when all four sources agree', () => {
    const set: VersionSet = {
      'package.json': '1.5.1',
      'src/index.ts': '1.5.1',
      'README.md': '1.5.1',
      'CHANGELOG.md': '1.5.1',
    };
    const finding = checkVersionSet(set);
    expect(finding.drift).toBe(false);
    if (!finding.drift) {
      expect(finding.version).toBe('1.5.1');
    }
  });

  it('returns drift=true on v1.5.0 shape — characterization from commit 12d7153', () => {
    const set: VersionSet = {
      'package.json': '1.5.0',
      'src/index.ts': '1.4.1',
      'README.md': '1.4.1',
      'CHANGELOG.md': '1.4.1',
    };
    const finding = checkVersionSet(set);
    expect(finding.drift).toBe(true);
    if (finding.drift) {
      expect(finding.disagreements).toHaveLength(4);
      const pkg = finding.disagreements.find((d) => d.source === 'package.json');
      expect(pkg?.value).toBe('1.5.0');
      const idx = finding.disagreements.find((d) => d.source === 'src/index.ts');
      expect(idx?.value).toBe('1.4.1');
    }
  });
});

describe('formatDriftMessage', () => {
  const driftFinding = {
    drift: true as const,
    disagreements: [
      { source: 'package.json' as const, value: '1.5.0' },
      { source: 'src/index.ts' as const, value: '1.4.1' },
      { source: 'README.md' as const, value: '1.4.1' },
      { source: 'CHANGELOG.md' as const, value: '1.4.1' },
    ],
  };

  it('names all four sources on drift', () => {
    const msg = formatDriftMessage(driftFinding);
    expect(msg).toContain('package.json=1.5.0');
    expect(msg).toContain('src/index.ts=1.4.1');
    expect(msg).toContain('README.md=1.4.1');
    expect(msg).toContain('CHANGELOG.md=1.4.1');
  });

  it('points at `npm run bump` as the remediation', () => {
    const msg = formatDriftMessage(driftFinding);
    expect(msg).toContain('npm run bump');
  });
});
