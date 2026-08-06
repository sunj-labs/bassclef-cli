// Resolve --dir (or cwd) to an absolute, canonical, safety-checked path.
//
// Two independent scope checks per ADR-002:
//   1. resolved path must be under $HOME (unless allowAnyDir=true)
//   2. resolved path must be owned by the current uid (unless allowAnyDir=true)
//
// Canonicalization via realpathSync catches symlink traversals and
// $HOME-relative escapes ($HOME/../../etc).

import { realpathSync, statSync } from 'node:fs';
import { isAbsolute, resolve as pathResolve } from 'node:path';
import { homedir } from 'node:os';

export class ResolveError extends Error {
  override readonly name = 'ResolveError';
}

export interface ResolveInput {
  cwd: string;
  cliArg: string | undefined;
  allowAnyDir: boolean;
}

export function resolveTargetDir(input: ResolveInput): string {
  const raw = input.cliArg ?? input.cwd;
  const beforeReal = isAbsolute(raw) ? raw : pathResolve(input.cwd, raw);

  let canonical: string;
  try {
    canonical = realpathSync(beforeReal);
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === 'ENOENT') {
      throw new ResolveError(`target directory does not exist: ${beforeReal}`);
    }
    throw new ResolveError(`cannot resolve target directory: ${beforeReal} (${err.code ?? 'unknown'})`);
  }

  if (!input.allowAnyDir) {
    const home = homedir();
    if (!isUnder(canonical, home)) {
      throw new ResolveError(
        `target directory is not under your home directory (${home}). ` +
          `Pass --allow-any-dir if this is intentional.`
      );
    }
    // Ownership check — process.getuid may be undefined on Windows.
    if (typeof process.getuid === 'function') {
      const uid = process.getuid();
      let stat;
      try {
        stat = statSync(canonical);
      } catch (e) {
        const err = e as NodeJS.ErrnoException;
        throw new ResolveError(`cannot stat target directory (${err.code ?? 'unknown'}): ${canonical}`);
      }
      if (stat.uid !== uid) {
        throw new ResolveError(
          `target directory is not owned by the current user. ` +
            `Pass --allow-any-dir if this is intentional.`
        );
      }
    }
  }

  return canonical;
}

function isUnder(child: string, parent: string): boolean {
  const rel = pathResolve(child);
  const par = pathResolve(parent);
  if (rel === par) return true;
  return rel.startsWith(par + '/');
}
