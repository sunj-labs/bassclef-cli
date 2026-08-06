// bassclef init test list — per Beck TDD.
//
// End-to-end tests spawning the compiled CLI at dist/cli.js on a fresh
// temp directory. These are the Tier 0 tests the ADR-002 contract
// depends on.
//
// [x] fresh empty target → both files written; exit 0; verbose lists each
// [x] rerun on already-initialized dir → files unchanged; exit 0; "already initialized"
// [x] target has existing .claude/settings.json → refuses; exit 1; message names --force
// [x] target has existing settings.json + --force → overwrites; exit 0
// [x] --dry-run on empty target → prints plan; writes nothing
// [x] --dry-run on partial target → prints "would skip" for existing
// [x] --dir nonexistent → refuses; exit 1
// [x] target dir outside HOME → refuses; exit 1; message names --allow-any-dir
// [x] partial state — settings.json exists, other missing → creates other, reports counts, exit 0
// [x] --dry-run always prints per-file plan (does not depend on --verbose)
// [x] output contains no banned words from the jargon block list
//
// Deferred: running as root (uid=0) refusal — requires a uid-0 fixture,
//   verified manually. Deferred: symlink attack on the target path —
//   covered by writeSafely tests directly.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

// Bassclef jargon block list — user-facing PROSE must not use these
// words. The check strips file paths first (substrate.config.md is the
// name of a file we ship — an unavoidable term of art; the ban applies
// to explanation text, not filenames).
const BANNED_WORDS = [
  'workunit',
  'primitive',
  'load-bearing',
  'operationalize',
  'anticorruption',
  'mediation',
  'andon',
  'provenance',
  'dispatcher',
];

function stripPathsFromOutput(text: string): string {
  // Remove anything that looks like a POSIX path so file names don't
  // trip banned-word scans on prose.
  return text.replace(/\S*\/\S+/g, '<path>');
}

let workDir: string;

function runCli(args: readonly string[], opts?: { cwd?: string }) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 8000,
    cwd: opts?.cwd,
  });
}

beforeEach(() => {
  // Use HOME as the base so default-safety checks (under HOME) pass.
  workDir = mkdtempSync(join(HOME, '.bassclef-init-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef init — happy path', () => {
  it('writes both files on fresh empty target', () => {
    const r = runCli(['--verbose'], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, '.claude/settings.json'))).toBe(true);
    expect(existsSync(join(workDir, 'substrate.config.md'))).toBe(true);
    expect(r.stdout + r.stderr).toContain('created');
  });

  it('refuses re-run when the manifest exists (points at sync)', () => {
    // Per ADR-003 P7: init refuses to re-baseline a project that already
    // has a manifest. Sync is the path for updates.
    runCli([], { cwd: workDir });
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/already initialized|bassclef sync/i);
  });

  it('re-baselines the manifest with --force', () => {
    runCli([], { cwd: workDir });
    const r = runCli(['--force'], { cwd: workDir });
    expect(r.status).toBe(0);
  });
});

describe('bassclef init — safety refusals', () => {
  it('preserves an existing settings.json when --force not passed', () => {
    // Per decomp P5: partial state runs to completion — the missing file
    // gets created, the existing one is kept. Exit 0. Message names
    // --force so Sam knows how to overwrite if she wants to.
    mkdirSync(join(workDir, '.claude'));
    writeFileSync(join(workDir, '.claude/settings.json'), '{"prior":true}');
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(r.stdout + r.stderr).toContain('--force');
    // Original content preserved.
    expect(readFileSync(join(workDir, '.claude/settings.json'), 'utf8'))
      .toBe('{"prior":true}');
  });

  it('overwrites with --force', () => {
    mkdirSync(join(workDir, '.claude'));
    writeFileSync(join(workDir, '.claude/settings.json'), '{"prior":true}');
    const r = runCli(['--force'], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(readFileSync(join(workDir, '.claude/settings.json'), 'utf8'))
      .not.toBe('{"prior":true}');
  });

  it('refuses --dir pointing at nonexistent path', () => {
    const r = runCli(['--dir', join(workDir, 'nope')]);
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/does not exist|not found/i);
  });

  it('refuses target dir outside HOME (message names --allow-any-dir)', () => {
    // Use /tmp — under system tmpdir, likely outside HOME.
    const outside = mkdtempSync(join(tmpdir(), 'bassclef-outside-test-'));
    try {
      if (outside.startsWith(HOME)) return; // skip on hosts where tmpdir is inside HOME
      const r = runCli(['--dir', outside]);
      expect(r.status).toBe(1);
      expect(r.stderr).toContain('--allow-any-dir');
    } finally {
      rmSync(outside, { recursive: true, force: true });
    }
  });
});

describe('bassclef init — dry-run', () => {
  it('prints per-file plan on empty target and writes nothing', () => {
    const r = runCli(['--dry-run'], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(r.stdout + r.stderr).toMatch(/would create/i);
    expect(existsSync(join(workDir, '.claude/settings.json'))).toBe(false);
    expect(existsSync(join(workDir, 'substrate.config.md'))).toBe(false);
  });

  it('shows would-skip on partial target', () => {
    writeFileSync(join(workDir, 'substrate.config.md'), 'prior');
    const r = runCli(['--dry-run'], { cwd: workDir });
    expect(r.status).toBe(0);
    const out = r.stdout + r.stderr;
    expect(out).toMatch(/would create.*settings\.json/i);
    expect(out).toMatch(/would skip.*substrate\.config\.md/i);
  });

  it('always prints the plan even without --verbose', () => {
    const r = runCli(['--dry-run'], { cwd: workDir });
    expect(r.stdout + r.stderr).toMatch(/would create/i);
  });
});

describe('bassclef init — partial state', () => {
  it('creates missing files and reports 1 created, 1 unchanged', () => {
    mkdirSync(join(workDir, '.claude'));
    writeFileSync(join(workDir, '.claude/settings.json'), '{"prior":true}');
    // substrate.config.md missing.
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'substrate.config.md'))).toBe(true);
    expect(r.stdout + r.stderr).toMatch(/1 created.*1 unchanged/i);
    // settings.json content preserved.
    expect(readFileSync(join(workDir, '.claude/settings.json'), 'utf8'))
      .toBe('{"prior":true}');
  });
});

describe('bassclef init — plain-language output', () => {
  it('contains no banned words in prose output (paths excluded)', () => {
    const runs = [
      runCli(['--verbose'], { cwd: workDir }),
      runCli(['--dry-run'], { cwd: mkdtempSync(join(HOME, '.bassclef-init-test-')) }),
    ];
    for (const r of runs) {
      const raw = (r.stdout + '\n' + r.stderr).toLowerCase();
      const prose = stripPathsFromOutput(raw);
      for (const w of BANNED_WORDS) {
        expect(prose, `prose contained banned word "${w}":\n${prose}`).not.toContain(w);
      }
    }
  });
});
