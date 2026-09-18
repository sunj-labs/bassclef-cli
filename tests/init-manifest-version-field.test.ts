// Init manifest carries top-level .version — bassclef-upstream#1749.
//
// The v0.45.0 substrate ships `.claude/hooks/session-reflection.d/91-
// npm-version-drift.sh` which delegates to `lib/npm-version-check.sh`'s
// `check_lite_version_drift`. That function reads
// `jq -r '.version // ""'` from `.bassclef/init.manifest.json`. Without
// this field the drift banner silently never fires.
//
// # test-list:
// [x] fresh init writes .bassclef/init.manifest.json with top-level .version
// [x] .version matches the cli's package.json version (matches src/index.ts too)
// [x] .version is present alongside legacy $bassclef.generated_by_version

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

// eslint-disable-next-line @typescript-eslint/no-var-requires
const pkg = JSON.parse(readFileSync(resolve(REPO_ROOT, 'package.json'), 'utf8')) as {
  version: string;
};

let workDir: string;
let fakeHome: string;

function runInit() {
  return spawnSync(process.execPath, [CLI, 'init'], {
    encoding: 'utf8',
    timeout: 60000,
    cwd: workDir,
    env: { ...process.env, HOME: fakeHome },
  });
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(HOME, '.bassclef-mv-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-mv-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('bassclef-upstream#1749 — init.manifest.json carries top-level .version', () => {
  it('writes top-level .version field', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const manifest = JSON.parse(
      readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8')
    );
    expect(manifest).toHaveProperty('version');
    expect(typeof manifest.version).toBe('string');
  });

  it('.version matches package.json version', () => {
    const r = runInit();
    expect(r.status).toBe(0);
    const manifest = JSON.parse(
      readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8')
    );
    expect(manifest.version).toBe(pkg.version);
  });

  it('.version coexists with legacy $bassclef.generated_by_version', () => {
    // Duplicate is deliberate — the drift hook reads .version at top
    // level; existing readers read $bassclef.generated_by_version.
    // Both fields must carry the same value.
    const r = runInit();
    expect(r.status).toBe(0);
    const manifest = JSON.parse(
      readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8')
    );
    expect(manifest.version).toBe(manifest.$bassclef.generated_by_version);
  });
});
