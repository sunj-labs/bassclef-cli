// Executable-bit enforcer for copied hook binaries.
//
// After the walker copies a .sh file to its scope target, this module
// sets mode 0755 (owner rwx, group rx, other rx). Every copied hook
// must be executable so Claude Code can invoke it at session-start.
//
// Cross-platform: on win32, POSIX file modes are ignored by the OS,
// so this module no-ops with an INFO stderr note. Existing Node.js
// on Windows returns a mode that does not carry Unix semantics; the
// hook still runs via /bin/sh if a POSIX layer is present, or via
// PowerShell wrapper in cygwin/msys.
//
// @verifies S3-fold (Saltzer-Schroeder — executable bit missing after copy)
// @verifies N3-fold (Nygard — chmod fails on non-POSIX; INFO stderr note)
// @verifies P1-fold (Hunt & Thomas — reads HOOK_EXECUTABLE_MODE constant)
// @verifies UC-init-walker-hook-routing Ext 6d

import { chmodSync } from 'node:fs';
import { HOOK_EXECUTABLE_MODE } from './hook-constants.js';

/**
 * Set the executable bit on a copied hook file.
 *
 * @param targetPath — the absolute path to the copied .sh file.
 * @throws when chmod fails on a POSIX platform (permission denied,
 *   file missing, etc.). On win32 the call is a no-op with an INFO
 *   stderr note; it never throws.
 */
export function setExecutable(targetPath: string): void {
  if (process.platform === 'win32') {
    process.stderr.write(
      `bassclef init: executable bit not applicable on this OS (${targetPath}). ` +
        `Claude Code will still invoke the hook if a POSIX shell layer is present.\n`
    );
    return;
  }
  chmodSync(targetPath, HOOK_EXECUTABLE_MODE);
}
