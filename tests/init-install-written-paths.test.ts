// bassclef-upstream#2036 Finding #8 — convergence from cli-side.
//
// bassclef init writes <targetDir>/state/install-written-paths.json so
// bassclef-upstream discipline hooks (pre-commit-identifier-leak-scrub,
// pre-commit-gate 3-marker gate section) know these paths were installed
// by the init writer and skip discipline on them. Without the write, every
// cold adopter fires false-positive BLOCKs on dispatcher-installed files.
//
// Schema mirrors lib/install-written-paths.sh install_written_paths_register:
//   {
//     schema_version: "1.0.0",
//     entries: [{ path, writer, written_at, content_hash: "sha256:<64-hex>" }]
//   }
//
// test-list:
// [x] fresh init writes state/install-written-paths.json with schema_version 1.0.0
// [x] every entry declares writer "bassclef-init-npm"
// [x] every entry carries content_hash in "sha256:<64-hex>" shape
// [x] entries include at least one created config-composer path (e.g., substrate.config.md)
// [x] entries include bundled substrate paths (walker-copied)
// [x] repeat init is idempotent on path — no duplicate entries

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync, rmSync, readFileSync, existsSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');

const SHA256_PREFIXED = /^sha256:[0-9a-f]{64}$/;

interface Entry {
  path: string;
  writer: string;
  written_at: string;
  content_hash: string;
}

interface Manifest {
  schema_version: string;
  entries: Entry[];
}

let workDir: string;
let fakeHome: string;

function run(cmd: string, args: readonly string[] = []) {
  return spawnSync(process.execPath, [CLI, cmd, ...args], {
    encoding: 'utf8',
    timeout: 30000,
    cwd: workDir,
    env: { ...process.env, HOME: fakeHome },
  });
}

function readIwp(): Manifest {
  return JSON.parse(
    readFileSync(join(workDir, 'state/install-written-paths.json'), 'utf8')
  );
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(homedir(), '.bassclef-iwp-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-iwp-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef init writes state/install-written-paths.json (bassclef-upstream#2036 Finding #8)', () => {
  it('writes a manifest at schema_version 1.0.0 after a fresh init', () => {
    const r = run('init');
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'state/install-written-paths.json'))).toBe(true);
    const manifest = readIwp();
    expect(manifest.schema_version).toBe('1.0.0');
    expect(Array.isArray(manifest.entries)).toBe(true);
    expect(manifest.entries.length).toBeGreaterThan(0);
  });

  it('tags every entry with writer "bassclef-init-npm"', () => {
    run('init');
    const manifest = readIwp();
    for (const e of manifest.entries) {
      expect(e.writer).toBe('bassclef-init-npm');
    }
  });

  it('shapes every content_hash as sha256:<64-hex>', () => {
    run('init');
    const manifest = readIwp();
    for (const e of manifest.entries) {
      expect(e.content_hash).toMatch(SHA256_PREFIXED);
    }
  });

  it('includes config-composer paths (substrate.config.md)', () => {
    run('init');
    const paths = readIwp().entries.map((e) => e.path);
    expect(paths).toContain('substrate.config.md');
  });

  it('includes bundled substrate paths (.claude/skills/...)', () => {
    run('init');
    const paths = readIwp().entries.map((e) => e.path);
    expect(paths.some((p) => p.startsWith('.claude/skills/'))).toBe(true);
  });

  it('stays idempotent on path across repeat init runs', () => {
    run('init');
    const before = readIwp().entries.length;
    expect(before).toBeGreaterThan(0);
    // Second init into the same workDir — bassclef init refuses writes
    // that would overwrite without --force, but idempotency on paths
    // register still holds: the manifest should not duplicate rows.
    run('init');
    const after = readIwp();
    const paths = after.entries.map((e) => e.path);
    const unique = new Set(paths);
    expect(unique.size).toBe(paths.length);
  });
});
