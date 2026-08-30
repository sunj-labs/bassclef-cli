// Read + validate + write the bassclef init manifest.
//
// Every manifest touch flows through here — ADR-002 complete-mediation
// extended to the manifest file itself.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { writeSafely, mkdirSafely } from './write-safely.js';
import {
  Manifest,
  ManifestEntry,
  MANIFEST_SCHEMA_VERSION,
} from './manifest-types.js';

export const MANIFEST_RELATIVE_PATH = '.bassclef/init.manifest.json';

export class ManifestReadError extends Error {
  override readonly name = 'ManifestReadError';
  readonly kind: 'Missing' | 'Malformed' | 'SchemaTooNew';

  constructor(kind: ManifestReadError['kind'], message: string) {
    super(message);
    this.kind = kind;
  }
}

export function readManifest(targetDir: string): Manifest {
  const path = join(targetDir, MANIFEST_RELATIVE_PATH);
  let raw: string;
  try {
    raw = readFileSync(path, 'utf8');
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === 'ENOENT') {
      throw new ManifestReadError(
        'Missing',
        `not initialized — no manifest at ${path}. Run \`bassclef init\` ` +
          `(or \`bassclef init --force\` if managed files already exist).`
      );
    }
    throw new ManifestReadError('Malformed', `cannot read manifest at ${path}: ${err.code ?? 'unknown'}`);
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ManifestReadError(
      'Malformed',
      `manifest is not valid JSON at ${path}. Repair it by hand or run \`bassclef init --force\` to re-baseline.`
    );
  }

  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    !('$bassclef' in parsed) ||
    typeof (parsed as { $bassclef: unknown }).$bassclef !== 'object' ||
    (parsed as { $bassclef: object }).$bassclef === null
  ) {
    throw new ManifestReadError(
      'Malformed',
      `manifest is missing the $bassclef block at ${path}. Repair or re-baseline via \`bassclef init --force\`.`
    );
  }

  const marker = (parsed as { $bassclef: { manifest_schema_version?: unknown } }).$bassclef;
  const schema = marker.manifest_schema_version;
  if (typeof schema !== 'string') {
    throw new ManifestReadError(
      'Malformed',
      `manifest lacks a $bassclef.manifest_schema_version field at ${path}.`
    );
  }
  if (compareSchemaVersion(schema, MANIFEST_SCHEMA_VERSION) > 0) {
    throw new ManifestReadError(
      'SchemaTooNew',
      `manifest schema version ${schema} is newer than this package understands ` +
        `(${MANIFEST_SCHEMA_VERSION}). Upgrade @thebassclef/core.`
    );
  }

  // Structural check on files[] — accept legacy entries missing content_hash_sha256.
  const obj = parsed as { files?: unknown };
  if (!Array.isArray(obj.files)) {
    throw new ManifestReadError('Malformed', `manifest.files is not an array at ${path}.`);
  }

  return parsed as Manifest;
}

export function writeManifest(targetDir: string, manifest: Manifest): void {
  const path = join(targetDir, MANIFEST_RELATIVE_PATH);
  const body = JSON.stringify(manifest, null, 2) + '\n';
  mkdirSafely(dirname(path));
  writeSafely(path, body, { force: true });
}

// Detect a legacy init manifest — the v0.0.2 shape that carries only
// the 3 config-file entries. Returns true when the manifest was written
// by @thebassclef/core before 0.1.0 introduced the extended substrate
// bundling contract.
//
// @risk R4 — typed module owns manifest inspection; consumers never
// reach into JSON directly.
// @rfc  H1 — schema evolution: v0.0.2 stays readable under this
// discipline; v0.1.0+ manifests read cleanly too because the check
// is additive (files.length AND schema_version, both signals).
//
// Two conditions mark a manifest as legacy:
// 1. files array has 3 entries — the greenfield v0.0.2 init shape
// 2. manifest_schema_version is older than 0.1.0 (the bundling bump)
//
// Either condition alone flips true. Both false means the manifest
// carries the extended shape.
export function detectLegacyManifest(manifest: Manifest): boolean {
  if (manifest.files.length === 3) return true;
  const declaredVersion = manifest.$bassclef.manifest_schema_version;
  if (compareSchemaVersion(declaredVersion, '0.1.0') < 0) return true;
  return false;
}

// Compare semver-shaped strings (major.minor.patch). Returns
// negative / zero / positive like a comparator.
export function compareSchemaVersion(a: string, b: string): number {
  const A = a.split('.').map((x) => parseInt(x, 10));
  const B = b.split('.').map((x) => parseInt(x, 10));
  for (let i = 0; i < Math.max(A.length, B.length); i++) {
    const av = A[i] ?? 0;
    const bv = B[i] ?? 0;
    if (av !== bv) return av - bv;
  }
  return 0;
}

// Re-exports so callers do not need to import from the templates dir.
export { MANIFEST_SCHEMA_VERSION };
export type { ManifestEntry, Manifest };
