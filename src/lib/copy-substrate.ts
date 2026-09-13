// Walker for dist/<tier>/ tree — reads bundled substrate, copies each
// file verbatim to the adopter repo.
//
// Per bassclef-upstream ADR-055 D1: settings.json is copied byte-for-byte
// from dist/<tier>/.claude/settings.json. Cli does NOT compose. Cli does
// NOT filter entries at runtime. Upstream did tier filtering at build
// time via scripts/build-adopter-tree.sh.
//
// Per ADR-055 D4: cli fails loudly on missing wiring manifest or on
// schema major version mismatch. Structured error names path expected +
// remediation. Silent skip is not acceptable.
//
// Bundle layout the walker expects:
//   <bundleRoot>/
//     standards/bassclef-wiring-manifest.json  ← schema check reads this
//     .claude/settings.json                    ← copied verbatim per D1
//     CLAUDE.md, whereami.md, .bassclef-source.json, .gitignore
//                                              ← templates (placeholders
//                                                substituted upstream of
//                                                writeSafely by init.ts)
//
// Bundle root resolution:
//   - Explicit `bundleRoot` in options wins (used by Tier 0 tests).
//   - Otherwise walk up import.meta.url to package.json + descend into
//     dist/lite/. The compiled dist/cli.js lands under the package root;
//     dist/lite/ sits alongside it.
//
// @requirement R-NPM-lite-002 (walker)
// @requirement R-NPM-lite-003 (verbatim settings.json)
// @risk N1 (Nygard) — fail-loud typed errors; dispatch layer maps to exit 4+5
// @risk L1 (Torvalds) — every ADR-002 safety invariant preserved
// @rfc N1 — progress callback fires once per top-level directory group

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeSafely, mkdirSafely, WriteError } from './write-safely.js';

const EXPECTED_WIRING_SCHEMA_MAJOR = 2;
const WIRING_MANIFEST_RELATIVE = 'standards/bassclef-wiring-manifest.json';

export type CopyFailureKind =
  | 'ManifestMissing'
  | 'SchemaIncompatible'
  | 'BundleMissing';

// Typed error the init dispatcher maps to exit codes 4 + 5.
// Nygard fail-loud discipline: each kind carries the specific cure
// as part of the message; the dispatcher does not fabricate its own.
export class CopyFailure extends Error {
  constructor(readonly kind: CopyFailureKind, message: string) {
    super(message);
    this.name = 'CopyFailure';
  }
}

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
  /**
   * Optional content transform applied per file before writeSafely runs.
   * Init passes a placeholder-substitution function so CLAUDE.md and
   * whereami.md and .bassclef-source.json land with substituted values.
   * settings.json passes through untouched (verbatim per ADR-055 D1).
   */
  transform?: (relPath: string, content: string) => string;
}

export interface CopyResult {
  copied: string[];
  refused: string[];
  errored: string[];
  wouldCopy?: string[];
  erroredMessages?: string[];
  /**
   * Total hook entries counted across every event in the copied
   * settings.json. Feeds the ADR-055 D5 hook-count banner. Zero when
   * settings.json missing OR unparseable (walker still returned; init
   * surfaces the miss via structured error).
   */
  hookCount: number;
  /** Wiring manifest version string (e.g., "2.0.0"). Empty when manifest read failed. */
  wiringVersion: string;
}

export function copySubstrate(
  targetDir: string,
  options: CopyOptions = {}
): CopyResult {
  const bundleRoot = resolveBundleRoot(options.bundleRoot);
  // Precondition per ADR-055 D4: manifest present + schema major compatible.
  // Throws CopyFailure with kind 'ManifestMissing' or 'SchemaIncompatible'.
  const manifest = readWiringManifest(bundleRoot);

  const result: CopyResult = {
    copied: [],
    refused: [],
    errored: [],
    erroredMessages: [],
    hookCount: 0,
    wiringVersion: manifest.version,
  };
  if (options.dryRun) result.wouldCopy = [];

  const files = walkDistTree(bundleRoot);
  const groups = groupByTopDirectory(files);

  for (const [directory, groupFiles] of groups) {
    let completedInGroup = 0;
    for (const relPath of groupFiles) {
      const outcome = copyOne(relPath, bundleRoot, targetDir, options, result);
      if (outcome !== 'skipped') completedInGroup += 1;
    }
    if (options.onProgress) options.onProgress(directory, completedInGroup);
  }

  // Count hooks in the settings.json actually on disk (adopter's copy in
  // real run; bundle's copy in dry-run). Reading the on-disk file proves
  // the walker landed it. Wiring manifest hook count would be identical,
  // but reading the copied file is the honest signal.
  result.hookCount = readHookCount(
    options.dryRun
      ? join(bundleRoot, '.claude/settings.json')
      : join(targetDir, '.claude/settings.json')
  );

  return result;
}

