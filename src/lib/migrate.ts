// bassclef migrate library — Path A + Path B logic per ADR-008.
//
// Three public functions:
// - detectAdopterState(targetDir): composes readManifest + boolean
//   detectLegacyManifest into a 4-value discriminated shape
// - runPathA(targetDir, manifest, args): 0.0.2 → 0.1.0 upgrade with
//   config file hash preservation
// - runPathB(targetDir, args): 0.0.1 no-manifest → full init dispatch
//
// Design constraints per ADR-008:
// - Manifest write is the LAST operation in Path A (R3 bulkhead)
// - Config files listed in CONFIG_FILES survive migration (R2 Linus)
// - Path B calls runInit — no re-implementation (R6 Ousterhout reuse)
// - Prompt confirms shape before any write (Cooper); --yes bypasses (R7)
// - Unknown state → caller sees discriminated kind + message (R4 Nygard)

import { readManifest, writeManifest, ManifestReadError, computeConfigHashes } from './manifest-io.js';
import type { Manifest } from './manifest-types.js';
import { copySubstrate } from './copy-substrate.js';
import { confirm } from './prompt.js';
import { CONFIG_FILES, CURRENT_ENTRY_COUNT } from './paths.js';
import { runInit } from '../commands/init.js';
import { version } from '../index.js';

export type AdopterState =
  | 'current'
  | 'legacy-3-entry'
  | 'no-manifest'
  | { kind: 'unknown'; message: string }
  | { kind: 'error'; message: string };

export interface MigrateArgs {
  dryRun: boolean;
  verbose: boolean;
  yes: boolean;
  allowRoot: boolean;
  allowAnyDir: boolean;
  dir: string | undefined;
}

export interface MigrateResult {
  added: string[];
  preserved: string[];
  refused: string[];
  errored: string[];
  exitCode: number;
}

// Test hook — production callers do not pass this. Tests inject a
// fixture bundle path so copySubstrate can find the manifest without
// requiring a real substrate/ tree populated by the prepublish script.
export interface MigrateInternalOptions {
  bundleRoot?: string;
}

// Composes existing readManifest + detectLegacyManifest into the
// 4-value discriminated shape ADR-008 D1 requires. Kept in migrate.ts
// so manifest-io stays a pure boolean surface.
export async function detectAdopterState(targetDir: string): Promise<AdopterState> {
  let manifest: Manifest;
  try {
    manifest = readManifest(targetDir);
  } catch (e) {
    if (e instanceof ManifestReadError) {
      if (e.kind === 'Missing') return 'no-manifest';
      return { kind: 'error', message: e.message };
    }
    throw e;
  }

  // Legacy check reads two signals per detectLegacyManifest:
  // files.length === 3 OR schema_version < 0.1.0.
  const isLegacy = manifest.files.length === 3;
  const schemaLegacy = manifest.$bassclef.manifest_schema_version.startsWith('0.0.');
  if (isLegacy || schemaLegacy) return 'legacy-3-entry';

  // Current shape check — matches bundled substrate count.
  if (manifest.files.length === CURRENT_ENTRY_COUNT) return 'current';

  // Structurally valid manifest, neither legacy nor current — fail fast
  // per R4 Nygard. Adopter reinstalls @thebassclef/core and reruns.
  return {
    kind: 'unknown',
    message: `manifest has ${manifest.files.length} entries; expected 3 (legacy) or ${CURRENT_ENTRY_COUNT} (current)`,
  };
}

