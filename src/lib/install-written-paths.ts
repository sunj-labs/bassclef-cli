// Install-written-paths manifest writer (bassclef-upstream#2036 Finding #8).
//
// Writes `<targetDir>/state/install-written-paths.json` matching the schema
// bassclef-upstream's lib/install-written-paths.sh reads via
// `is_install_written_path`. Discipline hooks (pre-commit-identifier-leak-scrub,
// pre-commit-gate 3-marker section, etc.) consult the manifest and skip
// install-written paths. Without this register call, every bassclef init on
// a cold adopter leaves the manifest empty and the hooks fire false-positives
// on the dispatcher-written files.
//
// Shape mirrors lib/install-written-paths.sh install_written_paths_register:
//
//   {
//     "schema_version": "1.0.0",
//     "entries": [
//       { "path": "<rel>", "writer": "bassclef-init-npm",
//         "written_at": "<ISO>", "content_hash": "sha256:<64-hex>" }
//     ]
//   }
//
// Idempotent on path: existing entry for a path is replaced.

import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const SCHEMA_VERSION = '1.0.0' as const;

// Writer slug the sibling lib's _IWP_WRITERS enum accepts.
const WRITER_SLUG = 'bassclef-init-npm' as const;

export interface InstallWrittenPathEntry {
  path: string;
  writer: typeof WRITER_SLUG;
  written_at: string;
  content_hash: string;
}

export interface InstallWrittenPathsManifest {
  schema_version: typeof SCHEMA_VERSION;
  entries: InstallWrittenPathEntry[];
}

export interface RegisterInput {
  /** Repo-relative path exactly as recorded in init.manifest.json. */
  relativePath: string;
  /** Pre-computed sha256 of what the writer wrote (bare 64-hex, no prefix). */
  contentHashSha256: string;
}

export function registerInstallWrittenPaths(
  targetDir: string,
  paths: ReadonlyArray<RegisterInput>,
  now: Date = new Date()
): void {
  if (paths.length === 0) return;

  const manifestPath = join(targetDir, 'state', 'install-written-paths.json');

  let manifest: InstallWrittenPathsManifest = {
    schema_version: SCHEMA_VERSION,
    entries: [],
  };

  if (existsSync(manifestPath)) {
    try {
      const parsed = JSON.parse(readFileSync(manifestPath, 'utf8')) as unknown;
      if (
        parsed &&
        typeof parsed === 'object' &&
        'entries' in parsed &&
        Array.isArray((parsed as { entries: unknown }).entries)
      ) {
        manifest = parsed as InstallWrittenPathsManifest;
        manifest.schema_version = SCHEMA_VERSION;
      }
    } catch {
      // Malformed existing manifest — overwrite with a fresh one. Fail-soft
      // per @luminary michael-nygard; preserving corrupted state helps nobody.
    }
  }

  const writtenAt = now.toISOString().replace(/\.\d{3}Z$/, 'Z');

  // Dedupe within the current input first — bassclef init dual-writes
  // undeclared hooks to both user and project scope, so copiedEntries
  // can carry the same adopter-relative path twice. The sibling lib
  // keys on path alone (not path + scope), so one entry per path is
  // the correct shape; last entry wins (content is identical across
  // scopes).
  const uniqueInputs = new Map<string, RegisterInput>();
  for (const p of paths) {
    uniqueInputs.set(p.relativePath, p);
  }

  const incomingPaths = new Set(uniqueInputs.keys());
  manifest.entries = manifest.entries.filter((e) => !incomingPaths.has(e.path));

  for (const p of uniqueInputs.values()) {
    manifest.entries.push({
      path: p.relativePath,
      writer: WRITER_SLUG,
      written_at: writtenAt,
      content_hash: `sha256:${p.contentHashSha256}`,
    });
  }

  mkdirSync(dirname(manifestPath), { recursive: true });
  writeFileSync(
    manifestPath,
    JSON.stringify(manifest, null, 2) + '\n',
    'utf8'
  );
}

export function hashBytes(content: string): string {
  return createHash('sha256').update(content).digest('hex');
}
