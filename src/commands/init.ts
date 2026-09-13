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
import { MANIFEST_RELATIVE_PATH, readManifestShapeVersion } from '../lib/manifest-io.js';
import { copySubstrate, CopyFailure } from '../lib/copy-substrate.js';
import { HOOKS_SUBPATH } from '../lib/paths.js';

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

  // cli 1.0.1 upgrade advisory per RFC-0002 L1 fold. Fires when a
  // 1.0.0-shaped manifest exists (no schema_version field OR < 2).
  // If the adopter confirms (or passes --yes), init proceeds as though
  // --force was set — the confirmation IS the consent to overwrite.
  const advisoryOutcome = maybeEmitUpgradeAdvisory(targetDir, args.yes);
  if (advisoryOutcome === 'refused') return 1;
  const upgradeApproved = advisoryOutcome === 'upgrade-approved';

  // Manifest-exists refusal per ADR-003. Init refuses to re-baseline
  // a project that already has a manifest unless --force. Sync is the
  // path for updates; init is the path for greenfield bootstrap.
  // The upgrade path from cli 1.0.0 → 1.0.1 (advisory confirmed) also
  // bypasses this refusal — the confirmation IS the consent.
  if (!args.force && !args.dryRun && !upgradeApproved) {
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
    return dispatchSubstrateCopy(targetDir, args.force || upgradeApproved, args.verbose, true, args.allowRoot, args.json);
  }

  // runReal writes the cli-composed plans (substrate.config.md) then
  // dispatches the walker for dist/lite/. Manifest is written last with
  // the union of both results so `bassclef sync` sees every managed file.
  return runReal(plans, args.force || upgradeApproved, args.verbose, targetDir, args.allowRoot, args.json);
}

/**
 * Emit the cli 1.0.1 upgrade advisory when a 1.0.0-shaped manifest is
 * present at the target. Returns 'ok' when init should proceed, 'refused'
 * when the adopter said no.
 *
 * Cli 1.0.0 wrote nothing to the HOOKS_SUBPATH under home. Cli 1.0.1 does. Adopters
 * upgrading in place see new files at user scope. Torvalds L1 fold —
 * name the behavior change explicitly + wait for confirm.
 *
 * Non-interactive path: --yes passes silently. Interactive path: prints
 * the advisory + reads one line from stdin. Empty or 'y' → proceed.
 * Any other line → refuse (exit 1).
 */
function maybeEmitUpgradeAdvisory(targetDir: string, yes: boolean): 'ok' | 'refused' | 'upgrade-approved' {
  const manifestPath = join(targetDir, MANIFEST_RELATIVE_PATH);
  if (!existsSync(manifestPath)) return 'ok';
  // Manifest read goes through the typed wrapper in src/lib/manifest-io.ts
  // per R4 discipline. Wrapper returns null when the manifest is absent,
  // unreadable, OR missing the schema_version field (1.0.0 shape).
  const version = readManifestShapeVersion(targetDir);
  // Manifest already at v2 (or later) — no upgrade to announce.
  if (version !== null && version >= 2) return 'ok';
  process.stdout.write(
    'bassclef init: cli 1.0.1 introduces user-scope hook installation at ' +
      `~/${HOOKS_SUBPATH}. cli 1.0.0 did not write there.\n`
  );
  if (yes) return 'upgrade-approved';
  process.stdout.write('bassclef init: continue? (y/N) ');
  const answer = readOneLineFromStdin();
  if (answer === '' || answer === 'y' || answer === 'Y') return 'upgrade-approved';
  process.stdout.write('bassclef init: aborted by adopter.\n');
  return 'refused';
}

function readOneLineFromStdin(): string {
  // Minimal read — one syscall, no full readline dependency. Returns
  // empty string on EOF (piped input closed) so CI paths default to 'ok'.
  try {
    const buf = Buffer.alloc(256);
    const n = require('node:fs').readSync(0, buf, 0, 256, null);
    return n > 0 ? buf.slice(0, n).toString('utf8').trim() : '';
  } catch {
    return '';
  }
}