// Path A — 0.0.2 legacy install → 0.1.0 shape.
// Preserves 3 config files via computeConfigHashes; adds 146 substrate
// files via copySubstrate (default deny leaves existing files alone).
export async function runPathA(
  targetDir: string,
  _existingManifest: Manifest,
  args: MigrateArgs,
  opts: MigrateInternalOptions = {}
): Promise<MigrateResult> {
  // Compute hashes for adopter's existing config files so the new
  // manifest records their current content (R2 Linus adopter contract).
  const configHashes = await computeConfigHashes(targetDir, [...CONFIG_FILES]);

  // Ask before writing unless --yes was passed (R7 Cooper).
  const ttyOverride = args.yes ? 'yes' : null;
  const proceed = await confirm(
    `Ready to migrate to 0.1.0. Adds substrate files; preserves ${Object.keys(configHashes).length} existing config files.\nProceed?`,
    { defaultNo: true, ttyOverride }
  );
  if (!proceed) {
    process.stdout.write('bassclef migrate: aborted. No files changed.\n');
    return { added: [], preserved: [], refused: [], errored: [], exitCode: 0 };
  }

  if (args.dryRun) {
    process.stdout.write(
      `bassclef migrate: dry-run — would add substrate files; would preserve ` +
        `${Object.keys(configHashes).length} config files.\n`
    );
    return { added: [], preserved: Object.keys(configHashes), refused: [], errored: [], exitCode: 0 };
  }

  // Copy substrate with default deny — existing config files land in `refused`
  // which we translate to `preserved` in the migrate summary (Path A intent).
  const copyResult = copySubstrate(targetDir, { force: false, bundleRoot: opts.bundleRoot });

  const added = copyResult.copied;
  const preserved = copyResult.refused.filter((p) =>
    (CONFIG_FILES as readonly string[]).includes(p)
  );
  const refused = copyResult.refused.filter(
    (p) => !(CONFIG_FILES as readonly string[]).includes(p)
  );
  const errored = copyResult.errored;

  // Build new 149-entry manifest — 146 added substrate entries + 3
  // preserved config entries with adopter-edited hashes recorded.
  const newManifest: Manifest = {
    $bassclef: {
      template: 'init.manifest.json',
      manifest_schema_version: '0.1.0',
      generated_by: '@thebassclef/core',
      generated_by_version: version,
    },
    created_at: new Date().toISOString(),
    target_dir: targetDir,
    files: [
      ...added.map((path) => ({
        path,
        template: basename(path),
        template_version: '0.1.0',
        outcome: 'created' as const,
      })),
      ...preserved.map((path) => ({
        path,
        template: basename(path),
        template_version: '0.1.0',
        content_hash_sha256: configHashes[path],
        outcome: 'unchanged' as const,
      })),
    ],
  };

  // Manifest write is the LAST operation per R3 bulkhead — if we crash
  // above, the pre-migration manifest remains untouched on disk.
  writeManifest(targetDir, newManifest);

  // RFC N3 output shape — "preserved with existing content" in plain language.
  const parts = [
    `${added.length} added`,
    `${preserved.length} preserved with existing content`,
    ...(refused.length > 0 ? [`${refused.length} refused`] : []),
    ...(errored.length > 0 ? [`${errored.length} errored`] : []),
  ];
  process.stdout.write(`bassclef migrate: ${parts.join('; ')}.\n`);
  // RFC N4 folder guidance — mirror init's final line.
  process.stdout.write(
    `bassclef migrate: your substrate lives under .claude/. ` +
      `Add .claude/ to .gitignore if you have not.\n`
  );

  const exitCode = errored.length > 0 ? 1 : refused.length > 0 ? 2 : 0;
  return { added, preserved, refused, errored, exitCode };
}

// Path B — 0.0.1 name-reservation → full init dispatch.
// Reuses runInit per R6 Ousterhout deep-module discipline.
export async function runPathB(
  targetDir: string,
  args: MigrateArgs
): Promise<MigrateResult> {
  process.stdout.write(
    `bassclef migrate: no prior manifest detected. Running full init for ${CURRENT_ENTRY_COUNT} files.\n`
  );

  // Construct init argv from migrate args. --force is required because
  // an adopter at 0.0.1 has no manifest but may have loose files.
  const initArgv: string[] = [];
  if (args.dir) initArgv.push('--dir', args.dir);
  if (args.dryRun) initArgv.push('--dry-run');
  if (args.verbose) initArgv.push('--verbose');
  if (args.allowRoot) initArgv.push('--allow-root');
  if (args.allowAnyDir) initArgv.push('--allow-any-dir');
  initArgv.push('--force');

  const exitCode = runInit(initArgv);
  // Post-dispatch: init already reports its own summary. Add the
  // folder guidance line here too (RFC N4).
  if (exitCode === 0) {
    process.stdout.write(
      `bassclef migrate: your substrate lives under .claude/. ` +
        `Add .claude/ to .gitignore if you have not.\n`
    );
  }

  // Return a MigrateResult shape. `added` is a placeholder count —
  // init tracks its own outcomes; migrate surfaces only exit code.
  return {
    added: exitCode === 0 ? Array(CURRENT_ENTRY_COUNT).fill('(via init)') : [],
    preserved: [],
    refused: [],
    errored: [],
    exitCode,
  };
}

// Minimal basename — no need to pull in node:path for one call site.
function basename(path: string): string {
  const parts = path.split('/');
  return parts[parts.length - 1] ?? path;
}
