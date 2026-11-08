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
 * The grid, in columns. One unit, used everywhere below the install log.
 *
 * This is the whole bounding device. The install log prints flush left;
 * everything bassclef says about itself steps in by this much, and the
 * eye reads the step as a change of speaker. No rule is drawn, because a
 * drawn rule is what you add when the spacing is not doing its job.
 *
 * Exported because `init.ts` indents the value-test block by the same
 * amount. Two call sites, one constant — if they ever disagree the
 * banner has two grids, which is worse than having none.
 *
 * @see cli#484 — four lenses (Vignelli, Tufte, Rams, Ive) reached the
 *   indent over a border independently. The rendered comparison and the
 *   font-coverage evidence are linked from that ticket.
 */
export const BRAND_MARK_INDENT = 2;

/**
 * Narrowest terminal that fits the composed mark.
 *
 * Derived rather than guessed: whichever is wider, the art or the
 * tagline, plus the grid. Below this the art is dropped AND the indent
 * is dropped, because when space runs out the grid is the first luxury
 * to go. A mark clipped mid-letter reads as a broken product rather
 * than a narrow window.
 */
export const BRAND_MARK_MIN_COLUMNS = Math.max(
  BRAND_MARK_ART_WIDTH,
  TAGLINE.length,
) + BRAND_MARK_INDENT;

/** The name, lowercase, as it is typed. */
const NAME = 'bassclef';

/**
 * Brass. 256-colour index 179, chosen to sit clear of status green and red.
 *
 * One value, two devices. `CHIP_ON` fills a cell with brass and prints
 * near-black on it — a solid plate. `ART_ON` draws in brass on the
 * terminal's own ground — line art. Foreground and inverted read as
 * distinct objects at the same hue, which is how the figlet and the chip
 * can both be brass without the colour stopping to mean anything. The
 * plate still outweighs the line art, so the hierarchy holds.
 *
 * A second, muted gold was tried for the art (index 137) and rejected:
 * two golds that are close but not equal read as a mistake rather than a
 * choice.
 *
 * These were raw ESC bytes in the file until cli#484. A control
 * character in source survives nothing — not a copy-paste, not an editor
 * that trims, not a diff viewer. `\x1b` is the same byte and it is
 * visible to every one of those.
 */
const BRASS = 179;
const CHIP_ON = `\x1b[48;5;${BRASS}m\x1b[38;5;233m\x1b[1m`;
const ART_ON = `\x1b[38;5;${BRASS}m`;
const DIM_ON = '\x1b[2m';
const CHIP_OFF = '\x1b[0m';

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
 * Whether this run should emit colour.
 *
 * Pure, so it can be tested without a pty. The caller reads the
 * environment once and hands the answer down; nothing below here guesses.
 *
 * Order is deliberate. `FORCE_COLOR` is an explicit instruction and wins,
 * including `FORCE_COLOR=0` meaning off. `NO_COLOR` is the cross-tool
 * convention (no-color.org) and any value counts, even empty. `TERM=dumb`
 * names a terminal that cannot render it. Everything else falls through to
 * the real question: is a person looking at this, or is it going to a file?
 *
 * Piped output gets no colour, and that is load-bearing rather than
 * polite — the cold-adopter smoke captures and CI logs are pipes, and
 * escape codes in them would corrupt the record of what an adopter sees.
 *
 * @param env - the process environment to read.
 * @param isTTY - `process.stdout.isTTY`, which is `undefined` when piped.
 * @returns true when ANSI is safe to emit.
 */
export function supportsColour(
  env: Record<string, string | undefined>,
  isTTY: boolean | undefined,
): boolean {
  if (env.FORCE_COLOR !== undefined && env.FORCE_COLOR !== '') {
    return env.FORCE_COLOR !== '0';
  }
  if (env.NO_COLOR !== undefined) return false;
  if (env.TERM === 'dumb') return false;
  return isTTY === true;
}

/**
 * Indent every non-empty line of a block by `spaces` columns.
 *
 * Blank lines stay blank. Trailing whitespace on an otherwise empty line
 * is invisible but shows up in diffs and in `git` warnings, and a reader
 * selecting the text gets it too.
 *
 * @param text - the block to indent.
 * @param spaces - columns to add. `0` returns the text untouched.
 * @returns the indented block.
 */
export function indentBlock(text: string, spaces: number): string {
  if (spaces <= 0) return text;
  const pad = ' '.repeat(spaces);
  return text
    .split('\n')
    .map((line) => (line === '' ? line : pad + line))
    .join('\n');
}

/**
 * Compose the install mark.
 *
 * The chip is composed in here rather than beside here. That is the whole
 * point of cli#484: `renderChip` existed, passed five tests, and was never
 * called, because nothing asserted a relationship between the unit and the
 * composition. The sibling test now asserts this output CONTAINS the chip.
 * Do not inline the chip's escape codes to avoid the call — the call is
 * the contract.
 *
 * @param version - version string printed beneath the art. The caller
 *   passes the same version the rest of the banner uses, so the mark
 *   cannot drift from `package.json`.
 * @param columns - terminal width, or `undefined` when stdout is not a
 *   terminal. Below `BRAND_MARK_MIN_COLUMNS` the art is dropped and the
 *   text prints alone. `undefined` keeps the full mark: piped output has
 *   no width to overflow, and keeping it there is what lets smoke
 *   captures and CI logs show what an adopter actually sees.
 * @param opts.colour - whether to emit ANSI. Defaults to `false`, so a
 *   caller that forgets to ask gets the safe answer rather than escape
 *   codes in a log file.
 * @returns the block to print, newline-terminated.
 */
export function renderBrandMark(
  version: string,
  columns?: number,
  opts: { colour?: boolean } = {},
): string {
  const colour = opts.colour === true;
  const narrow = typeof columns === 'number' && columns < BRAND_MARK_MIN_COLUMNS;

  // When colour is on the chip is a brass plate, and its own padding puts
  // the plate's left edge on the grid. With colour off there is no plate,
  // so the bare word goes on the grid instead — the padding would push it
  // one column out of line with the art above it, for nothing.
  const nameCell = colour ? renderChip({ colour: true }) : NAME;
  const tagline = colour ? `${DIM_ON}${TAGLINE}${CHIP_OFF}` : TAGLINE;
  const text = `${nameCell}  ${version}\n${tagline}\n`;

  if (narrow) return text;

  const art = BRAND_MARK_ART.map((row) =>
    colour ? `${ART_ON}${row}${CHIP_OFF}` : row,
  ).join('\n');

  return indentBlock(`${art}\n\n${text}`, BRAND_MARK_INDENT);
}
