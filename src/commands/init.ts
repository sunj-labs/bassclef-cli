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

import { existsSync, lstatSync, readFileSync } from 'node:fs';
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
import { HOOKS_SUBPATH, CLAUDE_TARGET_ROOT } from '../lib/paths.js';
import { buildInitReport, renderJsonReport, type InitReport } from '../lib/init-report.js';
import type { CopyResult } from '../lib/copy-substrate.js';

// Static tier for @thebassclef/lite. When standard + ultra packages
// ship, this resolves from the installed package.json `name` field
// (see UC-init §"Technology + data variations").
const RESOLVED_TIER = 'lite';

/**
 * @pattern patterns/code/gof/strategy.md
 *
 * The output writer is chosen once from the --json flag and passed down.
 * Before cli 1.1.1 each print site asked whether JSON was on, and the
 * JSON itself went to stderr with human prose following it on stdout.
 * Per ADR-010 D6: under --json the routine human lines are not printed
 * at all, so stdout carries the object and nothing else. Errors keep
 * using stderr directly and stay the only thing there.
 */
type Say = (s: string) => void;
const SAY_HUMAN: Say = (s) => { process.stdout.write(s); };
const SAY_QUIET: Say = () => { /* --json: stdout belongs to the report */ };
function makeSay(json: boolean): Say {
  return json ? SAY_QUIET : SAY_HUMAN;
}

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
  const advisoryOutcome = maybeEmitUpgradeAdvisory(targetDir, args.yes, args.json);
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

  const say = makeSay(args.json);

  if (args.dryRun) {
    runDryRun(plans, say);
    const outcome = dispatchSubstrateCopy(
      targetDir, args.force || upgradeApproved, args.verbose, true, args.allowRoot, say
    );
    if (args.json) {
      // A dry run writes no manifest (RFC-0004 M-3) but still reports
      // what it would have written, so a script can preview the shape.
      const report = buildInitReport({
        entries: outcome.result?.wouldCopyEntries ?? [],
        configs: plans.map((pl) => ({ path: pl.relativePath })),
        refused: outcome.result?.refused ?? [],
        // A dry run still reads every source file, so it can still fail
        // to read one. Hard-coding this empty hid those failures from
        // the JSON (RFC-0005 A-3).
        errored: outcome.result?.errored ?? [],
        hookCount: outcome.result?.hookCount ?? 0,
        declaredHooksCopied: 0,
        tier: RESOLVED_TIER,
      });
      renderJsonReport(report, (t) => { process.stdout.write(t); });
    }
    return outcome.code;
  }

  // runReal writes the cli-composed plans (substrate.config.md) then
  // dispatches the walker for dist/lite/. Manifest is written last with
  // the union of both results so `bassclef sync` sees every managed file.
  return runReal(plans, args.force || upgradeApproved, args.verbose, targetDir, args.allowRoot, args.json, say);
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
function maybeEmitUpgradeAdvisory(targetDir: string, yes: boolean, json: boolean): 'ok' | 'refused' | 'upgrade-approved' {
  // Under --json stdout carries the report alone, so the prompt moves to
  // stderr rather than being suppressed. A prompt nobody sees would hang.
  const prompt: Say = json ? (t) => { process.stderr.write(t); } : SAY_HUMAN;
  const manifestPath = join(targetDir, MANIFEST_RELATIVE_PATH);
  if (!existsSync(manifestPath)) return 'ok';
  // Manifest read goes through the typed wrapper in src/lib/manifest-io.ts
  // per R4 discipline. Wrapper returns null when the manifest is absent,
  // unreadable, OR missing the schema_version field (1.0.0 shape).
  const version = readManifestShapeVersion(targetDir);
  // Manifest already at v2 (or later) — no upgrade to announce.
  if (version !== null && version >= 2) return 'ok';
  prompt(
    'bassclef init: cli 1.0.1 introduces user-scope hook installation at ' +
      `~/${HOOKS_SUBPATH}. cli 1.0.0 did not write there.\n`
  );
  if (yes) return 'upgrade-approved';
  prompt('bassclef init: continue? (y/N) ');
  const answer = readOneLineFromStdin();
  if (answer === '' || answer === 'y' || answer === 'Y') return 'upgrade-approved';
  prompt('bassclef init: aborted by adopter.\n');
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
interface DispatchOutcome {
  code: number;
  /** Present when the walker ran. Absent when it failed before copying. */
  result?: CopyResult;
}

function dispatchSubstrateCopy(
  targetDir: string,
  force: boolean,
  verbose: boolean,
  dryRun: boolean,
  allowRoot: boolean,
  say: Say
): DispatchOutcome {
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
      if (e.kind === 'ManifestMissing') return { code: 4 };
      if (e.kind === 'SchemaIncompatible') return { code: 5 };
      // BundleMissing falls through — reinstall message already in the
      // exception; treat as exit 2 (write-time class per ADR-002).
      return { code: 2 };
    }
    throw e;
  }

  // Dry-run branch — print "would create" per walker entry so the
  // preview matches the real footprint. Per bassclef-cli#60.
  if (dryRun) {
    const wouldCopy = result.wouldCopy ?? [];
    for (const relativePath of wouldCopy) {
      const targetPath = join(targetDir, relativePath);
      say(`  ${'would create'.padEnd(14)} ${targetPath}\n`);
    }
    if (wouldCopy.length > 0) {
      say(
        `bassclef init: ${wouldCopy.length} substrate files would be copied.\n`
      );
    }
    // Banner in dry-run too — reader sees the shape before committing.
    say(
      `bassclef init: ${result.hookCount} hooks armed (${RESOLVED_TIER} tier).\n`
    );
    return { code: 0, result };
  }

  if (result.copied.length === 0 && result.refused.length === 0 && result.errored.length === 0) {
    return { code: 0, result };
  }
  // Group copied files by top-level directory for the summary line.
  const groupCounts = new Map<string, number>();
  for (const path of result.copied) {
    const parts = path.split('/');
    const top = parts.length >= 2 ? parts.slice(0, 2).join('/') : parts[0] ?? '';
    groupCounts.set(top, (groupCounts.get(top) ?? 0) + 1);
  }
  for (const [directory, count] of groupCounts) {
    say(`  ${directory}: ${count} files copied\n`);
  }
  const parts: string[] = [];
  if (result.copied.length > 0) parts.push(`${result.copied.length} substrate files copied`);
  if (result.refused.length > 0) parts.push(`${result.refused.length} refused`);
  if (result.errored.length > 0) parts.push(`${result.errored.length} error(s)`);
  say(`bassclef init: ${parts.join(', ')}.\n`);
  // Per bassclef-cli#60: print the grand total so the reader sees one
  // number that matches the on-disk footprint (1 config file — substrate.config.md
  // — plus the walker output).
  const grandTotal = 1 + result.copied.length;
  say(
    `bassclef init: ${grandTotal} files total (1 config + ${result.copied.length} substrate).\n`
  );
  // Norman N1 fold — banner names installed HOOK count + per-scope breakdown.
  // The declared count comes from settings.json (result.hookCount).
  // Cli 1.0.3 (bassclef-cli#87) — the tarball now ships helpers + fragments
  // alongside declared commands (recursive tree copy at prepublish). The
  // banner still reports "N of M" for DECLARED COMMANDS ONLY so the number
  // matches settings.json. Helpers land silently — not counted in N.
  const declaredCommandLeaves = readDeclaredCommandLeaves(
    join(targetDir, '.claude', 'settings.json')
  );
  const copiedHookEntries = result.copiedEntries.filter(
    (e) =>
      e.path.startsWith(HOOKS_SUBPATH) &&
      e.path.endsWith('.sh') &&
      declaredCommandLeaves.has(basename(e.path))
  );
  const copiedCount = copiedHookEntries.length;
  const declaredCount = result.hookCount;
  // Per bassclef-cli#120: "failed" means write errored, not refused.
  // Refused means the adopter file was preserved (expected + safe); errored
  // means a write actually failed. Conflating them told fresh-install readers
  // "44 failed" when nothing failed. Only errored counts qualify the hook line.
  const erroredCount = result.errored.length;
  const userScope = copiedHookEntries.filter((e) => e.scope === 'user').length;
  const projectScope = copiedHookEntries.filter((e) => e.scope === 'project').length;
  const scopeSuffix = userScope + projectScope > 0
    ? ` ${projectScope} in <repo>/${HOOKS_SUBPATH.replace(/\/$/, '')}, ${userScope} in ~/${HOOKS_SUBPATH.replace(/\/$/, '')}.`
    : '';
  if (erroredCount > 0) {
    say(
      `bassclef init: Installed ${copiedCount} of ${declaredCount} hooks (${RESOLVED_TIER} tier).${scopeSuffix} ` +
        `${erroredCount} failed — see errors above. Rerun bassclef init to retry.\n`
    );
  } else {
    say(
      `bassclef init: Installed ${copiedCount} of ${declaredCount} hooks (${RESOLVED_TIER} tier).${scopeSuffix}\n`
    );
  }

  // Cli 1.1.0 (goal 2026-09-16 cli#90) — per-type count banner for the
  // lite catalog. Skills, rules, agents, luminaries land at project
  // scope per ADR-057. Banner reports each family so adopters see what
  // the tarball delivered. Norman signifier: name the type + location.
  //
  // Path-prefix classification (matches ADR-057 D1 exactly). Init walker
  // routes by prefix, not manifest type — no manifest read at init time.
  // @risk L2 (Toulmin — hidden signal): counts up front so adopters
  // reading changelog fast see the file-count delta.
  const catalogCounts = {
    skills: 0,
    rules: 0,
    agents: 0,
    luminaries: 0,
    libs: 0,
    adrs: 0,
    standards: 0,
    templates: 0,
    'presence-templates': 0,
    scripts: 0,
    'root-docs': 0,
  };
  // Prefixes built from CLAUDE_TARGET_ROOT constant so R6 single-source-of-truth
  // check (grep for literal .claude/(hooks|skills|rules) outside paths.ts) stays green.
  const SKILLS_PREFIX = `${CLAUDE_TARGET_ROOT}/skills/`;
  const RULES_PREFIX = `${CLAUDE_TARGET_ROOT}/rules/`;
  const AGENTS_PREFIX = `${CLAUDE_TARGET_ROOT}/agents/`;
  const LUMINARIES_PREFIX = `${CLAUDE_TARGET_ROOT}/luminaries/`;
  const CLAUDE_ROOT_PREFIX = `${CLAUDE_TARGET_ROOT}/`;
  for (const entry of result.copiedEntries) {
    if (entry.path.startsWith(SKILLS_PREFIX)) catalogCounts.skills += 1;
    else if (entry.path.startsWith(RULES_PREFIX)) catalogCounts.rules += 1;
    else if (entry.path.startsWith(AGENTS_PREFIX)) catalogCounts.agents += 1;
    else if (entry.path.startsWith(LUMINARIES_PREFIX)) catalogCounts.luminaries += 1;
    else if (entry.path.startsWith('lib/')) catalogCounts.libs += 1;
    else if (entry.path.startsWith('architecture/decisions/')) catalogCounts.adrs += 1;
    else if (entry.path.startsWith('standards/')) catalogCounts.standards += 1;
    else if (entry.path.startsWith('templates/')) catalogCounts.templates += 1;
    else if (entry.path.startsWith('presence/install/')) catalogCounts['presence-templates'] += 1;
    else if (entry.path.startsWith('scripts/')) catalogCounts.scripts += 1;
    else if (
      !entry.path.startsWith(CLAUDE_ROOT_PREFIX) &&
      !entry.path.includes('/') &&
      /^[A-Z]/.test(entry.path)
    ) {
      // Root-doc heuristic — repo-root file starting with uppercase letter
      // (README.md, AGENTS.md, CLAUDE-lite.md, CONTRIBUTING.md, etc.)
      catalogCounts['root-docs'] += 1;
    }
  }
  const claudeCounts = [
    catalogCounts.skills > 0 ? `${catalogCounts.skills} skills` : null,
    catalogCounts.rules > 0 ? `${catalogCounts.rules} rules` : null,
    catalogCounts.agents > 0 ? `${catalogCounts.agents} agents` : null,
    catalogCounts.luminaries > 0 ? `${catalogCounts.luminaries} luminaries` : null,
  ].filter((s): s is string => s !== null);
  if (claudeCounts.length > 0) {
    say(
      `bassclef init: Installed ${claudeCounts.join(', ')} under <repo>/.claude/.\n`
    );
  }
  const otherCounts = [
    catalogCounts.libs > 0 ? `${catalogCounts.libs} libs` : null,
    catalogCounts.adrs > 0 ? `${catalogCounts.adrs} ADRs` : null,
    catalogCounts.templates > 0 ? `${catalogCounts.templates} templates` : null,
    catalogCounts['presence-templates'] > 0
      ? `${catalogCounts['presence-templates']} presence-templates`
      : null,
    catalogCounts.standards > 0 ? `${catalogCounts.standards} standards` : null,
    catalogCounts['root-docs'] > 0 ? `${catalogCounts['root-docs']} root-docs` : null,
    catalogCounts.scripts > 0 ? `${catalogCounts.scripts} scripts` : null,
  ].filter((s): s is string => s !== null);
  if (otherCounts.length > 0) {
    say(
      `bassclef init: Installed ${otherCounts.join(', ')} under <repo>/.\n`
    );
  }
  // Per bassclef-cli#120: Norman feedback discipline — surface a line only
  // when it names something the reader can act on. "0 files refused" tells a
  // fresh adopter nothing they need. Only emit when refused > 0.
  if (result.refused.length > 0) {
    say(
      `bassclef init: ${result.refused.length} files refused (path collision).` +
        ` Use --force to overwrite existing files.\n`
    );
  }
  // The JSON report used to be written here, to stderr, with human lines
  // following it on stdout. It now goes to stdout as the last thing the
  // run writes. See runReal + runInit. Per ADR-010 D6 (#94).
  if (verbose && result.erroredMessages) {
    for (const msg of result.erroredMessages) {
      process.stderr.write(`  substrate: ${msg}\n`);
    }
  }
  // N5 fold — banner reads "N of M" on mismatch (informational). Exit
  // code follows the existing refused/errored discipline so partial-
  // copy scenarios where settings.json refused (adopter's existing
  // file preserved) still exit 0 when no hook copy actually errored.
  return { code: result.errored.length > 0 ? 2 : 0, result };
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

