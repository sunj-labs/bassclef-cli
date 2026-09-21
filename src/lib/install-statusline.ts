// bassclef init — statusline install step.
//
// Copies the tarball's bundled statusline dispatcher into the adopter's
// user-level Claude Code home (`~/.claude/bassclef-statusline.sh`), and
// writes the `statusLine` field into the project's `.claude/settings.json`
// so Claude Code renders the substrate statusline on every session.
//
// Ships as the cli-side pair to bassclef-upstream#1860 (which extends
// the rich-impl fallback chain so version + script paths resolve under a
// tarball layout, not only under a sibling repo checkout).
//
// Preserves ADR-002 invariants:
//   - Consumer resolves HOME via resolveHome() before calling this.
//   - No symlink follows on the dispatcher target (lstat check).
//   - Preserve-not-overwrite is the default; --force is the opt-in.
//   - Fail-loud on missing bundled source.
//
// Anchor: @luminary jerome-saltzer-and-michael-schroeder — complete mediation
// on every write, atomic replace via rename after write.
// Anchor: @luminary tony-hoare — preconditions checked before writes;
// postconditions reported via structured kinds so init-report renders cleanly.

import { existsSync, readFileSync, writeFileSync, mkdirSync, chmodSync, renameSync, lstatSync, unlinkSync } from 'node:fs';
import { join, dirname } from 'node:path';

/** Absolute path fragments used across the install. */
export interface InstallStatuslineOptions {
  /** Absolute path to the adopter's home directory (from resolveHome). */
  home: string;
  /** Absolute path to the project directory init is baselining. */
  projectDir: string;
  /** Absolute path to the bassclef-cli package root (contains dist/lite/). */
  packageDir: string;
  /** Overwrite operator-edited targets. Default false. */
  force: boolean;
  /** Do not write anything; report the plan instead. Default false. */
  dryRun: boolean;
  /** Skip the whole step (both writes). Default false. */
  skip: boolean;
  /**
   * Signal from the walker: the project's `.claude/settings.json` was
   * preserved from a prior state, not written by this init run. When
   * true, the settings merge is skipped so init's own preservation
   * discipline is not violated by an add-on step. Dispatcher install
   * still runs (user-scope `~/.claude/` is orthogonal). Default false.
   */
  settingsPreserved?: boolean;
}

/** Per-target outcome the init report renders. */
export type StatuslineOutcomeKind =
  | 'installed'
  | 'unchanged'
  | 'preserved'
  | 'replaced'
  | 'skipped'
  | 'would-install';

export interface StatuslineOutcome {
  kind: StatuslineOutcomeKind;
  /** Absolute path the outcome describes. */
  path: string;
  /** One-sentence detail, mostly for --json + verbose banner. */
  detail: string;
}

export interface InstallStatuslineReport {
  dispatcher: StatuslineOutcome;
  settings: StatuslineOutcome;
}

/** Canonical statusLine field value bassclef writes. */
export const STATUSLINE_FIELD = {
  type: 'command' as const,
  command: 'bash ~/.claude/bassclef-statusline.sh',
} as const;

const DISPATCHER_REL = ['dist', 'lite', 'presence', 'cli', 'bassclef-statusline.dispatcher.sh'];
const USER_DISPATCHER_REL = ['.claude', 'bassclef-statusline.sh'];
const PROJECT_SETTINGS_REL = ['.claude', 'settings.json'];

export function installStatusline(opts: InstallStatuslineOptions): InstallStatuslineReport {
  if (opts.skip) {
    return {
      dispatcher: skipped(join(opts.home, ...USER_DISPATCHER_REL)),
      settings: skipped(join(opts.projectDir, ...PROJECT_SETTINGS_REL)),
    };
  }

  const dispatcherSource = join(opts.packageDir, ...DISPATCHER_REL);
  if (!existsSync(dispatcherSource)) {
    throw new Error(
      `bassclef init: cannot install statusline — bundled dispatcher missing at ${dispatcherSource}. ` +
        'Reinstall @thebassclef/lite or file a bug.'
    );
  }

  const sourceBody = readFileSync(dispatcherSource, 'utf8');
  const dispatcher = handleDispatcher(opts, dispatcherSource, sourceBody);
  const settings = handleSettings(opts);

  return { dispatcher, settings };
}

