// prompt module — Tier 0 tests per Beck TDD.
//
// confirm(question, opts?) wraps Node's readline/promises. Test harness
// bypasses real TTY via ttyOverride. --yes argv flag maps to
// ttyOverride: 'yes' at runtime.
//
// RED signal — src/lib/prompt.ts does not exist yet. Import fails.
// Every test here fails until Step 6 ships the module (~50 LOC).
//
// Ledger ties:
// - R5 (Feathers — testability of interactive surface via ttyOverride)
// - R7 (Cooper — no-TTY environment must degrade safely)
//
// test-list (Beck):
// [ ] // @risk: R5 — ttyOverride: 'yes' returns true
// [ ] // @risk: R5 — ttyOverride: 'no' returns false
// [ ] // @risk: R7 — no TTY + no override returns false (safe default)
// [ ] // @risk: R5 — defaultNo: true respects Enter alone as false
//
// Design constraint per ADR-008 D2: default answer is No. Changing this
// is MAJOR (adopter safety regression). The defaultNo test pins that.

import { describe, it, expect } from 'vitest';
import { confirm } from '../../src/lib/prompt.js';

describe('confirm', () => {
  it('// @risk: R5 — ttyOverride yes returns true', async () => {
    const result = await confirm('proceed?', { ttyOverride: 'yes' });
    expect(result).toBe(true);
  });

  it('// @risk: R5 — ttyOverride no returns false', async () => {
    const result = await confirm('proceed?', { ttyOverride: 'no' });
    expect(result).toBe(false);
  });

  it('// @risk: R7 — no TTY and no override returns false (safe default)', async () => {
    // Simulate no-TTY by passing ttyOverride: null and inputStream: undefined
    // implementation reads process.stdin.isTTY; in vitest that is undefined,
    // so real behavior is "no TTY" by default in this suite.
    const result = await confirm('proceed?', { ttyOverride: null });
    expect(result).toBe(false);
  });

  it('// @risk: R5 — defaultNo true does not force true return under no-TTY', async () => {
    // The default answer stays No under no-TTY. defaultNo is a
    // signal to the caller about the prompt shape, not an override.
    const result = await confirm('proceed?', { defaultNo: true, ttyOverride: null });
    expect(result).toBe(false);
  });
});
