// cli#460 / brass mark — bassclef init brand mark.
//
// @verifies cli#460 (mark printed above the ready block)
// @requirement cli#475 defers the bass clef glyph; this is the ASCII mark
//
// The mark this replaces was broken two ways, both measured. 98 of its 135
// glyphs were solid block, so line spacing above 1.0 turned it into a mass.
// And Monaco carries neither U+2580 nor U+2584 — verified by reading the
// font binary, 1,624 codepoints, neither present — so a third of the
// silhouette was absent there rather than blurred.
//
// The cure is to stop pretending a terminal is a bitmap. The figlet is
// built from printable ASCII, so no font can fail it.
//
// The grid is still DATA, not code. A paste from a figlet generator can
// carry a Unicode dash in with it, and an edit can pad one row and not its
// neighbours. The first four tests assert the character set and the
// geometry mechanically, because neither corrupts visibly on the author's
// own machine.
//
// test-list:
// [x] art is exactly 4 rows
// [x] every art row is the same width — no ragged right edge
// [x] art is pure printable ASCII — nothing outside 0x20..0x7E
// [x] art is narrower than the 53-column mark it replaces
// [x] renderBrandMark interpolates the version it is handed
// [x] columns below the minimum returns text only
// [x] columns at the minimum returns the full mark
// [x] columns undefined (piped) returns the full mark
// [x] composed mark never exceeds the declared minimum
// [x] tagline survives in both the wide and the narrow shape
// [x] chip carries one space of padding each side
// [x] chip is lowercase
// [x] chip degrades to the bare word when colour is off
// [x] chip colour path still contains the word
// [x] chip is ASCII once colour is stripped
// [x] default init prints the mark above "Bassclef is ready."
// [x] init --json stdout carries no mark
//
// Pre-mortem folds: docs/risk-ledgers/2026-11-06-brass-mark.md
//   (I1 assert charset mechanically, I2 assert even widths, I3 test the
//    colour-off degrade, N4 keep the undefined-width path, N5 keep the
//    narrow fallback, N6 version comes from the argument, F7 rewrite the
//    grid tests rather than drop them, F8 pin the chip, F9 prove the new
//    mark is smaller than the one it replaces)
//
// Anchor luminary: @luminary jony-ive — material honesty; a character grid
// is not a bitmap. @luminary michael-feathers — the grid tests exist
// because the grid corrupts silently. @luminary kent-beck — RED first.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  BRAND_MARK_ART,
  BRAND_MARK_ART_WIDTH,
  BRAND_MARK_MIN_COLUMNS,
  renderBrandMark,
  renderChip,
} from '../src/lib/init-brand-mark.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

/** Width of the mark this one replaces. The change has to be a reduction. */
const PRIOR_MARK_COLUMNS = 53;

/** Anything outside printable ASCII. One such character is a defect. */
const NON_ASCII = /[^\x20-\x7E]/;

/** Strip ANSI so the payload can be asserted on its own. */
const stripAnsi = (s: string): string => s.replace(/\[[0-9;]*m/g, '');

function runCli(args: readonly string[], cwd: string, home: string) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 15000,
    cwd,
    env: { ...process.env, HOME: home },
  });
}

describe('brand mark grid — the data that corrupts silently', () => {
  it('art is exactly 4 rows', () => {
    expect(BRAND_MARK_ART).toHaveLength(4);
  });

  it('every art row is the same width — no ragged right edge', () => {
    const widths = [...new Set(BRAND_MARK_ART.map((r) => r.length))];
    expect(widths, `rows have differing widths: ${widths.join(', ')}`).toHaveLength(1);
    expect(widths[0]).toBe(BRAND_MARK_ART_WIDTH);
  });

  it('art is pure printable ASCII — no font can fail it', () => {
    for (const [i, row] of BRAND_MARK_ART.entries()) {
      const bad = row.match(NON_ASCII);
      const found = bad
        ? `U+${bad[0].codePointAt(0)!.toString(16).toUpperCase().padStart(4, '0')}`
        : '';
      expect(
        bad,
        `art row ${i} contains ${found} — this mark exists precisely so it needs no font coverage`,
      ).toBeNull();
    }
  });

  it('art is narrower than the 53-column mark it replaces', () => {
    expect(BRAND_MARK_ART_WIDTH).toBeLessThan(PRIOR_MARK_COLUMNS);
  });
});

