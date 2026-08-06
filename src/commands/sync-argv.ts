// Small argv reducer for `bassclef sync` flags.
//
// Same hand-rolled shape as init-argv per ADR-001 economy-of-mechanism.

export interface SyncArgs {
  force: boolean;
  replaceEdits: boolean;
  dryRun: boolean;
  diff: boolean;
  verbose: boolean;
  allowRoot: boolean;
  allowAnyDir: boolean;
  dir: string | undefined;
}

const DEFAULTS: SyncArgs = {
  force: false,
  replaceEdits: false,
  dryRun: false,
  diff: false,
  verbose: false,
  allowRoot: false,
  allowAnyDir: false,
  dir: undefined,
};

export class SyncArgvError extends Error {
  override readonly name = 'SyncArgvError';
}

export function parseSyncArgs(argv: readonly string[]): SyncArgs {
  const out: SyncArgs = { ...DEFAULTS };
  let i = 0;
  while (i < argv.length) {
    const token = argv[i]!;
    if (token === '--force') { out.force = true; i += 1; continue; }
    if (token === '--replace-edits') { out.replaceEdits = true; i += 1; continue; }
    if (token === '--dry-run') { out.dryRun = true; i += 1; continue; }
    if (token === '--diff') { out.diff = true; i += 1; continue; }
    if (token === '--verbose') { out.verbose = true; i += 1; continue; }
    if (token === '--allow-root') { out.allowRoot = true; i += 1; continue; }
    if (token === '--allow-any-dir') { out.allowAnyDir = true; i += 1; continue; }
    if (token === '--dir') {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) {
        throw new SyncArgvError('--dir requires a value');
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
      throw new SyncArgvError(`unknown flag: ${token}`);
    }
    throw new SyncArgvError(`unexpected argument: ${token}`);
  }
  return out;
}
