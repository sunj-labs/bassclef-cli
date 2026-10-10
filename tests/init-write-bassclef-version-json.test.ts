// cli#411 — bassclef init writes bassclef-version.json.
//
// @verifies R-NPM-lite-011 (statusline reads workdir version, no fallback)
// @requirement cli#411 (ticket body + 2026-10-09 cold-adopter smoke evidence)
//
// Characterization test (Feathers) — pins the walker's current behavior
// as a Tier 0 contract. The ticket cli#411 asked for `bassclef init` to
// write bassclef-version.json to the adopter workdir. The walker in
// src/lib/copy-substrate.ts already does this: it walks every file
// under dist/lite/ and writes to the mirror path under targetDir.
// bassclef-version.json ships at dist/lite/bassclef-version.json, so
// the walker lands it at <targetDir>/bassclef-version.json.
//
// The ticket's root-cause grep (src/commands/init.ts + src/lib/*.ts)
// returned zero hits because the walker handles files generically —
// no name-specific code to grep. This test pins the invariant so a
// future tier-filter change does not silently exclude the file and
// reintroduce the statusline-shows-stale-version failure mode seen on
// cold-adopter-1 at 2026-10-09.
//
// The 2026-10-09 symptom (v1.8.0 showing despite cli v1.9.12) was
// addressed by PR #410's --purge-adopter sibling-cache sweep. This
// test closes cli#411 by locking in the init-side write path.
//
// test-list:
// [x] default init writes <targetDir>/bassclef-version.json
// [x] written file is byte-for-byte identical to dist/lite/bassclef-version.json
// [x] written file .version matches dist/lite/bassclef-version.json .version
// [x] init.manifest.json carries a row for bassclef-version.json with source='bundle'
// [x] install-written-paths.json carries bassclef-version.json entry with writer=bassclef-init-npm
// [x] --dry-run does NOT write the version file
// [x] --force re-init refreshes the file (overwrites a stale adopter copy)
//
// Anchor luminary: @luminary michael-feathers — characterization pins
// the file-exists + hash-matches contract so a future refactor can't
// silently drop it. Anchor: @luminary tony-hoare — pre/postcondition
// (bundled file exists → written file exists with matching content).

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const DIST_LITE = resolve(REPO_ROOT, 'dist/lite');
const BUNDLED_VERSION_FILE = join(DIST_LITE, 'bassclef-version.json');
const HOME = homedir();

function sha256(path: string): string {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function runCli(args: readonly string[], cwd: string, home: string) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 15000,
    cwd,
    env: { ...process.env, HOME: home },
  });
}

let workDir: string;
let fakeHome: string;

beforeEach(() => {
  if (!existsSync(DIST_LITE) || !existsSync(join(DIST_LITE, '.claude/settings.json'))) {
    const r = spawnSync(process.execPath, [
      resolve(REPO_ROOT, 'scripts/prepublish-bundle-substrate.mjs'),
    ], { encoding: 'utf8', timeout: 30000, env: { ...process.env } });
    if (r.status !== 0) {
      throw new Error(
        `prepublish failed to seed dist/lite/ fixture: ${r.stderr || r.stdout}`
      );
    }
  }
  fakeHome = mkdtempSync(join(HOME, '.bassclef-init-version-json-fakehome-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-init-version-json-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef init writes bassclef-version.json (cli#411 characterization)', () => {
  it('default init writes <targetDir>/bassclef-version.json', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'bassclef-version.json'))).toBe(true);
  });

  it('written file is byte-for-byte identical to dist/lite/bassclef-version.json', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(sha256(join(workDir, 'bassclef-version.json'))).toBe(sha256(BUNDLED_VERSION_FILE));
  });

  it('written file .version matches dist/lite/bassclef-version.json .version', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    const written = JSON.parse(readFileSync(join(workDir, 'bassclef-version.json'), 'utf8'));
    const bundled = JSON.parse(readFileSync(BUNDLED_VERSION_FILE, 'utf8'));
    expect(written.version).toBe(bundled.version);
    expect(typeof written.version).toBe('string');
    expect(written.version.length).toBeGreaterThan(0);
  });

  it('init.manifest.json carries a row for bassclef-version.json with source=bundle', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    const manifest = JSON.parse(
      readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8')
    );
    const row = (manifest.files ?? manifest.entries ?? []).find(
      (e: { path?: string }) => e.path === 'bassclef-version.json'
    );
    expect(row, `init.manifest.json should carry a row for bassclef-version.json. Got: ${JSON.stringify(manifest.files ?? manifest.entries, null, 2)}`).toBeDefined();
    expect(row.source).toBe('bundle');
  });

  it('install-written-paths.json carries bassclef-version.json entry with writer=bassclef-init-npm', () => {
    const r = runCli([], workDir, fakeHome);
    expect(r.status).toBe(0);
    const iwpPath = join(workDir, 'state', 'install-written-paths.json');
    expect(existsSync(iwpPath)).toBe(true);
    const iwp = JSON.parse(readFileSync(iwpPath, 'utf8'));
    const entry = (iwp.entries ?? []).find(
      (e: { path?: string }) => e.path === 'bassclef-version.json'
    );
    expect(entry, `install-written-paths.json should carry bassclef-version.json. Got: ${JSON.stringify(iwp.entries, null, 2)}`).toBeDefined();
    expect(entry.writer).toBe('bassclef-init-npm');
    expect(entry.content_hash).toMatch(/^sha256:[0-9a-f]{64}$/);
  });

  it('--dry-run does NOT write bassclef-version.json', () => {
    const r = runCli(['--dry-run'], workDir, fakeHome);
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'bassclef-version.json'))).toBe(false);
  });

  it('--force re-init refreshes a stale adopter bassclef-version.json', () => {
    // First init writes the bundled version.
    const r1 = runCli([], workDir, fakeHome);
    expect(r1.status).toBe(0);
    const bundledContent = readFileSync(BUNDLED_VERSION_FILE, 'utf8');

    // Simulate adopter stale cache — write an older version shape.
    writeFileSync(
      join(workDir, 'bassclef-version.json'),
      JSON.stringify({ version: 'v0.0.0-stale', marker_tag: 'stale' }, null, 2)
    );

    // --force re-init refreshes the file back to bundled content.
    const r2 = runCli(['--force'], workDir, fakeHome);
    expect(r2.status).toBe(0);
    const refreshed = readFileSync(join(workDir, 'bassclef-version.json'), 'utf8');
    expect(refreshed).toBe(bundledContent);
  });
});