describe('renderBrandMark contract', () => {
  it('interpolates the version it is handed', () => {
    const out = renderBrandMark('9.9.9', 120);
    expect(out).toContain('9.9.9');
    expect(out).not.toContain('{version}');
  });

  it('returns the full mark when columns is at the minimum', () => {
    expect(renderBrandMark('1.0.0', BRAND_MARK_MIN_COLUMNS)).toContain(BRAND_MARK_ART[1]);
  });

  it('returns text only below the minimum — a clipped mark reads as corruption', () => {
    const out = renderBrandMark('1.0.0', BRAND_MARK_MIN_COLUMNS - 1);
    expect(out).not.toContain(BRAND_MARK_ART[1]);
    expect(out).toContain('1.0.0');
  });

  it('returns the full mark when columns is undefined (piped, not a terminal)', () => {
    expect(renderBrandMark('1.0.0', undefined)).toContain(BRAND_MARK_ART[1]);
  });

  it('composed mark never exceeds the declared minimum', () => {
    const out = renderBrandMark('1.9.20', 200);
    for (const line of out.split('\n')) {
      expect(
        line.length,
        `composed line is ${line.length} cols, over the ${BRAND_MARK_MIN_COLUMNS}-col budget`,
      ).toBeLessThanOrEqual(BRAND_MARK_MIN_COLUMNS);
    }
  });

  it('carries the tagline in both the wide and the narrow shape', () => {
    expect(renderBrandMark('1.0.0', 200)).toContain('the agent band');
    expect(renderBrandMark('1.0.0', 10)).toContain('the agent band');
  });
});

describe('chip — the recurring mark', () => {
  it('carries one space of padding each side', () => {
    expect(renderChip({ colour: false })).toBe(' bassclef ');
  });

  it('is lowercase', () => {
    const plain = renderChip({ colour: false });
    expect(plain).toBe(plain.toLowerCase());
  });

  it('degrades to the bare word when colour is off', () => {
    const plain = renderChip({ colour: false });
    expect(plain).not.toContain('');
    expect(plain.trim()).toBe('bassclef');
  });

  it('carries colour when asked, and the word survives it', () => {
    const coloured = renderChip({ colour: true });
    expect(coloured).toContain('');
    expect(stripAnsi(coloured)).toBe(' bassclef ');
  });

  it('is pure ASCII once colour is stripped', () => {
    expect(stripAnsi(renderChip({ colour: true })).match(NON_ASCII)).toBeNull();
  });
});

describe('bassclef init prints the mark', () => {
  let workDir: string;
  let fakeHome: string;

  beforeEach(() => {
    // dist/lite/ fixture is built once by the globalSetup in
    // vitest.config.ts (cli#463).
    fakeHome = mkdtempSync(join(HOME, '.bassclef-brand-mark-fakehome-'));
    workDir = mkdtempSync(join(fakeHome, '.bassclef-brand-mark-work-'));
  });

  afterEach(() => {
    try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
    try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
  });

  it('default init prints the mark above "Bassclef is ready."', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    const markAt = r.stdout.indexOf(BRAND_MARK_ART[1]);
    const readyAt = r.stdout.indexOf('Bassclef is ready.');
    expect(markAt).toBeGreaterThan(-1);
    expect(readyAt).toBeGreaterThan(-1);
    expect(markAt).toBeLessThan(readyAt);
  });

  it('init --json stdout carries no mark', () => {
    const r = runCli(['--json'], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).not.toContain(BRAND_MARK_ART[1]);
    expect(() => JSON.parse(r.stdout) as unknown).not.toThrow();
  });
});
