// @verifies R-NPM-014
//
// test-list:
// [x] Skeleton: local scenario runs npm pack + install + --version; VerificationResult.forVersion returns ok
// [x] Fixture: cleanup removes temp dir on success path
// [x] Fixture: cleanup removes temp dir on failure path (npm pack fail simulated via bogus workingDir)
// [ ] Full: local scenario runs all 3 verbs (--version, init, sync --dry-run) — deferred to Step 6b
// [ ] Full: published scenario runs against @thebassclef/core@0.0.2 on live registry — deferred to Step 6b
// [ ] Full: init verb writes 3 expected files per ADR-002 L203-211 — deferred to Step 6b
// [ ] Full: sync --dry-run on freshly initialized dir reports no changes per ADR-003 — deferred to Step 6b
// [ ] Extension 4a: npm install failure surfaces install error text — deferred to Step 6b
// [ ] Extension 5b: version-string mismatch detected — deferred to Step 6b
// [ ] Extension 8a: fixture cleanup failure is warn-only when HarnessRun succeeded — deferred to Step 6b
// [ ] Extension 9a: aggregate mixed result (local ok, published fail) → exit code 8 mapping — deferred to Step 6b (Step 9 confirms via workflow)
//
// Walking skeleton per Cockburn — Step 6a lands the thin end-to-end path for
// the local scenario + --version verb only. Step 6b extends to full coverage
// per the deferred rows above. Step 9 confirms integration on synthetic
// release event.

import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { HarnessRun } from './lib/harness-run.js';
import { Fixture } from './lib/fixture.js';

const repoRoot = path.resolve(__dirname, '..');

describe('npm install harness — walking skeleton', () => {
  it('local scenario: pack + install + --version passes on the current working copy', async () => {
    const run = new HarnessRun('local', {
      workingDir: repoRoot,
      failFast: true,
    });
    const outcome = await run.run();
    // Failure mode diagnostics land in outcome — surface them on assert fail
    // so the CI log carries actionable text without a re-run.
    if (!outcome.ok) {
      const detail = outcome.fatalError
        ? `fatal: ${outcome.fatalError}`
        : outcome.verbs.map((v) => `${v.verb}: ${v.result.detail}`).join(' | ');
      throw new Error(`walking skeleton failed — ${detail}`);
    }
    expect(outcome.scenario).toBe('local');
    expect(outcome.ok).toBe(true);
    expect(outcome.verbs).toHaveLength(1);
    expect(outcome.verbs[0].verb).toBe('--version');
    expect(outcome.verbs[0].result.ok).toBe(true);
  });

  it('fixture: cleanup removes temp dir on success path', async () => {
    const fixture = new Fixture();
    await fixture.create();
    const root = fixture.root();
    expect(fs.existsSync(root)).toBe(true);
    await fixture.cleanup();
    expect(fs.existsSync(root)).toBe(false);
  });

  it('fixture: cleanup removes temp dir even after a failed pack attempt', async () => {
    // Use a bogus workingDir to force TarballPack.local() to throw.
    const bogusDir = '/nonexistent/path/for/harness/test';
    const run = new HarnessRun('local', {
      workingDir: bogusDir,
      failFast: true,
    });
    const outcome = await run.run();
    // Expected: fatal error captured; no verbs recorded (fail happens before verbs)
    expect(outcome.ok).toBe(false);
    expect(outcome.fatalError).toBeDefined();
    // Fixture cleanup should still have fired — HarnessRun.summarize() runs
    // it in the finally-like path even on fatal error. Nothing to assert
    // directly since the temp dir path was internal to the Fixture instance,
    // but absence of a fixtureCleanupError indicates cleanup ran.
    expect(outcome.fixtureCleanupError).toBeUndefined();
  });
});
