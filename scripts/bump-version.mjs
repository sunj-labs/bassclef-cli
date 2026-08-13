#!/usr/bin/env node
// scripts/bump-version.mjs
//
// Bumps the @thebassclef/core version + rewrites CHANGELOG.md.
//
// @requirement R-NPM-007
//
// See standards/npm-versioning-and-changelog.md for the policy.
// See docs/decompositions/wu-5-methodology.md for the code shape.
// See docs/use-cases/UC-script-bump.md for the operator flow.
// Registry: docs/requirements/2026-08-11-npm-distribution.md.

import { readFileSync, writeFileSync, renameSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';

const USAGE = 'Usage: npm run bump patch|minor|major [--allow-dirty] [--date YYYY-MM-DD]';

export class ArgvError extends Error {}
export class RefusedError extends Error {}

export function parseArgs(argv) {
  const args = argv.slice(2);
  let bumpType = null;
  let allowDirty = false;
  let dateOverride = null;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--allow-dirty') { allowDirty = true; continue; }
    if (arg === '--date') { dateOverride = args[++i]; continue; }
    if (['patch', 'minor', 'major'].includes(arg)) { bumpType = arg; continue; }
    throw new ArgvError(`Unknown arg: ${arg}\n${USAGE}`);
  }

  if (!bumpType) throw new ArgvError(`Missing bump type.\n${USAGE}`);
  if (dateOverride !== null && !/^\d{4}-\d{2}-\d{2}$/.test(dateOverride)) {
    throw new ArgvError(`--date must be YYYY-MM-DD, got: ${dateOverride}`);
  }

  return { bumpType, allowDirty, dateOverride };
}

export function computeNewVersion(current, bumpType) {
  const base = current.split('-')[0];
  const parts = base.split('.').map(Number);
  if (parts.length !== 3 || parts.some(n => !Number.isInteger(n) || n < 0)) {
    throw new RefusedError(`Invalid current version: ${current}`);
  }

  // Semver §11 — any bump from a pre-release lands on the base version.
  const wasPreRelease = current !== base;
  if (wasPreRelease) return base;

  let [major, minor, patch] = parts;
  switch (bumpType) {
    case 'patch': patch += 1; break;
    case 'minor': minor += 1; patch = 0; break;
    case 'major': major += 1; minor = 0; patch = 0; break;
    default: throw new RefusedError(`Unknown bump type: ${bumpType}`);
  }
  return `${major}.${minor}.${patch}`;
}

export function renameUnreleasedBlock(changelogText, newVersion, date) {
  const unreleasedHeader = /^## \[Unreleased\]\s*$/m;
  const match = unreleasedHeader.exec(changelogText);
  if (!match) throw new RefusedError('No [Unreleased] block in CHANGELOG.md.');

  const startIdx = match.index + match[0].length;
  const rest = changelogText.slice(startIdx);
  const nextHeadingMatch = /^## \[/m.exec(rest);
  const contentEnd = nextHeadingMatch
    ? startIdx + nextHeadingMatch.index
    : changelogText.length;
  const unreleasedContent = changelogText.slice(startIdx, contentEnd);

  // Empty means only whitespace + empty subsection headers.
  const meaningfulContent = unreleasedContent
    .replace(/^\s*###\s+\w+\s*$/gm, '')
    .trim();
  if (meaningfulContent === '') {
    throw new RefusedError('[Unreleased] block is empty. Add changes before bumping.');
  }

  const freshUnreleased =
    '## [Unreleased]\n\n### Added\n\n### Changed\n\n### Fixed\n\n### Notes\n\n';
  const newVersionHeader = `## [${newVersion}] - ${date}`;
  const versionedBlock = newVersionHeader + unreleasedContent;

  let updated =
    changelogText.slice(0, match.index) +
    freshUnreleased +
    versionedBlock +
    changelogText.slice(contentEnd);

  // Update the compare links at the bottom.
  const compareLink = /^\[Unreleased\]:\s+(.*compare\/v)([\d.\-\w]+)\.\.\.HEAD\s*$/m;
  const linkMatch = compareLink.exec(updated);
  if (linkMatch) {
    const prevVersion = linkMatch[2];
    const baseUrl = linkMatch[1];
    const newUnreleasedLink = `[Unreleased]: ${baseUrl}${newVersion}...HEAD`;
    const newVersionLink = `[${newVersion}]: ${baseUrl}${prevVersion}...v${newVersion}`;
    updated = updated.replace(linkMatch[0], `${newUnreleasedLink}\n${newVersionLink}`);
  }

  return updated;
}

export function refuseIfDirty(allowDirty, runCmd) {
  if (allowDirty) return;
  const runner = runCmd || ((cmd) => execSync(cmd).toString());
  const status = runner('git status --porcelain');
  const lines = status.split('\n').filter(Boolean);
  const allowed = new Set(['package.json', 'CHANGELOG.md', 'src/index.ts']);
  const disallowed = lines.filter(line => {
    // porcelain format: XY<space>path where XY is a 2-char status field.
    const match = line.match(/^..\s(.+)$/);
    if (!match) return true;
    return !allowed.has(match[1]);
  });
  if (disallowed.length > 0) {
    throw new RefusedError(
      `Working tree dirty:\n${disallowed.join('\n')}\nCommit or stash first, or pass --allow-dirty.`
    );
  }
}

export function writePackageJsonVersion(pkgPath, newVersion) {
  const text = readFileSync(pkgPath, 'utf8');
  const updated = text.replace(
    /"version":\s*"[^"]+"/,
    `"version": "${newVersion}"`
  );
  const tmpPath = pkgPath + '.tmp';
  writeFileSync(tmpPath, updated, 'utf8');
  renameSync(tmpPath, pkgPath);
}

