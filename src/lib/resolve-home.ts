// Shared home-directory resolver.
//
// Both ScopeRouter (user-scope hook target resolution) and future
// callers need to resolve $HOME with the same guards:
//  - HOME unset  → CopyFailure kind 'EnvironmentIncomplete'
//  - HOME=/root  → CopyFailure kind 'SudoBypassRefused' unless allowRoot
//
// This module owns the rule. Consumers call resolveHome({allowRoot}).
//
// @verifies P2-fold (RFC-0002 Hunt & Thomas — DRY on $HOME resolution)
// @verifies N2-fold (Nygard — $HOME unset fail-loud)
// @verifies S1-fold (Saltzer-Schroeder — sudo bypass refused)
// @verifies UC-init-walker-hook-routing Ext 1a + 1c

import { realpathSync } from 'node:fs';
import { homedir } from 'node:os';

// CopyFailure type + kind is defined in copy-substrate.ts. We re-declare
// the class here as a local alias to avoid a circular import through
// scope-router.ts. Both classes are the same shape; instanceof works
// across the alias because we import + re-export the real class below.
export { CopyFailure } from './copy-substrate-failures.js';
import { CopyFailure } from './copy-substrate-failures.js';

export interface ResolveHomeOptions {
  /** Permit HOME=/root — matches init.ts --allow-root override. Default false. */
  allowRoot: boolean;
}

/**
 * Return the canonical home directory path for the current process.
 *
 * @throws CopyFailure kind 'EnvironmentIncomplete' when HOME is unset or empty.
 * @throws CopyFailure kind 'SudoBypassRefused' when HOME=/root and allowRoot=false.
 */
export function resolveHome(opts: ResolveHomeOptions): string {
  const raw = process.env.HOME;
  if (raw === undefined || raw === '') {
    throw new CopyFailure(
      'EnvironmentIncomplete',
      'HOME environment variable is unset. ' +
        'bassclef init needs HOME set to resolve user-scope hook targets. ' +
        'Set HOME to your home directory and rerun.'
    );
  }
  if (raw === '/root' && !opts.allowRoot) {
    throw new CopyFailure(
      'SudoBypassRefused',
      'HOME resolves to /root — sudo bypass detected. ' +
        'Routing user-scope hooks to /root breaks the adopter maintenance model. ' +
        'Run bassclef init without sudo, or pass --allow-root if this is intentional.'
    );
  }
  // Prefer os.homedir() when it matches HOME (it wraps env with a fallback);
  // fall back to HOME itself when they diverge (e.g., HOME=/root + allowRoot).
  const canonical = raw === homedir() ? homedir() : raw;
  // Resolve symlinks so downstream containment checks work against the
  // canonical path (defensive per @luminary saltzer-schroeder).
  try {
    return realpathSync(canonical);
  } catch {
    // realpath fails when the path does not exist. Return the raw value
    // and let the caller's write attempt surface the failure.
    return canonical.endsWith('/') ? canonical.slice(0, -1) : canonical;
  }
}
