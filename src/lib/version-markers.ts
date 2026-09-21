// Version-marker library — reads + compares + formats the version
// across the four version-bearing files in this repo.
//
// @verifies R-NPM-007 (extension per Epic #194 Stories 1-3)
//
// Four sources carry the current version string:
//   - package.json .version
//   - src/index.ts   `export const version = 'X.Y.Z' as const;`
//   - README.md      `<!-- version-start -->X.Y.Z<!-- version-end -->`
//   - CHANGELOG.md   first `## [X.Y.Z] - YYYY-MM-DD` heading below `[Unreleased]`
//
// The bump script `scripts/bump-version.mjs` writes all four in one shot.
// A hand-edit of package.json alone leaves the sibling files stale — the
// v1.5.0 mis-ship class this cure closes.
//
// Design: `parseVersionMarker` is pure (Strategy per source). `readVersionSet`
// wraps it with fs reads. `checkVersionSet` compares the tuple. `formatDriftMessage`
// composes the operator-facing string.
//
// See docs/decompositions/2026-09-21-pre-tag-version-sync.md § Part 2 for
// GRASP + interfaces + patterns.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export type VersionSource =
  | 'package.json'
  | 'src/index.ts'
  | 'README.md'
  | 'CHANGELOG.md';

export type VersionSet = Record<VersionSource, string>;

export const VERSION_SOURCES: readonly VersionSource[] = [
  'package.json',
  'src/index.ts',
  'README.md',
  'CHANGELOG.md',
] as const;

/**
 * Thrown when any version marker cannot be read from its source.
 * Callers see a clear failure — never `null`, empty string, or `undefined`.
 * The `source` field names which file failed.
 */
export class VersionMarkerNotFound extends Error {
  public readonly source: VersionSource;

  constructor(source: VersionSource, message: string) {
    super(message);
    this.name = 'VersionMarkerNotFound';
    this.source = source;
  }
}

export type DriftFinding =
  | { drift: false; version: string }
  | {
      drift: true;
      disagreements: Array<{ source: VersionSource; value: string }>;
    };

/**
 * Parse the version string from a single source's file content.
 * Pure function — no I/O. Throws VersionMarkerNotFound on parse failure.
 */
export function parseVersionMarker(
  source: VersionSource,
  content: string,
): string {
  switch (source) {
    case 'package.json': {
      let pkg: unknown;
      try {
        pkg = JSON.parse(content);
      } catch (err) {
        throw new VersionMarkerNotFound(
          source,
          `package.json is not valid JSON: ${(err as Error).message}`,
        );
      }
      if (
        typeof pkg !== 'object' ||
        pkg === null ||
        typeof (pkg as { version?: unknown }).version !== 'string'
      ) {
        throw new VersionMarkerNotFound(
          source,
          'package.json is missing a string `.version` key.',
        );
      }
      return (pkg as { version: string }).version;
    }

    case 'src/index.ts': {
      const match = content.match(
        /export const version = '([^']+)' as const;/,
      );
      const captured = match?.[1];
      if (!captured) {
        throw new VersionMarkerNotFound(
          source,
          "src/index.ts is missing `export const version = 'X.Y.Z' as const;`",
        );
      }
      return captured;
    }

    case 'README.md': {
      const match = content.match(
        /<!-- version-start -->([^<]+)<!-- version-end -->/,
      );
      const captured = match?.[1];
      if (!captured) {
        throw new VersionMarkerNotFound(
          source,
          'README.md is missing the `<!-- version-start -->X.Y.Z<!-- version-end -->` marker.',
        );
      }
      return captured;
    }

    case 'CHANGELOG.md': {
      const lines = content.split('\n');
      let seenUnreleased = false;
      for (const line of lines) {
        if (/^## \[Unreleased\]/.test(line)) {
          seenUnreleased = true;
          continue;
        }
        if (seenUnreleased) {
          const match = line.match(/^## \[(\d+\.\d+\.\d+)\]/);
          const captured = match?.[1];
          if (captured) return captured;
        }
      }
      throw new VersionMarkerNotFound(
        source,
        'CHANGELOG.md has no `## [X.Y.Z]` heading below `[Unreleased]`.',
      );
    }
  }
}

/**
 * Read all four version markers from disk. Returns the tuple.
 * Throws VersionMarkerNotFound if any source fails to parse.
 */
export function readVersionSet(repoRoot: string): VersionSet {
  const result = {} as VersionSet;
  for (const source of VERSION_SOURCES) {
    const path = resolve(repoRoot, source);
    const content = readFileSync(path, 'utf8');
    result[source] = parseVersionMarker(source, content);
  }
  return result;
}

/**
 * Compare a version set. Returns drift=false when all four agree.
 * Returns drift=true with the per-source values on any disagreement.
 * Pure function.
 */
export function checkVersionSet(set: VersionSet): DriftFinding {
  const entries = Object.entries(set) as Array<[VersionSource, string]>;
  const firstEntry = entries[0];
  if (!firstEntry) {
    // Unreachable — VersionSet is always fully populated by readVersionSet.
    // Belt-and-suspenders per Nygard fail-loud.
    throw new Error('checkVersionSet received an empty VersionSet.');
  }
  const first = firstEntry[1];
  const allAgree = entries.every(([, value]) => value === first);
  if (allAgree) {
    return { drift: false, version: first };
  }
  return {
    drift: true,
    disagreements: entries.map(([source, value]) => ({ source, value })),
  };
}

/**
 * Format the operator-facing message for a DriftFinding.
 * On drift, names all four sources + points at `npm run bump`.
 */
export function formatDriftMessage(finding: DriftFinding): string {
  if (!finding.drift) {
    return `Version-sync OK: all four sources at ${finding.version}.`;
  }
  const rows = finding.disagreements.map(
    ({ source, value }) => `  ${source}=${value}`,
  );
  return [
    'Version drift detected across sources:',
    ...rows,
    '',
    'Run `npm run bump patch` (or minor/major) to update all four in sync.',
    'See CONTRIBUTING.md § Version bumps for the discipline.',
  ].join('\n');
}
