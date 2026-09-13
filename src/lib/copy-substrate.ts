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
import { classify, type ScopeDecision } from './scope-router.js';
import { setExecutable } from './executable-bit-enforcer.js';
import { HOOKS_SUBPATH, SETTINGS_SUBPATH } from './paths.js';

const EXPECTED_WIRING_SCHEMA_MAJOR = 2;
const WIRING_MANIFEST_RELATIVE = 'standards/bassclef-wiring-manifest.json';

// CopyFailure + CopyFailureKind extracted to a shared module in cli
// 1.0.1 so scope-router.ts + resolve-home.ts can throw the same type
// without circular imports. Re-exported here for existing consumers
// (init.ts, tests) that import from copy-substrate directly.
export { CopyFailure, type CopyFailureKind } from './copy-substrate-failures.js';
import { CopyFailure } from './copy-substrate-failures.js';

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
  /**
   * Permit HOME=/root when routing user-scope hooks (matches init.ts
   * --allow-root). Default false. Added cli 1.0.1 per RFC-0002 L1+S1
   * folds — sudo bypass refused unless explicitly allowed.
   */
  allowRoot?: boolean;
}

/**
 * A single copy attempt result. Added cli 1.0.1 per RFC-0002 P3 fold —
 * carries the scope the file landed at (user vs project) so downstream
 * consumers do not have to reconstruct scope from the path.
 */
export interface CopiedEntry {
  path: string;
  scope: 'user' | 'project';
}

export interface CopyResult {
  /**
   * Adopter-relative paths of successfully copied files. Kept as
   * string[] for backward compatibility with cli 1.0.0 tests + consumers.
   * The richer per-scope shape lives in `copiedEntries` per P3 fold.
   */
  copied: string[];
  /** Per-scope shape of the same list. Consumers preferring scope info read this. */
  copiedEntries: CopiedEntry[];
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
    copiedEntries: [],
    refused: [],
    errored: [],
    erroredMessages: [],
    hookCount: 0,
    wiringVersion: manifest.version,
  };
  if (options.dryRun) result.wouldCopy = [];

  const files = walkDistTree(bundleRoot);
  const groups = groupByTopDirectory(files);

  // Build scope map AFTER the walk — needs the set of bundle hook
  // files so buildScopeMap can silent-skip commands that reference
  // hooks not in the bundle (legacy adopter fixtures).
  const bundleHookRelPaths = new Set(files.filter(isHookFile));
  const scopeMap = buildScopeMap(bundleRoot, targetDir, options, bundleHookRelPaths);

  for (const [directory, groupFiles] of groups) {
    let completedInGroup = 0;
    for (const relPath of groupFiles) {
      const outcome = copyOne(relPath, bundleRoot, targetDir, options, result, scopeMap);
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

/**
 * Build a map from hook-relative-path (a HOOKS_SUBPATH entry — see
 * src/lib/paths.ts) to a ScopeDecision that names where it should
 * land per settings.json.
 *
 * Reads the bundled settings.json AND the set of hook files actually
 * present in the bundle. Only classifies commands whose derived source
 * path matches a bundle hook file — legacy adopter fixtures with
 * unprefixed commands that reference files not in the bundle silent-
 * skip. Real fail-loud on UnknownScopePrefix fires only when a bundle
 * hook's declared command uses an unrecognized prefix (per N6 fold).
 */
function buildScopeMap(
  bundleRoot: string,
  targetDir: string,
  options: CopyOptions,
  bundleHookRelPaths: ReadonlySet<string>
): Map<string, ScopeDecision> {
  const map = new Map<string, ScopeDecision>();
  const settingsPath = join(bundleRoot, SETTINGS_SUBPATH);
  if (!fileExists(settingsPath)) return map;

  let parsed: { hooks?: Record<string, Array<{ hooks?: Array<{ command?: string }> }>> };
  try {
    parsed = JSON.parse(readFileSync(settingsPath, 'utf8'));
  } catch {
    return map;
  }

  const allowRoot = options.allowRoot ?? false;
  for (const eventBlocks of Object.values(parsed.hooks ?? {})) {
    for (const block of eventBlocks) {
      for (const entry of block.hooks ?? []) {
        const cmd = entry.command;
        if (typeof cmd !== 'string' || cmd.length === 0) continue;
        // Legacy adopter fixtures may carry unprefixed commands
        // (e.g., "example.sh"). Silent-skip so migrate flows on old
        // shapes still work. Any `$`-prefixed command runs through
        // classify — unknown prefixes throw per N6; path traversal
        // throws per S4.
        if (!cmd.startsWith('$')) continue;
        // classify may throw UnknownScopePrefix, PathTraversalRefused,
        // EnvironmentIncomplete, or SudoBypassRefused. All propagate —
        // the walker refuses to write anything until the adopter cures.
        const decision = classify({ command: cmd }, { targetDir, allowRoot });
        // Derive the bundle-relative source path — strip the prefix.
        const relSource = cmd
          .replace(/^\$HOME\//, '')
          .replace(/^\$CLAUDE_PROJECT_DIR\//, '')
          .replace(/\/{2,}/g, '/');
        // Only record commands referencing bundle hook files. Others
        // (settings.json in the bundle may name hooks the bundle
        // doesn't ship) silent-skip so the walker doesn't try to
        // write files that don't exist.
        if (!bundleHookRelPaths.has(relSource)) continue;
        map.set(relSource, decision);
      }
    }
  }
  return map;
}

/** Recognize a bundle-relative hook file so the walker routes it per scope. */
function isHookFile(relPath: string): boolean {
  return relPath.startsWith(HOOKS_SUBPATH) && relPath.endsWith('.sh');
}

function copyOne(
  relPath: string,
  bundleRoot: string,
  targetDir: string,
  options: CopyOptions,
  result: CopyResult,
  scopeMap: Map<string, ScopeDecision>
): 'copied' | 'refused' | 'errored' | 'wouldCopy' | 'skipped' {
  const sourcePath = join(bundleRoot, relPath);
  const adopterRelPath = mapAdopterPath(relPath);
  // Hook files route per scope map; non-hook files stay project-scope.
  const scopeDecision: ScopeDecision | undefined = isHookFile(relPath)
    ? scopeMap.get(relPath)
    : undefined;
  const targetPath = scopeDecision ? scopeDecision.targetPath : join(targetDir, adopterRelPath);
  const scope: 'user' | 'project' = scopeDecision ? scopeDecision.scope : 'project';

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
    // Hook files need the executable bit set — Claude Code invokes them
    // via /bin/sh; a non-executable file silently fails at session-start.
    if (isHookFile(relPath)) {
      setExecutable(targetPath);
    }
    // Record both shapes — string path (backward compat) + scoped entry (P3 fold).
    result.copied.push(adopterRelPath);
    result.copiedEntries.push({ path: adopterRelPath, scope });
    return 'copied';
  } catch (e) {
    if (e instanceof WriteError) {
      if (e.kind === 'AlreadyExists') {
        result.refused.push(adopterRelPath);
        return 'refused';
      }
      if (e.kind === 'SymlinkRefused') {
        result.refused.push(adopterRelPath);
        // Surface the readlink target on stderr per N2 fold so the
        // adopter can decide (delete symlink vs preserve). The message
        // carries the "points to: X" clause per write-safely.ts.
        process.stderr.write(`bassclef init: ${e.message}\n`);
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
