// @requirement R-NPM-014
//
// TarballPack — one factory per scenario. `local()` runs npm pack in the
// cli working copy. `published()` fetches from live registry with one
// retry per UC Extension 3b + ADR-006 Decision 3. See
// docs/decompositions/npm-install-harness.md § "TarballPack" for GRASP.

import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';

export type TarballSource = 'local' | 'published';

export interface TarballPackResult {
  path: string;
  version: string;
  source: TarballSource;
}

export class TarballPack {
  static async local(workingDir: string, packDestDir: string): Promise<TarballPackResult> {
    // `npm pack --json --pack-destination <dir>` produces the tarball in
    // packDestDir and emits JSON metadata to stdout including the filename
    // + version. Serializes both in one subprocess call.
    const result = spawnSync(
      'npm',
      ['pack', '--json', '--pack-destination', packDestDir],
      { cwd: workingDir, encoding: 'utf8' },
    );
    if (result.status !== 0) {
      throw new Error(
        `npm pack failed in ${workingDir} (exit ${result.status}): ${result.stderr}`,
      );
    }
    const parsed = JSON.parse(result.stdout);
    // npm pack --json returns an array; one element per packed package.
    const entry = Array.isArray(parsed) ? parsed[0] : parsed;
    const filename = entry.filename as string;
    const version = entry.version as string;
    const tarballPath = path.join(packDestDir, filename);
    // Sanity — file must exist. Catches the case where npm reports success
    // but the tarball landed somewhere unexpected.
    if (!fs.existsSync(tarballPath)) {
      throw new Error(`npm pack reported success but tarball missing at ${tarballPath}`);
    }
    return { path: tarballPath, version, source: 'local' };
  }

  static async published(
    packageName: string,
    version: string,
    packDestDir: string,
  ): Promise<TarballPackResult> {
    // One retry per UC Extension 3b — transient registry flakes.
    const spec = `${packageName}@${version}`;
    for (let attempt = 1; attempt <= 2; attempt++) {
      const result = spawnSync(
        'npm',
        ['pack', spec, '--json', '--pack-destination', packDestDir],
        { encoding: 'utf8' },
      );
      if (result.status === 0) {
        const parsed = JSON.parse(result.stdout);
        const entry = Array.isArray(parsed) ? parsed[0] : parsed;
        const filename = entry.filename as string;
        const resolvedVersion = entry.version as string;
        const tarballPath = path.join(packDestDir, filename);
        if (!fs.existsSync(tarballPath)) {
          throw new Error(
            `npm pack reported success but tarball missing at ${tarballPath}`,
          );
        }
        return { path: tarballPath, version: resolvedVersion, source: 'published' };
      }
      if (attempt === 1) {
        // Wait 5s before retry per UC Extension 3b.
        await new Promise((r) => setTimeout(r, 5000));
      } else {
        throw new Error(
          `npm pack ${spec} failed after 2 attempts (exit ${result.status}): ${result.stderr}`,
        );
      }
    }
    // Unreachable — the loop above always returns or throws.
    throw new Error('TarballPack.published() reached unreachable branch');
  }
}