// Reader-side wiring manifest check per ADR-055 D4.
// Emits typed CopyFailure the dispatcher maps to exit code 4 or 5.
function readWiringManifest(bundleRoot: string): { version: string } {
  const manifestPath = join(bundleRoot, WIRING_MANIFEST_RELATIVE);
  if (!fileExists(manifestPath)) {
    throw new CopyFailure(
      'ManifestMissing',
      `Wiring manifest missing at ${manifestPath}. ` +
        `Cli built for schema_version ${EXPECTED_WIRING_SCHEMA_MAJOR}.x. ` +
        `Run \`npm install @thebassclef/lite@latest\` to fix.`
    );
  }
  let manifest: { version?: unknown };
  let raw: string;
  try {
    raw = readFileSync(manifestPath, 'utf8');
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    throw new CopyFailure(
      'ManifestMissing',
      `Wiring manifest at ${manifestPath} unreadable (${err.code ?? 'unknown'}). ` +
        `Reinstall @thebassclef/lite to restore the bundle.`
    );
  }
  try {
    manifest = JSON.parse(raw);
  } catch (e) {
    const err = e as Error;
    throw new CopyFailure(
      'SchemaIncompatible',
      `Wiring manifest at ${manifestPath} is not valid JSON: ${err.message}. ` +
        `Reinstall @thebassclef/lite to restore the bundle.`
    );
  }
  if (typeof manifest.version !== 'string' || manifest.version.length === 0) {
    throw new CopyFailure(
      'SchemaIncompatible',
      `Wiring manifest at ${manifestPath} missing 'version' field. ` +
        `Cli requires schema_version ${EXPECTED_WIRING_SCHEMA_MAJOR}.x. ` +
        `Reinstall @thebassclef/lite to fix.`
    );
  }
  const major = parseInt(manifest.version.split('.')[0] ?? '0', 10);
  if (major !== EXPECTED_WIRING_SCHEMA_MAJOR) {
    throw new CopyFailure(
      'SchemaIncompatible',
      `Wiring manifest at ${manifestPath} has version ${manifest.version}. ` +
        `Cli built for schema_version ${EXPECTED_WIRING_SCHEMA_MAJOR}.x. ` +
        `Upgrade cli OR downgrade @thebassclef/lite to a compatible version.`
    );
  }
  return { version: manifest.version };
}

function walkDistTree(bundleRoot: string): string[] {
  if (!dirExists(bundleRoot)) {
    throw new CopyFailure(
      'BundleMissing',
      `Bundled substrate missing at ${bundleRoot}. ` +
        `Reinstall @thebassclef/lite to restore the bundle.`
    );
  }
  const results: string[] = [];
  function walk(dir: string): void {
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      const st = statSync(full);
      if (st.isDirectory()) walk(full);
      else results.push(relative(bundleRoot, full));
    }
  }
  walk(bundleRoot);
  // Sort so ordering is deterministic (ADR-055 D3 stability).
  results.sort();
  return results;
}

// npm-pack strips `.gitignore` files unconditionally (hard exclusion,
// not overridable via .npmignore or `files`). The bundle ships the
// template as `gitignore` (no dot). Walker renames back at write time
// so adopters land a proper `.gitignore` in their repo.
const GITIGNORE_BUNDLE_NAME = 'gitignore';
const GITIGNORE_ADOPTER_NAME = '.gitignore';

function mapAdopterPath(relPath: string): string {
  // Only rename the top-level `gitignore` template. Any deeper file
  // literally named `gitignore` passes through (defensive — dist/lite/
  // only has this one).
  if (relPath === GITIGNORE_BUNDLE_NAME) return GITIGNORE_ADOPTER_NAME;
  return relPath;
}