function handleDispatcher(
  opts: InstallStatuslineOptions,
  sourcePath: string,
  sourceBody: string
): StatuslineOutcome {
  const target = join(opts.home, ...USER_DISPATCHER_REL);

  if (opts.dryRun) {
    return {
      kind: 'would-install',
      path: target,
      detail: `Dry-run: would copy ${sourcePath} → ${target} (0755).`,
    };
  }

  if (!existsSync(target)) {
    writeExec(target, sourceBody);
    return { kind: 'installed', path: target, detail: `Wrote ${target} (0755) from bundled dispatcher.` };
  }

  // Refuse to follow a symlink at the target.
  const st = lstatSync(target);
  if (st.isSymbolicLink()) {
    if (!opts.force) {
      return {
        kind: 'preserved',
        path: target,
        detail: `${target} is a symlink; refusing to follow. Pass --force to replace.`,
      };
    }
    unlinkSync(target);
    writeExec(target, sourceBody);
    return { kind: 'replaced', path: target, detail: `Replaced symlink at ${target} with bundled dispatcher.` };
  }

  const existing = readFileSync(target, 'utf8');
  if (existing === sourceBody) {
    return { kind: 'unchanged', path: target, detail: `${target} already matches bundled dispatcher.` };
  }

  if (!opts.force) {
    return {
      kind: 'preserved',
      path: target,
      detail: `${target} differs from bundled dispatcher. Pass --force to overwrite.`,
    };
  }

  writeExec(target, sourceBody);
  return { kind: 'replaced', path: target, detail: `Overwrote ${target} (--force) with bundled dispatcher.` };
}

function handleSettings(opts: InstallStatuslineOptions): StatuslineOutcome {
  const target = join(opts.projectDir, ...PROJECT_SETTINGS_REL);

  if (opts.settingsPreserved) {
    return {
      kind: 'preserved',
      path: target,
      detail: `${target} was preserved by init (--force not passed on existing file). ` +
        `Statusline field not merged. Re-run init with --force to overwrite.`,
    };
  }

  if (opts.dryRun) {
    return {
      kind: 'would-install',
      path: target,
      detail: `Dry-run: would set statusLine in ${target}.`,
    };
  }

  const existing = readSettings(target);
  const desired = STATUSLINE_FIELD;
  const current = existing.statusLine as unknown;

  if (current === undefined) {
    const next = { ...existing, statusLine: desired };
    writeSettings(target, next);
    return { kind: 'installed', path: target, detail: `Wrote statusLine field to ${target}.` };
  }

  if (matchesDesired(current)) {
    return { kind: 'unchanged', path: target, detail: `${target} already carries the bassclef statusLine.` };
  }

  if (!opts.force) {
    return {
      kind: 'preserved',
      path: target,
      detail: `${target} carries a different statusLine. Pass --force to overwrite.`,
    };
  }

  const next = { ...existing, statusLine: desired };
  writeSettings(target, next);
  return { kind: 'replaced', path: target, detail: `Overwrote statusLine in ${target} (--force).` };
}

function skipped(path: string): StatuslineOutcome {
  return {
    kind: 'skipped',
    path,
    detail: '--skip-statusline set; no changes to statusline target.',
  };
}

function writeExec(target: string, body: string): void {
  mkdirSync(dirname(target), { recursive: true });
  const tmp = `${target}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, body, { mode: 0o755 });
  renameSync(tmp, target);
  chmodSync(target, 0o755);
}

function readSettings(target: string): Record<string, unknown> {
  if (!existsSync(target)) return {};
  const raw = readFileSync(target, 'utf8');
  if (raw.trim() === '') return {};
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
    return {};
  } catch {
    return {};
  }
}

function writeSettings(target: string, next: Record<string, unknown>): void {
  mkdirSync(dirname(target), { recursive: true });
  const tmp = `${target}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`, { mode: 0o644 });
  renameSync(tmp, target);
}

function matchesDesired(current: unknown): boolean {
  if (!current || typeof current !== 'object' || Array.isArray(current)) return false;
  const c = current as Record<string, unknown>;
  return c.type === STATUSLINE_FIELD.type && c.command === STATUSLINE_FIELD.command;
}
