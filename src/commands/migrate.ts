// bassclef migrate command — Phase 1 shell (Step 5).
//
// Step 5 ships the argv-parse-and-dispatch shell. Full detection +
// Path A + Path B orchestration lands at Step 6 per ADR-008.
//
// Contract this stub honors today:
// - parseMigrateArgs errors → exit 1 with stderr message (R1)
// - --help prints usage; exits 0
// - unknown state (currently: every non-error path) → exit 99 with
//   "not yet implemented" message; Step 6 replaces this with the
//   D1 four-value detection branch
//
// @risk: R1 — argv parse errors surface with the offending token
// named on stderr; caller sees exit 1 with actionable message.

import { parseMigrateArgs, ArgvError } from './migrate-argv.js';

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

export function runMigrate(argv: readonly string[]): number {
  // Step 5 (this file today): argv parse only. Step 6 fills the body.
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

  // Silence unused-var TypeScript lint while the body is a stub.
  // Step 6 replaces this block with the D1 detection branch +
  // Path A / Path B dispatch.
  void args;

  process.stderr.write(
    `bassclef migrate: not yet implemented — Step 6 of goal ` +
      `2026-08-30a-npm-lite-migrate-subcommand ships the body\n`
  );
  return 99;
}
