// `bassclef init` — writes bassclef config into a project directory.
//
// @requirement R-NPM-002 + R-NPM-lite-002 (walker) + R-NPM-lite-003 (verbatim
// settings.json) + R-NPM-lite-004 (hook-count banner) + R-NPM-lite-005 (fail-loud)
//
// Contract: docs/adrs/ADR-002-bassclef-init-safety-contract.md.
// Reader contract: docs/adrs/ADR-009-manifest-as-init-contract-source.md +
// bassclef-upstream ADR-055 D1-D7.
// Design: docs/use-cases/UC-init.md (Phase 1 rewrite).
//
// Ousterhout deep-module: the command interface is
//   bassclef init [--force] [--dry-run] [--dir <path>] [--allow-root]
//                 [--allow-any-dir] [--verbose]
// The implementation hides argv parsing, path resolution, existence
// checks, wiring-manifest schema check, tree walk, atomic writes,
// placeholder substitution, hook-count banner formatting.
//
// Exit codes per ADR-002 §Invariants (extended 2026-09-13):
//   0 — success (all writes succeeded OR partial-success mix)
//   1 — refused by policy (existing file without --force; root; outside HOME)
//   2 — safety check failed at write (symlink; parent not writable; verify fail)
//   3 — invalid args
//   4 — wiring manifest missing (ADR-055 D4)
//   5 — wiring manifest schema major incompatible (ADR-055 D4)

import { existsSync, lstatSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { parseInitArgs, ArgvError } from './init-argv.js';
import { resolveTargetDir, ResolveError } from '../lib/resolve-target-dir.js';
import { writeSafely, mkdirSafely, WriteError } from '../lib/write-safely.js';
import { hashContent } from '../lib/hash.js';
import { version as pkgVersion } from '../index.js';
import {
  substrateConfigMdTemplate,
  SUBSTRATE_CONFIG_TEMPLATE_VERSION,
} from './init-templates/substrate-config-md.js';
import { manifestTemplate } from './init-templates/manifest-json.js';
import type { ManifestEntry } from '../lib/manifest-types.js';
import { MANIFEST_RELATIVE_PATH } from '../lib/manifest-io.js';
import { copySubstrate, CopyFailure } from '../lib/copy-substrate.js';

// Static tier for @thebassclef/lite. When standard + ultra packages
// ship, this resolves from the installed package.json `name` field
// (see UC-init §"Technology + data variations").
const RESOLVED_TIER = 'lite';

// Files subject to placeholder substitution per UC-init §Main step 5 +
// ADR-002 §Amendment 2026-09-13 §Placeholder substitution. settings.json
// is deliberately excluded — verbatim per ADR-055 D1.
const PLACEHOLDER_FILES = new Set([
  'CLAUDE.md',
  'docs/whereami.md',
  'whereami.md',
  '.bassclef-source.json',
]);

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

  // Build the cli-composed plan (substrate.config.md only — settings.json
  // now comes from dist/lite/ walker per ADR-055 D1). The walker fires
  // after this composition step; both share the same writeSafely path.
  const plans: FilePlan[] = [
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
    runDryRun(plans);
    return dispatchSubstrateCopy(targetDir, args.force, args.verbose, true);
  }

  // runReal writes the cli-composed plans (substrate.config.md) then
  // dispatches the walker for dist/lite/. Manifest is written last with
  // the union of both results so `bassclef sync` sees every managed file.
  return runReal(plans, args.force, args.verbose, targetDir);
}


// Dispatch the walker per bassclef-upstream ADR-055 D1-D7.
// Fails loudly with exit codes 4 (manifest missing) + 5 (schema
// incompatible) per ADR-055 D4. Prints hook-count banner per ADR-055 D5.
// Returns the dispatch's exit code so runInit can propagate it.
function dispatchSubstrateCopy(
  targetDir: string,
  force: boolean,
  verbose: boolean,
  dryRun: boolean
): number {
  const substitute = makePlaceholderTransform(targetDir);
  let result;
  try {
    result = copySubstrate(targetDir, {
      force,
      dryRun,
      transform: substitute,
    });
  } catch (e) {
    if (e instanceof CopyFailure) {
      // Nygard fail-loud per ADR-055 D4. Exit codes 4 + 5 documented
      // in ADR-002 §Amendment 2026-09-13.
      process.stderr.write(`bassclef init: ${e.message}\n`);
      if (e.kind === 'ManifestMissing') return 4;
      if (e.kind === 'SchemaIncompatible') return 5;
      // BundleMissing falls through — reinstall message already in the
      // exception; treat as exit 2 (write-time class per ADR-002).
      return 2;
    }
    throw e;
  }

  // Dry-run branch — print "would create" per walker entry so the
  // preview matches the real footprint. Per bassclef-cli#60.
  if (dryRun) {
    const wouldCopy = result.wouldCopy ?? [];
    for (const relativePath of wouldCopy) {
      const targetPath = join(targetDir, relativePath);
      process.stdout.write(`  ${'would create'.padEnd(14)} ${targetPath}\n`);
    }
    if (wouldCopy.length > 0) {
      process.stdout.write(
        `bassclef init: ${wouldCopy.length} substrate files would be copied.\n`
      );
    }
    // Banner in dry-run too — reader sees the shape before committing.
    process.stdout.write(
      `bassclef init: ${result.hookCount} hooks armed (${RESOLVED_TIER} tier).\n`
    );
    return 0;
  }

  if (result.copied.length === 0 && result.refused.length === 0 && result.errored.length === 0) {
    return 0;
  }
  // Group copied files by top-level directory for the summary line.
  const groupCounts = new Map<string, number>();
  for (const path of result.copied) {
    const parts = path.split('/');
    const top = parts.length >= 2 ? parts.slice(0, 2).join('/') : parts[0] ?? '';
    groupCounts.set(top, (groupCounts.get(top) ?? 0) + 1);
  }
  for (const [directory, count] of groupCounts) {
    process.stdout.write(`  ${directory}: ${count} files copied\n`);
  }
  const parts: string[] = [];
  if (result.copied.length > 0) parts.push(`${result.copied.length} substrate files copied`);
  if (result.refused.length > 0) parts.push(`${result.refused.length} refused`);
  if (result.errored.length > 0) parts.push(`${result.errored.length} error(s)`);
  process.stdout.write(`bassclef init: ${parts.join(', ')}.\n`);
  // Per bassclef-cli#60: print the grand total so the reader sees one
  // number that matches the on-disk footprint (1 config file — substrate.config.md
  // — plus the walker output).
  const grandTotal = 1 + result.copied.length;
  process.stdout.write(
    `bassclef init: ${grandTotal} files total (1 config + ${result.copied.length} substrate).\n`
  );
  // ADR-055 D5 hook-count banner — grade-8 message per Cooper.
  process.stdout.write(
    `bassclef init: ${result.hookCount} hooks armed (${RESOLVED_TIER} tier).\n`
  );
  if (verbose && result.erroredMessages) {
    for (const msg of result.erroredMessages) {
      process.stderr.write(`  substrate: ${msg}\n`);
    }
  }
  return result.errored.length > 0 ? 2 : 0;
}