// Dispatch the walker per bassclef-upstream ADR-055 D1-D7.
// Fails loudly with exit codes 4 (manifest missing) + 5 (schema
// incompatible) per ADR-055 D4. Prints hook-count banner per ADR-055 D5.
// Returns the dispatch's exit code so runInit can propagate it.
function dispatchSubstrateCopy(
  targetDir: string,
  force: boolean,
  verbose: boolean,
  dryRun: boolean,
  allowRoot: boolean,
  json: boolean
): number {
  const substitute = makePlaceholderTransform(targetDir);
  let result;
  try {
    result = copySubstrate(targetDir, {
      force,
      dryRun,
      transform: substitute,
      allowRoot,
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
  // Norman N1 fold — banner names installed HOOK count + per-scope breakdown.
  // The declared count comes from settings.json (result.hookCount).
  // The copied count must be counted from HOOK files only, not total
  // copied files (which include settings.json + templates + manifest).
  const copiedHookEntries = result.copiedEntries.filter(
    (e) => e.path.startsWith(HOOKS_SUBPATH) && e.path.endsWith('.sh')
  );
  const copiedCount = copiedHookEntries.length;
  const declaredCount = result.hookCount;
  const failedCount = result.refused.length + result.errored.length;
  const userScope = copiedHookEntries.filter((e) => e.scope === 'user').length;
  const projectScope = copiedHookEntries.filter((e) => e.scope === 'project').length;
  const scopeSuffix = userScope + projectScope > 0
    ? ` ${projectScope} in <repo>/${HOOKS_SUBPATH.replace(/\/$/, '')}, ${userScope} in ~/${HOOKS_SUBPATH.replace(/\/$/, '')}.`
    : '';
  if (failedCount > 0) {
    process.stdout.write(
      `bassclef init: Installed ${copiedCount} of ${declaredCount} hooks (${RESOLVED_TIER} tier).${scopeSuffix} ` +
        `${failedCount} failed — see errors above. Rerun bassclef init to retry.\n`
    );
  } else {
    process.stdout.write(
      `bassclef init: Installed ${copiedCount} of ${declaredCount} hooks (${RESOLVED_TIER} tier).${scopeSuffix}\n`
    );
  }
  // H1 fold — --json emits structured stderr line adopter tooling can parse.
  if (json) {
    const report = {
      copied: copiedCount,
      declared: declaredCount,
      failed: failedCount,
      scope_counts: { user: userScope, project: projectScope },
      tier: RESOLVED_TIER,
    };
    process.stderr.write(JSON.stringify(report) + '\n');
  }
  if (verbose && result.erroredMessages) {
    for (const msg of result.erroredMessages) {
      process.stderr.write(`  substrate: ${msg}\n`);
    }
  }
  // N5 fold — banner reads "N of M" on mismatch (informational). Exit
  // code follows the existing refused/errored discipline so partial-
  // copy scenarios where settings.json refused (adopter's existing
  // file preserved) still exit 0 when no hook copy actually errored.
  return result.errored.length > 0 ? 2 : 0;
}

// Placeholder substitution per UC-init §Main step 5 + ADR-002 amendment.
// Runs before writeSafely inside copySubstrate. settings.json passes
// through unchanged — verbatim per ADR-055 D1.
//
// Canonical shapes per UC-init amendment 2026-09-13: [REPO_NAME],
// [ISO_TIMESTAMP], [TIER]. bassclef-upstream v0.39.0 dist-templates
// (CLAUDE.md at least) also use `[Repo name]` (mixed case, with space)
// and `<tier>` (angle brackets) as historical variants. This transform
// accepts both shapes so cold-adopter output shows real values, not
// literal placeholders. Drop the historical variants after
// bassclef-cli#77 lands the upstream template rewrite.
function makePlaceholderTransform(targetDir: string): (relPath: string, content: string) => string {
  const repoName = basename(targetDir);
  const timestamp = new Date().toISOString();
  return (relPath, content) => {
    if (!PLACEHOLDER_FILES.has(relPath)) return content;
    return content
      // Canonical shapes.
      .replace(/\[REPO_NAME\]/g, repoName)
      .replace(/\[ISO_TIMESTAMP\]/g, timestamp)
      .replace(/\[TIER\]/g, RESOLVED_TIER)
      // Historical shapes shipped by bassclef-upstream v0.39.0 dist-templates.
      // Follow-on: bassclef-cli#77 tracks the upstream cure.
      .replace(/\[Repo name\]/g, repoName)
      .replace(/<tier>/g, RESOLVED_TIER);
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

function runReal(plans: readonly FilePlan[], force: boolean, verbose: boolean, targetDir: string, allowRoot: boolean, json: boolean): number {
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
  const walkerExit = dispatchSubstrateCopy(targetDir, force, verbose, false, allowRoot, json);

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
