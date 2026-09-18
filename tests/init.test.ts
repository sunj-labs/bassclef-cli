// bassclef init test list — per Beck TDD.
//
// @verifies R-NPM-002
//
// End-to-end tests spawning the compiled CLI at dist/cli.js on a fresh
// temp directory. These are the Tier 0 tests the ADR-002 contract
// depends on. Registry: docs/requirements/2026-08-11-npm-distribution.md.
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
// [ ] #60: --dry-run count equals real-run substrate count + 2 configs
// [ ] #60: --dry-run writes nothing to substrate paths
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
let fakeHome: string;

function runCli(args: readonly string[], opts?: { cwd?: string }) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    // Bumped 8s -> 60s -> 180s 2026-09-18. v0.45.0 substrate has ~445
    // files locally, ~507 on CI (fresh sibling regen). Init dry-run on
    // slower CI hardware previously SIGKILLed at 60s mid-stdout,
    // truncating "would create" lines to 172 out of 507 expected. The
    // parity test at line ~274 caught it; publish workflow blocked.
    // Same class as bassclef-cli#116 (smoke timeout), PR #128 (8s→60s).
    timeout: 180000,
    cwd: opts?.cwd,
    // Cli 1.0.1 writes to $HOME/.claude/hooks/ for user-scope hooks.
    // Every test isolates to a temp HOME so runs don't pollute the
    // operator's real ~/.claude/hooks/ tree.
    env: { ...process.env, HOME: fakeHome },
  });
}

beforeEach(() => {
  // Isolate HOME first so mkdtemp for workDir sits inside it — the
  // resulting workDir is a real dir under a real (temp) HOME so the
  // ADR-002 "target under HOME" safety check passes without --allow-any-dir.
  fakeHome = mkdtempSync(join(HOME, '.bassclef-init-fakehome-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-init-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
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
    // gets created, the existing one is kept. Exit 0. Original settings.json
    // preserved via writeSafely refuse-overwrite in the dist/lite/ walker
    // per ADR-055 D1 + ADR-002 Default 1.
    mkdirSync(join(workDir, '.claude'));
    writeFileSync(join(workDir, '.claude/settings.json'), '{"prior":true}');
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);
    // Refused entry reported in walker output.
    expect(r.stdout + r.stderr).toMatch(/refused/i);
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
  it('creates missing config; walker refuses existing settings.json', () => {
    mkdirSync(join(workDir, '.claude'));
    writeFileSync(join(workDir, '.claude/settings.json'), '{"prior":true}');
    // substrate.config.md missing; walker files (settings.json + 4 templates
    // + wiring manifest) partially missing.
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'substrate.config.md'))).toBe(true);
    // 1 cli-composed config created; walker reports substrate files copied
    // and settings.json refused.
    expect(r.stdout + r.stderr).toMatch(/1 config files created/i);
    expect(r.stdout + r.stderr).toMatch(/refused/i);
    // Original content preserved.
    expect(readFileSync(join(workDir, '.claude/settings.json'), 'utf8'))
      .toBe('{"prior":true}');
  });
});

describe('bassclef init — dry-run parity with real run (#60 + ADR-055)', () => {
  // Regression test for bassclef-cli#60. Extended for ADR-055 D1 in
  // Phase 3: init walks dist/lite/ (not substrate/).
  //
  // cli 1.0.4 amended for dual-scope walker: undeclared hook files
  // (helpers + fragments the settings.json does not name as `command:`)
  // land at BOTH user scope AND project scope. Each undeclared hook
  // file writes TWO filesystem entries, so dry-run reports two
  // "would create" lines per undeclared hook file.
  //
  // Invariant: `wouldCreateLines.length` equals
  //   walkerFileCount + undeclaredHookFileCount + 1 config file.
  it('would-create count matches walker output including dual-scope helpers', () => {
    const fsMod = require('node:fs') as typeof import('node:fs');
    const distLite = join(REPO_ROOT, 'dist/lite');

    // Walk dist/lite/ once, count total files AND collect hook file paths
    // (files under .claude/hooks/ ending in .sh).
    let walkerCount = 0;
    const hookRelPaths: string[] = [];
    function walk(absDir: string, relDir: string): void {
      for (const name of fsMod.readdirSync(absDir)) {
        const abs = join(absDir, name);
        const rel = relDir ? `${relDir}/${name}` : name;
        const st = fsMod.statSync(abs);
        if (st.isDirectory()) walk(abs, rel);
        else {
          walkerCount += 1;
          if (rel.startsWith('.claude/hooks/') && rel.endsWith('.sh')) {
            hookRelPaths.push(rel);
          }
        }
      }
    }
    walk(distLite, '');

    // Read settings.json declared commands — derive their bundle-relative
    // source paths so we know which hook files are declared. Anything
    // under .claude/hooks/*.sh NOT in this set is undeclared and
    // dual-writes at cli 1.0.4.
    const settings = JSON.parse(
      fsMod.readFileSync(join(distLite, '.claude/settings.json'), 'utf8')
    ) as { hooks?: Record<string, Array<{ hooks?: Array<{ command?: string }> }>> };
    const declared = new Set<string>();
    for (const eventBlocks of Object.values(settings.hooks ?? {})) {
      for (const block of eventBlocks) {
        for (const h of block.hooks ?? []) {
          if (typeof h.command === 'string' && h.command.startsWith('$')) {
            declared.add(
              h.command
                .replace(/^\$HOME\//, '')
                .replace(/^\$CLAUDE_PROJECT_DIR\//, '')
                .replace(/\/{2,}/g, '/')
            );
          }
        }
      }
    }
    const undeclaredHookCount = hookRelPaths.filter((p) => !declared.has(p)).length;
    const expectedCount = walkerCount + undeclaredHookCount + 1; // + substrate.config.md

    const r = runCli(['--dry-run'], { cwd: workDir });
    expect(r.status).toBe(0);

    const wouldCreateLines = (r.stdout + r.stderr)
      .split('\n')
      .filter((line) => /would create/i.test(line));
    expect(wouldCreateLines.length).toBe(expectedCount);
  });

  it('writes nothing under dry-run', () => {
    const r = runCli(['--dry-run'], { cwd: workDir });
    expect(r.status).toBe(0);
    // No walker output should land on disk in dry-run.
    expect(existsSync(join(workDir, '.claude/settings.json'))).toBe(false);
    expect(existsSync(join(workDir, 'CLAUDE.md'))).toBe(false);
    expect(existsSync(join(workDir, 'standards/bassclef-wiring-manifest.json'))).toBe(false);
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
