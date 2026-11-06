/**
 * The bassclef mark — a figlet at install, a chip everywhere else.
 *
 * Parent ticket: cli#460. Glyph follow-up: cli#475.
 * Pre-mortem folds: docs/risk-ledgers/2026-11-06-brass-mark.md
 *
 * ## Why this is built from letters
 *
 * The mark this replaces was drawn in Unicode block elements, and it
 * failed two ways that are independent of each other.
 *
 * It blobbed. 98 of its 135 glyphs were solid `U+2588`, so the silhouette
 * rode entirely on 37 half-blocks. Those break apart as soon as a
 * terminal's line spacing passes 1.0, and line spacing is the viewer's
 * setting, not ours.
 *
 * And it was absent on Monaco. Reading the font binary directly: Monaco's
 * cmap holds 1,624 codepoints and contains neither `U+2580` nor `U+2584`.
 * A third of the mark was tofu there, not blurred.
 *
 * A survey of 34 developer CLIs found that block elements appear as
 * identity in exactly two of them — the only two that print a pictorial
 * logo. Everywhere else blocks are data: QR codes, progress bars,
 * sparklines. So the evidence and the failure point the same way.
 *
 * This mark is printable ASCII throughout. No font can fail it, because
 * every font has the alphabet. That is the whole design.
 *
 * ## Two sizes, one voice
 *
 * The figlet greets once, at install. The chip marks every line after
 * that. Jest invented the chip form, Astro and Nx adopted it
 * independently, and its defining property is that it degrades to the
 * bare word when colour is absent — in a log file, a CI capture, or a
 * terminal with colour off.
 *
 * @see cli#475 — the real bass clef character renders via font fallback
 *   and is one column wide. Both verified. Deferred by operator decision,
 *   not on merit; the reasoning is recorded on that ticket.
 */

/**
 * The wordmark, four rows of printable ASCII.
 *
 * This grid is DATA. A paste from a figlet generator can carry a Unicode
 * dash in with it, and an edit can pad one row and not its neighbours.
 * Neither corrupts visibly on the author's own machine, so the sibling
 * test asserts the character set and the row widths mechanically. Do not
 * relax those assertions to accommodate an edit — fix the edit.
 */
export const BRAND_MARK_ART: readonly string[] = Object.freeze([
  ' _                          _       __  ',
  '| |__  __ _  ___  ___  __  | | ___ / _| ',
  "| '_ \\/ _` |(_-< (_-< / _| | |/ -_)|  _|",
  '|_.__/\\__,_|/__/ /__/ \\__| |_|\\___||_|  ',
]);

/** Width of every art row. The test asserts all four match this. */
export const BRAND_MARK_ART_WIDTH = 40;

/** The tagline, on one line now that the text sits below the art. */
const TAGLINE = 'the agent band that backs your solos';

/**
 * Narrowest terminal that fits the composed mark.
 *
 * Derived rather than guessed: whichever is wider, the art or the
 * tagline. Below this the art is dropped and the text prints alone,
 * because a mark clipped mid-letter reads as a broken product rather
 * than a narrow window.
 */
export const BRAND_MARK_MIN_COLUMNS = Math.max(
  BRAND_MARK_ART_WIDTH,
  TAGLINE.length,
);

/** The name, lowercase, as it is typed. */
const NAME = 'bassclef';

/** Brass. 256-colour index 179, chosen to sit clear of status green and red. */
const CHIP_ON = '[48;5;179m[38;5;233m[1m';
const CHIP_OFF = '[0m';

/**
 * The recurring mark — the name on a brass field, one space each side.
 *
 * The padding is not decoration. It is what makes this read as a chip
 * rather than as coloured text, and it is the one rule Jest, Astro and
 * Nx all share.
 *
 * @param opts.colour - whether to emit ANSI. Pass `false` when writing to
 *   a file or when the caller has detected a terminal without colour. The
 *   payload is identical either way; only the wrapper differs. That is
 *   the property the whole idiom exists for.
 * @returns ` bassclef `, wrapped in colour when asked.
 */
export function renderChip(opts: { colour: boolean }): string {
  const payload = ` ${NAME} `;
  return opts.colour ? `${CHIP_ON}${payload}${CHIP_OFF}` : payload;
}

/**
 * Compose the install mark.
 *
 * @param version - version string printed beneath the art. The caller
 *   passes the same version the rest of the banner uses, so the mark
 *   cannot drift from `package.json`.
 * @param columns - terminal width, or `undefined` when stdout is not a
 *   terminal. Below `BRAND_MARK_MIN_COLUMNS` the art is dropped and the
 *   text prints alone. `undefined` keeps the full mark: piped output has
 *   no width to overflow, and keeping it there is what lets smoke
 *   captures and CI logs show what an adopter actually sees.
 * @returns the block to print, newline-terminated.
 */
export function renderBrandMark(version: string, columns?: number): string {
  const text = `${NAME} ${version}\n${TAGLINE}\n`;

  if (typeof columns === 'number' && columns < BRAND_MARK_MIN_COLUMNS) {
    return text;
  }

  return `${BRAND_MARK_ART.join('\n')}\n\n${text}`;
}
