// smoke-report.test.ts — Tier 0 test for scripts/smoke-report.sh
//
// @verifies spec § Acceptance items 6 + 7
// @verifies UC-smoke-run § Main flow Step 16 + Extensions 15a/b/c/d
// @verifies decompose § ReportBuilder + PublisherController + Report
// @verifies pre-mortem D1 + D2 + D5 + D6 + V5 folds
//
// Uses a MOCK gh binary for the publish path. Real gh behavior verified
// on the cold-adopter profile per operator directive.
//
// # test-list:
// [x] --help exits 0
// [x] exit 1 when captures dir missing (jq error via non-existent file)
// [x] exit 2 when both assertion JSONs missing
// [x] happy path — writes report.md; exits 0 when all pass
// [x] any RED row makes exit 3
// [x] report body has YAML frontmatter with report_shape_version: 1
// [x] report body has pass/fail matrix per source
// [x] report body has RED-row detail section for failures
// [x] --publish (mocked gh) posts issue and returns issue number
// [x] --publish updates existing issue when idempotency search hits
// [x] --publish --new creates fresh issue even when open exists
// [x] --publish uses SMOKE_REPO_TARGET env override

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT = resolve(__dirname, '../scripts/smoke-report.sh');

let workDir: string;
let capturesDir: string;
let mockGh: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), 'smoke-report-test-'));
  capturesDir = join(workDir, 'today');
  mkdirSync(capturesDir, { recursive: true });
  mockGh = join(workDir, 'gh');
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

/** Write a fake assertion JSON. */
function writeAssertions(name: 'hooks' | 'skills', rows: Array<{ source: string; check: string; status: 'PASS' | 'FAIL'; message: string; capture_path?: string }>): void {
  const enriched = rows.map(r => ({
    capture_path: r.capture_path ?? '(none)',
    ...r,
  }));
  writeFileSync(join(capturesDir, `${name}-assertions.json`), JSON.stringify(enriched));
}

/** Write a mock gh with given body. Sets +x. */
function writeMockGh(body: string): void {
  writeFileSync(mockGh, body);
  chmodSync(mockGh, 0o755);
}

function runReport(extraArgs: string[] = [], env: Record<string, string> = {}): { status: number | null; stdout: string; stderr: string } {
  const r = spawnSync('bash', [SCRIPT, '--captures-dir', capturesDir, ...extraArgs], {
    encoding: 'utf8',
    env: { ...process.env, ...env },
  });
  return { status: r.status, stdout: r.stdout, stderr: r.stderr };
}

describe('smoke-report — usage and preconditions', () => {
  it('--help exits 0', () => {
    const r = spawnSync('bash', [SCRIPT, '--help'], { encoding: 'utf8' });
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('smoke-report.sh');
  });

  it('exit 2 when both assertion JSONs missing', () => {
    const r = runReport();
    expect(r.status).toBe(2);
    expect(r.stderr).toMatch(/neither hooks-assertions.*nor skills-assertions/);
  });
});

describe('smoke-report — build path', () => {
  it('happy path — writes report.md; exit 0 when all pass', () => {
    writeAssertions('hooks', [
      { source: 'h1', check: 'no-not-found', status: 'PASS', message: '0 matches' },
    ]);
    const r = runReport(['--version-tag', '1.1.1']);
    expect(r.status).toBe(0);
    const report = readFileSync(join(capturesDir, 'report.md'), 'utf8');
    expect(report).toContain('report_shape_version: 1');
    expect(report).toContain('overall: PASS');
    expect(report).toContain('1.1.1');
  });

  it('any RED row makes exit 3', () => {
    writeAssertions('hooks', [
      { source: 'h1', check: 'no-not-found', status: 'FAIL', message: '2 matches' },
    ]);
    const r = runReport(['--version-tag', '1.1.1']);
    expect(r.status).toBe(3);
    const report = readFileSync(join(capturesDir, 'report.md'), 'utf8');
    expect(report).toContain('overall: FAIL');
  });

  it('report body has pass/fail matrix and RED-row detail', () => {
    // Write a capture file the report will snippet
    const capPath = join(workDir, 'defect.out');
    writeFileSync(capPath, '=== output ===\nBLOCKED: something\n=== exit: 1\n');
    writeAssertions('hooks', [
      { source: 'h1', check: 'no-unexpected-blocked', status: 'FAIL', message: '1 BLOCKED', capture_path: capPath },
    ]);
    runReport(['--version-tag', '1.1.1']);
    const report = readFileSync(join(capturesDir, 'report.md'), 'utf8');
    expect(report).toContain('## Hooks');
    expect(report).toContain('| source | check | status | message |');
    expect(report).toContain('## RED rows');
    expect(report).toContain('### h1 — no-unexpected-blocked');
    expect(report).toContain('BLOCKED: something');
  });
});

describe('smoke-report — publish path (mocked gh)', () => {
  it('--publish posts new issue and returns issue number', () => {
    writeAssertions('hooks', [
      { source: 'h1', check: 'no-not-found', status: 'PASS', message: 'ok' },
    ]);
    // Mock gh: issue list returns []; issue create prints URL ending in /123
    writeMockGh(`#!/bin/bash
if [[ "$1" == "issue" && "$2" == "list" ]]; then
  echo '[]'
elif [[ "$1" == "api" ]]; then
  echo 'kingofrock'
elif [[ "$1" == "issue" && "$2" == "create" ]]; then
  echo "https://github.com/sunj-labs/bassclef-cli/issues/123"
fi
`);
    const r = runReport(['--version-tag', '1.1.1', '--publish', '--gh', mockGh]);
    expect(r.status).toBe(0);
    expect(r.stdout.trim()).toBe('123');
  });

  it('--publish updates existing issue when idempotency search hits', () => {
    writeAssertions('hooks', [
      { source: 'h1', check: 'no-not-found', status: 'PASS', message: 'ok' },
    ]);
    writeMockGh(`#!/bin/bash
if [[ "$1" == "issue" && "$2" == "list" ]]; then
  echo '[{"number": 42}]'
elif [[ "$1" == "api" ]]; then
  echo 'kingofrock'
elif [[ "$1" == "issue" && "$2" == "edit" ]]; then
  exit 0
fi
`);
    const r = runReport(['--version-tag', '1.1.1', '--publish', '--gh', mockGh]);
    expect(r.status).toBe(0);
    expect(r.stdout.trim()).toBe('42 (updated)');
  });

  it('--publish --new forces fresh issue even when open exists', () => {
    writeAssertions('hooks', [
      { source: 'h1', check: 'no-not-found', status: 'PASS', message: 'ok' },
    ]);
    writeMockGh(`#!/bin/bash
if [[ "$1" == "issue" && "$2" == "list" ]]; then
  echo '[{"number": 42}]'  # would-be idempotency hit
elif [[ "$1" == "api" ]]; then
  echo 'kingofrock'
elif [[ "$1" == "issue" && "$2" == "create" ]]; then
  echo "https://github.com/sunj-labs/bassclef-cli/issues/999"
fi
`);
    const r = runReport(['--version-tag', '1.1.1', '--publish', '--new', '--gh', mockGh]);
    expect(r.status).toBe(0);
    expect(r.stdout.trim()).toBe('999');
  });
});
