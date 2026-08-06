// Manifest types + schema-version constant.
//
// Kept in src/lib/ so both commands (init, sync) and the init template
// module can depend on a neutral location. Previously these types
// lived in src/commands/init-templates/manifest-json.ts, which forced
// src/lib/manifest-io.ts to reach across the layer boundary. That
// direction is a layering defect. Types live here now.

export const MANIFEST_SCHEMA_VERSION = '0.0.2' as const;

export interface ManifestEntry {
  path: string;
  template: string;
  template_version: string;
  content_hash_sha256?: string;
  outcome: 'created' | 'unchanged' | 'refused' | 'error' | 'updated';
  updated_at?: string;
}

export interface Manifest {
  $bassclef: {
    template: 'init.manifest.json';
    manifest_schema_version: string;
    generated_by: '@thebassclef/core';
    generated_by_version: string;
  };
  created_at: string;
  target_dir: string;
  files: ManifestEntry[];
}
