#!/usr/bin/env node
// scripts/check-version-set.mjs
//
// Reads the four version-bearing files in this repo. Asserts they
// agree on the same version string. Exits 0 on agreement, 2 on drift.
//
// @requirement R-NPM-007 (extension per Epic #194 Stories 1-3)
//
// Callable from:
//   - The pre-commit git hook (scripts/git-hooks/pre-commit-version-sync.sh)
//   - Manual operator invocation (`node scripts/check-version-set.mjs`)
//   - The PR-CI workflow (via `npm test`, indirectly, through the vitest suite)
//
// Design: self-contained ESM script. Mirrors src/lib/version-markers.ts.
// An integration test at tests/check-version-set.integration.test.ts spawns
// this script against fixtures and asserts exit codes; if TS + this mjs
// diverge, the test catches it.
//
// See docs/specs/2026-09-21-pre-tag-version-sync.md § Design notes.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SOURCES = ['package.json', 'src/index.ts', 'README.md', 'CHANGELOG.md'];

class VersionMarkerNotFound extends Error {
  constructor(source, message) {
    super(message);
    this.name = 'VersionMarkerNotFound';
    this.source = source;
  }
}

function parseVersionMarker(source, content) {
  if (source === 'package.json') {
    let pkg;
    try {
      pkg = JSON.parse(content);
    } catch (err) {
      throw new VersionMarkerNotFound(
        source,
        `package.json is not valid JSON: ${err.message}`,
      );
    }
    if (!pkg || typeof pkg.version !== 'string') {
      throw new VersionMarkerNotFound(
        source,
        'package.json is missing a string `.version` key.',
      );
    }
    return pkg.version;
  }

  if (source === 'src/index.ts') {
    const match = content.match(/export const version = '([^']+)' as const;/);
    if (!match || !match[1]) {
      throw new VersionMarkerNotFound(
        source,
        "src/index.ts is missing `export const version = 'X.Y.Z' as const;`",
      );
    }
    return match[1];
  }

  if (source === 'README.md') {
    const match = content.match(
      /<!-- version-start -->([^<]+)<!-- version-end -->/,
    );
    if (!match || !match[1]) {
      throw new VersionMarkerNotFound(
        source,
        'README.md is missing the `<!-- version-start -->X.Y.Z<!-- version-end -->` marker.',
      );
    }
    return match[1];
  }

  if (source === 'CHANGELOG.md') {
    const lines = content.split('\n');
    let seenUnreleased = false;
    for (const line of lines) {
      if (/^## \[Unreleased\]/.test(line)) {
        seenUnreleased = true;
        continue;
      }
      if (seenUnreleased) {
        const match = line.match(/^## \[(\d+\.\d+\.\d+)\]/);
        if (match && match[1]) return match[1];
      }
    }
    throw new VersionMarkerNotFound(
      source,
      'CHANGELOG.md has no `## [X.Y.Z]` heading below `[Unreleased]`.',
    );
  }

  throw new VersionMarkerNotFound(source, `Unknown source: ${source}`);
}

function readVersionSet(repoRoot) {
  const set = {};
  for (const source of SOURCES) {
    const path = resolve(repoRoot, source);
    const content = readFileSync(path, 'utf8');
    set[source] = parseVersionMarker(source, content);
  }
  return set;
}

function checkVersionSet(set) {
  const entries = Object.entries(set);
  if (entries.length === 0) {
    throw new Error('checkVersionSet received an empty VersionSet.');
  }
  const first = entries[0][1];
  const allAgree = entries.every(([, value]) => value === first);
  if (allAgree) return { drift: false, version: first };
  return {
    drift: true,
    disagreements: entries.map(([source, value]) => ({ source, value })),
  };
}

function formatDriftMessage(finding) {
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

function main() {
  // Repo root: passed as first argv, or CWD.
  const repoRoot = process.argv[2] || process.cwd();
  let set;
  try {
    set = readVersionSet(repoRoot);
  } catch (err) {
    if (err instanceof VersionMarkerNotFound) {
      process.stderr.write(
        `Version marker missing in ${err.source}: ${err.message}\n`,
      );
      process.stderr.write(
        'Fix the marker or run `npm run bump patch` to re-write all four.\n',
      );
      process.exit(2);
    }
    process.stderr.write(`Unexpected error: ${err.message}\n`);
    process.exit(2);
  }

  const finding = checkVersionSet(set);
  if (finding.drift) {
    process.stderr.write(formatDriftMessage(finding) + '\n');
    process.exit(2);
  }
  // Quiet on success — hooks + CI should not spam.
  if (process.env.CHECK_VERSION_SET_VERBOSE === '1') {
    process.stdout.write(formatDriftMessage(finding) + '\n');
  }
  process.exit(0);
}

const isMain =
  process.argv[1] &&
  fileURLToPath(import.meta.url) === resolve(process.argv[1]);

if (isMain) {
  main();
}

export {
  parseVersionMarker,
  readVersionSet,
  checkVersionSet,
  formatDriftMessage,
  VersionMarkerNotFound,
  SOURCES,
};
