// Scope router — maps a settings.json command to a filesystem target
// on the adopter machine.
//
// Two prefixes carry meaning in cli 1.0.1:
//   $HOME/...                 → user scope; lands under HOOKS_SUBPATH inside home
//   $CLAUDE_PROJECT_DIR/...   → project scope; lands under HOOKS_SUBPATH inside targetDir
// Any other prefix throws UnknownScopePrefix — the adopter must upgrade
// cli to a version that supports the new prefix, rather than the walker
// silent-dropping the hook. See src/lib/paths.ts for the HOOKS_SUBPATH
// constant that spells the hook subpath.
//
// GRASP roles (per docs/decompositions/2026-09-13d-cli-1-0-1-hook-routing-grasp.md):
//   Information Expert — sole owner of the scope-prefix knowledge.
//   Strategy (GoF)     — per-prefix routing rule; extensible via new strategy.
//   Chain of Responsibility (GoF) — validation chain; each step may throw.
//
// @pattern patterns/code/gof/strategy.md
// @pattern patterns/code/gof/chain-of-responsibility.md
// @verifies S1-fold (Saltzer-Schroeder — sudo bypass via resolveHome)
// @verifies N2-fold (Nygard — $HOME unset via resolveHome)
// @verifies N6-fold (Nygard — unknown prefix throws)
// @verifies S4-fold (Saltzer-Schroeder — path traversal refused)
// @verifies P3-fold (Hunt & Thomas — ScopeDecision {scope, targetPath} shape)
// @verifies UC-init-walker-hook-routing main step 5-6 + Ext 1a, 1c, 5b, 6e

import { resolve as pathResolve, join, normalize } from 'node:path';
import { CopyFailure } from './copy-substrate-failures.js';
import { resolveHome } from './resolve-home.js';

export { CopyFailure } from './copy-substrate-failures.js';

const PREFIX_HOME = '$HOME/';
const PREFIX_PROJECT = '$CLAUDE_PROJECT_DIR/';

export interface HookCommand {
  /** The full command string from settings.json — starts with $HOME or $CLAUDE_PROJECT_DIR. */
  command: string;
}

export interface ScopeRouterOptions {
  /** The adopter repo directory init was invoked on. Used for project scope. */
  targetDir: string;
  /** Permit HOME=/root during home resolve. Matches init.ts --allow-root. */
  allowRoot: boolean;
}

export type ScopeDecision =
  | { scope: 'user'; targetPath: string }
  | { scope: 'project'; targetPath: string };

/**
 * Classify a settings.json hook command and return its scope + target
 * path on the adopter machine.
 *
 * @throws CopyFailure kind 'UnknownScopePrefix' | 'EnvironmentIncomplete'
 *   | 'SudoBypassRefused' | 'PathTraversalRefused'.
 */
export function classify(
  hook: HookCommand,
  opts: ScopeRouterOptions
): ScopeDecision {
  const cmd = hook.command;
  if (typeof cmd !== 'string' || cmd.length === 0) {
    throw new CopyFailure(
      'UnknownScopePrefix',
      'Hook command is empty. settings.json must supply a non-empty command string.'
    );
  }

  if (cmd.startsWith(PREFIX_HOME)) {
    return classifyUser(cmd.slice(PREFIX_HOME.length), opts);
  }
  if (cmd.startsWith(PREFIX_PROJECT)) {
    return classifyProject(cmd.slice(PREFIX_PROJECT.length), opts);
  }

  throw new CopyFailure(
    'UnknownScopePrefix',
    `Hook command "${cmd}" uses an unknown scope prefix. ` +
      `cli 1.0.1 handles "$HOME/..." and "$CLAUDE_PROJECT_DIR/..." only. ` +
      `Upgrade cli to a version that supports this prefix.`
  );
}

function classifyUser(relPath: string, opts: ScopeRouterOptions): ScopeDecision {
  const home = resolveHome({ allowRoot: opts.allowRoot });
  const cleaned = normalizeRel(relPath);
  const targetPath = normalize(join(home, cleaned));
  assertContained(targetPath, home, opts.allowRoot ? '/root' : null);
  return { scope: 'user', targetPath };
}

function classifyProject(relPath: string, opts: ScopeRouterOptions): ScopeDecision {
  const cleaned = normalizeRel(relPath);
  const targetPath = normalize(join(opts.targetDir, cleaned));
  assertContained(targetPath, opts.targetDir);
  return { scope: 'project', targetPath };
}

/**
 * Collapse duplicate slashes in the relative path — settings.json may
 * ship with `$HOME//.claude//hooks//x.sh`; the walker treats them as
 * equivalent to the clean shape.
 */
function normalizeRel(rel: string): string {
  return rel.replace(/\/{2,}/g, '/');
}

/**
 * Guard against `..` traversal — the resolved target must live under
 * the containing root. Complete mediation per @luminary saltzer-schroeder.
 */
function assertContained(target: string, root: string, altRoot?: string | null): void {
  const resolvedTarget = pathResolve(target);
  const resolvedRoot = pathResolve(root);
  if (resolvedTarget === resolvedRoot) return;
  if (resolvedTarget.startsWith(resolvedRoot + '/')) return;
  if (altRoot) {
    const resolvedAlt = pathResolve(altRoot);
    if (resolvedTarget === resolvedAlt) return;
    if (resolvedTarget.startsWith(resolvedAlt + '/')) return;
  }
  throw new CopyFailure(
    'PathTraversalRefused',
    `Hook target "${target}" escapes ${root}. ` +
      `settings.json commands must resolve inside the declared scope root. ` +
      `If this is a bassclef-upstream bundle defect, file at sunj-labs/bassclef-upstream.`
  );
}
