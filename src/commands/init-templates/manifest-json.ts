// Init manifest — .bassclef/init.manifest.json.
//
// Written by `bassclef init` on every successful (or partial) run.
// The manifest records:
//   - which files init wrote or skipped
//   - the template version each file used
//   - the package version of `@thebassclef/core` at run time
//   - the ISO timestamp of the run
//
// The sync command (later work) reads the manifest to know exactly
// which templates need upgrading — no content hash guessing, no full
// history walk. If the manifest is missing (older init, or user
// deleted it), sync falls back to a safe "read the marker keys inside
// each written file" flow.
//
// A future `bassclef uninit` command reads the manifest to reverse
// the writes safely.

export const MANIFEST_TEMPLATE_VERSION = '0.0.1' as const;

export interface ManifestEntry {
  path: string;
  template: string;
  template_version: string;
  outcome: 'created' | 'unchanged' | 'refused' | 'error';
}

export interface Manifest {
  $bassclef: {
    template: 'init.manifest.json';
    template_version: typeof MANIFEST_TEMPLATE_VERSION;
    generated_by: '@thebassclef/core';
    generated_by_version: string;
  };
  created_at: string;
  target_dir: string;
  files: ManifestEntry[];
}

export function manifestTemplate(input: {
  pkgVersion: string;
  targetDir: string;
  files: ManifestEntry[];
}): string {
  const value: Manifest = {
    $bassclef: {
      template: 'init.manifest.json',
      template_version: MANIFEST_TEMPLATE_VERSION,
      generated_by: '@thebassclef/core',
      generated_by_version: input.pkgVersion,
    },
    created_at: new Date().toISOString(),
    target_dir: input.targetDir,
    files: input.files,
  };
  return JSON.stringify(value, null, 2) + '\n';
}
