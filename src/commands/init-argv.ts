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
  /**
   * Skip the 1.0.0 → 1.0.1 upgrade advisory prompt. Non-interactive
   * shells + CI runners set this. Added cli 1.0.1 per RFC-0002 L1 fold.
   */
  yes: boolean;
  /**
   * Emit a machine-readable JSON summary line on stderr alongside the
   * human banner. Adopter tooling parses this stable shape instead of
   * screen-scraping the prose. Added cli 1.0.1 per RFC-0002 H1 fold.
   */
  json: boolean;
  /**
   * Skip the statusline install step (both the ~/.claude/ dispatcher
   * copy and the .claude/settings.json statusLine write). Added cli
   * 1.2.3 per bassclef-upstream#1860 pair.
   */
  skipStatusline: boolean;
}

const DEFAULTS: InitArgs = {
  force: false,
  dryRun: false,
  verbose: false,
  allowRoot: false,
  allowAnyDir: false,
  dir: undefined,
  yes: false,
  json: false,
  skipStatusline: false,
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
    if (token === '--yes') {
      out.yes = true;
      i += 1;
      continue;
    }
    if (token === '--json') {
      out.json = true;
      i += 1;
      continue;
    }
    if (token === '--skip-statusline') {
      out.skipStatusline = true;
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
