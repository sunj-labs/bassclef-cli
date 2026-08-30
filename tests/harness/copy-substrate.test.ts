// copySubstrate harness — Tier 0 tests per ledger v3 L106.
//
// Ten tests covering R1 (one export), R3 (no direct writeFileSync),
// R5 (no substrate/ literal in commands), R7-fallback (hash mismatch),
// N1 (per-directory progress), N2 (error messages name the fix).
//
// test-list (Beck):
// [ ] R1: src/lib/copy-substrate.ts exports exactly one symbol
// [ ] happy: 3-file fixture → all 3 copied; result.copied.length matches
// [ ] R3: no fs.writeFileSync in copy-substrate.ts (grep audit)
// [ ] R5: no literal 'substrate/' in src/commands/ (grep audit)
// [ ] refused: existing target file → refused; content preserved
// [ ] --force: existing target file → overwritten
// [ ] --dry-run: nothing written; wouldCopy list populated
// [ ] R7-fallback: bundle content hash mismatch → errored + file named
// [ ] N2: error message names the fix ('rerun ... --force' or equivalent)
// [ ] N1: per-directory progress line fires once per directory
//
// RED signal — src/lib/copy-substrate.ts does not exist at Step 4.
// Vitest parse fails at the import statement. Every test in this file
// is counted as failed until Step 6 lands the module.
//
// @rfc H2 — count parameterization: no literal 146 in assertions.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { createHash } from 'node:crypto';

import { copySubstrate } from '../../src/lib/copy-substrate.js';

const REPO_ROOT = resolve(__dirname, '..', '..');
const COPY_MODULE_PATH = join(REPO_ROOT, 'src', 'lib', 'copy-substrate.ts');

interface MiniEntry {
  path: string;
  content_hash: string;
  slug: string;
  tier: string;
  type: string;
}
interface MiniManifest {
  entries: MiniEntry[];
}

let workDir: string;
let targetDir: string;
let bundleRoot: string; // simulates the npm-package substrate/ tree

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-copy-test-'));
  targetDir = join(workDir, 'adopter');
  bundleRoot = join(workDir, 'bundle', 'substrate');
  mkdirSync(targetDir, { recursive: true, mode: 0o755 });
  mkdirSync(bundleRoot, { recursive: true, mode: 0o755 });
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function sha256(content: string): string {
  return 'sha256:' + createHash('sha256').update(content).digest('hex');
}

function seedBundle(manifest: MiniManifest, contentPerFile: Record<string, string>): void {
  const manifestPath = join(bundleRoot, '.bassclef', 'lite-manifest.json');
  mkdirSync(dirname(manifestPath), { recursive: true, mode: 0o755 });
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  for (const entry of manifest.entries) {
    const p = join(bundleRoot, entry.path);
    mkdirSync(dirname(p), { recursive: true, mode: 0o755 });
    writeFileSync(p, contentPerFile[entry.path] ?? '');
  }
}

function threeEntryManifest(): MiniManifest {
  return {
    entries: [
      { path: '.claude/skills/example/SKILL.md', content_hash: sha256('skill'), slug: 'example-skill', tier: 'lite', type: 'skill' },
      { path: '.claude/rules/example.md', content_hash: sha256('rule'), slug: 'example-rule', tier: 'lite', type: 'rule' },
      { path: '.claude/hooks/example.sh', content_hash: sha256('hook'), slug: 'example-hook', tier: 'lite', type: 'hook' },
    ],
  };
}

