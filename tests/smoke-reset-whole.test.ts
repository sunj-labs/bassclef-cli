// smoke-reset-whole.test.ts — Tier 0 test for scripts/smoke-reset-whole.sh
//
// @verifies spec § Acceptance item 8 (--whole clears + snapshots + --restore)
// @verifies UC-smoke-run § Extension 1b (--restore path)
// @verifies decompose § ResetController + Snapshot entity
// @verifies RFC F6 fold (Cooper — reset undo)
// @verifies pre-mortem V3 fold (Vogels — self-prune old snapshots)
//
// All tests use fake target dirs in workDir. --skip-delegate keeps the
// real smoke-reset.sh from firing against the operator's real home.
//
// # test-list:
// [x] --help exits 0
// [x] snapshot happy path — copies each target dir to backup root
// [x] --dry-run writes no snapshot
// [x] --restore restores from a snapshot dir
// [x] auto-prune removes snapshot dirs older than 7 days
// [x] missing target dirs skip cleanly (no error)

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, readdirSync, existsSync, utimesSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT = resolve(__dirname, '../scripts/smoke-reset-whole.sh');

let workDir: string;
let backupRoot: string;
let target1: string;
let target2: string;
let targetsFile: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-reset-whole-test-'));
  backupRoot = join(workDir, 'backups');
  target1 = join(workDir, 'target-a');
  target2 = join(workDir, 'target-b');
  mkdirSync(target1);
  mkdirSync(target2);
  writeFileSync(join(target1, 'file1.txt'), 'content-a');
  writeFileSync(join(target2, 'file2.txt'), 'content-b');
  targetsFile = join(workDir, 'targets.txt');
  writeFileSync(targetsFile, `${target1}\n${target2}\n`);
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function run(args: string[]): { status: number | null; stdout: string; stderr: string } {
  const r = spawnSync('bash', [SCRIPT,
    '--targets-file', targetsFile,
    '--backup-root', backupRoot,
    '--skip-delegate',
    ...args
  ], { encoding: 'utf8' });
  return { status: r.status, stdout: r.stdout, stderr: r.stderr };
}

describe('smoke-reset-whole — usage', () => {
  it('--help exits 0', () => {
    const r = spawnSync('bash', [SCRIPT, '--help'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('smoke-reset-whole.sh');
  });
});

describe('smoke-reset-whole — snapshot happy path', () => {
  it('copies each target dir to backup root', () => {
    const r = run([]);
    expect(r.status).toBe(0);
    const backupDirs = readdirSync(backupRoot);
    expect(backupDirs).toHaveLength(1);
    const snapDir = join(backupRoot, backupDirs[0]);
    expect(existsSync(join(snapDir, 'target-a', 'file1.txt'))).toBe(true);
    expect(existsSync(join(snapDir, 'target-b', 'file2.txt'))).toBe(true);
  });

  it('--dry-run writes no snapshot', () => {
    const r = run(['--dry-run']);
    expect(r.status).toBe(0);
    // Backup root may not even exist after dry-run.
    if (existsSync(backupRoot)) {
      expect(readdirSync(backupRoot)).toHaveLength(0);
    }
  });

  it('missing target dirs skip cleanly (no error)', () => {
    // Point one target at a nonexistent path.
    writeFileSync(targetsFile, `${target1}\n${join(workDir, 'not-here')}\n`);
    const r = run([]);
    expect(r.status).toBe(0);
    expect(r.stderr).toMatch(/skip \(target absent/);
    // The existing target still got snapshotted.
    const backupDirs = readdirSync(backupRoot);
    expect(backupDirs).toHaveLength(1);
    expect(existsSync(join(backupRoot, backupDirs[0], 'target-a', 'file1.txt'))).toBe(true);
  });
});

describe('smoke-reset-whole — restore', () => {
  it('--restore restores from a snapshot dir', () => {
    // First snapshot to create a backup.
    run([]);
    const backupDirs = readdirSync(backupRoot);
    const ts = backupDirs[0];

    // Corrupt the target: write a different file.
    rmSync(join(target1, 'file1.txt'));
    writeFileSync(join(target1, 'wrong.txt'), 'wrong-content');

    // Restore.
    const r = run(['--restore', ts]);
    expect(r.status).toBe(0);
    expect(existsSync(join(target1, 'file1.txt'))).toBe(true);
    expect(readFileSync(join(target1, 'file1.txt'), 'utf8')).toBe('content-a');
    // Wrong file gone (rm -rf then cp)
    expect(existsSync(join(target1, 'wrong.txt'))).toBe(false);
  });
});

describe('smoke-reset-whole — auto-prune (V3 fold)', () => {
  it('removes snapshot dirs older than 7 days', () => {
    // Seed an "old" snapshot dir with mtime 10 days ago.
    const oldTs = '2025-01-01T00-00-00Z';
    const oldSnap = join(backupRoot, oldTs);
    mkdirSync(oldSnap, { recursive: true });
    writeFileSync(join(oldSnap, 'old.txt'), 'old-content');

    const tenDaysAgo = new Date();
    tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);
    utimesSync(oldSnap, tenDaysAgo, tenDaysAgo);

    // Fire a fresh snapshot — should prune the old dir.
    const r = run([]);
    expect(r.status).toBe(0);
    expect(existsSync(oldSnap)).toBe(false);
    // A new snapshot dir exists.
    expect(readdirSync(backupRoot).length).toBe(1);
  });
});