function runDryRun(plans: readonly FilePlan[], say: Say): number {
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
    say(`  ${planned.padEnd(14)} ${p.fullPath}${extra}\n`);
  }
  return 0;
}

function runReal(plans: readonly FilePlan[], force: boolean, verbose: boolean, targetDir: string, allowRoot: boolean, json: boolean, say: Say): number {
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
      say(`  ${label.padEnd(10)} ${r.plan.fullPath}\n`);
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
    say(
      `bassclef init: ${created} config files created, ${unchanged} unchanged. Pass --force to overwrite.\n`
    );
  } else if (created === 0 && unchanged === plans.length) {
    say('bassclef init: already initialized. No changes.\n');
  } else {
    say(`bassclef init: ${created} config files created, ${unchanged} unchanged.\n`);
  }

  // Walker fires now — per ADR-055 D1-D5. Fails loudly with structured
  // errors + specific exit codes when the bundle is broken. Walker-owned
  // files stay OUT of the init manifest — sync manages cli-composed
  // templates (currently substrate.config.md); walker files refresh via
  // `bassclef init --force`.
  const walker = dispatchSubstrateCopy(targetDir, force, verbose, false, allowRoot, say);

  // One description of the run, read by the manifest and by the JSON
  // report. Before cli 1.1.1 each counted separately and disagreed.
  // Count declared hook commands the same way the banner does, so the
  // report's hooks.declared and hooks.copied share one unit (RFC-0005 A-2).
  const declaredLeaves = readDeclaredCommandLeaves(
    join(targetDir, '.claude', 'settings.json')
  );
  const declaredHooksCopied = (walker.result?.copiedEntries ?? []).filter(
    (e) =>
      e.path.startsWith(HOOKS_SUBPATH) &&
      e.path.endsWith('.sh') &&
      declaredLeaves.has(basename(e.path))
  ).length;

  const report = buildInitReport({
    entries: walker.result?.copiedEntries ?? [],
    configs: results.map((r) => ({ path: r.plan.relativePath })),
    refused: walker.result?.refused ?? [],
    errored: walker.result?.errored ?? [],
    hookCount: walker.result?.hookCount ?? 0,
    declaredHooksCopied,
    tier: RESOLVED_TIER,
  });

  // The manifest now names every file the run touched, not just the
  // config files. Per ADR-010 D1; this is what ADR-002 §Amendment
  // 2026-09-13 already committed to and the Phase 3 code did not do.
  writeManifest(targetDir, results, walker.result);

  // RFC N4 — folder guidance line after walker (only on success).
  if (walker.code === 0) {
    say(
      `bassclef init: your substrate lives under .claude/. ` +
        `Add .claude/ to .gitignore if you have not.\n`
    );
  }

  // Last thing written, and under --json the only thing on stdout.
  if (json) {
    renderJsonReport(report, (t) => { process.stdout.write(t); });
  }

  return walker.code;
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

