// The single audited write function per ADR-002 complete-mediation.
//
// Every file write in the init chain flows through here. There is no
// other place that touches fs.write*.
//
// Safety primitives:
//   O_CREAT | O_EXCL   — atomic existence check (EEXIST if file exists)
//   O_NOFOLLOW         — refuses to follow a symlink at the final path
//   0o644              — world-readable, owner-writable, standard config
//
// Symlink refusal is UNCONDITIONAL. --force does not override. This
// closes the TOCTOU class of attack where an attacker plants a symlink
// between check-time and write-time.

import {
  openSync,
  writeSync,
  closeSync,
  unlinkSync,
  accessSync,
  lstatSync,
  mkdirSync,
  constants,
} from 'node:fs';
import { dirname } from 'node:path';

export class WriteError extends Error {
  override readonly name = 'WriteError';
  readonly kind:
    | 'AlreadyExists'
    | 'SymlinkRefused'
    | 'ParentMissing'
    | 'ParentNotWritable'
    | 'Unknown';

  constructor(kind: WriteError['kind'], message: string) {
    super(message);
    this.kind = kind;
  }
}

export interface WriteOptions {
  force?: boolean;
}

const FLAGS_CREATE = constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW | constants.O_WRONLY;

export function writeSafely(path: string, content: string, opts: WriteOptions = {}): void {
  const parent = dirname(path);

  // Pre-flight: parent must exist AND be writable. Errors defined out
  // by early exit — no half-written state possible.
  try {
    accessSync(parent, constants.F_OK);
  } catch {
    throw new WriteError('ParentMissing', `parent directory does not exist: ${parent}`);
  }
  try {
    accessSync(parent, constants.W_OK);
  } catch {
    throw new WriteError('ParentNotWritable', `parent directory is not writable: ${parent}`);
  }

  // Pre-check: is there anything at the final path? Use lstat so we
  // see a symlink itself, not what it points at. A subsequent racing
  // swap between this check and the atomic open is still caught by
  // O_NOFOLLOW at the syscall level — this pre-check exists to give
  // a specific error message per case, not for safety.
  let existing: 'symlink' | 'regular' | 'other' | 'none';
  try {
    const st = lstatSync(path);
    if (st.isSymbolicLink()) existing = 'symlink';
    else if (st.isFile()) existing = 'regular';
    else existing = 'other';
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === 'ENOENT') existing = 'none';
    else throw new WriteError('Unknown', `cannot stat ${path}: ${err.code ?? 'unknown'}`);
  }

  // Symlink refusal is unconditional per ADR-002. --force cannot override.
  if (existing === 'symlink') {
    throw new WriteError('SymlinkRefused', `refusing to follow symlink at target path: ${path}`);
  }

  if (existing !== 'none' && !opts.force) {
    throw new WriteError('AlreadyExists', `file already exists (pass --force to overwrite): ${path}`);
  }

  if (existing !== 'none' && opts.force) {
    // Regular file (or other non-symlink shape) with --force: remove and recreate.
    try {
      unlinkSync(path);
    } catch (e) {
      const err = e as NodeJS.ErrnoException;
      if (err.code !== 'ENOENT') {
        throw new WriteError('Unknown', `cannot remove existing entry at ${path}: ${err.code ?? 'unknown'}`);
      }
    }
  }

  let fd: number;
  try {
    fd = openSync(path, FLAGS_CREATE, 0o644);
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === 'EEXIST') {
      // Race: something appeared between our lstat and open. Refuse.
      throw new WriteError('AlreadyExists', `file appeared during write (race): ${path}`);
    }
    if (err.code === 'ELOOP' || err.code === 'EMLINK' || err.code === 'ENOTSUP') {
      // Race: a symlink appeared. O_NOFOLLOW blocked it. Refuse.
      throw new WriteError('SymlinkRefused', `refusing to follow symlink at target path: ${path}`);
    }
    throw new WriteError('Unknown', `cannot open ${path}: ${err.code ?? 'unknown'}`);
  }

  try {
    writeSync(fd, content);
  } finally {
    closeSync(fd);
  }
}

// Create a directory tree safely. Same auditing surface as writeSafely
// so ADR-002's complete-mediation claim holds — every filesystem
// mutation in the init chain flows through this module.
//
// `recursive: true` is used because init writes under `.claude/` which
// may not exist. Intermediate directories inherit mode 0o755. If the
// leaf already exists as a symlink, we refuse (matches writeSafely's
// symlink discipline).

export function mkdirSafely(path: string): void {
  // Check terminal component for a symlink before creating.
  try {
    const st = lstatSync(path);
    if (st.isSymbolicLink()) {
      throw new WriteError('SymlinkRefused', `refusing to create over symlink: ${path}`);
    }
    if (st.isDirectory()) {
      // Already a real directory — no-op.
      return;
    }
    // Something else exists at that path — refuse.
    throw new WriteError('AlreadyExists', `cannot create directory: non-directory entry exists at ${path}`);
  } catch (e) {
    if (e instanceof WriteError) throw e;
    const err = e as NodeJS.ErrnoException;
    if (err.code !== 'ENOENT') {
      throw new WriteError('Unknown', `cannot stat ${path}: ${err.code ?? 'unknown'}`);
    }
    // ENOENT — proceed to mkdir.
  }

  try {
    mkdirSync(path, { recursive: true, mode: 0o755 });
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === 'EACCES' || err.code === 'EPERM') {
      throw new WriteError('ParentNotWritable', `cannot create directory (permission): ${path}`);
    }
    throw new WriteError('Unknown', `cannot create directory: ${path} (${err.code ?? 'unknown'})`);
  }
}
