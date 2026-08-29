// Copy the bundled substrate tree into the adopter project.
//
// @requirement R-NPM-lite-001
// @risk R1 — one public export; the walk, hash check, and write path
// hide inside. Consumer code calls one method.
// @risk R3 — imports writeSafely from write-safely.ts; never touches
// fs.writeFileSync directly.
// @risk R5 — consumer code walks the manifest, not the filesystem.
// The SUBSTRATE_ROOT literal lives in src/lib/paths.ts (R6).
// @risk R7-fallback — every file's content hash is verified against
// the bundled manifest before it lands on disk. Mismatch aborts the
// entry with a fix-oriented message.
// @rfc  N1 — progress callback fires once per top-level directory as
// each group completes. Sam sees `hooks: 25 files done` cadence.
// @rfc  N2 — error strings name a corrective action ("rerun with
// --force", "reinstall the package") rather than only the technical
// cause ("SHA256 mismatch").
//
// Sequence per copy-substrate:
//   1. Load bundled manifest at <bundleRoot>/.bassclef/lite-manifest.json
//   2. For each entry:
//      a. Read source at <bundleRoot>/<entry.path>
//      b. Hash the content; compare against entry.content_hash
//      c. On dry run: record wouldCopy. On real run: dispatch writeSafely.
//      d. Classify outcome: copied / refused / errored.
//   3. When a top-level directory group completes, fire onProgress.
//
// Bundle-root resolution:
//   - Explicit `bundleRoot` in options wins (used by Tier 0 tests).
//   - Otherwise resolve via createRequire on import.meta.url + the
//     package.json entry — the compiled dist/ files land under the
//     package root; the substrate/ tree sits alongside them.
//
// State diagram per entry lives in docs/decompositions/2026-08-28-npm-lite-bundling.md
// § State diagram — per-file copy outcome (Step 6 copy-substrate).

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { writeSafely, mkdirSafely, WriteError } from './write-safely.js';
import { SUBSTRATE_ROOT } from './paths.js';

interface CopyOptions {
  /** Directory that holds the bundled substrate tree. Tests override this. */
  bundleRoot?: string;
  /** Overwrite existing adopter files. Default: refuse. */
  force?: boolean;
  /** Report what would happen without writing anything. */
  dryRun?: boolean;
  /**
   * Called once per top-level directory after that group finishes copying.
   * `count` is the number of entries whose relative path started with the
   * same first two segments (a top-level folder under the target root).
   */
  onProgress?: (directory: string, count: number) => void;
}

interface CopyResult {
  copied: string[];
  refused: string[];
  errored: string[];
  wouldCopy?: string[];
  erroredMessages?: string[];
}

interface BundledEntry {
  path: string;
  content_hash: string;
}

interface BundledManifest {
  entries: BundledEntry[];
}

export function copySubstrate(
  targetDir: string,
  options: CopyOptions = {}
): CopyResult {
  const bundleRoot = resolveBundleRoot(options.bundleRoot);
  const manifest = loadBundledManifest(bundleRoot);

  const result: CopyResult = {
    copied: [],
    refused: [],
    errored: [],
    erroredMessages: [],
  };
  if (options.dryRun) result.wouldCopy = [];

  // Group entries by top-level directory (first two path segments) so
  // the progress callback fires per group.
  const groups = groupByTopDirectory(manifest.entries);

  for (const [directory, entries] of groups) {
    let completedInGroup = 0;
    for (const entry of entries) {
      const outcome = copyOne(entry, bundleRoot, targetDir, options, result);
      if (outcome !== 'skipped') completedInGroup += 1;
    }
    if (options.onProgress) options.onProgress(directory, completedInGroup);
  }

  return result;
}

function copyOne(
  entry: BundledEntry,
  bundleRoot: string,
  targetDir: string,
  options: CopyOptions,
  result: CopyResult
): 'copied' | 'refused' | 'errored' | 'wouldCopy' | 'skipped' {
  const sourcePath = join(bundleRoot, entry.path);
  const targetPath = join(targetDir, entry.path);

  let content: string;
  try {
    content = readFileSync(sourcePath, 'utf8');
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    const message =
      `${entry.path} — cannot read bundled source (${err.code ?? 'unknown'}). ` +
      `Reinstall @thebassclef/core to restore the bundle.`;
    result.errored.push(entry.path);
    result.erroredMessages?.push(message);
    return 'errored';
  }

  const declaredHash = stripHashPrefix(entry.content_hash);
  const actualHash = sha256Hex(content);
  if (declaredHash !== actualHash) {
    const message =
      `${entry.path} — bundled content hash does not match the manifest. ` +
      `Reinstall @thebassclef/core to repair the bundle, then rerun bassclef init --force.`;
    result.errored.push(entry.path);
    result.erroredMessages?.push(message);
    return 'errored';
  }

  if (options.dryRun) {
    result.wouldCopy?.push(entry.path);
    return 'wouldCopy';
  }

  try {
    mkdirSafely(dirname(targetPath));
    writeSafely(targetPath, content, { force: options.force ?? false });
    result.copied.push(entry.path);
    return 'copied';
  } catch (e) {
    if (e instanceof WriteError) {
      if (e.kind === 'AlreadyExists') {
        result.refused.push(entry.path);
        return 'refused';
      }
      if (e.kind === 'SymlinkRefused') {
        result.refused.push(entry.path);
        return 'refused';
      }
      const message =
        `${entry.path} — write failed (${e.kind}): ${e.message}. ` +
        `Check the target directory exists and is writable, then rerun.`;
      result.errored.push(entry.path);
      result.erroredMessages?.push(message);
      return 'errored';
    }
    throw e;
  }
}

function loadBundledManifest(bundleRoot: string): BundledManifest {
  const manifestPath = join(bundleRoot, '.bassclef', 'lite-manifest.json');
  const raw = readFileSync(manifestPath, 'utf8');
  const parsed = JSON.parse(raw) as BundledManifest;
  if (!Array.isArray(parsed.entries)) {
    throw new Error(
      `bundled manifest at ${manifestPath} has no entries[] array. ` +
      `Reinstall @thebassclef/core to restore the bundle.`
    );
  }
  return parsed;
}

function resolveBundleRoot(explicit: string | undefined): string {
  if (explicit && explicit.length > 0) return resolve(explicit);
  // Default: resolve the package.json path from this module, walk to
  // the package root, then append the substrate/ tree.
  const require = createRequire(import.meta.url);
  const pkgJsonPath = require.resolve('@thebassclef/core/package.json');
  const pkgRoot = dirname(pkgJsonPath);
  return join(pkgRoot, SUBSTRATE_ROOT);
}

function groupByTopDirectory(entries: readonly BundledEntry[]): Map<string, BundledEntry[]> {
  const groups = new Map<string, BundledEntry[]>();
  for (const entry of entries) {
    const parts = entry.path.split('/');
    const top = parts.length >= 2 ? parts.slice(0, 2).join('/') : parts[0] ?? '';
    if (!groups.has(top)) groups.set(top, []);
    groups.get(top)!.push(entry);
  }
  return groups;
}

function stripHashPrefix(value: string): string {
  const prefix = 'sha256:';
  return value.startsWith(prefix) ? value.slice(prefix.length) : value;
}

function sha256Hex(content: string): string {
  return createHash('sha256').update(content).digest('hex');
}

// Keep fileURLToPath in the import surface so future refinement per
// RFC S2 (deferred to scope-e) has one place to swap out createRequire
// for a plain import.meta.url + relative resolve.
void fileURLToPath;
