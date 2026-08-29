// manifest-io legacy detection + schema evolution — Tier 0 tests per ledger v3 L107.
//
// Three tests covering R4 (typed module wraps JSON) + H1 (schema
// evolution: v0.0.2 shape is subset of extended v0.1.0).
//
// test-list (Beck):
// [ ] R4: no `JSON.parse.*manifest` outside src/lib/ (grep audit)
// [ ] H1: v0.0.2 fixture reads clean under readManifest (superset preserved)
// [ ] detectLegacyManifest returns true for 3-entry legacy; false for extended
//
// RED signal — detectLegacyManifest does not exist yet in src/lib/manifest-io.ts.
// Import fails; every test in this file counts as failed until Step 6 extends
// the module (~20 LOC per decomp § Control objects — manifest-io.ts EXTENDED).

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve, dirname } from 'node:path';

import { readManifest, detectLegacyManifest } from '../../src/lib/manifest-io.js';
import type { Manifest } from '../../src/lib/manifest-types.js';

const REPO_ROOT = resolve(__dirname, '..', '..');
const LEGACY_FIXTURE_PATH = join(REPO_ROOT, 'tests', 'fixtures', 'v0.0.2-init-manifest.json');

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-manifest-legacy-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function seedManifestAt(targetDir: string, body: string): void {
  const manifestPath = join(targetDir, '.bassclef', 'init.manifest.json');
  mkdirSync(dirname(manifestPath), { recursive: true, mode: 0o755 });
  writeFileSync(manifestPath, body);
}

describe('manifest-io — R4 typed wrapper', () => {
  it('// @risk: R4 — no JSON.parse targets a manifest outside src/lib/', () => {
    const srcDir = join(REPO_ROOT, 'src');
    // Grep for any JSON.parse call whose line references "manifest".
    const result = spawnSync('grep', ['-rE', 'JSON\\.parse.*manifest', srcDir, '--exclude-dir=lib'], {
      encoding: 'utf8',
    });
    // grep exit code 1 means no match — the passing shape.
    expect(result.status).toBe(1);
    expect(result.stdout.trim()).toBe('');
  });
});

describe('manifest-io — H1 schema evolution', () => {
  it('// @rfc: H1 — v0.0.2 fixture reads clean under readManifest with every field preserved', () => {
    const fixtureBody = readFileSync(LEGACY_FIXTURE_PATH, 'utf8');
    seedManifestAt(workDir, fixtureBody);
    const parsed = readManifest(workDir);
    // Every v0.0.2 field must survive.
    expect(parsed.$bassclef.manifest_schema_version).toBe('0.0.2');
    expect(parsed.$bassclef.generated_by).toBe('@thebassclef/core');
    expect(parsed.files.length).toBe(3);
    // Confirm every file entry preserved its fields.
    for (const file of parsed.files) {
      expect(file.path).toBeTruthy();
      expect(file.template).toBeTruthy();
      expect(file.template_version).toBeTruthy();
      expect(file.content_hash_sha256).toMatch(/^[0-9a-f]{64}$/);
      expect(file.outcome).toBe('created');
    }
  });
});

describe('manifest-io — detectLegacyManifest', () => {
  it('returns true for a 3-entry v0.0.2 init manifest and false for an extended manifest', () => {
    const fixtureBody = readFileSync(LEGACY_FIXTURE_PATH, 'utf8');
    const legacy = JSON.parse(fixtureBody) as Manifest;
    expect(detectLegacyManifest(legacy)).toBe(true);

    // Extended shape — more files, bumped schema version.
    const extended: Manifest = {
      $bassclef: {
        template: 'init.manifest.json',
        manifest_schema_version: '0.1.0',
        generated_by: '@thebassclef/core',
        generated_by_version: '0.1.0',
      },
      created_at: '2026-08-29T00:00:00.000Z',
      target_dir: '/adopter',
      files: [
        ...legacy.files,
        { path: '.claude/skills/one/SKILL.md', template: 'one', template_version: '0.1.0', content_hash_sha256: 'd'.repeat(64), outcome: 'created' },
        { path: '.claude/rules/one.md', template: 'one', template_version: '0.1.0', content_hash_sha256: 'e'.repeat(64), outcome: 'created' },
      ],
    };
    expect(detectLegacyManifest(extended)).toBe(false);
  });
});
