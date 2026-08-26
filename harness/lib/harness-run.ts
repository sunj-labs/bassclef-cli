// @requirement R-NPM-014
// @pattern patterns/code/gof/template-method.md (catalog check pending Step 8)
//
// HarnessRun — top-level Controller. Sequences the pipeline for one scenario
// (local pack OR published fetch). See
// docs/decompositions/npm-install-harness.md § "HarnessRun".

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
      if (this.opts.failFast !== false && !verbs[verbs.length - 1].result.ok) {
        return this.summarize(verbs, fixture);
      }
      // Verb 2 — init (Step 6b extension will enable; skeleton stops here)
      // Verb 3 — sync --dry-run (Step 6b extension will enable; skeleton stops here)
      return await this.summarize(verbs, fixture);
    } catch (err) {
      fatalError = (err as Error).message;
      return await this.summarize(verbs, fixture, fatalError);
    }
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
