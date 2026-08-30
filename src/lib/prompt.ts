// Interactive prompt wrapper — wraps Node's readline/promises so tests
// can bypass a live TTY via ttyOverride injection.
//
// Ships as ONE public function per Ousterhout deep-module discipline.
// The confirm shape hides readline behind a promise-returning boolean.
//
// Per ADR-008 D2:
// - Default answer is No (adopter safety default).
// - --yes argv flag maps to ttyOverride: 'yes' at runtime.
// - No TTY + no override returns false with a stderr note.
//
// @risk R5 — Feathers: ttyOverride makes the module testable without
// a live TTY. Every test injects the override; production reads TTY.
// @risk R7 — Cooper: no-TTY environment degrades safely (false), never
// hangs on a missing stdin.

import { createInterface } from 'node:readline/promises';
import { stdin, stdout, stderr } from 'node:process';

export interface ConfirmOptions {
  /** true → Enter alone returns false; false → Enter alone returns true. Default true. */
  defaultNo?: boolean;
  /** Test hook. 'yes' or 'no' bypasses TTY. null (default) reads real TTY. */
  ttyOverride?: 'yes' | 'no' | null;
}

export async function confirm(
  question: string,
  opts: ConfirmOptions = {}
): Promise<boolean> {
  const { defaultNo = true, ttyOverride = null } = opts;

  // Test hook — bypass TTY entirely.
  if (ttyOverride === 'yes') return true;
  if (ttyOverride === 'no') return false;

  // No TTY available — safe default is false, with a note on stderr
  // pointing the operator at --yes for scripted upgrades.
  if (!stdin.isTTY) {
    stderr.write(
      `bassclef: no terminal detected; declining prompt.\n` +
        `         Run with --yes for non-interactive mode.\n`
    );
    return false;
  }

  const rl = createInterface({ input: stdin, output: stdout });
  try {
    const suffix = defaultNo ? ' [y/N] ' : ' [Y/n] ';
    const answer = (await rl.question(question + suffix)).trim().toLowerCase();
    if (answer === '') return !defaultNo;
    return answer === 'y' || answer === 'yes';
  } finally {
    rl.close();
  }
}
