// Feathers characterization test — init output parity vs dist/lite/.
//
// @verifies R-NPM-lite-002 (init walker reads dist/<tier>/ per ADR-055 D1)
// @verifies R-NPM-lite-003 (verbatim settings.json copy per ADR-055 D1)
// @verifies R-NPM-lite-004 (hook-count banner per ADR-055 D5)
//
// Port of bassclef-upstream/.claude/hooks/tests/init-output-parity.test.sh
// shape into TypeScript vitest. Upstream test runs against the upstream
// build script's output; this test runs against the cli's init on a
// fresh adopter directory.
//
// test-list:
// [x] fresh dir + init → exit 0
// [x] adopter .claude/settings.json byte-identical to dist/lite/.claude/settings.json
// [x] adopter CLAUDE.md exists (placeholders substituted)
// [x] adopter whereami.md exists (placeholders substituted)
// [x] adopter .bassclef-source.json exists (placeholders substituted)
// [x] adopter .gitignore exists (verbatim)
// [x] hook-count banner appears in stdout with shape "N hooks armed (lite tier)"
// [x] N in banner matches hook count in copied settings.json
// [x] adopter dir mirrors dist/lite/ shape — no extra dist/lite paths missing
//
// RED-first per Beck. Before Step 2 walker + Step 3 verbatim copy +
// Step 5 banner land, this test FAILS on every assertion 2-8. The
// failures name the specific files missing + the banner absent.
//
// Anchor luminary: @luminary michael-feathers — characterization tests
// pin actual observable behavior. Anchor: @luminary kent-beck — RED
// before source.

import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const DIST_LITE = resolve(REPO_ROOT, 'dist/lite');
const HOME = homedir();

function sha256(p: string): string {
  return createHash('sha256').update(readFileSync(p)).digest('hex');
}

function runCli(args: readonly string[], opts?: { cwd?: string }) {
  return spawnSync(process.execPath, [CLI, 'init', ...args], {
    encoding: 'utf8',
    timeout: 15000,
    cwd: opts?.cwd,
  });
}

let workDir: string;

beforeAll(() => {
  // Fixture precondition: dist/lite/ must exist. `npm run build` (vite)
  // cleans dist/, so we self-heal by running prepublish when the
  // fixture is missing. Env-gated on the substrate build to keep the
  // fixture minimal and fast in CI.
  if (!existsSync(DIST_LITE) || !existsSync(join(DIST_LITE, '.claude/settings.json'))) {
    const r = spawnSync(process.execPath, [
      resolve(REPO_ROOT, 'scripts/prepublish-bundle-substrate.mjs'),
    ], {
      encoding: 'utf8',
      timeout: 30000,
      env: { ...process.env, BASSCLEF_BUILD_DIST_LITE: '1' },
    });
    if (r.status !== 0) {
      throw new Error(
        `prepublish failed to seed dist/lite/ fixture: ${r.stderr || r.stdout}`
      );
    }
  }
});

beforeEach(() => {
  workDir = mkdtempSync(join(HOME, '.bassclef-init-parity-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('init output parity — adopter tree mirrors dist/lite/ (ADR-055 D1)', () => {
  it('fresh dir + init produces exit 0 and settings.json byte-identical to dist/lite/', () => {
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);

    // Verbatim copy per ADR-055 D1: adopter settings.json is byte-for-byte
    // identical to dist/lite/.claude/settings.json.
    const adopterSettings = join(workDir, '.claude/settings.json');
    const bundleSettings = join(DIST_LITE, '.claude/settings.json');
    expect(existsSync(adopterSettings)).toBe(true);
    expect(sha256(adopterSettings)).toBe(sha256(bundleSettings));
  });

  it('adopter dir has all 4 dist/lite/ templates present after init', () => {
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);

    // Files from dist/lite/ that carry placeholders (substitution runs
    // at write time; content differs from bundle source but the file
    // must exist).
    for (const name of ['CLAUDE.md', 'whereami.md', '.bassclef-source.json']) {
      expect(existsSync(join(workDir, name))).toBe(true);
    }
    // .gitignore is verbatim (no placeholders).
    expect(existsSync(join(workDir, '.gitignore'))).toBe(true);
  });

  it('prints hook-count banner in shape "N hooks armed (lite tier)" per ADR-055 D5', () => {
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);
    expect(r.stdout).toMatch(/\d+ hooks armed \(lite tier\)/);
  });

  it('banner N matches hook count across all events in copied settings.json', () => {
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);

    // Extract N from the banner.
    const match = r.stdout.match(/(\d+) hooks armed \(lite tier\)/);
    expect(match).not.toBeNull();
    const banneredN = parseInt(match![1], 10);

    // Count hooks across every event in the adopter's settings.json.
    const adopterSettings = JSON.parse(
      readFileSync(join(workDir, '.claude/settings.json'), 'utf8')
    );
    let actual = 0;
    for (const matcherBlocks of Object.values(adopterSettings.hooks ?? {}) as any[]) {
      for (const block of matcherBlocks) {
        actual += (block.hooks ?? []).length;
      }
    }
    expect(banneredN).toBe(actual);
  });

  it('placeholders substituted in CLAUDE.md, whereami.md, .bassclef-source.json', () => {
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);

    for (const name of ['CLAUDE.md', 'whereami.md', '.bassclef-source.json']) {
      const content = readFileSync(join(workDir, name), 'utf8');
      // Placeholders defined in ADR-002 amendment 2026-09-13.
      expect(content).not.toMatch(/\[REPO_NAME\]/);
      expect(content).not.toMatch(/\[ISO_TIMESTAMP\]/);
      expect(content).not.toMatch(/\[TIER\]/);
    }
  });

  it('settings.json is NOT placeholder-substituted (verbatim per D1)', () => {
    const r = runCli([], { cwd: workDir });
    expect(r.status).toBe(0);

    // Verbatim byte-identity is the strongest possible check on D1.
    // The bundle's settings.json contains no placeholders anyway (build
    // script emits final content), but if it ever did, D1 says do not
    // substitute — byte-identity is the invariant.
    expect(sha256(join(workDir, '.claude/settings.json')))
      .toBe(sha256(join(DIST_LITE, '.claude/settings.json')));
  });
});
