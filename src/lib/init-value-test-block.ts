// Sam-verbatim value-test block printed by `bassclef init` at the end
// of a successful run. Per cli#406 + bassclef-upstream#2006.
//
// The block replaces the catalog-count summary ("N skills, M rules, K
// agents…") as the default closer. Catalog counts still ship behind
// --verbose for operators who want the inventory.
//
// Text is the Sam-verbatim target from the Saturday-evaluator analysis
// (~/Downloads/sam_val_prop_analysis.pdf §"3. Single cheapest change").
// Do NOT edit without updating bassclef-upstream#2006 + this test:
//   tests/init-value-test-block.test.ts
//
// cli#477 added the closing line, and it is the only addition to the
// verbatim text. The reason: the block walks the reader to /build, and
// /build opens a pull request. A pull request needs a GitHub remote,
// which `bassclef init` does not create. Without the line the reader
// finds that out at step three, after riffing and planning — the point
// of highest investment. The line names the requirement rather than a
// skill, because /onboard-repo Path A still requires bassclef cloned as
// a peer at ~/src/<org>/bassclef, which an npm adopter does not have.
// It also says which step is free, so first value stays one command away.
//
// cli#484 added one blank line above /launch and one above /build. No
// word changed, so bassclef-upstream#2006 is untouched — this is spacing,
// and the sibling test skips blank lines when it walks the block.
//
// The reason: `claude` + `/riff` already had a blank line above them and
// the other two cues did not. Three cues, two shapes. A reader scanning
// for "what do I type" was given one rhythm and then a different one.
//
// cli#484 also broke the two long lines at their sentence boundaries.
// They were 94 and 93 columns and wrapped mid-sentence on an 80-column
// terminal, which is the default width. No word changed and no sentence
// moved — only where the newline falls.
//
// I first claimed this needed bassclef-upstream#2006 updated, and that
// was wrong. #2006 quotes the target as a markdown blockquote, which
// carries no column budget. It pins the words. It does not pin the wrap.
//
// A sibling test now asserts every line fits 80 columns WITH the indent
// applied, so this cannot come back the way it arrived.
//
// The per-line test in init-value-test-block.test.ts could not have
// caught any of this: it iterates this constant and asserts stdout
// contains each line, so it only proves stdout and the constant agree
// with each other. Edit the constant and it follows along. That is why
// the sibling test pins the opening words as literals instead.
//
// Anchor luminary: @luminary michael-feathers — characterization pins
// the exact Sam-verbatim words. Anchor: @luminary alan-cooper — Sam's
// 3-level goal (end + experience + life).

export const VALUE_TEST_BLOCK = `Bassclef is ready.

It added engineering workflows and automatic checks to Claude Code.
Nothing else needs configuring.

Try it on something small:

  claude
  /riff

Describe a feature you're considering.
You'll get three approaches before any code is written.

Then choose one:

  /launch

When the plan looks right:

  /build

/riff works on its own.
/launch and /build open pull requests, so those need a GitHub remote.
`;
