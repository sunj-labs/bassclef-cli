// manifest-io test list — per Beck TDD.
//
// readManifest returns typed data + typed errors. writeManifest is
// atomic via writeSafely.
//
// [x] valid manifest → returns parsed data
// [x] missing manifest file → typed error (Missing)
// [x] malformed JSON → typed error (Malformed)
// [x] manifest with newer schema version than we understand → typed error (SchemaTooNew)
// [x] manifest without $bassclef block → typed error (Malformed)
// [x] legacy manifest without content_hash_sha256 fields → parses OK, hashes are undefined
// [x] writeManifest round-trips: write then read returns the same shape

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import {
  readManifest,
  writeManifest,
  ManifestReadError,
  MANIFEST_SCHEMA_VERSION,
} from '../src/lib/manifest-io.js';

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-manifest-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function writeManifestFile(content: string): void {
  const dir = join(workDir, '.bassclef');
  const path = join(dir, 'init.manifest.json');
  require('node:fs').mkdirSync(dir, { recursive: true, mode: 0o755 });
  writeFileSync(path, content);
}

const CURRENT_MANIFEST_SHAPE = {
  $bassclef: {
    template: 'init.manifest.json',
    manifest_schema_version: MANIFEST_SCHEMA_VERSION,
    generated_by: '@thebassclef/core',
    generated_by_version: '0.0.1',
  },
  created_at: '2026-08-06T00:00:00.000Z',
  target_dir: '/some/path',
  files: [
    {
      path: '.claude/settings.json',
      template: 'settings.json',
      template_version: '0.0.1',
      content_hash_sha256: 'abc123',
      outcome: 'created',
    },
  ],
};

describe('readManifest', () => {
  it('returns parsed data for a valid manifest', () => {
    writeManifestFile(JSON.stringify(CURRENT_MANIFEST_SHAPE));
    const result = readManifest(workDir);
    expect(result.files.length).toBe(1);
    expect(result.files[0]?.path).toBe('.claude/settings.json');
  });

  it('throws Missing when manifest file does not exist', () => {
    expect(() => readManifest(workDir)).toThrow(ManifestReadError);
    try {
      readManifest(workDir);
    } catch (e) {
      expect((e as ManifestReadError).kind).toBe('Missing');
    }
  });

  it('throws Malformed on invalid JSON', () => {
    writeManifestFile('{not valid json');
    try {
      readManifest(workDir);
      throw new Error('should not reach');
    } catch (e) {
      expect((e as ManifestReadError).kind).toBe('Malformed');
    }
  });

  it('throws SchemaTooNew on newer schema version', () => {
    const future = {
      ...CURRENT_MANIFEST_SHAPE,
      $bassclef: {
        ...CURRENT_MANIFEST_SHAPE.$bassclef,
        manifest_schema_version: '99.0.0',
      },
    };
    writeManifestFile(JSON.stringify(future));
    try {
      readManifest(workDir);
      throw new Error('should not reach');
    } catch (e) {
      expect((e as ManifestReadError).kind).toBe('SchemaTooNew');
    }
  });

  it('throws Malformed when $bassclef block is missing', () => {
    const bad = { created_at: 'x', target_dir: '/x', files: [] };
    writeManifestFile(JSON.stringify(bad));
    try {
      readManifest(workDir);
      throw new Error('should not reach');
    } catch (e) {
      expect((e as ManifestReadError).kind).toBe('Malformed');
    }
  });

  it('parses legacy manifest without content_hash_sha256', () => {
    const legacy = {
      ...CURRENT_MANIFEST_SHAPE,
      files: [
        {
          path: '.claude/settings.json',
          template: 'settings.json',
          template_version: '0.0.1',
          outcome: 'created',
        },
      ],
    };
    writeManifestFile(JSON.stringify(legacy));
    const result = readManifest(workDir);
    expect(result.files[0]?.content_hash_sha256).toBeUndefined();
  });
});

describe('writeManifest', () => {
  it('round-trips through readManifest', () => {
    writeManifest(workDir, {
      $bassclef: {
        template: 'init.manifest.json',
        manifest_schema_version: MANIFEST_SCHEMA_VERSION,
        generated_by: '@thebassclef/core',
        generated_by_version: '0.0.1',
      },
      created_at: '2026-08-06T00:00:00.000Z',
      target_dir: workDir,
      files: [
        {
          path: 'substrate.config.md',
          template: 'substrate.config.md',
          template_version: '0.0.1',
          content_hash_sha256: 'deadbeef',
          outcome: 'created',
        },
      ],
    });
    const roundtrip = readManifest(workDir);
    expect(roundtrip.files[0]?.content_hash_sha256).toBe('deadbeef');
  });
});
