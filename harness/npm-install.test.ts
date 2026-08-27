// @verifies R-NPM-014
//
// test-list:
// [x] Skeleton: local scenario runs npm pack + install + --version; VerificationResult.forVersion returns ok
// [x] Fixture: cleanup removes temp dir on success path
// [x] Fixture: cleanup removes temp dir on failure path (npm pack fail simulated via bogus workingDir)
// [x] Full: local scenario runs all 3 verbs (--version, init, sync --dry-run) end to end
// [x] Extension 5b: version-string mismatch detected by VerificationResult.forVersion
// [x] Extension 6b: init missing expected files detected by VerificationResult.forInit
// [x] Extension 7a: sync --dry-run unexpected diff detected by VerificationResult.forSyncDryRun
// [x] Extension 8a-adjacent: verification failure text carries actionable detail (exit code + stderr)
// [~] Full: published scenario runs against live registry — env-gated (HARNESS_INCLUDE_PUBLISHED=1) so local runs default off; CI enables on release event
// [~] Extension 4a: npm install failure surfaces install error text — deferred to Step 9 integration (needs a broken tarball fixture to simulate deterministically)
// [~] Extension 2a: temp dir creation failure — deferred to Step 9 (hard to simulate without mocking fs.mkdtempSync)
// [~] Extension 8a: fixture cleanup failure warn-only when HarnessRun succeeded — deferred to Step 9 (needs a locked dir simulation)
// [~] Extension 9a: aggregate mixed result exit code 8 mapping — deferred to Step 9 (verified via workflow, not test file)
//
// Step 6a landed thin end-to-end for --version verb only. Step 6b extends to
// all 3 verbs + published scenario + 4 extension paths via VerificationResult
// unit tests. Deferred rows have explicit rationale — 4 belong to Step 9
// (integration + workflow verify), 1 stays env-gated at all times.

import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { HarnessRun } from './lib/harness-run.js';
import { Fixture } from './lib/fixture.js';
import { VerificationResult } from './lib/verification.js';
import type { CliCaptured } from './lib/cli-invocation.js';

const repoRoot = path.resolve(__dirname, '..');

// Helper — build a mock CliCaptured for extension unit tests without
// spawning a subprocess. Keeps extension coverage fast + deterministic.
function mockCaptured(overrides: Partial<CliCaptured> = {}): CliCaptured {
  return {
    exitCode: 0,
    stdout: '',
    stderr: '',
    timedOut: false,
    ...overrides,
  };
}

// Step 6b superseded the walking-skeleton "local scenario / --version only"
// test with the "full local scenario / all 3 verbs" test in the block below.
// The 2 fixture-direct tests stay — they exercise Fixture without going
// through HarnessRun, which the full-coverage test does not do.

describe('npm install harness — fixture behavior (direct)', () => {
  it('fixture: cleanup removes temp dir on success path', async () => {
    const fixture = new Fixture();
    await fixture.create();
    const root = fixture.root();
    expect(fs.existsSync(root)).toBe(true);
    await fixture.cleanup();
    expect(fs.existsSync(root)).toBe(false);
  });

  it('fixture: cleanup removes temp dir even after a failed pack attempt', async () => {
    const bogusDir = '/nonexistent/path/for/harness/test';
    const run = new HarnessRun('local', {
      workingDir: bogusDir,
      failFast: true,
    });
    const outcome = await run.run();
    expect(outcome.ok).toBe(false);
    expect(outcome.fatalError).toBeDefined();
    expect(outcome.fixtureCleanupError).toBeUndefined();
  });
});

describe('npm install harness — full local scenario', () => {
  it('local scenario: all 3 verbs (--version, init, sync --dry-run) pass end to end', async () => {
    // failFast: false so all 3 verbs run regardless — full diagnostic on any
    // single-verb failure lands in the log. Pre-mortem R2.2 named the reason.
    const run = new HarnessRun('local', {
      workingDir: repoRoot,
      failFast: false,
    });
    const outcome = await run.run();
    if (!outcome.ok) {
      const detail = outcome.fatalError
        ? `fatal: ${outcome.fatalError}`
        : outcome.verbs.map((v) => `${v.verb}: ${v.result.detail}`).join(' | ');
      throw new Error(`full local scenario failed — ${detail}`);
    }
    expect(outcome.scenario).toBe('local');
    expect(outcome.ok).toBe(true);
    expect(outcome.verbs).toHaveLength(3);
    expect(outcome.verbs.map((v) => v.verb)).toEqual([
      '--version',
      'init',
      'sync --dry-run',
    ]);
    expect(outcome.verbs.every((v) => v.result.ok)).toBe(true);
  });
});

// Published-fetch scenario runs against the live npm registry. Gated on env
// var HARNESS_INCLUDE_PUBLISHED — default off in local dev (avoids network
// dependency + flake). CI workflow sets the env var on release-triggered
// runs. Pre-mortem R1.3 named the reason.
const shouldRunPublished = process.env.HARNESS_INCLUDE_PUBLISHED === '1';
const publishedIt = shouldRunPublished ? it : it.skip;

