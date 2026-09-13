// Manifest types + schema-version constant.
//
// Kept in src/lib/ so both commands (init, sync) and the init template
// module can depend on a neutral location. Previously these types
// lived in src/commands/init-templates/manifest-json.ts, which forced
// src/lib/manifest-io.ts to reach across the layer boundary. That
// direction is a layering defect. Types live here now.

// Bumped to 0.1.0 alongside @thebassclef/core 0.1.0 per H1 discipline —
// the extended manifest shape (149-entry substrate bundle) is additive
// over the 0.0.2 3-entry init shape. detectLegacyManifest reads this
// constant to decide when a manifest predates the bundling contract.
export const MANIFEST_SCHEMA_VERSION = '0.1.0' as const;

// Top-level shape-version integer added cli 1.0.1 per RFC-0002 L2 fold.
// Distinct from the string $bassclef.manifest_schema_version — this
// integer marks the shape gate for adopter tooling that reads the manifest.
// v1 (implicit — no field): no per-entry scope field.
// v2: per-entry scope field ('user' | 'project') on hook entries.
export const MANIFEST_SHAPE_VERSION = 2 as const;

export interface ManifestEntry {
  path: string;
  template: string;
  template_version: string;
  content_hash_sha256?: string;
  outcome: 'created' | 'unchanged' | 'refused' | 'error' | 'updated';
  updated_at?: string;
  /** Scope the file landed at ('user' | 'project'). Cli 1.0.1+ per RFC-0002 F6+L2. */
  scope?: 'user' | 'project';
}

export interface Manifest {
  /** Top-level shape marker per RFC-0002 L2. Integer 2 as of cli 1.0.1. */
  schema_version: typeof MANIFEST_SHAPE_VERSION;
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