// Keeps the src/index.ts version constant in sync with package.json.
// The constant is what `bassclef --version` prints, so drift breaks
// the CLI + programmatic API tests. Refuses when the literal is
// missing rather than silently no-op.
export function writeIndexTsVersion(indexTsPath, newVersion) {
  const text = readFileSync(indexTsPath, 'utf8');
  const pattern = /export const version = '[^']+' as const;/;
  if (!pattern.test(text)) {
    throw new RefusedError(
      `Version constant not found in ${indexTsPath}. Expected: export const version = '...' as const;`
    );
  }
  const updated = text.replace(
    pattern,
    `export const version = '${newVersion}' as const;`
  );
  const tmpPath = indexTsPath + '.tmp';
  writeFileSync(tmpPath, updated, 'utf8');
  renameSync(tmpPath, indexTsPath);
}

export function writeChangelog(changelogPath, newText) {
  const tmpPath = changelogPath + '.tmp';
  writeFileSync(tmpPath, newText, 'utf8');
  renameSync(tmpPath, changelogPath);
}

export function todayUTC() {
  return new Date().toISOString().slice(0, 10);
}

export async function main(argv, cwd) {
  const workDir = cwd || process.cwd();

  let opts;
  try {
    opts = parseArgs(argv);
  } catch (e) {
    if (e instanceof ArgvError) {
      process.stderr.write(e.message + '\n');
      process.exit(3);
    }
    throw e;
  }

  try {
    refuseIfDirty(opts.allowDirty);

    const pkgPath = path.join(workDir, 'package.json');
    if (!existsSync(pkgPath)) {
      throw new RefusedError(`package.json not found at ${pkgPath}. Run from repo root.`);
    }
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    if (!pkg.version) throw new RefusedError('package.json has no version field.');

    const changelogPath = path.join(workDir, 'CHANGELOG.md');
    if (!existsSync(changelogPath)) {
      throw new RefusedError(`CHANGELOG.md not found at ${changelogPath}. Run from repo root.`);
    }

    const newVersion = computeNewVersion(pkg.version, opts.bumpType);
    const date = opts.dateOverride || todayUTC();

    const currentChangelog = readFileSync(changelogPath, 'utf8');
    const newChangelog = renameUnreleasedBlock(currentChangelog, newVersion, date);

    writeChangelog(changelogPath, newChangelog);
    writePackageJsonVersion(pkgPath, newVersion);

    const indexTsPath = path.join(workDir, 'src/index.ts');
    if (!existsSync(indexTsPath)) {
      throw new RefusedError(`src/index.ts not found at ${indexTsPath}. Run from repo root.`);
    }
    writeIndexTsVersion(indexTsPath, newVersion);

    process.stdout.write(`Bumped: ${pkg.version} → ${newVersion}\n`);
    process.stdout.write('Next steps:\n');
    process.stdout.write('  git add package.json CHANGELOG.md src/index.ts\n');
    process.stdout.write(`  git commit -m "chore: release v${newVersion}"\n`);
    process.stdout.write(`  git tag v${newVersion}\n`);
    process.stdout.write(`  git push origin main v${newVersion}\n`);
  } catch (e) {
    if (e instanceof RefusedError) {
      process.stderr.write(`Refused: ${e.message}\n`);
      process.exit(1);
    }
    throw e;
  }
}

// Only run main when invoked directly (not when imported for tests).
const invokedDirectly = import.meta.url === `file://${process.argv[1]}`;
if (invokedDirectly) {
  main(process.argv).catch(e => {
    process.stderr.write(`Error: ${e.message}\n`);
    process.exit(2);
  });
}
