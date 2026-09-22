// Characterization tests for scripts/smoke-drive-skills.sh — cli #217 cure.
//
// Spawns the drive against 3 fixture claude mocks. Verifies:
//   - Drive uses natural-language prompts (not leading-slash) at invocation site
//   - Drive captures include real output when mock returns skill-shaped text
//   - Drive captures include "Unknown command:" when mock reproduces the failure
//   - Drive captures include clarifying question when mock reproduces Cooper C1
//
// The drive script itself does not run assertions — assertion happens in
// scripts/smoke-assert-skills.sh via lib check functions. These tests
// exercise the drive layer + fixture-based capture shape.
//
// @verifies cli #217 acceptance
//
// test-list:
// [x] happy path — 5 skills fire; 5 capture files written; each carries skill-shaped text
// [x] happy path — /temperance marker file lands under scratch state/markers/temperance/
// [x] unknown-command shape — leading-slash prompt returns "Unknown command:"; captures reflect it
// [x] clarifying-question shape — prompt returns "Waiting for your input"; capture reflects; no marker
// [x] drive uses natural-language prompt shape (script contains "run the /X skill" template)
// [x] drive does NOT fire raw `-p "/skillname"` for skills at authoring site

import { describe, it, expect, afterAll } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync, readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..', '..');
const DRIVE = resolve(REPO_ROOT, 'scripts/smoke-drive-skills.sh');
const FIXTURES = resolve(__dirname, 'fixtures/smoke-drive-skills');

function runDrive(opts: {
  claude: string;
  outDir: string;
  timeoutSec?: number;
  cwd?: string;
}) {
  const args = [DRIVE, '--out', opts.outDir, '--claude', opts.claude];
  if (opts.timeoutSec !== undefined) {
    args.push('--timeout', String(opts.timeoutSec));
  }
  return spawnSync('bash', args, {
    encoding: 'utf8',
    cwd: opts.cwd ?? REPO_ROOT,
    env: { ...process.env, PATH: process.env.PATH ?? '' },
  });
}

describe('scripts/smoke-drive-skills.sh — cli #217 characterization', () => {
  const workDirs: string[] = [];

  function makeWorkDir(): { outDir: string; cwd: string } {
    const root = mkdtempSync(resolve(tmpdir(), 'smoke-drive-skills-'));
    workDirs.push(root);
    return {
      outDir: resolve(root, 'captures'),
      cwd: root,
    };
  }

  afterAll(() => {
    for (const d of workDirs) {
      rmSync(d, { recursive: true, force: true });
    }
  });

  it('happy path — 5 captures written; each carries skill-shaped text', () => {
    const { outDir, cwd } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-happy-all.sh'),
      outDir,
      cwd,
    });
    expect(r.status, `stderr: ${r.stderr}`).toBe(0);

    const captures = readdirSync(outDir).sort();
    expect(captures).toHaveLength(5);

    const temperance = readFileSync(resolve(outDir, 'temperance.out'), 'utf8');
    expect(temperance).toMatch(/Firing \/temperance/);
    expect(temperance).toMatch(/Marker written/);

    const luminary = readFileSync(
      resolve(outDir, 'luminary-don-norman.out'),
      'utf8',
    );
    expect(luminary).toMatch(/Don Norman/);

    const kiss = readFileSync(
      resolve(outDir, 'kiss-words-this-is-verbose-corporate-sounding-text.out'),
      'utf8',
    );
    expect(kiss).toMatch(/Rewritten/);
    expect(kiss).toMatch(/grade/);
  });

  it('happy path — /temperance marker file lands under scratch state/markers/temperance/', () => {
    const { outDir, cwd } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-happy-all.sh'),
      outDir,
      cwd,
    });
    expect(r.status, `stderr: ${r.stderr}`).toBe(0);
    const markerDir = resolve(cwd, 'state/markers/temperance');
    expect(existsSync(markerDir)).toBe(true);
    const markers = readdirSync(markerDir);
    expect(markers.length).toBeGreaterThan(0);
  });

  it('unknown-command shape — captures reflect the failure', () => {
    const { outDir, cwd } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-unknown-command.sh'),
      outDir,
      cwd,
    });
    // Drive script exits 0 regardless of individual skill result (per spec L28).
    // The point is that CAPTURES must reflect the failure so the assertion suite catches it.
    expect(r.status).toBe(0);

    // With natural-language prompts, this mock's "/*)" branch does NOT match
    // (prompts don't start with '/'). Captures should show the mock's non-slash branch output.
    const temperance = readFileSync(resolve(outDir, 'temperance.out'), 'utf8');
    // Should NOT contain "Unknown command: /temperance" because cured drive uses natural-language.
    expect(temperance).not.toMatch(/Unknown command: \/temperance/);
    // Should contain the mock's non-slash-branch output OR mock's natural-language ack.
    expect(temperance).toMatch(/natural-language prompt received/);
  });

  it('clarifying-question shape — capture reflects wait-for-input; no marker lands', () => {
    const { outDir, cwd } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-clarifying-question.sh'),
      outDir,
      cwd,
    });
    expect(r.status).toBe(0);

    const temperance = readFileSync(resolve(outDir, 'temperance.out'), 'utf8');
    expect(temperance).toMatch(/Waiting for your input/);

    // Critical: NO marker file should exist since the mock never touched disk.
    const markerDir = resolve(cwd, 'state/markers/temperance');
    if (existsSync(markerDir)) {
      const markers = readdirSync(markerDir);
      expect(markers, 'clarifying-question mock never touches marker dir').toHaveLength(0);
    }
  });

  it('drive uses natural-language prompt shape at authoring site (RFC L1 fold)', () => {
    // Static grep — the drive script must build prompts via a natural-language
    // template, not fire `claude -p "/skillname"` directly.
    const source = readFileSync(DRIVE, 'utf8');
    // The template phrase per docs/decompositions/2026-09-22c-*.md L83
    expect(source).toMatch(/run the.*skill/i);
  });

  it('drive does NOT invoke raw `-p "/skill"` shape for defaulted skills', () => {
    // Guard against regression to the cli #217 shape.
    // The default skill list has entries like `/temperance` — these must NOT be
    // passed to -p verbatim. They should be embedded in a natural-language prompt.
    const source = readFileSync(DRIVE, 'utf8');
    // The invocation site should NOT contain `-p "$skill"` bare form
    // (where $skill would be a leading-slash string).
    // Cured shape wraps in a prompt template variable.
    expect(source).not.toMatch(/-p\s+"\$skill"/);
  });
});