// Placeholder substitution per UC-init §Main step 5 + ADR-002 amendment.
// Runs before writeSafely inside copySubstrate. settings.json passes
// through unchanged — verbatim per ADR-055 D1.
function makePlaceholderTransform(targetDir: string): (relPath: string, content: string) => string {
  const repoName = basename(targetDir);
  const timestamp = new Date().toISOString();
  return (relPath, content) => {
    if (!PLACEHOLDER_FILES.has(relPath)) return content;
    return content
      .replace(/\[REPO_NAME\]/g, repoName)
      .replace(/\[ISO_TIMESTAMP\]/g, timestamp)
      .replace(/\[TIER\]/g, RESOLVED_TIER);
  };
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

  if (anyError) {
    // Manifest is written for whatever succeeded before the error.
    writeManifest(targetDir, results);
    const parts: string[] = [];
    if (created > 0) parts.push(`${created} created`);
    if (unchanged > 0) parts.push(`${unchanged} unchanged`);
    if (refused > 0) parts.push(`${refused} refused`);
    const otherErrors = errored.length - refused;
    if (otherErrors > 0) parts.push(`${otherErrors} error(s)`);
    process.stderr.write(`bassclef init: ${parts.join(', ')}.\n`);
    return 2;
  }

  if (anyRefused && created > 0) {
    process.stdout.write(
      `bassclef init: ${created} config files created, ${unchanged} unchanged. Pass --force to overwrite.\n`
    );
  } else if (created === 0 && unchanged === plans.length) {
    process.stdout.write('bassclef init: already initialized. No changes.\n');
  } else {
    process.stdout.write(`bassclef init: ${created} config files created, ${unchanged} unchanged.\n`);
  }

  // Walker fires now — per ADR-055 D1-D5. Fails loudly with structured
  // errors + specific exit codes when the bundle is broken. Walker-owned
  // files stay OUT of the init manifest — sync manages cli-composed
  // templates (currently substrate.config.md); walker files refresh via
  // `bassclef init --force`.
  const walkerExit = dispatchSubstrateCopy(targetDir, force, verbose, false);

  // Manifest reflects cli-composed writes only. Walker success or
  // failure does not change this.
  writeManifest(targetDir, results);

  // RFC N4 — folder guidance line after walker (only on success).
  if (walkerExit === 0) {
    process.stdout.write(
      `bassclef init: your substrate lives under .claude/. ` +
        `Add .claude/ to .gitignore if you have not.\n`
    );
  }

  return walkerExit;
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
    'Exit codes:',
    '  0 — success',
    '  1 — refused by policy (existing file; running as root; outside HOME)',
    '  2 — safety check failed at write (symlink; parent not writable)',
    '  3 — invalid args',
    '  4 — wiring manifest missing from bundled substrate (reinstall @thebassclef/lite)',
    '  5 — wiring manifest schema major version incompatible with this cli',
    '',
    'Files written under <target>:',
    '  substrate.config.md            Bassclef project manifest',
    '  .bassclef/init.manifest.json   Record of what init wrote (used by sync)',
    '',
    '  Plus the bundled substrate tree from dist/lite/:',
    '  .claude/settings.json          Claude Code settings (verbatim from bundle)',
    '  CLAUDE.md, whereami.md, .bassclef-source.json, .gitignore',
    '                                 Templates with placeholders substituted',
    '',
    '  Run with --dry-run first to preview the full file list before',
    '  writing anything to disk.',
    '',
  ].join('\n');
}
