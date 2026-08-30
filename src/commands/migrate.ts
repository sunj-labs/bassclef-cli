// bassclef migrate command — Phase 2 body per ADR-008 (Step 6).
//
// Parses argv, runs root check, detects adopter state via
// detectAdopterState, dispatches Path A or Path B, surfaces exit code.
//
// @risk R1 — argv parse errors surface with the offending token named
// on stderr; caller sees exit 1 with actionable message.
// @risk R4 — unknown adopter state → exit 5 with Nygard cure message.

import { parseMigrateArgs, ArgvError } from './migrate-argv.js';
import { detectAdopterState, runPathA, runPathB } from '../lib/migrate.js';
import { readManifest } from '../lib/manifest-io.js';
import { shouldRefuseRoot } from './init.js';

export function usage(): string {
  return `bassclef migrate — upgrade adopter substrate to the current shape

Usage:
  bassclef migrate [options]

Options:
  --dry-run          Preview the shape without writing anything
  --verbose          Print one line per file (not just the summary)
  --yes              Skip the interactive confirmation prompt (CI + scripts)
  --allow-root       Allow running as root
  --allow-any-dir    Allow a target outside the current user's home
  --dir <path>       Target directory (defaults to current working dir)
  --help             Print this message

Two upgrade paths run automatically based on adopter state:
  0.0.2 legacy install → Path A: adds 146 substrate files; preserves
                         the 3 edited config files via SHA-256 hash
  0.0.1 name-reservation → Path B: full init for all 149 files

Exit codes:
  0  success (files landed, or already at current shape, or user aborted)
  1  argv error, root check failed, or manifest could not be read
  2  one or more per-file writes refused (symlink, parent not writable)
  4  manifest schema version newer than this migrate knows about
  5  adopter state does not match 0.0.x or 0.1.0 — reinstall @thebassclef/core
`;
}

export async function runMigrate(argv: readonly string[]): Promise<number> {
  let args;
  try {
    args = parseMigrateArgs(argv);
  } catch (e) {
    if (e instanceof ArgvError) {
      process.stderr.write(`bassclef migrate: ${e.message}\n`);
      return 1;
    }
    throw e;
  }

  // Root check — same discipline as init/sync per ADR-002.
  const uid = typeof process.getuid === 'function' ? process.getuid() : undefined;
  if (shouldRefuseRoot(uid, args.allowRoot)) {
    process.stderr.write(
      `bassclef migrate: refusing to run as root. Pass --allow-root to override, ` +
        `or run as the project owner.\n`
    );
    return 1;
  }

  const targetDir = args.dir ?? process.cwd();
  const state = await detectAdopterState(targetDir);

  // Current shape — nothing to migrate.
  if (state === 'current') {
    process.stdout.write('bassclef migrate: already at 0.1.0 shape. Nothing to migrate.\n');
    return 0;
  }

  // No manifest — Path B full init dispatch.
  if (state === 'no-manifest') {
    const result = await runPathB(targetDir, args);
    return result.exitCode;
  }

  // Legacy 3-entry — Path A migration.
  if (state === 'legacy-3-entry') {
    const manifest = readManifest(targetDir);
    const result = await runPathA(targetDir, manifest, args);
    return result.exitCode;
  }

  // Object shape — unknown or error kind.
  if (state.kind === 'unknown') {
    process.stderr.write(
      `bassclef migrate: adopter state does not match 0.0.x or 0.1.0. ` +
        `Reinstall @thebassclef/core then rerun. (${state.message})\n`
    );
    return 5;
  }

  if (state.kind === 'error') {
    process.stderr.write(`bassclef migrate: ${state.message}\n`);
    // Distinguish SchemaTooNew (exit 4) from Malformed (exit 1) via
    // message content since ManifestReadError has already been mapped
    // into a plain message here.
    if (state.message.includes('newer than this package')) return 4;
    return 1;
  }

  // Exhaustiveness — should never reach here.
  return 1;
}
