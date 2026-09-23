// Characterization tests for scripts/smoke-drive-riff.sh.
//
// Spawns the drive against 6 fixture claude mocks. Verifies exit code +
// stderr tag line + stdout capture shape.
//
// @verifies Epic #199 Story 1 acceptance
//
// Per RFC council disposition Revised A (docs/rfcs/2026-09-21c-smoke-drive-riff-council.md):
// - F1 path traversal — 2 tests (safe path passes; dangerous path exits 1)
// - F2 assertion sub-classes — 3 tests (no-html, empty-html, no-h2)
// - F3 env-miss token detection — 1 test (Playwright BLOCK signature → exit 6)
// - F4 tag-line contract — every test asserts the stderr tag line shape
//
// test-list:
// [x] happy path — fixture writes HTML with <h2>; drive exits 0 with PASS tag
// [x] no-html sub-class — fixture writes nothing; drive exits 3 with FAIL:no-html
// [x] empty-html sub-class — fixture writes 0-byte HTML; drive exits 3 with FAIL:empty-html
// [x] no-h2 sub-class — fixture writes HTML without <h2>; drive exits 3 with FAIL:no-h2
// [x] Playwright block — fixture emits BLOCK message; drive exits 6 with ENV_DEGRADED
// [x] timeout — fixture sleeps past timeout; drive exits 5 with TIMEOUT
// [x] claude missing — CLAUDE_BIN=/nonexistent; drive exits 127
// [x] path traversal — RIFF_SCRATCH=/ ; drive exits 1 with SETUP_FAIL
// [x] teardown — scratch dir removed on success + on assertion fail

import { describe, it, expect, afterAll } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..', '..');
const DRIVE = resolve(REPO_ROOT, 'scripts/smoke-drive-riff.sh');
const FIXTURES = resolve(__dirname, 'fixtures/smoke-drive-riff');

function runDrive(opts: {
  claude: string;
  scratch: string;
  outDir: string;
  timeoutSec?: number;
  skipPrecondition?: boolean;
}) {
  // Tests default to --reset --skip-precondition. Production runs use
  // chain semantics (--no-reset + scaffold-present check).
  const args = [DRIVE, '--out', opts.outDir, '--reset'];
  if (opts.skipPrecondition !== false) {
    args.push('--skip-precondition');
  }
  if (opts.timeoutSec !== undefined) {
    args.push('--timeout', String(opts.timeoutSec));
  }
  return spawnSync('bash', args, {
    encoding: 'utf8',
    env: {
      ...process.env,
      CLAUDE_BIN: opts.claude,
      RIFF_SCRATCH: opts.scratch,
    },
  });
}

describe('scripts/smoke-drive-riff.sh — characterization', () => {
  const workDirs: string[] = [];

  function makeWorkDir(): { scratch: string; outDir: string } {
    const root = mkdtempSync(resolve(tmpdir(), 'smoke-riff-'));
    workDirs.push(root);
    return {
      scratch: resolve(root, 'scratch'),
      outDir: resolve(root, 'out'),
    };
  }

  afterAll(() => {
    for (const d of workDirs) {
      rmSync(d, { recursive: true, force: true });
    }
  });

  it('happy path — HTML with <h2> lands; exit 0 with PASS tag', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-happy.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(0);
    expect(r.stderr).toContain('smoke-drive-riff: PASS');
  });

  it('no-html sub-class — fixture writes nothing; exit 3 FAIL:no-html', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-empty.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(3);
    expect(r.stderr).toContain('smoke-drive-riff: FAIL:no-html');
  });

  it('empty-html sub-class — 0-byte HTML; exit 3 FAIL:empty-html', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-empty-html.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(3);
    expect(r.stderr).toContain('smoke-drive-riff: FAIL:empty-html');
  });

  it('no-h2 sub-class — HTML without <h2>; exit 3 FAIL:no-h2', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-no-h2.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(3);
    expect(r.stderr).toContain('smoke-drive-riff: FAIL:no-h2');
  });

  it('Playwright block — BLOCK message triggers exit 6 ENV_DEGRADED', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-playwright-block.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(6);
    expect(r.stderr).toContain('smoke-drive-riff: ENV_DEGRADED');
    expect(r.stderr.toLowerCase()).toContain('playwright');
  });

  it('MCP generic block — mcp token alone triggers exit 6 (F-AR-1 cure)', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-mcp-generic.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(6);
    expect(r.stderr).toContain('smoke-drive-riff: ENV_DEGRADED');
    expect(r.stderr.toLowerCase()).toContain('mcp');
  });

  it('Browser launch error — browser token triggers exit 6 (F-AR-1 cure)', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-browser-error.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(6);
    expect(r.stderr).toContain('smoke-drive-riff: ENV_DEGRADED');
    expect(r.stderr.toLowerCase()).toContain('browser');
  });

  it('API usage limit — Anthropic 400 usage-limit triggers exit 6 (2026-09-21 verification)', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-api-limit.sh'),
      scratch,
      outDir,
    });
    expect(r.status).toBe(6);
    expect(r.stderr).toContain('smoke-drive-riff: ENV_DEGRADED');
  });

  it('timeout — fixture sleeps past timeout; exit 5 TIMEOUT', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-timeout.sh'),
      scratch,
      outDir,
      timeoutSec: 2,
    });
    expect(r.status).toBe(5);
    expect(r.stderr).toContain('smoke-drive-riff: TIMEOUT');
  }, 15000);

  it('claude binary missing — exit 127', () => {
    const { scratch, outDir } = makeWorkDir();
    const r = runDrive({
      claude: '/nonexistent/claude-binary',
      scratch,
      outDir,
    });
    expect(r.status).toBe(127);
  });

  it('path traversal — RIFF_SCRATCH=/ blocked; exit 1 SETUP_FAIL', () => {
    const { outDir } = makeWorkDir();
    const r = runDrive({
      claude: resolve(FIXTURES, 'claude-happy.sh'),
      scratch: '/',
      outDir,
    });
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('smoke-drive-riff: SETUP_FAIL');
  });

  it('teardown — scratch dir removed on success', () => {
    const { scratch, outDir } = makeWorkDir();
    runDrive({
      claude: resolve(FIXTURES, 'claude-happy.sh'),
      scratch,
      outDir,
    });
    expect(existsSync(scratch)).toBe(false);
  });

  it('teardown — scratch dir removed on assertion fail', () => {
    const { scratch, outDir } = makeWorkDir();
    runDrive({
      claude: resolve(FIXTURES, 'claude-empty.sh'),
      scratch,
      outDir,
    });
    expect(existsSync(scratch)).toBe(false);
  });

  it('precondition — chain mode + no scaffold → exit 1 SETUP_FAIL:not-scaffolded', () => {
    // Real chain semantics: --no-reset + no .claude/skills/riff/SKILL.md
    // in scratch. Simulates the case where /onboard-repo failed upstream.
    const { scratch, outDir } = makeWorkDir();
    // Make scratch dir but leave it un-scaffolded.
    require('node:fs').mkdirSync(scratch, { recursive: true });

    const args = [DRIVE, '--out', outDir, '--no-reset']; // no --skip-precondition
    const r = spawnSync('bash', args, {
      encoding: 'utf8',
      env: {
        ...process.env,
        CLAUDE_BIN: resolve(FIXTURES, 'claude-happy.sh'),
        RIFF_SCRATCH: scratch,
      },
    });
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('smoke-drive-riff: SETUP_FAIL:not-scaffolded');
  });
});
