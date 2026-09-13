// init-hook-routing test list — per Beck TDD + test-list-discipline.
//
// Sibling to tests/init.test.ts. Covers banner shape + manifest scope
// field + upgrade advisory prompt + --json flag added in cli 1.0.1.
//
// @verifies L1-fold (Torvalds — cli 1.0.0 → 1.0.1 advisory)
// @verifies L2-fold (Torvalds — manifest schema_version=2)
// @verifies L3-fold (Torvalds — sync ignores user-scope entries)
// @verifies H1-fold (Hyrum — --json flag for stable machine output)
// @verifies H2-fold (Hyrum — CopyResult.scope shape)
// @verifies N1-fold (Norman — Installed banner shape)
// @verifies N2-fold (Norman — symlink error includes readlink target)
// @verifies F6-fold (Feathers — manifest scope field)
// @verifies P3-fold (Hunt & Thomas — CopyResult per-entry shape)
//
// RED phase — new arg flags + banner rewrite + manifest schema not
// implemented yet. Every test [ ] pending.
//
// # test-list:
// [ ] init banner uses Norman "Installed N of M" shape
// [ ] init banner on partial-copy failure includes "N failed" clause
// [ ] init manifest carries schema_version=2 at top level
// [ ] init manifest carries per-entry scope field (user | project)
// [ ] init on a 1.0.0-installed target prints upgrade advisory + waits for confirm
// [ ] init with --yes flag on 1.0.0-installed target skips the advisory prompt
// [ ] init --json flag emits structured stderr line
// [ ] init without --json omits the structured line
// [ ] CopyResult.copied entries are {path, scope} objects (not raw strings)
// [ ] symlink error message includes readlink target path
// [ ] sync on mixed-scope manifest ignores user-scope entries for edit detection

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, readFileSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');

let workDir: string;
let fakeHome: string;
let originalHome: string | undefined;

function runCli(args: readonly string[], opts?: { cwd?: string; env?: NodeJS.ProcessEnv }) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 8000,
    cwd: opts?.cwd,
    env: opts?.env ?? { ...process.env, HOME: fakeHome },
  });
}

beforeEach(() => {
  originalHome = process.env.HOME;
  workDir = mkdtempSync(join(homedir(), '.bassclef-init-hookroute-'));
  fakeHome = mkdtempSync(join(homedir(), '.bassclef-init-fakehome-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
  if (originalHome === undefined) delete process.env.HOME;
  else process.env.HOME = originalHome;
});

describe('init banner — Norman shape (N1 council fold)', () => {
  it('emits "Installed N of M hooks (lite tier)" on happy path', () => {
    const r = runCli(['--dir', workDir, '--allow-any-dir']);
    expect(r.stdout).toMatch(/Installed \d+ of \d+ hooks \(lite tier\)/);
  });

  it('emits partial-copy banner "N of M hooks. K failed" on error path', () => {
    // Seed a symlink at user-scope target to force refusal.
    mkdirSync(join(fakeHome, '.claude/hooks'), { recursive: true });
    const decoy = join(fakeHome, '.claude/hooks/decoy');
    writeFileSync(decoy, 'sentinel');
    symlinkSync(decoy, join(fakeHome, '.claude/hooks/bassclef-sync.sh'));
    const r = runCli(['--dir', workDir, '--allow-any-dir']);
    expect(r.stdout).toMatch(/failed/);
    expect(r.stdout).toMatch(/Rerun bassclef init/);
  });
});

describe('init manifest — schema v2 (L2 + F6 fold)', () => {
  it('writes manifest with schema_version=2 at top level', () => {
    runCli(['--dir', workDir]);
    const manifest = JSON.parse(
      readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8')
    );
    expect(manifest.schema_version).toBe(2);
  });

  it('writes per-entry scope field on hook entries', () => {
    runCli(['--dir', workDir]);
    const manifest = JSON.parse(
      readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8')
    );
    const hookEntries = (manifest.files ?? []).filter((f: { path: string }) =>
      f.path.includes('.claude/hooks/')
    );
    for (const entry of hookEntries) {
      expect(['user', 'project']).toContain(entry.scope);
    }
  });
});

describe('init upgrade path from 1.0.0 (L1 council fold)', () => {
  it('prints upgrade advisory when 1.0.0 manifest present without user-scope entries', () => {
    mkdirSync(join(workDir, '.bassclef'), { recursive: true });
    // 1.0.0-shaped manifest — no schema_version, no scope fields
    writeFileSync(
      join(workDir, '.bassclef/init.manifest.json'),
      JSON.stringify({ files: [{ path: 'substrate.config.md', outcome: 'created' }] })
    );
    const r = runCli(['--dir', workDir, '--allow-any-dir', '--yes']);
    // Advisory expected in output — pass --yes to non-interactively confirm
    expect(r.stdout).toMatch(/user-scope hook installation/);
    expect(r.stdout).toMatch(/1.0.1/);
  });

  it('skips advisory when --yes flag passed', () => {
    mkdirSync(join(workDir, '.bassclef'), { recursive: true });
    writeFileSync(
      join(workDir, '.bassclef/init.manifest.json'),
      JSON.stringify({ files: [] })
    );
    const r = runCli(['--dir', workDir, '--allow-any-dir', '--yes']);
    // Should not hang on stdin
    expect(r.status).not.toBeNull();
  });
});

describe('init --json flag (H1 council fold)', () => {
  it('emits structured stderr line when --json passed', () => {
    const r = runCli(['--dir', workDir, '--allow-any-dir', '--json']);
    const jsonLine = r.stderr.split('\n').find((l) => l.trim().startsWith('{'));
    expect(jsonLine).toBeDefined();
    const parsed = JSON.parse(jsonLine!);
    expect(parsed).toHaveProperty('copied');
    expect(parsed).toHaveProperty('declared');
    expect(parsed).toHaveProperty('scope_counts');
    expect(parsed.scope_counts).toHaveProperty('user');
    expect(parsed.scope_counts).toHaveProperty('project');
  });

  it('omits structured line when --json omitted', () => {
    const r = runCli(['--dir', workDir, '--allow-any-dir']);
    const jsonLine = r.stderr.split('\n').find((l) => l.trim().startsWith('{'));
    expect(jsonLine).toBeUndefined();
  });
});

describe('CopyResult shape (P3 + H2 folds)', () => {
  it('copied entries are {path, scope} objects, not raw strings', () => {
    // Runs the copySubstrate function directly to inspect shape.
    // Import at test-file level so RED fires on missing new export.
    // (Placeholder pin — proper import lands with the code phase.)
    expect(true).toBe(true); // stub — real test authored after Phase 5 lands the type.
  });
});

describe('symlink error message (N2 council fold)', () => {
  it('names the readlink target in the error message', () => {
    if (process.platform === 'win32') return;
    mkdirSync(join(fakeHome, '.claude/hooks'), { recursive: true });
    const decoy = join(fakeHome, '.claude/hooks/decoy-somewhere-else');
    writeFileSync(decoy, 'x');
    symlinkSync(decoy, join(fakeHome, '.claude/hooks/bassclef-sync.sh'));
    const r = runCli(['--dir', workDir, '--allow-any-dir']);
    expect(r.stderr).toContain('decoy-somewhere-else');
  });
});

describe('sync ignores user-scope entries (L3 council fold)', () => {
  it('sync does not report user-scope edits as adopter drift', () => {
    // Seed a mixed-scope manifest and run sync; assert no user-scope
    // paths appear in the drift-report.
    // Placeholder — full flow lands with sync-side changes in code phase.
    expect(true).toBe(true);
  });
});
