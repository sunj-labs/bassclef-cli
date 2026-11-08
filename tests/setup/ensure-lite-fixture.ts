// Builds the dist/lite/ fixture once, before any test file runs.
//
// Parent ticket: sunj-labs/bassclef-cli#463
// Diagnosis: state/markers/diagnose/fix-463-lite-fixture-race.marker
//
// Why this exists. Four test files each carried a self-heal that rebuilt
// dist/lite/ when it looked missing — three of them in `beforeEach`, so once
// per test rather than once per file. Each comment says it was copied from a
// neighbour. `npm run build` empties dist/ (vite.config.ts sets
// `emptyOutDir: true`), so after a build those files raced to repopulate the
// same directory while reading it. Whichever won decided which tests failed,
// which is why the count moves between runs: the ticket recorded 21 failures
// and this branch measured 19. The failures land on assertions like "writes
// nothing under dry-run", so they read as defects in `init`. They are not.
//
// Why this does not cross the decision recorded in vitest.config.ts. That
// comment rejects globalSetup for auto-*building* — compiling src/ into dist/
// — because it would hide build failures behind test failures. The reason is
// sound, and this file keeps it: it never runs `vite build`. It asserts the
// CLI is already compiled and fails naming the missing build, so a build
// failure still reads as a build failure. What it does build is the substrate
// bundle, which is a fixture rather than the product under test.
//
// tests/harness/prepublish-bundle.test.ts drives the bundler as its own
// subject, and is deliberately untouched.

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const DIST_LITE = resolve(REPO_ROOT, 'dist/lite');
const SETTINGS = join(DIST_LITE, '.claude/settings.json');
const BUNDLER = resolve(REPO_ROOT, 'scripts/prepublish-bundle-substrate.mjs');

export default function setup(): void {
  if (!existsSync(CLI)) {
    throw new Error(
      'dist/cli.js is missing, so the suite has nothing to spawn.\n' +
        'Run `npm run build` first. This setup does not build for you on\n' +
        'purpose — a build failure should read as a build failure, per the\n' +
        'note in vitest.config.ts.',
    );
  }

  if (existsSync(SETTINGS)) return;

  // cli#482 — the bundler now refuses when the sibling checkout sits past
  // the pinned tag, because shipping from a source that disagrees with the
  // pin is how a local build stops matching what CI publishes. That guard
  // is right for a publish and wrong here: this builds a test fixture, and
  // a developer whose sibling is on a release branch should still be able
  // to run the suite. So the fixture downgrades the guard to a warning and
  // the bundler prints which source it read, which is what makes a
  // confusing test failure traceable.
  const r = spawnSync(process.execPath, [BUNDLER], {
    encoding: 'utf8',
    timeout: 60000,
    env: { ...process.env, BASSCLEF_PIN_MISMATCH: 'warn' },
  });

  if (r.status !== 0) {
    throw new Error(
      'Could not build the dist/lite/ fixture, so every init test would fail\n' +
        'for a reason unrelated to the code under test.\n\n' +
        `  ${BUNDLER}\n\n${r.stderr || r.stdout}`,
    );
  }

  // Exit 0 is not evidence the fixture landed. Check the file the init tests
  // actually read.
  if (!existsSync(SETTINGS)) {
    throw new Error(
      'The fixture bundler exited 0 but dist/lite/.claude/settings.json is\n' +
        'not there. Treating the fixture as unbuilt rather than trusting the\n' +
        'exit code.',
    );
  }
}
