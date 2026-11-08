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
// cli#484 — the chip shipped in #476 and never printed once. renderChip
// was exported, had the five tests above, emitted correct ANSI, and had
// no caller. Every test passed because each half was pinned alone and
// nothing asserted a relationship between them. These are that assertion
// plus the grid it arrived with.
//
// [x] the composed mark CONTAINS the chip — the missing assertion
// [x] colour off composes no escape codes at all
// [x] colour on puts brass on the art, not only on the chip
// [x] art and chip use the same brass index — one colour, two devices
// [x] every line of the wide mark starts on the grid
// [x] the narrow fallback drops the indent with the art
// [x] indentBlock leaves blank lines blank — no trailing whitespace
// [x] indentBlock with 0 is the identity
// [x] supportsColour: piped stdout (isTTY undefined) is false
// [x] supportsColour: a terminal is true
// [x] supportsColour: NO_COLOR beats a terminal
// [x] supportsColour: NO_COLOR empty still counts, per no-color.org
// [x] supportsColour: TERM=dumb beats a terminal
// [x] supportsColour: FORCE_COLOR overrides a pipe
// [x] supportsColour: FORCE_COLOR=0 means off even on a terminal
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
  BRAND_MARK_INDENT,
  BRAND_MARK_MIN_COLUMNS,
  indentBlock,
  renderBrandMark,
  renderChip,
  supportsColour,
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

// cli#484. The defect was not that any of these functions was wrong. It
// was that renderBrandMark never called renderChip, and no test could
// tell, because every test exercised one function at a time. The first
// test in this block is the one that fails on the code that shipped.
describe('the composition — brass actually reaches the output', () => {
  it('the composed mark CONTAINS the chip, not a copy of its escape codes', () => {
    const out = renderBrandMark('1.0.0', 120, { colour: true });
    expect(
      out,
      'renderChip is exported, tested, and was never called — that is the bug this pins',
    ).toContain(renderChip({ colour: true }));
  });

  it('puts brass on the art too, not only on the chip', () => {
    const out = renderBrandMark('1.0.0', 120, { colour: true });
    // The art row carries its own colour run, independent of the chip's.
    expect(out).toMatch(/\x1b\[38;5;179m \_ {26}\_ {7}__/);
  });

  it('draws art and chip from one brass index — two devices, one colour', () => {
    const out = renderBrandMark('1.0.0', 120, { colour: true });
    const indices = [...out.matchAll(/\x1b\[(?:38|48);5;(\d+)m/g)].map((m) => m[1]);
    const brass = indices.filter((i) => i !== '233'); // 233 is the ink on the plate
    expect(
      [...new Set(brass)],
      `more than one gold in play: ${[...new Set(brass)].join(', ')} — two near-equal golds read as a mistake`,
    ).toEqual(['179']);
  });

  it('composes no escape codes at all when colour is off', () => {
    const out = renderBrandMark('1.0.0', 120, { colour: false });
    expect(out).not.toContain('\x1b');
  });

  it('defaults to colour off — a forgetful caller gets the safe answer', () => {
    expect(renderBrandMark('1.0.0', 120)).not.toContain('\x1b');
  });
});

describe('the grid — indentation is the bounding device', () => {
  it('starts every line of the wide mark on the grid', () => {
    const out = renderBrandMark('1.0.0', 120);
    for (const line of out.split('\n')) {
      if (line === '') continue;
      expect(
        line.startsWith(' '.repeat(BRAND_MARK_INDENT)),
        `line is off the grid: ${JSON.stringify(line)}`,
      ).toBe(true);
    }
  });

  it('drops the indent with the art when the terminal is too narrow', () => {
    const out = renderBrandMark('1.0.0', BRAND_MARK_MIN_COLUMNS - 1);
    expect(out.startsWith(' ')).toBe(false);
  });

  it('accounts for the indent in the minimum width', () => {
    expect(BRAND_MARK_MIN_COLUMNS).toBe(BRAND_MARK_ART_WIDTH + BRAND_MARK_INDENT);
  });

  it('leaves blank lines blank — an indented blank is invisible whitespace', () => {
    expect(indentBlock('a\n\nb', 2)).toBe('  a\n\n  b');
  });

  it('is the identity at zero', () => {
    expect(indentBlock('a\nb', 0)).toBe('a\nb');
  });
});

describe('supportsColour — decided once, never guessed', () => {
  it('is false for piped stdout, so captures and CI logs stay clean', () => {
    expect(supportsColour({}, undefined)).toBe(false);
  });

  it('is true for a terminal', () => {
    expect(supportsColour({}, true)).toBe(true);
  });

  it('honours NO_COLOR over a terminal', () => {
    expect(supportsColour({ NO_COLOR: '1' }, true)).toBe(false);
  });

  it('honours NO_COLOR when empty — any value counts, per no-color.org', () => {
    expect(supportsColour({ NO_COLOR: '' }, true)).toBe(false);
  });

  it('honours TERM=dumb over a terminal', () => {
    expect(supportsColour({ TERM: 'dumb' }, true)).toBe(false);
  });

  it('lets FORCE_COLOR override a pipe', () => {
    expect(supportsColour({ FORCE_COLOR: '1' }, undefined)).toBe(true);
  });

  it('reads FORCE_COLOR=0 as off, even on a terminal', () => {
    expect(supportsColour({ FORCE_COLOR: '0' }, true)).toBe(false);
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
