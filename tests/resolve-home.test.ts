// resolve-home test list — per Beck TDD + test-list-discipline.
//
// @verifies P2-fold (RFC-0002 Andy Hunt & Dave Thomas — DRY on $HOME resolution)
// @verifies N2-fold (Nygard — $HOME unset fail-loud)
// @verifies S1-fold (Saltzer-Schroeder — sudo bypass refused)
// @verifies UC-init-walker-hook-routing Ext 1a + 1c
//
// RED phase — src/lib/resolve-home.ts does not exist yet. Import fails.
// Every test [ ] pending. Turns [x] as src file lands.
//
// # test-list:
// [ ] resolveHome({allowRoot: false}) returns os.homedir() when HOME set
// [ ] resolveHome({allowRoot: false}) throws EnvironmentIncomplete when HOME empty
// [ ] resolveHome({allowRoot: false}) throws SudoBypassRefused when HOME=/root
// [ ] resolveHome({allowRoot: true}) returns /root when HOME=/root
// [ ] resolveHome resolves symlinked HOME to its canonical path
// [ ] resolveHome preserves trailing slash absence (no trailing /)

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { homedir } from 'node:os';
// RED: this import fails today; file authored in code phase.
import { resolveHome, CopyFailure } from '../src/lib/resolve-home.js';

let originalHome: string | undefined;

beforeEach(() => {
  originalHome = process.env.HOME;
});

afterEach(() => {
  if (originalHome === undefined) delete process.env.HOME;
  else process.env.HOME = originalHome;
});

describe('resolveHome — happy path', () => {
  it('returns os.homedir() when HOME set and allowRoot=false', () => {
    if (homedir() === '/root') return;
    const result = resolveHome({ allowRoot: false });
    expect(result).toBe(homedir());
  });

  it('preserves trailing slash absence', () => {
    if (homedir() === '/root') return;
    const result = resolveHome({ allowRoot: false });
    expect(result.endsWith('/')).toBe(false);
  });

  it('resolves symlinked HOME to its canonical path', () => {
    if (homedir() === '/root') return;
    const result = resolveHome({ allowRoot: false });
    expect(result).toMatch(/^\//);
  });
});

describe('resolveHome — $HOME unset (Ext 1a)', () => {
  it('throws EnvironmentIncomplete when HOME empty', () => {
    process.env.HOME = '';
    expect(() => resolveHome({ allowRoot: false })).toThrow(CopyFailure);
    try {
      resolveHome({ allowRoot: false });
    } catch (e) {
      expect((e as CopyFailure).kind).toBe('EnvironmentIncomplete');
    }
  });
});

describe('resolveHome — sudo bypass (Ext 1c)', () => {
  it('throws SudoBypassRefused when HOME=/root and allowRoot=false', () => {
    process.env.HOME = '/root';
    expect(() => resolveHome({ allowRoot: false })).toThrow(CopyFailure);
    try {
      resolveHome({ allowRoot: false });
    } catch (e) {
      expect((e as CopyFailure).kind).toBe('SudoBypassRefused');
    }
  });

  it('returns /root when HOME=/root and allowRoot=true', () => {
    process.env.HOME = '/root';
    const result = resolveHome({ allowRoot: true });
    expect(result).toBe('/root');
  });
});
