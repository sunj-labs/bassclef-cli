// `bassclef sync` — updates bassclef-managed files in place.
//
// Contract: docs/adrs/ADR-003-bassclef-sync-safety-contract.md.
// Design: docs/decompositions/wu-3-sync.md.
//
// Sync reads the init manifest, computes the current content hash of
// each managed file, and classifies per file into one of four cases:
// Current / NeedsUpdate / Edited / Deleted. Default action per case
// is refuse; two orthogonal flags (--force and --replace-edits)
// override the version and edit checks independently. Symlink refusal
// via O_NOFOLLOW inherits from ADR-002 and cannot be overridden.

import { existsSync, lstatSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { parseSyncArgs, SyncArgvError, type SyncArgs } from './sync-argv.js';
import { resolveTargetDir, ResolveError } from '../lib/resolve-target-dir.js';
import { writeSafely, mkdirSafely, WriteError } from '../lib/write-safely.js';
import {
  readManifest,
  writeManifest,
  ManifestReadError,
  type ManifestEntry,
  type Manifest,
} from '../lib/manifest-io.js';
import { hashContent } from '../lib/hash.js';
import { shouldRefuseRoot } from './init.js';
import { version as pkgVersion } from '../index.js';
import {
  settingsJsonTemplate,
  SETTINGS_TEMPLATE_VERSION,
} from './init-templates/settings-json.js';
import {
  substrateConfigMdTemplate,
  SUBSTRATE_CONFIG_TEMPLATE_VERSION,
} from './init-templates/substrate-config-md.js';

interface TemplateSpec {
  templateName: string;
  currentVersion: string;
  render: (pkgVersion: string) => string;
  // Recognizer for the `$bassclef` marker in the file's content.
  hasMarker: (content: string) => boolean;
}

const TEMPLATES: readonly TemplateSpec[] = [
  {
    templateName: 'settings.json',
    currentVersion: SETTINGS_TEMPLATE_VERSION,
    render: settingsJsonTemplate,
    hasMarker: (c) => c.includes('"$bassclef"'),
  },
  {
    templateName: 'substrate.config.md',
    currentVersion: SUBSTRATE_CONFIG_TEMPLATE_VERSION,
    render: substrateConfigMdTemplate,
    hasMarker: (c) => c.includes('bassclef_template:'),
  },
];

type Case =
  | { kind: 'Current' }
  | { kind: 'NeedsUpdate'; fromVersion: string; toVersion: string }
  | { kind: 'Edited'; manifestUpdatedAt: string | undefined; currentMtime: string }
  | { kind: 'Deleted' }
  | { kind: 'NoMarker' }
  | { kind: 'UnknownHash' };

interface FileDecision {
  entry: ManifestEntry;
  fullPath: string;
  spec: TemplateSpec | undefined; // undefined if the manifest lists a template we do not know
  case: Case;
  action: 'no-op' | 'update' | 'refuse';
  refusalReason?: string;
  nextStep?: string;
}

export function runSync(argv: readonly string[]): number {
  let args: SyncArgs;
  try {
    args = parseSyncArgs(argv);
  } catch (e) {
    if (e instanceof SyncArgvError) {
      process.stderr.write(`bassclef sync: ${e.message}\n`);
      process.stderr.write(usage());
      return 3;
    }
    throw e;
  }

  const currentUid =
    typeof process.getuid === 'function' ? process.getuid() : undefined;
  if (shouldRefuseRoot(currentUid, args.allowRoot)) {
    process.stderr.write(
      'bassclef sync: refusing to run as root. Pass --allow-root if this is intentional.\n'
    );
    return 1;
  }

  let targetDir: string;
  try {
    targetDir = resolveTargetDir({
      cwd: process.cwd(),
      cliArg: args.dir,
      allowAnyDir: args.allowAnyDir,
    });
  } catch (e) {
    if (e instanceof ResolveError) {
      process.stderr.write(`bassclef sync: ${e.message}\n`);
      return 1;
    }
    throw e;
  }

  let manifest;
  try {
    manifest = readManifest(targetDir);
  } catch (e) {
    if (e instanceof ManifestReadError) {
      process.stderr.write(`bassclef sync: ${e.message}\n`);
      // SchemaTooNew is operationally different — the CLI needs an
      // upgrade. Give it its own exit code so scripts can distinguish.
      if (e.kind === 'SchemaTooNew') return 4;
      return 1;
    }
    throw e;
  }

  const decisions: FileDecision[] = manifest.files.map((entry) =>
    classify(entry, targetDir, args)
  );

  if (args.dryRun) {
    return runDryRun(decisions, args.diff);
  }

  return runReal(decisions, targetDir, manifest);
}

function classify(entry: ManifestEntry, targetDir: string, args: SyncArgs): FileDecision {
  const fullPath = join(targetDir, entry.path);
  const spec = TEMPLATES.find((t) => t.templateName === entry.template);

  if (spec === undefined) {
    return {
      entry,
      fullPath,
      spec: undefined,
      case: { kind: 'Current' }, // unknown template — treat as no-op with a note
      action: 'no-op',
      refusalReason: `unknown template: ${entry.template}`,
    };
  }

  if (!existsSync(fullPath)) {
    const canRestore = args.force && args.replaceEdits;
    return {
      entry,
      fullPath,
      spec,
      case: { kind: 'Deleted' },
      action: canRestore ? 'update' : 'refuse',
      refusalReason: canRestore ? undefined : `${entry.path} — you have deleted this file since init. Sync will not recreate it without both --force and --replace-edits.`,
      nextStep: canRestore ? undefined : 'bassclef sync --force --replace-edits',
    };
  }

  // Read the managed file directly. Reads are unmediated per ADR-003
  // §Complete-mediation — reads carry no state-change risk and adding
  // a shim would not close a TOCTOU gap (the atomic-open at write time
  // is where safety lives). Writes still flow through writeSafely.
  let currentContent: string;
  try {
    currentContent = readFileSync(fullPath, 'utf8');
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    return {
      entry,
      fullPath,
      spec,
      case: { kind: 'Edited', manifestUpdatedAt: entry.updated_at, currentMtime: 'unknown' },
      action: 'refuse',
      refusalReason: `${entry.path} — cannot read (${err.code ?? 'unknown'}).`,
    };
  }

  if (!spec.hasMarker(currentContent)) {
    return {
      entry,
      fullPath,
      spec,
      case: { kind: 'NoMarker' },
      action: 'refuse',
      refusalReason: `${entry.path} — file is not managed by bassclef (no $bassclef marker). Sync will not overwrite it.`,
    };
  }

  if (entry.content_hash_sha256 === undefined) {
    return {
      entry,
      fullPath,
      spec,
      case: { kind: 'UnknownHash' },
      action: 'refuse',
      refusalReason: `${entry.path} — manifest lacks content hash. This can happen on manifests written before content-hash tracking. Repair via \`bassclef init --force\` (drops any adopter edits) or add the current hash by hand.`,
      nextStep: 'bassclef init --force',
    };
  }

  const currentHash = hashContent(currentContent);
  const templateOutput = spec.render(pkgVersion);
  const templateOutputHash = hashContent(templateOutput);
  const currentTemplateVersion = spec.currentVersion;

  const versionOutdated = currentTemplateVersion !== entry.template_version;
  const adopterEdited = currentHash !== entry.content_hash_sha256;
  const wouldChange = templateOutputHash !== currentHash;

  if (!wouldChange) {
    return { entry, fullPath, spec, case: { kind: 'Current' }, action: 'no-op' };
  }

  if (adopterEdited) {
    // Edited case — dominant over version state per ADR-003. The
    // refusal names BOTH possible causes (adopter edit OR crashed
    // prior sync) because the classifier cannot tell them apart from
    // hash mismatch alone. It also notes a pending version bump when
    // one exists so the operator sees the whole trade-off.
    const mtime = safeMtimeIso(fullPath);
    const versionNote = versionOutdated
      ? `\n  a template update is also pending: ${entry.template_version} → ${currentTemplateVersion}`
      : '';
    return {
      entry,
      fullPath,
      spec,
      case: {
        kind: 'Edited',
        manifestUpdatedAt: entry.updated_at,
        currentMtime: mtime,
      },
      action: args.replaceEdits ? 'update' : 'refuse',
      refusalReason: args.replaceEdits
        ? undefined
        : `${entry.path} — content differs from what init/sync last recorded.\n` +
          `  either you edited the file, or a prior sync did not finish.\n` +
          `  last sync recorded:  ${entry.updated_at ?? '(unknown)'}\n` +
          `  file mtime is now:   ${mtime}` +
          versionNote + '\n' +
          `Run \`bassclef sync --diff\` to see the change.\n` +
          `Run \`bassclef sync --replace-edits\` to replace your edits.`,
      nextStep: args.replaceEdits ? undefined : 'bassclef sync --replace-edits',
    };
  }

  if (versionOutdated) {
    return {
      entry,
      fullPath,
      spec,
      case: {
        kind: 'NeedsUpdate',
        fromVersion: entry.template_version,
        toVersion: currentTemplateVersion,
      },
      action: args.force ? 'update' : 'refuse',
      refusalReason: args.force
        ? undefined
        : `${entry.path} — update available (template ${entry.template_version} → ${currentTemplateVersion}). Run \`bassclef sync --force\` to apply.`,
      nextStep: args.force ? undefined : 'bassclef sync --force',
    };
  }

  // Would change but neither edited nor version-outdated — treat as current;
  // this is the "crash between file write and manifest write" residue.
  return { entry, fullPath, spec, case: { kind: 'Current' }, action: 'no-op' };
}

function safeMtimeIso(path: string): string {
  try {
    return statSync(path).mtime.toISOString();
  } catch {
    return 'unknown';
  }
}

function runDryRun(decisions: readonly FileDecision[], showDiff: boolean): number {
  let anyChange = false;
  for (const d of decisions) {
    const label = describeCase(d.case);
    process.stdout.write(`  ${label.padEnd(18)} ${d.entry.path}\n`);
    if (d.action === 'update' || d.action === 'refuse') anyChange = true;
    if (showDiff && d.spec !== undefined && d.case.kind !== 'Current') {
      // Cheap diff — just show a version marker. Full unified diff is later work.
      process.stdout.write(`      template current: ${d.spec.currentVersion}\n`);
      process.stdout.write(`      manifest recorded: ${d.entry.template_version}\n`);
    }
  }
  if (!anyChange) {
    process.stdout.write('bassclef sync: all up to date.\n');
  }
  return 0;
}

function runReal(
  decisions: readonly FileDecision[], targetDir: string, manifest: Manifest
): number {
  let updated = 0;
  let refused = 0;
  let errors = 0;
  let noChange = 0;

  for (const d of decisions) {
    if (d.action === 'no-op') { noChange += 1; continue; }
    if (d.action === 'refuse') {
      refused += 1;
      process.stderr.write(`bassclef sync: refused: ${d.refusalReason ?? d.entry.path}\n`);
      continue;
    }
    if (d.spec === undefined) { noChange += 1; continue; }

    const newContent = d.spec.render(pkgVersion);
    const newHash = hashContent(newContent);
    const parent = d.fullPath.substring(0, d.fullPath.lastIndexOf('/'));
    // Preserve the current file's mode (0o644 default when the file is
    // absent, per ADR-003 P2).
    let preservedMode = 0o644;
    try {
      preservedMode = lstatSync(d.fullPath).mode & 0o777;
    } catch { /* file may not exist yet (Deleted+restore) */ }

    try {
      mkdirSafely(parent);
      writeSafely(d.fullPath, newContent, { force: true, mode: preservedMode });
    } catch (e) {
      errors += 1;
      const msg = e instanceof WriteError ? e.message : (e as Error).message;
      process.stderr.write(`bassclef sync: write failed: ${d.entry.path}: ${msg}\n`);
      continue;
    }

    // Per-file manifest commit — write the whole manifest after each
    // successful file update. O(n²) bytes across a full run, but crash
    // safety wins at this scale (2 managed files). Revisit if the
    // managed-file count grows into the dozens.
    updateManifestEntry(manifest, d.entry.path, {
      content_hash_sha256: newHash,
      template_version: d.spec.currentVersion,
      updated_at: new Date().toISOString(),
      outcome: 'updated',
    });
    try {
      writeManifest(targetDir, manifest);
    } catch (e) {
      errors += 1;
      process.stderr.write(`bassclef sync: manifest update failed after writing ${d.entry.path}: ${(e as Error).message}\n`);
      continue;
    }
    updated += 1;
    process.stdout.write(`  updated  ${d.entry.path}\n`);
  }

  const parts: string[] = [];
  if (updated > 0) parts.push(`${updated} updated`);
  if (noChange > 0) parts.push(`${noChange} up to date`);
  if (refused > 0) parts.push(`${refused} refused`);
  if (errors > 0) parts.push(`${errors} error(s)`);
  if (parts.length === 0) parts.push('nothing to do');

  const summary = parts.join(', ');
  if (errors > 0) {
    process.stderr.write(`bassclef sync: ${summary}.\n`);
    return 2;
  }
  if (refused > 0) {
    process.stderr.write(`bassclef sync: ${summary}.\n`);
    return 1;
  }
  process.stdout.write(`bassclef sync: ${summary}.\n`);
  return 0;
}

function updateManifestEntry(
  manifest: { files: ManifestEntry[] },
  path: string,
  patch: Partial<ManifestEntry>
): void {
  const idx = manifest.files.findIndex((f) => f.path === path);
  if (idx < 0) {
    manifest.files.push({
      path,
      template: patch.template ?? path,
      template_version: patch.template_version ?? '0.0.1',
      outcome: 'updated',
      ...patch,
    });
    return;
  }
  manifest.files[idx] = { ...manifest.files[idx]!, ...patch };
}

function describeCase(c: Case): string {
  switch (c.kind) {
    case 'Current': return 'up to date';
    case 'NeedsUpdate': return `update ${c.fromVersion}→${c.toVersion}`;
    case 'Edited': return 'edited by you';
    case 'Deleted': return 'deleted by you';
    case 'NoMarker': return 'no marker';
    case 'UnknownHash': return 'no hash in manifest';
  }
}

export function usage(): string {
  return [
    '',
    'Usage:',
    '  bassclef sync [options]',
    '',
    'Options:',
    '  --dir <path>       Target directory. Default: current working directory.',
    '  --force            Apply available template updates. Default: refuse.',
    '  --replace-edits    Replace files you have edited. Default: refuse.',
    '  --dry-run          Print per-file status; write nothing.',
    '  --diff             Show template version change per file (--dry-run friendly).',
    '  --allow-root       Allow running as root. Default: refuse.',
    '  --allow-any-dir    Allow --dir outside your home directory. Default: refuse.',
    '  --verbose          Print per-file result.',
    '',
    'Sync reads .bassclef/init.manifest.json in the target directory.',
    'It updates only files listed in the manifest that carry the $bassclef marker.',
    '',
  ].join('\n');
}