function copyOne(
  relPath: string,
  bundleRoot: string,
  targetDir: string,
  options: CopyOptions,
  result: CopyResult
): 'copied' | 'refused' | 'errored' | 'wouldCopy' | 'skipped' {
  const sourcePath = join(bundleRoot, relPath);
  const adopterRelPath = mapAdopterPath(relPath);
  const targetPath = join(targetDir, adopterRelPath);

  let content: string;
  try {
    content = readFileSync(sourcePath, 'utf8');
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    const message =
      `${relPath} — cannot read bundled source (${err.code ?? 'unknown'}). ` +
      `Reinstall @thebassclef/lite to restore the bundle.`;
    result.errored.push(adopterRelPath);
    result.erroredMessages?.push(message);
    return 'errored';
  }

  // Apply the caller-supplied transform (e.g., placeholder substitution
  // for CLAUDE.md, whereami.md, .bassclef-source.json). The transform
  // runs BEFORE writeSafely so mediation still owns the write boundary.
  // settings.json's transform returns content unchanged per ADR-055 D1.
  // Transform sees the ADOPTER path so the PLACEHOLDER_FILES membership
  // check in init.ts works for .gitignore (bundle: gitignore).
  const outputContent = options.transform ? options.transform(adopterRelPath, content) : content;

  if (options.dryRun) {
    result.wouldCopy?.push(adopterRelPath);
    return 'wouldCopy';
  }

  try {
    mkdirSafely(dirname(targetPath));
    writeSafely(targetPath, outputContent, { force: options.force ?? false });
    result.copied.push(adopterRelPath);
    return 'copied';
  } catch (e) {
    if (e instanceof WriteError) {
      if (e.kind === 'AlreadyExists') {
        result.refused.push(adopterRelPath);
        return 'refused';
      }
      if (e.kind === 'SymlinkRefused') {
        result.refused.push(adopterRelPath);
        return 'refused';
      }
      const message =
        `${adopterRelPath} — write failed (${e.kind}): ${e.message}. ` +
        `Check the target directory exists and is writable, then rerun.`;
      result.errored.push(adopterRelPath);
      result.erroredMessages?.push(message);
      return 'errored';
    }
    throw e;
  }
}

function resolveBundleRoot(explicit: string | undefined): string {
  if (explicit && explicit.length > 0) return resolve(explicit);
  // Walk up from the compiled dist/cli.js OR test-mode src/lib/*.ts to
  // package.json, then descend into dist/lite/.
  const thisFile = fileURLToPath(import.meta.url);
  let dir = dirname(thisFile);
  for (let i = 0; i < 5; i += 1) {
    if (fileExists(join(dir, 'package.json'))) {
      return join(dir, 'dist', 'lite');
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  throw new CopyFailure(
    'BundleMissing',
    `Cannot resolve bundled substrate root — package.json unreachable from ${thisFile}. ` +
      `Reinstall @thebassclef/lite.`
  );
}

function groupByTopDirectory(files: readonly string[]): Map<string, string[]> {
  const groups = new Map<string, string[]>();
  for (const p of files) {
    const parts = p.split('/');
    const top = parts.length >= 2 ? parts.slice(0, 2).join('/') : parts[0] ?? '';
    if (!groups.has(top)) groups.set(top, []);
    groups.get(top)!.push(p);
  }
  return groups;
}

function readHookCount(settingsPath: string): number {
  try {
    const parsed = JSON.parse(readFileSync(settingsPath, 'utf8'));
    let count = 0;
    for (const matcherBlocks of Object.values(parsed.hooks ?? {}) as Array<{ hooks?: unknown[] }[]>) {
      for (const block of matcherBlocks) {
        count += (block.hooks ?? []).length;
      }
    }
    return count;
  } catch {
    return 0;
  }
}

function fileExists(p: string): boolean {
  try {
    return statSync(p).isFile();
  } catch {
    return false;
  }
}

function dirExists(p: string): boolean {
  try {
    return statSync(p).isDirectory();
  } catch {
    return false;
  }
}

// Keep fileURLToPath in the import surface — the bundle-root resolver
// depends on ESM import.meta.url. Referenced above; this line is a
// re-export marker for future refactors that swap out URL parsing.
void fileURLToPath;
