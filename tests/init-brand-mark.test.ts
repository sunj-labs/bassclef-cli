// cli#460 — bassclef init brand mark.
//
// @verifies cli#460 (mark printed above the ready block)
// @requirement bassclef-upstream#2337 (design/brand-mark.md — grid + glyph set)
//
// Beck RED-first. Before src/lib/init-brand-mark.ts exists, the import
// below fails and every assertion in this file fails with it. Each
// assertion names the specific property of the mark that is missing.
//
// The grid is DATA, not code. An editor paste, a font substitution, or
// a careless reflow can corrupt it without changing behavior anywhere
// else. Tests 1-3 pin the grid's shape and codepoint set so corruption
// fails loudly here instead of shipping a broken mark to an adopter.
//
// test-list:
// [x] art grid is exactly 11 rows
// [x] every art row is at most 27 columns (cannot collide with the text column)
// [x] art uses exactly four non-ASCII codepoints: U+2580 U+2584 U+2588 U+00B7
// [x] renderBrandMark interpolates the version it is handed
// [x] columns below the minimum returns text only — no block glyph
// [x] columns at the minimum returns the full mark
// [x] columns undefined (piped, not a terminal) returns the full mark
// [x] composed mark is never wider than the declared minimum
// [x] default init prints the mark above "Bassclef is ready."
// [x] init --json stdout carries no block glyph (report contract intact)
//
// Anchor luminary: @luminary michael-feathers — characterization pins
// the grid. Anchor: @luminary kent-beck — RED before source.
// Anchor: @luminary tony-hoare — renderBrandMark is pure; width is an
// argument so the contract needs no TTY fixture.
// Anchor: @luminary donald-norman — a wrapped mark reads as corruption,
// so the narrow case drops it rather than wrapping it.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  BRAND_MARK_ART,
  BRAND_MARK_ART_WIDTH,
  BRAND_MARK_MIN_COLUMNS,
  renderBrandMark,
} from '../src/lib/init-brand-mark.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const DIST_LITE = resolve(REPO_ROOT, 'dist/lite');
const HOME = homedir();

/** Any Block Elements glyph. Used to assert presence or absence. */
const BLOCK_GLYPH = /[▀-▟]/;

function runCli(args: readonly string[], cwd: string, home: string) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 15000,
    cwd,
    env: { ...process.env, HOME: home },
  });
}

describe('brand mark grid (cli#460)', () => {
  it('art grid is exactly 11 rows', () => {
    expect(BRAND_MARK_ART).toHaveLength(11);
  });

  it('every art row is at most the declared art width', () => {
    expect(BRAND_MARK_ART_WIDTH).toBe(27);
    for (const [i, row] of BRAND_MARK_ART.entries()) {
      expect(
        row.length,
        `art row ${i} is ${row.length} cols, over the ${BRAND_MARK_ART_WIDTH}-col budget`,
      ).toBeLessThanOrEqual(BRAND_MARK_ART_WIDTH);
    }
  });

  it('art uses exactly four non-ASCII codepoints — U+2580 U+2584 U+2588 U+00B7', () => {
    const found = new Set<string>();
    for (const row of BRAND_MARK_ART) {
      for (const ch of row) {
        if (ch.codePointAt(0)! > 0x7f) found.add(ch);
      }
    }
    const codepoints = [...found]
      .map((c) => c.codePointAt(0)!)
      .sort((a, b) => a - b)
      .map((n) => `U+${n.toString(16).toUpperCase().padStart(4, '0')}`);
    expect(codepoints).toEqual(['U+00B7', 'U+2580', 'U+2584', 'U+2588']);
  });
});

describe('renderBrandMark contract (cli#460)', () => {
  it('interpolates the version it is handed', () => {
    const out = renderBrandMark('9.9.9', 120);
    expect(out).toContain('9.9.9');
    expect(out).not.toContain('{version}');
  });

  it('returns the full mark when columns is at the minimum', () => {
    expect(BRAND_MARK_MIN_COLUMNS).toBe(53);
    const out = renderBrandMark('1.0.0', BRAND_MARK_MIN_COLUMNS);
    expect(out).toMatch(BLOCK_GLYPH);
  });

  it('returns text only — no block glyph — below the minimum', () => {
    const out = renderBrandMark('1.0.0', BRAND_MARK_MIN_COLUMNS - 1);
    expect(out).not.toMatch(BLOCK_GLYPH);
    expect(out).toContain('1.0.0');
  });

  it('returns the full mark when columns is undefined (piped, not a terminal)', () => {
    const out = renderBrandMark('1.0.0', undefined);
    expect(out).toMatch(BLOCK_GLYPH);
  });

  it('composed mark is never wider than the declared minimum', () => {
    const out = renderBrandMark('1.9.19', 200);
    for (const line of out.split('\n')) {
      expect(
        line.length,
        `composed line is ${line.length} cols, over the ${BRAND_MARK_MIN_COLUMNS}-col minimum`,
      ).toBeLessThanOrEqual(BRAND_MARK_MIN_COLUMNS);
    }
  });

  it('carries the tagline in both the wide and the narrow shape', () => {
    expect(renderBrandMark('1.0.0', 200)).toContain('the agent band');
    expect(renderBrandMark('1.0.0', 10)).toContain('the agent band');
  });
});

describe('bassclef init prints the mark (cli#460)', () => {
  let workDir: string;
  let fakeHome: string;

  beforeEach(() => {
    // dist/lite/ fixture is built once by the globalSetup in
    // vitest.config.ts (cli#463). The self-heal that used to sit here raced
    // its three siblings over the same directory after a build.
    fakeHome = mkdtempSync(join(HOME, '.bassclef-init-brand-mark-fakehome-'));
    workDir = mkdtempSync(join(fakeHome, '.bassclef-init-brand-mark-work-'));
  });

  afterEach(() => {
    try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
    try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
  });

  it('default init prints the mark above "Bassclef is ready."', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).toMatch(BLOCK_GLYPH);
    const markAt = r.stdout.search(BLOCK_GLYPH);
    const readyAt = r.stdout.indexOf('Bassclef is ready.');
    expect(readyAt).toBeGreaterThan(-1);
    expect(markAt).toBeLessThan(readyAt);
  });

  it('init --json stdout carries no block glyph', () => {
    const r = runCli(['--json'], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(r.stdout).not.toMatch(BLOCK_GLYPH);
    // stdout is still the report alone.
    expect(() => JSON.parse(r.stdout) as unknown).not.toThrow();
  });
});
