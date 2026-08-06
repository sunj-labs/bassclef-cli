// Rendering function for .bassclef/init.manifest.json.
//
// Types + schema-version live in src/lib/manifest-types.ts so this
// module has one job: turn a Manifest into a JSON string.

import { Manifest, MANIFEST_SCHEMA_VERSION, type ManifestEntry } from '../../lib/manifest-types.js';

export function manifestTemplate(input: {
  pkgVersion: string;
  targetDir: string;
  files: ManifestEntry[];
}): string {
  const value: Manifest = {
    $bassclef: {
      template: 'init.manifest.json',
      manifest_schema_version: MANIFEST_SCHEMA_VERSION,
      generated_by: '@thebassclef/core',
      generated_by_version: input.pkgVersion,
    },
    created_at: new Date().toISOString(),
    target_dir: input.targetDir,
    files: input.files,
  };
  return JSON.stringify(value, null, 2) + '\n';
}
