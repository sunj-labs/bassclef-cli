// Small argv reducer for `bassclef migrate` flags.
//
// Hand-rolled per ADR-001 economy-of-mechanism — five booleans + one
// string flag do not warrant a library dependency. Sister to
// init-argv.ts and sync-argv.ts.
//
// Unknown flags and stray positional arguments throw ArgvError. The
// caller reports the specific message on stderr and exits with
// code 1 per ADR-008 D4 failure catalog.
//
// @risk: R1 — Ousterhout: typed return + errors thrown by offending
// token name close the wrong-intent-dispatch failure class.

export interface MigrateArgs {
  dryRun: boolean;
  verbose: boolean;
  yes: boolean;
  allowRoot: boolean;
  allowAnyDir: boolean;
  dir: string | undefined;
}

const DEFAULTS: MigrateArgs = {
  dryRun: false,
  verbose: false,
  yes: false,
  allowRoot: false,
  allowAnyDir: false,
  dir: undefined,
};

export class ArgvError extends Error {
  override readonly name = 'ArgvError';
}

export function parseMigrateArgs(argv: readonly string[]): MigrateArgs {
  const out: MigrateArgs = { ...DEFAULTS };
  let i = 0;
  while (i < argv.length) {
    const token = argv[i]!;
    if (token === '--dry-run') {
      out.dryRun = true;
      i += 1;
      continue;
    }
    if (token === '--verbose') {
      out.verbose = true;
      i += 1;
      continue;
    }
    if (token === '--yes') {
      out.yes = true;
      i += 1;
      continue;
    }
    if (token === '--allow-root') {
      out.allowRoot = true;
      i += 1;
      continue;
    }
    if (token === '--allow-any-dir') {
      out.allowAnyDir = true;
      i += 1;
      continue;
    }
    // --dir has two accepted shapes: `--dir <value>` and `--dir=<value>`.
    if (token === '--dir') {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) {
        throw new ArgvError('--dir requires a value');
      }
      out.dir = value;
      i += 2;
      continue;
    }
    if (token.startsWith('--dir=')) {
      out.dir = token.slice('--dir='.length);
      i += 1;
      continue;
    }
    if (token.startsWith('--')) {
      throw new ArgvError(`unknown flag: ${token}`);
    }
    throw new ArgvError(`unexpected argument: ${token}`);
  }
  return out;
}
