// @requirement R-NPM-014
// @pattern patterns/code/gof/strategy.md (factory-per-verb; catalog check pending Step 8)
//
// VerificationResult — pass/fail judgment per verb. One factory method per
// verb. See docs/decompositions/npm-install-harness.md § "VerificationResult".

import * as fs from 'node:fs';
import * as path from 'node:path';
import { CliCaptured } from './cli-invocation.js';

export class VerificationResult {
  private constructor(
    readonly ok: boolean,
    readonly detail: string,
  ) {}

  static forVersion(captured: CliCaptured, expected: string): VerificationResult {
    if (captured.timedOut) {
      return new VerificationResult(false, `--version timed out`);
    }
    if (captured.exitCode !== 0) {
      return new VerificationResult(
        false,
        `--version exit ${captured.exitCode}; stderr: ${captured.stderr}`,
      );
    }
    if (!captured.stdout.includes(expected)) {
      return new VerificationResult(
        false,
        `--version stdout missing '${expected}'; got: ${captured.stdout}`,
      );
    }
    return new VerificationResult(true, `--version OK (${expected})`);
  }

  static forInit(captured: CliCaptured, initDir: string): VerificationResult {
    if (captured.timedOut) {
      return new VerificationResult(false, `init timed out`);
    }
    if (captured.exitCode !== 0) {
      return new VerificationResult(
        false,
        `init exit ${captured.exitCode}; stderr: ${captured.stderr}`,
      );
    }
    // ADR-002 L203-211 names three files init writes.
    const expected = [
      path.join(initDir, '.claude', 'settings.json'),
      path.join(initDir, 'substrate.config.md'),
      path.join(initDir, '.bassclef', 'init.manifest.json'),
    ];
    const missing = expected.filter((p) => !fs.existsSync(p));
    if (missing.length > 0) {
      return new VerificationResult(
        false,
        `init succeeded but missing files: ${missing.join(', ')}`,
      );
    }
    return new VerificationResult(true, `init OK (${expected.length} files)`);
  }

  static forSyncDryRun(captured: CliCaptured): VerificationResult {
    if (captured.timedOut) {
      return new VerificationResult(false, `sync --dry-run timed out`);
    }
    if (captured.exitCode !== 0) {
      return new VerificationResult(
        false,
        `sync --dry-run exit ${captured.exitCode}; stderr: ${captured.stderr}`,
      );
    }
    // Freshly initialized dir → sync should report no changes. The exact
    // phrase depends on ADR-003; accept any of these variants.
    const noChangePhrases = ['already current', 'no changes', 'up to date'];
    const stdout = captured.stdout.toLowerCase();
    const found = noChangePhrases.some((p) => stdout.includes(p));
    if (!found) {
      return new VerificationResult(
        false,
        `sync --dry-run reported unexpected diff; stdout: ${captured.stdout}`,
      );
    }
    return new VerificationResult(true, `sync --dry-run OK (no diff)`);
  }
}
