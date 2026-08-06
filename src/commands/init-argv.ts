// Small argv reducer for `bassclef init` flags.
//
// Hand-rolled per ADR-001 economy-of-mechanism — five booleans + one
// string flag do not warrant a library dependency. If the flag set
// grows past ~10, revisit with `commander` or `citty`.
//
// Unknown flags and stray positional arguments throw. The caller
// reports the specific message on stderr and exits with code 3.

export interface InitArgs {
  force: boolean;
  dryRun: boolean;
  verbose: boolean;
  allowRoot: boolean;
  allowAnyDir: boolean;
  dir: string | undefined;
}

const DEFAULTS: InitArgs = {
  force: false,
  dryRun: false,
  verbose: false,
  allowRoot: false,
  allowAnyDir: false,
  dir: undefined,
};

export class ArgvError extends Error {
  override readonly name = 'ArgvError';
}

export function parseInitArgs(argv: readonly string[]): InitArgs {
  const out: InitArgs = { ...DEFAULTS };
  let i = 0;
  while (i < argv.length) {
    const token = argv[i]!;
    if (token === '--force') {
      out.force = true;
      i += 1;
      continue;
    }
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
