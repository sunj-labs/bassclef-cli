// The bassclef mark, printed by `bassclef init` at the end of a
// successful run. Per cli#460.
//
// Design spec is bassclef-upstream#2337 (`design/brand-mark.md` in
// upstream). That file is the source of truth for the grid and the
// glyph set. This module is one of two renderers; the other is the
// SVG render on the website (bassclef-web#451). The two cannot share
// code — one emits text, the other vectors — so they share the spec.
//
// Do NOT edit the grid without updating the spec AND this test:
//   tests/init-brand-mark.test.ts
//
// Anchor luminary: @luminary michael-feathers — the grid is data, and
// an editor paste or a font substitution can corrupt it silently. The
// test pins the row count, the width budget, and the exact codepoint
// set. Anchor: @luminary tony-hoare — renderBrandMark is pure and
// takes width as an argument, so its contract needs no TTY.
// Anchor: @luminary donald-norman — a wrapped mark reads as corrupted
// output, so the narrow case drops the mark rather than wrapping it.

/**
 * The mark itself, without the text beside it. Eleven rows, each
 * within `BRAND_MARK_ART_WIDTH` columns.
 *
 * Four non-ASCII glyphs appear here and nowhere else in the mark:
 * U+2580 UPPER HALF BLOCK, U+2584 LOWER HALF BLOCK, U+2588 FULL
 * BLOCK, and U+00B7 MIDDLE DOT. The first three are Block Elements;
 * the dot is Latin-1 Supplement. All four render at fixed pitch in
 * Menlo and SF Mono, so the mark needs no extra font.
 *
 * Braille Patterns would draw the curves better and were the first
 * draft. A font scan on 2026-10-26 found 0 of 256 Braille characters
 * in Menlo and 0 of 256 in SF Mono, so that draft was abandoned. The
 * spec records the finding so nobody re-derives it.
 */
export const BRAND_MARK_ART: readonly string[] = Object.freeze([
  '    ▄█▄▄                  ·',
  '   ████▀         ▄█████▄▄',
  '   ████        ▄██████████▄',
  '   ▀████       ████████████',
  '    ▀████▄      ▀████▀ ████',
  '     ▀██████▄▄       ▄█████',
  '   ·   ▀▀████████████████▀',
  '           ▀▀█████████▀▀',
  '               ▄█▄    ▄▄▄▄',
  '              █████  ▀████·',
  '      ·        ▀▀▀     ▀▀',
]);

/** Column budget for the art. Rows wider than this collide with the text. */
export const BRAND_MARK_ART_WIDTH = 27;

/** Blank columns between the art and the text beside it. */
const GAP = 5;

/** The tagline, split across the two rows it occupies beside the art. */
const TAGLINE_ROWS = ['the agent band', 'that backs your solos'] as const;

/** Which art row each text line sits beside. */
const VERSION_ROW = 1;
const TAGLINE_FIRST_ROW = 3;

/**
 * Narrowest terminal that fits the composed mark. Below this the mark
 * is dropped and the text prints alone.
 *
 * Derived, not guessed: the art budget, plus the gap, plus the longest
 * text line. A test asserts no composed line exceeds it.
 */
export const BRAND_MARK_MIN_COLUMNS =
  BRAND_MARK_ART_WIDTH + GAP + Math.max(...TAGLINE_ROWS.map((t) => t.length));

/**
 * Compose the mark for printing.
 *
 * @param version - version string shown beside the art. The caller
 *   passes the same version the rest of the banner uses, so the mark
 *   cannot drift from `package.json`.
 * @param columns - terminal width, or `undefined` when stdout is not a
 *   terminal. A number below `BRAND_MARK_MIN_COLUMNS` returns the text
 *   alone. `undefined` returns the full mark: piped output has no width
 *   to overflow, and keeping the mark there is what lets the smoke
 *   captures and CI logs show what an adopter sees.
 * @returns the block to print, newline-terminated.
 */
export function renderBrandMark(version: string, columns?: number): string {
  if (typeof columns === 'number' && columns < BRAND_MARK_MIN_COLUMNS) {
    return `bassclef  ${version}\n${TAGLINE_ROWS.join(' ')}\n`;
  }

  const textFor = (row: number): string => {
    if (row === VERSION_ROW) return `bassclef  ${version}`;
    const taglineIndex = row - TAGLINE_FIRST_ROW;
    return TAGLINE_ROWS[taglineIndex] ?? '';
  };

  const lines = BRAND_MARK_ART.map((art, row) => {
    const text = textFor(row);
    if (text === '') return art;
    return art.padEnd(BRAND_MARK_ART_WIDTH + GAP) + text;
  });

  return `${lines.join('\n')}\n`;
}
