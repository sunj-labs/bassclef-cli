// @requirement R-NPM-014
//
// InstallScope — subordinate controller for one `npm install --prefix` call.
// See docs/decompositions/npm-install-harness.md § "InstallScope" for GRASP.

import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { Fixture } from './fixture.js';
import { TarballPackResult } from './tarball-pack.js';

export interface InstalledBinary {
  binPath: string;
}

export class InstallScope {
  constructor(
    private fixture: Fixture,
    private tarball: TarballPackResult,
  ) {}

  async install(): Promise<InstalledBinary> {
    const prefix = this.fixture.npmPrefix();
    // -g plus --prefix installs as a global scoped to the fixture temp dir.
    // Without -g, npm treats this as a local install (writes to
    // <prefix>/node_modules) instead of a global (writes to <prefix>/bin +
    // <prefix>/lib/node_modules). Walking skeleton run caught this — the
    // adopter's `npm install -g @thebassclef/core` puts the binary at
    // <global-prefix>/bin/bassclef, so the harness must mirror that layout.
    // --ignore-scripts blocks any postinstall script execution — mirrors
    // ADR-004 L112 discipline for consistency.
    // --no-audit + --no-fund suppress noise unrelated to install correctness.
    const result = spawnSync(
      'npm',
      [
        'install',
        '-g',
        `--prefix=${prefix}`,
        '--ignore-scripts',
        '--no-audit',
        '--no-fund',
        this.tarball.path,
      ],
      { encoding: 'utf8' },
    );
    if (result.status !== 0) {
      throw new Error(
        `npm install failed (exit ${result.status}): ${result.stderr}`,
      );
    }
    // Locate the installed binary. `npm install --prefix P <tarball>` puts
    // package files under P/lib/node_modules/@thebassclef/core/ and creates
    // a symlink at P/bin/bassclef pointing to the package's dist/cli.js.
    const binPath = path.join(prefix, 'bin', 'bassclef');
    if (!fs.existsSync(binPath)) {
      throw new Error(
        `npm install succeeded but bassclef binary missing at ${binPath}`,
      );
    }
    return { binPath };
  }
}