describe('npm install harness — published scenario (env-gated)', () => {
  publishedIt(
    'published scenario: fetch @thebassclef/core@0.0.2 from live registry; 3 verbs pass',
    async () => {
      const run = new HarnessRun('published', {
        packageName: '@thebassclef/core',
        version: '0.0.2',
        failFast: false,
      });
      const outcome = await run.run();
      if (!outcome.ok) {
        const detail = outcome.fatalError
          ? `fatal: ${outcome.fatalError}`
          : outcome.verbs.map((v) => `${v.verb}: ${v.result.detail}`).join(' | ');
        throw new Error(`published scenario failed — ${detail}`);
      }
      expect(outcome.scenario).toBe('published');
      expect(outcome.ok).toBe(true);
      expect(outcome.verbs).toHaveLength(3);
    },
    120000, // 120s override — published fetch adds network hop + retry window
  );
});

// Extension unit tests — exercise VerificationResult factory methods
// directly with mock CliCaptured. No subprocess spawning; fast + deterministic.
// Extension paths verify UC extensions 5b, 6b, 7a per pre-mortem R2.3.

describe('npm install harness — extension coverage (unit tests)', () => {
  it('Extension 5b — VerificationResult.forVersion detects version-string mismatch', () => {
    const captured = mockCaptured({ stdout: '0.9.9\n' });
    const result = VerificationResult.forVersion(captured, '0.0.2');
    expect(result.ok).toBe(false);
    expect(result.detail).toContain("--version stdout missing '0.0.2'");
    expect(result.detail).toContain('0.9.9');
  });

  it('Extension 5b — VerificationResult.forVersion detects non-zero exit', () => {
    const captured = mockCaptured({ exitCode: 1, stderr: 'permission denied' });
    const result = VerificationResult.forVersion(captured, '0.0.2');
    expect(result.ok).toBe(false);
    expect(result.detail).toContain('--version exit 1');
    expect(result.detail).toContain('permission denied');
  });

  it('Extension 5b — VerificationResult.forVersion detects timeout', () => {
    const captured = mockCaptured({ timedOut: true });
    const result = VerificationResult.forVersion(captured, '0.0.2');
    expect(result.ok).toBe(false);
    expect(result.detail).toContain('timed out');
  });

  it('Extension 6b — VerificationResult.forInit detects missing expected files', () => {
    // Init reported success but no files exist at initDir — should fail.
    const captured = mockCaptured({ exitCode: 0, stdout: 'created 3 files' });
    const initDir = '/tmp/nonexistent-harness-init-dir-2026-08-27';
    const result = VerificationResult.forInit(captured, initDir);
    expect(result.ok).toBe(false);
    expect(result.detail).toContain('missing files');
    // All three expected paths should appear in the missing list
    expect(result.detail).toContain('.claude/settings.json');
    expect(result.detail).toContain('substrate.config.md');
    expect(result.detail).toContain('.bassclef/init.manifest.json');
  });

  it('Extension 6b — VerificationResult.forInit passes when 3 expected files exist', () => {
    // Create a fixture-like layout with the 3 files, then verify.
    const fixture = new Fixture();
    return fixture.create().then(async () => {
      try {
        const initDir = fixture.workDir();
        fs.mkdirSync(path.join(initDir, '.claude'), { recursive: true });
        fs.mkdirSync(path.join(initDir, '.bassclef'), { recursive: true });
        fs.writeFileSync(path.join(initDir, '.claude', 'settings.json'), '{}');
        fs.writeFileSync(path.join(initDir, 'substrate.config.md'), '# stub');
        fs.writeFileSync(
          path.join(initDir, '.bassclef', 'init.manifest.json'),
          '{}',
        );
        const captured = mockCaptured({ stdout: 'created 3 files' });
        const result = VerificationResult.forInit(captured, initDir);
        expect(result.ok).toBe(true);
        expect(result.detail).toContain('init OK');
      } finally {
        await fixture.cleanup();
      }
    });
  });

  it('Extension 7a — VerificationResult.forSyncDryRun detects unexpected diff (no known no-change phrase)', () => {
    const captured = mockCaptured({
      exitCode: 0,
      stdout: 'files pending: settings.json (drift detected)',
    });
    const result = VerificationResult.forSyncDryRun(captured);
    expect(result.ok).toBe(false);
    expect(result.detail).toContain('unexpected diff');
  });

  it('Extension 7a — VerificationResult.forSyncDryRun accepts "already current"', () => {
    const captured = mockCaptured({ stdout: 'already current — no changes' });
    const result = VerificationResult.forSyncDryRun(captured);
    expect(result.ok).toBe(true);
    expect(result.detail).toContain('sync --dry-run OK');
  });

  it('Extension 7a — VerificationResult.forSyncDryRun accepts "up to date"', () => {
    const captured = mockCaptured({ stdout: 'files up to date' });
    const result = VerificationResult.forSyncDryRun(captured);
    expect(result.ok).toBe(true);
  });
});