describe('copySubstrate — R1 module shape', () => {
  it('// @risk: R1 — src/lib/copy-substrate.ts exports exactly one symbol', () => {
    expect(existsSync(COPY_MODULE_PATH)).toBe(true);
    const src = readFileSync(COPY_MODULE_PATH, 'utf8');
    // Count top-of-line export statements. `export type` and `export interface` count.
    const exports = src.match(/^\s*export\s+(?!\*|\{)/gm) ?? [];
    expect(exports.length).toBe(1);
  });
});

describe('copySubstrate — happy path', () => {
  it('copies every manifest entry into the target dir', async () => {
    const manifest = threeEntryManifest();
    const content: Record<string, string> = {
      '.claude/skills/example/SKILL.md': 'skill',
      '.claude/rules/example.md': 'rule',
      '.claude/hooks/example.sh': 'hook',
    };
    seedBundle(manifest, content);
    const result = await copySubstrate(targetDir, { bundleRoot });
    expect(result.copied.length).toBe(manifest.entries.length);
    expect(result.errored.length).toBe(0);
    expect(readFileSync(join(targetDir, '.claude/skills/example/SKILL.md'), 'utf8')).toBe('skill');
  });
});

describe('copySubstrate — R3 no direct writeFileSync', () => {
  it('// @risk: R3 — copy-substrate.ts does not call fs.writeFileSync directly', () => {
    expect(existsSync(COPY_MODULE_PATH)).toBe(true);
    const src = readFileSync(COPY_MODULE_PATH, 'utf8');
    const withoutComments = src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
    expect(withoutComments).not.toMatch(/\bwriteFileSync\b/);
  });
});

describe('copySubstrate — R5 no substrate literal in commands', () => {
  it('// @risk: R5 — no literal "substrate/" string in src/commands/', () => {
    const commandsDir = join(REPO_ROOT, 'src', 'commands');
    const result = spawnSync('grep', ['-rE', "'substrate/", commandsDir], { encoding: 'utf8' });
    // grep exit code 1 means no match found — the passing shape.
    expect(result.status).toBe(1);
    expect(result.stdout.trim()).toBe('');
  });
});

describe('copySubstrate — refused behavior', () => {
  it('refuses to overwrite an existing file by default and preserves original content', async () => {
    const manifest: MiniManifest = {
      entries: [{ path: '.claude/rules/example.md', content_hash: sha256('new'), slug: 'ex', tier: 'lite', type: 'rule' }],
    };
    seedBundle(manifest, { '.claude/rules/example.md': 'new' });
    // Pre-seed adopter with existing content.
    const existing = join(targetDir, '.claude/rules/example.md');
    mkdirSync(dirname(existing), { recursive: true, mode: 0o755 });
    writeFileSync(existing, 'ORIGINAL');
    const result = await copySubstrate(targetDir, { bundleRoot });
    expect(result.refused.length).toBe(1);
    expect(result.copied.length).toBe(0);
    expect(readFileSync(existing, 'utf8')).toBe('ORIGINAL');
  });
});

describe('copySubstrate — --force behavior', () => {
  it('overwrites an existing file when force is true', async () => {
    const manifest: MiniManifest = {
      entries: [{ path: '.claude/rules/example.md', content_hash: sha256('new'), slug: 'ex', tier: 'lite', type: 'rule' }],
    };
    seedBundle(manifest, { '.claude/rules/example.md': 'new' });
    const existing = join(targetDir, '.claude/rules/example.md');
    mkdirSync(dirname(existing), { recursive: true, mode: 0o755 });
    writeFileSync(existing, 'ORIGINAL');
    const result = await copySubstrate(targetDir, { bundleRoot, force: true });
    expect(result.copied.length).toBe(1);
    expect(readFileSync(existing, 'utf8')).toBe('new');
  });
});

describe('copySubstrate — --dry-run behavior', () => {
  it('writes nothing and reports every entry as wouldCopy', async () => {
    const manifest = threeEntryManifest();
    seedBundle(manifest, {
      '.claude/skills/example/SKILL.md': 'skill',
      '.claude/rules/example.md': 'rule',
      '.claude/hooks/example.sh': 'hook',
    });
    const result = await copySubstrate(targetDir, { bundleRoot, dryRun: true });
    expect(result.wouldCopy?.length).toBe(manifest.entries.length);
    expect(result.copied.length).toBe(0);
    expect(existsSync(join(targetDir, '.claude'))).toBe(false);
  });
});

describe('copySubstrate — R7 fallback hash mismatch', () => {
  it('// @risk: R7-fallback — content hash mismatch marks the entry errored and names the file', async () => {
    const manifest: MiniManifest = {
      entries: [
        // manifest declares a hash that will NOT match the seeded content.
        { path: '.claude/rules/example.md', content_hash: sha256('declared'), slug: 'ex', tier: 'lite', type: 'rule' },
      ],
    };
    seedBundle(manifest, { '.claude/rules/example.md': 'actually-different-content' });
    const result = await copySubstrate(targetDir, { bundleRoot });
    expect(result.errored.length).toBe(1);
    expect(result.errored[0]).toMatch(/example\.md/);
  });
});

describe('copySubstrate — N2 error message names the fix', () => {
  it('// @rfc: N2 — hash mismatch error message names a corrective action, not just the cause', async () => {
    const manifest: MiniManifest = {
      entries: [
        { path: '.claude/rules/example.md', content_hash: sha256('declared'), slug: 'ex', tier: 'lite', type: 'rule' },
      ],
    };
    seedBundle(manifest, { '.claude/rules/example.md': 'different' });
    const result = await copySubstrate(targetDir, { bundleRoot });
    // Expect error message string to include remediation language,
    // not just "SHA256 mismatch". Ledger v3 L57 pins the pattern.
    const errorText = result.erroredMessages?.join(' ') ?? '';
    expect(errorText).toMatch(/rerun|reinstall|report|repair|--force/i);
  });
});

describe('copySubstrate — N1 per-directory progress', () => {
  it('// @rfc: N1 — invokes onProgress once per top-level directory in the manifest', async () => {
    const manifest = threeEntryManifest(); // 3 entries under 3 distinct dirs
    seedBundle(manifest, {
      '.claude/skills/example/SKILL.md': 'skill',
      '.claude/rules/example.md': 'rule',
      '.claude/hooks/example.sh': 'hook',
    });
    const progressCalls: Array<{ directory: string; count: number }> = [];
    await copySubstrate(targetDir, {
      bundleRoot,
      onProgress: (directory, count) => progressCalls.push({ directory, count }),
    });
    // 3 entries live under 3 top-level dirs (skills, rules, hooks).
    const uniqueDirs = new Set(progressCalls.map((c) => c.directory));
    expect(uniqueDirs.size).toBe(3);
    // Each call must name a directory string.
    for (const call of progressCalls) {
      expect(call.directory).toMatch(/^[a-z.]/);
      expect(call.count).toBeGreaterThan(0);
    }
  });
});
