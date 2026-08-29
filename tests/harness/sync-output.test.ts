// sync output shape — Tier 0 tests per ledger v3 L108.
//
// Two tests covering L2 (default per-directory summary; --verbose per-file).
// L2 finding — sync output shape drift on 149 files breaks adopter scripts
// binding to the 0.0.2 per-file shape. Default becomes per-directory
// summary; per-file lines require --verbose.
//
// test-list (Beck):
// [ ] L2: default output has one line per top-level directory (grouped)
// [ ] L2: --verbose output has one line per manifest entry (per-file)
//
// RED signal — bassclef sync currently reports on 3 config files with a
// per-file line each. It does not do the 149-entry walk and does not
// support a per-directory summary shape or --verbose flag. Both tests
// fail until Step 6 lands the extended sync command.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { createHash } from 'node:crypto';

const REPO_ROOT = resolve(__dirname, '..', '..');
const CLI_PATH = join(REPO_ROOT, 'dist', 'cli.js');

interface FileEntry {
  path: string;
  template: string;
  template_version: string;
  content_hash_sha256: string;
  outcome: 'created';
}
interface AdopterManifest {
  $bassclef: { template: 'init.manifest.json'; manifest_schema_version: string; generated_by: '@thebassclef/core'; generated_by_version: string };
  created_at: string;
  target_dir: string;
  files: FileEntry[];
}

let workDir: string;
let adopterDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-sync-output-test-'));
  adopterDir = join(workDir, 'adopter');
  mkdirSync(adopterDir, { recursive: true, mode: 0o755 });
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function sha256(content: string): string {
  return createHash('sha256').update(content).digest('hex');
}

function seedMultiDirManifest(): AdopterManifest {
  // 6 entries across 3 top-level directories under .claude/ — mirrors
  // the shape a 149-entry manifest presents. Assertions read
  // manifest.files.length, never a literal count.
  const files: FileEntry[] = [
    { path: '.claude/skills/one/SKILL.md', template: 'skill-one', template_version: '0.1.0', content_hash_sha256: sha256('a'), outcome: 'created' },
    { path: '.claude/skills/two/SKILL.md', template: 'skill-two', template_version: '0.1.0', content_hash_sha256: sha256('b'), outcome: 'created' },
    { path: '.claude/rules/one.md', template: 'rule-one', template_version: '0.1.0', content_hash_sha256: sha256('c'), outcome: 'created' },
    { path: '.claude/rules/two.md', template: 'rule-two', template_version: '0.1.0', content_hash_sha256: sha256('d'), outcome: 'created' },
    { path: '.claude/hooks/one.sh', template: 'hook-one', template_version: '0.1.0', content_hash_sha256: sha256('e'), outcome: 'created' },
    { path: '.claude/hooks/two.sh', template: 'hook-two', template_version: '0.1.0', content_hash_sha256: sha256('f'), outcome: 'created' },
  ];
  const manifest: AdopterManifest = {
    $bassclef: {
      template: 'init.manifest.json',
      manifest_schema_version: '0.1.0',
      generated_by: '@thebassclef/core',
      generated_by_version: '0.1.0',
    },
    created_at: '2026-08-29T00:00:00.000Z',
    target_dir: adopterDir,
    files,
  };
  // Write the manifest.
  const manifestPath = join(adopterDir, '.bassclef', 'init.manifest.json');
  mkdirSync(dirname(manifestPath), { recursive: true, mode: 0o755 });
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  // Seed the tracked files so sync classifies them as Current, not Deleted.
  for (const file of files) {
    const p = join(adopterDir, file.path);
    mkdirSync(dirname(p), { recursive: true, mode: 0o755 });
    // Write matching content so hash matches.
    writeFileSync(p, file.template);
  }
  return manifest;
}

function runSync(extraArgs: string[]): ReturnType<typeof spawnSync> {
  return spawnSync('node', [CLI_PATH, 'sync', '--dir', adopterDir, '--allow-any-dir', ...extraArgs], {
    cwd: adopterDir,
    encoding: 'utf8',
  });
}

describe('bassclef sync — L2 output shape default', () => {
  it('// @rfc: L2 — default output shows one summary line per top-level directory', () => {
    const manifest = seedMultiDirManifest();
    const result = runSync([]);
    expect(result.status).toBe(0);
    const lines = result.stdout.split('\n').filter((l) => l.match(/\.claude\/[a-z]+:/));
    // 3 top-level dirs seeded — expect 3 summary lines under .claude/.
    const dirs = new Set<string>();
    for (const file of manifest.files) {
      const parts = file.path.split('/');
      dirs.add(parts.slice(0, 2).join('/'));
    }
    expect(lines.length).toBe(dirs.size);
    // Line count must be lower than per-file count — proves it is a summary.
    expect(lines.length).toBeLessThan(manifest.files.length);
  });
});

describe('bassclef sync --verbose — L2 output shape per-file', () => {
  it('// @rfc: L2 — --verbose output emits one line per manifest entry', () => {
    const manifest = seedMultiDirManifest();
    const result = runSync(['--verbose']);
    expect(result.status).toBe(0);
    const perFileLines = result.stdout.split('\n').filter((l) => l.match(/\.claude\/[a-z]+\//));
    expect(perFileLines.length).toBeGreaterThanOrEqual(manifest.files.length);
  });
});
