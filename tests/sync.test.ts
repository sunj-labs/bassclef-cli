// bassclef sync test list — per Beck TDD.
//
// @verifies R-NPM-003
//
// End-to-end tests spawning the compiled CLI at dist/cli.js on a fresh
// temp directory. Uses `bassclef init` to establish the baseline, then
// exercises sync against synthetic conditions.
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
//
// [x] no manifest → refuses; exit 1; message names `bassclef init`
// [x] manifest present, all files current → no changes; exit 0
// [x] adopter edited substrate.config.md, no flag → refuses; exit 1; message names --replace-edits
// [x] adopter edited substrate.config.md + --replace-edits → replaces; hash + version in manifest; exit 0
// [x] adopter deleted a file, no flags → refuses; exit 1; message names deletion
// [x] adopter deleted a file + --force --replace-edits → recreates; exit 0
// [x] --dry-run on repo with adopter edits → lists changes; writes nothing
// [x] running as root without --allow-root → refuses; exit 1 (deferred; unit-tested via shouldRefuseRoot)
// [x] manifest is malformed JSON → refuses; exit 1; message names manual repair
// [x] file lacks bassclef_template marker → refuses; exit 1
//
// Phase 3 (bassclef-cli#73) — settings.json moved from cli-composed template
// to walker-owned dist/lite/ verbatim per ADR-055 D1. Sync manages the
// cli-composed template only (substrate.config.md). Walker files refresh
// via `bassclef init --force`. Adopter-edit tests use substrate.config.md
// as the marker-tracked file under sync's watch.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync, mkdirSync, unlinkSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

let workDir: string;

function runInit(args: readonly string[] = [], opts?: { cwd?: string }) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 8000,
    cwd: opts?.cwd,
  });
}

function runSync(args: readonly string[] = [], opts?: { cwd?: string }) {
  return spawnSync(process.execPath, [CLI, 'sync', ...args], {
    encoding: 'utf8',
    timeout: 8000,
    cwd: opts?.cwd,
  });
}

beforeEach(() => {
  workDir = mkdtempSync(join(HOME, '.bassclef-sync-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef sync — happy paths', () => {
  it('exits 0 with no changes when everything is current', () => {
    runInit([], { cwd: workDir });
    const r = runSync([], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(r.stdout + r.stderr).toMatch(/up to date|no change|current/i);
  });
});

describe('bassclef sync — no manifest', () => {
  it('refuses when the manifest is missing', () => {
    const r = runSync([], { cwd: workDir });
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/bassclef init/i);
  });
});

describe('bassclef sync — adopter edits', () => {
  it('refuses when adopter edited substrate.config.md (no flag)', () => {
    // substrate.config.md is the cli-composed template sync manages
    // post-Phase 3. Walker-owned files (settings.json, etc.) refresh
    // via `bassclef init --force`.
    runInit([], { cwd: workDir });
    const configPath = join(workDir, 'substrate.config.md');
    const original = readFileSync(configPath, 'utf8');
    writeFileSync(configPath, original + '\n\n<!-- adopter edit -->\n');

    const r = runSync([], { cwd: workDir });
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/edited|replace-edits/i);
    // Adopter edits preserved.
    expect(readFileSync(configPath, 'utf8')).toContain('<!-- adopter edit -->');
  });

  it('replaces adopter edits with --replace-edits', () => {
    runInit([], { cwd: workDir });
    const configPath = join(workDir, 'substrate.config.md');
    const original = readFileSync(configPath, 'utf8');
    writeFileSync(configPath, original + '\n\n<!-- adopter edit -->\n');

    const r = runSync(['--replace-edits'], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(readFileSync(configPath, 'utf8')).not.toContain('<!-- adopter edit -->');
  });
});

describe('bassclef sync — deletion', () => {
  it('refuses to recreate a deleted file without both flags', () => {
    runInit([], { cwd: workDir });
    unlinkSync(join(workDir, 'substrate.config.md'));

    const r = runSync([], { cwd: workDir });
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/deleted|missing|both/i);
    expect(existsSync(join(workDir, 'substrate.config.md'))).toBe(false);
  });

  it('recreates a deleted file with --force --replace-edits', () => {
    runInit([], { cwd: workDir });
    unlinkSync(join(workDir, 'substrate.config.md'));

    const r = runSync(['--force', '--replace-edits'], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, 'substrate.config.md'))).toBe(true);
  });
});

describe('bassclef sync — dry-run', () => {
  it('lists changes and writes nothing', () => {
    runInit([], { cwd: workDir });
    const configPath = join(workDir, 'substrate.config.md');
    const original = readFileSync(configPath, 'utf8');
    writeFileSync(configPath, original + '\n\n<!-- adopter edit -->\n');

    const r = runSync(['--dry-run'], { cwd: workDir });
    expect(r.stdout + r.stderr).toMatch(/edited|would/i);
    // Original edit preserved (dry-run wrote nothing).
    expect(readFileSync(configPath, 'utf8')).toContain('<!-- adopter edit -->');
  });
});

describe('bassclef sync — malformed manifest', () => {
  it('refuses on invalid JSON', () => {
    runInit([], { cwd: workDir });
    writeFileSync(join(workDir, '.bassclef/init.manifest.json'), '{not valid json');

    const r = runSync([], { cwd: workDir });
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/manifest|malformed|manual/i);
  });
});

describe('bassclef sync — marker discipline', () => {
  it('refuses to touch a manifest-listed file that lacks the bassclef_template marker', () => {
    runInit([], { cwd: workDir });
    // Replace substrate.config.md with content that lacks the marker.
    const configPath = join(workDir, 'substrate.config.md');
    writeFileSync(configPath, '# handmade\n\nnothing to see here.\n');

    const r = runSync(['--replace-edits'], { cwd: workDir });
    // Refused because file lost its bassclef_template marker.
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/marker|not managed/i);
    expect(readFileSync(configPath, 'utf8')).toBe('# handmade\n\nnothing to see here.\n');
  });
});
