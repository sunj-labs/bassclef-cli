// smoke-drive-skills.test.ts — Tier 0 test for scripts/smoke-drive-skills.sh
//
// @verifies spec § Acceptance item 4 (five skills via claude -p)
// @verifies UC-smoke-run § Main flow Step 12 + Extensions 11a + 11b
// @verifies decompose § SkillDriver (Control)
// @verifies pre-mortem V1 (Vogels — CRASH row on non-zero exit)
//
// Uses a MOCK claude binary written into workDir. Real claude behavior
// is verified separately on the cold-adopter Mac profile per operator
// (this session, 2026-09-18).
//
// # test-list:
// [x] --help exits 0
// [x] exit 2 when claude binary missing
// [x] --dry-run prints plan and writes nothing
// [x] happy path: fires 5 default skills via mock; writes 5 capture files
// [x] capture contains mock claude output
// [x] capture records exit code (== 0 for happy mock)
// [x] non-zero claude exit is captured; overall drive still exits 0
// [x] --skill-list-file uses custom list
// [x] --timeout kills a hanging mock skill (exit 142 in capture)
// [x] --out custom-dir writes captures there

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import {
  mkdtempSync, writeFileSync, readdirSync, readFileSync,
  rmSync, existsSync, chmodSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT = resolve(__dirname, '../scripts/smoke-drive-skills.sh');

let workDir: string;
let mockClaude: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-drive-test-'));
  mockClaude = join(workDir, 'claude');
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

/** Write a mock `claude` binary with a specific body. Sets +x. */
function writeMockClaude(body: string): void {
  writeFileSync(mockClaude, body);
  chmodSync(mockClaude, 0o755);
}

/** Run the driver with a given claude-bin path. */
function run(claudeBin: string, args: string[] = []): { status: number | null; stdout: string; stderr: string } {
  const r = spawnSync('bash', [SCRIPT, '--claude', claudeBin, ...args], { encoding: 'utf8' });
  return { status: r.status, stdout: r.stdout, stderr: r.stderr };
}

describe('smoke-drive-skills — usage and preconditions', () => {
  it('--help exits 0', () => {
    const r = spawnSync('bash', [SCRIPT, '--help'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('smoke-drive-skills.sh');
  });

  it('exit 2 when claude binary missing', () => {
    const r = run(join(workDir, 'nope-not-here'), []);
    expect(r.status).toBe(2);
    expect(r.stderr).toMatch(/claude binary not found/);
  });
});

describe('smoke-drive-skills — happy path with mock', () => {
  it('--dry-run prints plan and writes nothing', () => {
    writeMockClaude('#!/bin/bash\necho ok\n');
    const outDir = join(workDir, 'out');
    const r = run(mockClaude, ['--dry-run', '--out', outDir]);
    expect(r.status).toBe(0);
    expect(r.stderr).toMatch(/would run/);
    expect(existsSync(outDir)).toBe(false);
  });

  it('happy path — fires 5 default skills; writes 5 capture files', () => {
    // Mock echoes the -p arg so we can verify per-skill capture content.
    writeMockClaude('#!/bin/bash\necho "MOCK_RESPONSE_TO: $*"\n');
    const outDir = join(workDir, 'out');
    const r = run(mockClaude, ['--out', outDir]);
    expect(r.status).toBe(0);
    const files = readdirSync(outDir).sort();
    expect(files).toHaveLength(5);
    // Slugs from default list
    expect(files).toEqual([
      'kiss-words-this-is-verbose-corporate-sounding-text.out',
      'luminary-don-norman.out',
      'state-a-problem-brief-a-sample-problem-for-the-smoke-run.out',
      'temperance.out',
      'whats-the-plan.out',
    ]);
  });

  it('capture contains mock output and records exit code', () => {
    writeMockClaude('#!/bin/bash\necho "MOCK_RESPONSE"\nexit 0\n');
    const outDir = join(workDir, 'out');
    run(mockClaude, ['--out', outDir]);
    const captured = readFileSync(join(outDir, 'temperance.out'), 'utf8');
    expect(captured).toContain('MOCK_RESPONSE');
    expect(captured).toMatch(/=== exit: 0/);
    expect(captured).toMatch(/=== skill: \/temperance/);
  });
});

describe('smoke-drive-skills — failure modes', () => {
  it('non-zero claude exit is captured; overall drive still exits 0 (V1 fold)', () => {
    writeMockClaude('#!/bin/bash\necho "before fail"\nexit 5\n');
    const outDir = join(workDir, 'out');
    const r = run(mockClaude, ['--out', outDir]);
    expect(r.status).toBe(0); // driver completes; downstream assertion writes CRASH row
    const captured = readFileSync(join(outDir, 'temperance.out'), 'utf8');
    expect(captured).toContain('before fail');
    expect(captured).toMatch(/=== exit: 5/);
  });

  it('--timeout kills a hanging skill (exit 142)', () => {
    // Mock sleeps longer than the timeout.
    writeMockClaude('#!/bin/bash\nsleep 10\n');
    const outDir = join(workDir, 'out');
    // 1 second timeout; single-skill list to keep the test fast.
    const skillList = join(workDir, 'skills.txt');
    writeFileSync(skillList, '/temperance\n');
    const r = run(mockClaude, ['--out', outDir, '--timeout', '1', '--skill-list-file', skillList]);
    expect(r.status).toBe(0);
    const captured = readFileSync(join(outDir, 'temperance.out'), 'utf8');
    expect(captured).toMatch(/=== exit: 142/);
  });
});

describe('smoke-drive-skills — flags', () => {
  it('--skill-list-file uses custom skill list', () => {
    writeMockClaude('#!/bin/bash\necho ok\n');
    const outDir = join(workDir, 'out');
    const skillList = join(workDir, 'skills.txt');
    writeFileSync(skillList, '/temperance\n/verify\n');
    const r = run(mockClaude, ['--out', outDir, '--skill-list-file', skillList]);
    expect(r.status).toBe(0);
    const files = readdirSync(outDir).sort();
    expect(files).toEqual(['temperance.out', 'verify.out']);
  });

  it('--out custom-dir writes captures there', () => {
    writeMockClaude('#!/bin/bash\necho ok\n');
    const custom = join(workDir, 'my-custom-dir');
    const skillList = join(workDir, 'skills.txt');
    writeFileSync(skillList, '/temperance\n');
    run(mockClaude, ['--out', custom, '--skill-list-file', skillList]);
    expect(existsSync(join(custom, 'temperance.out'))).toBe(true);
  });
});
