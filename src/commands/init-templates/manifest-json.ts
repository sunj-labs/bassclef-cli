// Rendering function for .bassclef/init.manifest.json.
//
// Types + schema-version live in src/lib/manifest-types.ts so this
// module has one job: turn a Manifest into a JSON string.

import { Manifest, MANIFEST_SCHEMA_VERSION, MANIFEST_SHAPE_VERSION, type ManifestEntry } from '../../lib/manifest-types.js';

// The package that actually ships this cli. Was hardcoded to
// '@thebassclef/core', which npm deprecated when the free tier was
// renamed. A manifest naming a dead package sends its reader nowhere.
// Per ADR-010 D9.
const GENERATED_BY = '@thebassclef/lite';

export function manifestTemplate(input: {
  pkgVersion: string;
  targetDir: string;
  files: ManifestEntry[];
}): string {
  const value: Manifest = {
    schema_version: MANIFEST_SHAPE_VERSION,
    $bassclef: {
      template: 'init.manifest.json',
      manifest_schema_version: MANIFEST_SCHEMA_VERSION,
      generated_by: GENERATED_BY,
      generated_by_version: input.pkgVersion,
    },
    created_at: new Date().toISOString(),
    target_dir: input.targetDir,
    files: input.files,
  };
  return JSON.stringify(value, null, 2) + '\n';
}