/**
 * Record what the run wrote.
 *
 * Postcondition per ADR-010 D1 + D4: the manifest names every file the
 * run touched — the files cli composed, the files the walker copied, and
 * the files it refused or errored on. Entries are keyed by path AND
 * scope, because the walker writes undeclared hook helpers to both
 * scopes and two entries therefore share one path (RFC-0004 S-1).
 */
function writeManifest(
  targetDir: string,
  results: readonly FileResult[],
  walkerResult?: CopyResult
): void {
  const entries: ManifestEntry[] = results.map((r) => {
    const entry: ManifestEntry = {
      path: r.plan.relativePath,
      template: r.plan.templateName,
      template_version: r.plan.templateVersion,
      outcome: r.outcome,
      source: 'config-composer',
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

  if (walkerResult) {
    // Bundle entries carry a template name that is absent from the sync
    // TEMPLATES table on purpose. sync.ts classify() returns a no-op for
    // an unknown template, so recording these files changes no sync
    // action. `bassclef init --force` remains their refresh path.
    for (const copied of walkerResult.copiedEntries) {
      entries.push({
        path: copied.path,
        template: `bundle:${copied.path}`,
        template_version: pkgVersion,
        outcome: 'created',
        source: 'bundle',
        scope: copied.scope,
        ...(copied.content_hash_sha256
          ? { content_hash_sha256: copied.content_hash_sha256 }
          : {}),
        updated_at: new Date().toISOString(),
      });
    }
    // A partial init has to look partial. Recording only the successes
    // would make a half-finished run read as complete (ADR-010 D4).
    for (const path of walkerResult.refused) {
      entries.push({
        path,
        template: `bundle:${path}`,
        template_version: pkgVersion,
        outcome: 'refused',
        source: 'bundle',
      });
    }
    for (const path of walkerResult.errored) {
      entries.push({
        path,
        template: `bundle:${path}`,
        template_version: pkgVersion,
        outcome: 'error',
        source: 'bundle',
      });
    }
  }

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
  } catch (e) {
    // Init still exits 0: the files did land, and failing here would be
    // a lie in the other direction. What changes at cli 1.1.1 is the
    // silence. Sync reads this file to know what exists, so an init that
    // writes 379 files, fails to record them, and prints success leaves
    // the adopter with no way to notice. Per ADR-010 D10 (RFC-0004 N-1).
    const reason = e instanceof Error ? e.message : String(e);
    process.stderr.write(
      `bassclef init: could not write ${manifestPath} (${reason}). ` +
        `The files were written. Run \`bassclef init --force\` to rebuild the record.\n`
    );
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

/**
 * Read the settings.json on disk and return the Set of hook leaf names
 * declared as commands (`.sh` files at the end of `$HOME/…` or
 * `$CLAUDE_PROJECT_DIR/…` paths). Powers the cli 1.0.3 banner filter
 * that separates declared commands from helpers.
 *
 * Returns empty Set on any parse failure — banner degrades to 0-count
 * gracefully rather than crashing.
 */
function readDeclaredCommandLeaves(settingsPath: string): Set<string> {
  try {
    const parsed = JSON.parse(readFileSync(settingsPath, 'utf8')) as {
      hooks?: Record<string, Array<{ hooks?: Array<{ command?: string }> }>>;
    };
    const leaves = new Set<string>();
    for (const matcherBlocks of Object.values(parsed.hooks ?? {})) {
      for (const block of matcherBlocks) {
        for (const entry of block.hooks ?? []) {
          const cmd = entry.command;
          if (typeof cmd !== 'string' || cmd.length === 0) continue;
          if (!cmd.startsWith('$')) continue;
          const leaf = cmd.slice(cmd.lastIndexOf('/') + 1);
          if (leaf.endsWith('.sh')) leaves.add(leaf);
        }
      }
    }
    return leaves;
  } catch {
    return new Set();
  }
}
