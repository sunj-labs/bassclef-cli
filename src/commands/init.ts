// `bassclef init` — writes bassclef config into a project directory.
//
// @requirement R-NPM-002
//
// Contract: docs/adrs/ADR-002-bassclef-init-safety-contract.md.
// Design: docs/decompositions/wu-2-init.md.
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
//
// Ousterhout deep-module: the command interface is
//   bassclef init [--force] [--dry-run] [--dir <path>] [--allow-root]
//                 [--allow-any-dir] [--verbose]
// The implementation hides argv parsing, path resolution, existence
// checks, atomic writes, per-file result reporting.

import { existsSync, lstatSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { parseInitArgs, ArgvError } from './init-argv.js';
import { resolveTargetDir, ResolveError } from '../lib/resolve-target-dir.js';
import { writeSafely, mkdirSafely, WriteError } from '../lib/write-safely.js';
import { hashContent } from '../lib/hash.js';
import { version as pkgVersion } from '../index.js';
import {
  settingsJsonTemplate,
  SETTINGS_TEMPLATE_VERSION,
} from './init-templates/settings-json.js';
import {
  substrateConfigMdTemplate,
  SUBSTRATE_CONFIG_TEMPLATE_VERSION,
} from './init-templates/substrate-config-md.js';
import { manifestTemplate } from './init-templates/manifest-json.js';
import type { ManifestEntry } from '../lib/manifest-types.js';
import { MANIFEST_RELATIVE_PATH } from '../lib/manifest-io.js';

interface FilePlan {
  label: string;
  relativePath: string;
  fullPath: string;
  content: string;
  templateName: string;
  templateVersion: string;
}

type FileOutcome = 'created' | 'unchanged' | 'refused' | 'error';

interface FileResult {
  plan: FilePlan;
  outcome: FileOutcome;
  message?: string;
}

export function runInit(argv: readonly string[]): number {
  let args;
  try {
    args = parseInitArgs(argv);
  } catch (e) {
    if (e instanceof ArgvError) {
      process.stderr.write(`bassclef init: ${e.message}\n`);
      process.stderr.write(usage());
      return 3;
    }
    throw e;
  }

  // Root refusal (ADR-002 default).
  const currentUid =
    typeof process.getuid === 'function' ? process.getuid() : undefined;
  if (shouldRefuseRoot(currentUid, args.allowRoot)) {
    process.stderr.write(
      'bassclef init: refusing to run as root. Pass --allow-root if this is intentional.\n'
    );
    return 1;
  }

  // Resolve target directory (safety checks inside).
  let targetDir: string;
  try {
    targetDir = resolveTargetDir({
      cwd: process.cwd(),
      cliArg: args.dir,
      allowAnyDir: args.allowAnyDir,
    });
  } catch (e) {
    if (e instanceof ResolveError) {
      process.stderr.write(`bassclef init: ${e.message}\n`);
      return 1;
    }
    throw e;
  }

  // Manifest-exists refusal per ADR-003. Init refuses to re-baseline
  // a project that already has a manifest unless --force. Sync is the
  // path for updates; init is the path for greenfield bootstrap.
  if (!args.force && !args.dryRun) {
    const manifestPath = join(targetDir, MANIFEST_RELATIVE_PATH);
    if (existsSync(manifestPath)) {
      process.stderr.write(
        'bassclef init: already initialized (manifest exists). ' +
          'Run `bassclef sync` to apply updates, or `bassclef init --force` to re-baseline.\n'
      );
      return 1;
    }
  }

  // Build the plan.
  const plans: FilePlan[] = [
    {
      label: 'settings.json',
      relativePath: '.claude/settings.json',
      fullPath: join(targetDir, '.claude', 'settings.json'),
      content: settingsJsonTemplate(pkgVersion),
      templateName: 'settings.json',
      templateVersion: SETTINGS_TEMPLATE_VERSION,
    },
    {
      label: 'substrate.config.md',
      relativePath: 'substrate.config.md',
      fullPath: join(targetDir, 'substrate.config.md'),
      content: substrateConfigMdTemplate(pkgVersion),
      templateName: 'substrate.config.md',
      templateVersion: SUBSTRATE_CONFIG_TEMPLATE_VERSION,
    },
  ];

  if (args.dryRun) {
    return runDryRun(plans);
  }

  return runReal(plans, args.force, args.verbose, targetDir);
}

function runDryRun(plans: readonly FilePlan[]): number {
  for (const p of plans) {
    let planned: 'would create' | 'would skip' | 'would refuse';
    let extra = '';
    if (!existsSync(p.fullPath)) {
      planned = 'would create';
    } else {
      try {
        const st = lstatSync(p.fullPath);
        if (st.isSymbolicLink()) {
          planned = 'would refuse';
          extra = ' (symlink at target)';
        } else {
          planned = 'would skip';
          extra = ' (already exists — use --force)';
        }
      } catch {
        planned = 'would skip';
      }
    }
    process.stdout.write(`  ${planned.padEnd(14)} ${p.fullPath}${extra}\n`);
  }
  return 0;
}

function runReal(plans: readonly FilePlan[], force: boolean, verbose: boolean, targetDir: string): number {
  const results: FileResult[] = [];
  let anyRefused = false;
  let anyError = false;

  for (const p of plans) {
    // Ensure parent dir exists via the audited mkdirSafely — the
    // ADR-002 complete-mediation claim covers every filesystem
    // mutation in the init chain, not just file writes.
    const parent = dirname(p.fullPath);
    try {
      mkdirSafely(parent);
    } catch (e) {
      if (e instanceof WriteError) {
        results.push({ plan: p, outcome: 'error', message: e.message });
        anyError = true;
        continue;
      }
      throw e;
    }

    try {
      writeSafely(p.fullPath, p.content, { force });
      results.push({ plan: p, outcome: 'created' });
    } catch (e) {
      if (e instanceof WriteError) {
        if (e.kind === 'AlreadyExists') {
          results.push({ plan: p, outcome: 'unchanged' });
          anyRefused = true;
          continue;
        }
        if (e.kind === 'SymlinkRefused') {
          // Symlink refusal is its own outcome so downstream reporting
          // can distinguish it from a generic write error. --force does
          // not override; ADR-002 pins this as unconditional.
          results.push({ plan: p, outcome: 'refused', message: e.message });
          anyError = true;
          continue;
        }
        results.push({ plan: p, outcome: 'error', message: e.message });
        anyError = true;
        continue;
      }
      throw e;
    }
  }

  const created = results.filter((r) => r.outcome === 'created').length;
  const unchanged = results.filter((r) => r.outcome === 'unchanged').length;
  const errored = results.filter((r) => r.outcome === 'error');

  const refused = results.filter((r) => r.outcome === 'refused').length;

  if (verbose) {
    for (const r of results) {
      let label: string;
      if (r.outcome === 'error') label = `error (${r.message ?? 'unknown'})`;
      else if (r.outcome === 'refused') label = 'refused';
      else label = r.outcome;
      process.stdout.write(`  ${label.padEnd(10)} ${r.plan.fullPath}\n`);
    }
  }

  for (const r of errored) {
    const tag = r.outcome === 'refused' ? 'refused' : 'error';
    process.stderr.write(`bassclef init: ${tag}: ${r.message ?? 'write failed'}: ${r.plan.fullPath}\n`);
  }

  // Write the manifest so a later sync command knows what init did.
  // Manifest is best-effort: if it fails, the init above still stands.
  // The sync fallback path handles a missing manifest by reading marker
  // keys from each written file.
  writeManifest(targetDir, results);

  if (anyError) {
    const parts: string[] = [];
    if (created > 0) parts.push(`${created} created`);
    if (unchanged > 0) parts.push(`${unchanged} unchanged`);
    if (refused > 0) parts.push(`${refused} refused`);
    const otherErrors = errored.length - refused;
    if (otherErrors > 0) parts.push(`${otherErrors} error(s)`);
    process.stderr.write(`bassclef init: ${parts.join(', ')}.\n`);
    return 2;
  }

  if (created === 0 && unchanged === plans.length) {
    process.stdout.write('bassclef init: already initialized. No changes.\n');
    return 0;
  }

  if (anyRefused && created > 0) {
    process.stdout.write(
      `bassclef init: ${created} created, ${unchanged} unchanged. Pass --force to overwrite.\n`
    );
    return 0;
  }

  process.stdout.write(`bassclef init: ${created} created, ${unchanged} unchanged.\n`);
  return 0;
}

// Root-refusal predicate. Pure so it can be unit-tested without a
// uid-0 shell fixture. Returns true when the command should refuse.
//   currentUid = undefined → non-POSIX (Windows). Do not refuse.
//   currentUid = 0 (root)  → refuse unless --allow-root.
//   currentUid > 0         → allow.
export function shouldRefuseRoot(currentUid: number | undefined, allowRoot: boolean): boolean {
  if (currentUid === undefined) return false;
  if (currentUid !== 0) return false;
  return !allowRoot;
}

function writeManifest(targetDir: string, results: readonly FileResult[]): void {
  const entries: ManifestEntry[] = results.map((r) => {
    const entry: ManifestEntry = {
      path: r.plan.relativePath,
      template: r.plan.templateName,
      template_version: r.plan.templateVersion,
      outcome: r.outcome,
    };
    // Hash the content we actually wrote so sync can detect adopter
    // edits later. Only include a hash when we actually created the
    // file — an unchanged file may have been adopter-edited already,
    // and we do not want to falsely lock in the current disk content
    // as our baseline.
    if (r.outcome === 'created') {
      entry.content_hash_sha256 = hashContent(r.plan.content);
      entry.updated_at = new Date().toISOString();
    }
    return entry;
  });
  const manifestDir = join(targetDir, '.bassclef');
  const manifestPath = join(manifestDir, 'init.manifest.json');
  const content = manifestTemplate({
    pkgVersion,
    targetDir,
    files: entries,
  });
  try {
    mkdirSafely(manifestDir);
    // Manifest is always overwritten — it reflects the LATEST init run.
    // No safety concern: the marker keys make its origin explicit.
    writeSafely(manifestPath, content, { force: true });
  } catch {
    // Best-effort; do not fail init on manifest errors.
  }
}

export function usage(): string {
  return [
    '',
    'Usage:',
    '  bassclef init [options]',
    '',
    'Options:',
    '  --dir <path>       Target directory. Default: current working directory.',
    '  --force            Overwrite existing files. Default: refuse.',
    '  --dry-run          Print what would happen; write nothing.',
    '  --allow-root       Allow running as root. Default: refuse.',
    '  --allow-any-dir    Allow --dir outside your home directory. Default: refuse.',
    '  --verbose          Print per-file result.',
    '',
    'Files written under <target>:',
    '  .claude/settings.json          Claude Code settings (minimal, opt-in blocks)',
    '  substrate.config.md            Bassclef project manifest',
    '  .bassclef/init.manifest.json   Record of what init wrote (used by sync)',
    '',
  ].join('\n');
}
