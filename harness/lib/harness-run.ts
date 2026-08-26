// @requirement R-NPM-014
//
// HarnessRun — top-level Controller. Sequences the pipeline for one scenario
// (local pack OR published fetch). See
// docs/decompositions/npm-install-harness.md § "HarnessRun".
//
// Pattern note (Step 8): GoF Template Method pattern applies here (the
// pipeline order is fixed; per-scenario variance lives only in the pack()
// factory step). Catalog patterns/code/gof/template-method.md does not yet
// exist in bassclef-upstream. Annotation removed per
// .claude/rules/pattern-annotation.md L46-49. Follow-on ticket tracks
// catalog fill.

import { Fixture } from './fixture.js';
import { TarballPack, TarballPackResult } from './tarball-pack.js';
import { InstallScope } from './install-scope.js';
import { CliInvocation } from './cli-invocation.js';
import { VerificationResult } from './verification.js';

export type HarnessScenario = 'local' | 'published';

export interface HarnessOpts {
  workingDir?: string; // required for local scenario
  packageName?: string; // required for published scenario
  version?: string; // required for published scenario
  timeoutMs?: number;
  failFast?: boolean;
}

export interface HarnessOutcome {
  scenario: HarnessScenario;
  ok: boolean;
  verbs: Array<{ verb: string; result: VerificationResult }>;
  fixtureCleanupError?: string;
  fatalError?: string;
}

export class HarnessRun {
  constructor(
    private scenario: HarnessScenario,
    private opts: HarnessOpts,
  ) {}

  async run(): Promise<HarnessOutcome> {
    const fixture = new Fixture();
    const verbs: HarnessOutcome['verbs'] = [];
    let fatalError: string | undefined;
    try {
      await fixture.create();
      const tarball = await this.pack(fixture);
      const installed = await new InstallScope(fixture, tarball).install();
      // Verb 1 — --version
      const versionCaptured = await new CliInvocation(
        installed.binPath,
        '--version',
        [],
      ).run({ timeoutMs: this.opts.timeoutMs });
      verbs.push({
        verb: '--version',
        result: VerificationResult.forVersion(versionCaptured, tarball.version),
      });
      if (this.shouldStopAfter(verbs)) {
        return this.summarize(verbs, fixture);
      }
      // Verb 2 — init
      // Init verifies ADR-002 behavior. workDir lives under OS tmp (not
      // $HOME), so --allow-any-dir is required per ADR-002 L79-81. Pre-mortem
      // R1.1 flagged this; without the flag init exits 1 refusing to write
      // outside $HOME.
      const workDir = fixture.workDir();
      const initCaptured = await new CliInvocation(
        installed.binPath,
        'init',
        ['--dir', workDir, '--allow-any-dir'],
      ).run({ timeoutMs: this.opts.timeoutMs });
      verbs.push({
        verb: 'init',
        result: VerificationResult.forInit(initCaptured, workDir),
      });
      if (this.shouldStopAfter(verbs)) {
        return this.summarize(verbs, fixture);
      }
      // Verb 3 — sync --dry-run
      // Sync reads what init wrote — same workDir. Dry-run so no state
      // changes. Freshly initialized dir should report no diff per ADR-003.
      const syncCaptured = await new CliInvocation(
        installed.binPath,
        'sync',
        ['--dir', workDir, '--dry-run', '--allow-any-dir'],
      ).run({ timeoutMs: this.opts.timeoutMs });
      verbs.push({
        verb: 'sync --dry-run',
        result: VerificationResult.forSyncDryRun(syncCaptured),
      });
      return await this.summarize(verbs, fixture);
    } catch (err) {
      fatalError = (err as Error).message;
      return await this.summarize(verbs, fixture, fatalError);
    }
  }

  private shouldStopAfter(verbs: HarnessOutcome['verbs']): boolean {
    // failFast defaults true. When true, stop on first failure so the failing
    // verb's captured output surfaces without dilution. When false (e.g., the
    // full-coverage test), run every verb even when one fails so the log
    // carries the full diagnostic set. Pre-mortem R2.2 named this trade-off.
    if (this.opts.failFast === false) {
      return false;
    }
    const last = verbs[verbs.length - 1];
    return last !== undefined && !last.result.ok;
  }

  private async pack(fixture: Fixture): Promise<TarballPackResult> {
    if (this.scenario === 'local') {
      if (!this.opts.workingDir) {
        throw new Error('local scenario needs opts.workingDir');
      }
      return TarballPack.local(this.opts.workingDir, fixture.root());
    }
    if (!this.opts.packageName || !this.opts.version) {
      throw new Error('published scenario needs opts.packageName + opts.version');
    }
    return TarballPack.published(this.opts.packageName, this.opts.version, fixture.root());
  }

  private async summarize(
    verbs: HarnessOutcome['verbs'],
    fixture: Fixture,
    fatalError?: string,
  ): Promise<HarnessOutcome> {
    let cleanupError: string | undefined;
    try {
      await fixture.cleanup();
    } catch (err) {
      cleanupError = (err as Error).message;
    }
    const ok = !fatalError && verbs.every((v) => v.result.ok);
    return {
      scenario: this.scenario,
      ok,
      verbs,
      fixtureCleanupError: cleanupError,
      fatalError,
    };
  }
}
