// Prepublish bundle harness — Tier 0 tests per ledger v3 L105.
//
// Nine tests covering R2 (pure Node), R7 (fail-fast at 3 checkpoints),
// R9 (size ceiling), + #45 cure (bundled manifest at
// substrate/.bassclef/lite-manifest.json). H2 count parameterization
// is enforced inline — every assertion reads manifest.entries.length,
// never a literal.
//
// test-list (Beck):
// [x] R7: sibling manifest missing → exit nonzero + stderr names path
// [x] R7: manifest present + one source file missing → exit nonzero + names missing path
// [x] R2: script contains zero execSync|spawn|spawnSync calls
// [x] happy: sibling manifest + all sources present → exit 0 + substrate/ populated
// [x] R9: total bundled size over 5MB → exit nonzero + size in stderr
// [x] postflight: file count != manifest.entries.length + 1 → exit nonzero
// [x] #45: happy path writes bundled manifest at substrate/.bassclef/lite-manifest.json
// [x] #45: bundled manifest entries[] length matches source manifest
// [x] #45: bundled manifest is valid JSON
// [x] tarball-audit: npm pack --dry-run bundles zero operator-private paths
//
// RED signal — scripts/prepublish-bundle-substrate.mjs does not exist
// at Step 4. Node exits 1 with MODULE_NOT_FOUND. Tests fail on the
// exit-code + stderr assertions until Step 5 lands.
//
// @rfc H2 — count parameterization: no literal 146 in assertions.
// @risk R2 — script under test must stay pure Node.
// @risk R7 — script under test must fail fast at three checkpoints.
// @risk R9 — script under test must enforce 5MB ceiling.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname, resolve } from 'node:path';

const REPO_ROOT = resolve(__dirname, '..', '..');
const SCRIPT_PATH = join(REPO_ROOT, 'scripts', 'prepublish-bundle-substrate.mjs');
const MINI_FIXTURE_PATH = join(REPO_ROOT, 'tests', 'fixtures', 'lite-manifest-mini.json');

interface MiniManifest {
  entries: Array<{ path: string; content_hash: string; slug: string; tier: string; type: string }>;
}

let workDir: string;
let fakeSibling: string;
let bundleDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-prepub-test-'));
  fakeSibling = join(workDir, 'bassclef-upstream');
  bundleDir = join(workDir, 'bassclef-cli');
  mkdirSync(fakeSibling, { recursive: true, mode: 0o755 });
  mkdirSync(bundleDir, { recursive: true, mode: 0o755 });
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function runScript(env: Record<string, string> = {}, cwd = bundleDir): ReturnType<typeof spawnSync> {
  // Legacy tests characterize substrate/ path only; dist/lite/ build is
  // opt-out per BASSCLEF_BUILD_DIST_LITE=0. Phase 2 tests (Step 6) opt
  // back in and seed the wiring manifest + templates in their own fixtures.
  return spawnSync('node', [SCRIPT_PATH], {
    cwd,
    env: { BASSCLEF_BUILD_DIST_LITE: '0', ...process.env, ...env },
    encoding: 'utf8',
  });
}

function seedSiblingManifest(manifest: MiniManifest): void {
  writeFileSync(join(fakeSibling, 'lite-manifest.json'), JSON.stringify(manifest, null, 2));
}

function seedSourceFiles(manifest: MiniManifest, contentPerFile = ''): void {
  for (const entry of manifest.entries) {
    const p = join(fakeSibling, entry.path);
    mkdirSync(dirname(p), { recursive: true, mode: 0o755 });
    writeFileSync(p, contentPerFile);
  }
}

function loadMini(): MiniManifest {
  return JSON.parse(readFileSync(MINI_FIXTURE_PATH, 'utf8')) as MiniManifest;
}

describe('prepublish-bundle — R7 fail-fast', () => {
  it('// @risk: R7 — exits nonzero with "manifest missing" when sibling manifest is absent', () => {
    // fakeSibling has no lite-manifest.json
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/manifest missing/i);
  });

  it('// @risk: R7 — exits nonzero with specific missing path when a source file is absent', () => {
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    // Deliberately do NOT seed source files.
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(new RegExp(manifest.entries[0]!.path.replace(/\./g, '\\.')));
  });
});

describe('prepublish-bundle — R2 pure Node', () => {
  it('// @risk: R2 — script contains zero execSync|spawn|spawnSync calls', () => {
    expect(existsSync(SCRIPT_PATH)).toBe(true);
    const src = readFileSync(SCRIPT_PATH, 'utf8');
    // Strip comments so // execSync in prose does not trigger.
    const withoutLineComments = src.replace(/\/\/[^\n]*/g, '');
    const withoutBlockComments = withoutLineComments.replace(/\/\*[\s\S]*?\*\//g, '');
    expect(withoutBlockComments).not.toMatch(/\bexecSync\b/);
    expect(withoutBlockComments).not.toMatch(/\bspawn\b/);
    expect(withoutBlockComments).not.toMatch(/\bspawnSync\b/);
  });
});

describe('prepublish-bundle — happy path', () => {
  it('exits 0 and populates substrate/ when sibling manifest and sources are present', () => {
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    seedSourceFiles(manifest, ''); // empty files match sha256 of empty string
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const bundled = join(bundleDir, 'substrate');
    expect(existsSync(bundled)).toBe(true);
    // Count files under substrate/ recursively. Expect manifest entries
    // + 1 for the bundled manifest at substrate/.bassclef/lite-manifest.json.
    function walk(dir: string): string[] {
      return readdirSync(dir).flatMap((name) => {
        const p = join(dir, name);
        return statSync(p).isDirectory() ? walk(p) : [p];
      });
    }
    expect(walk(bundled).length).toBe(manifest.entries.length + 1);
  });
});

describe('prepublish-bundle — #45 bundled manifest cure', () => {
  it('writes a bundled manifest at substrate/.bassclef/lite-manifest.json', () => {
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    seedSourceFiles(manifest, '');
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const bundledManifestPath = join(bundleDir, 'substrate', '.bassclef', 'lite-manifest.json');
    expect(existsSync(bundledManifestPath)).toBe(true);
  });

  it('bundled manifest entries[] length matches the source manifest', () => {
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    seedSourceFiles(manifest, '');
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const bundledManifestPath = join(bundleDir, 'substrate', '.bassclef', 'lite-manifest.json');
    const parsed = JSON.parse(readFileSync(bundledManifestPath, 'utf8')) as { entries: unknown[] };
    expect(Array.isArray(parsed.entries)).toBe(true);
    expect(parsed.entries.length).toBe(manifest.entries.length);
  });

  it('bundled manifest is valid JSON with a trailing newline', () => {
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    seedSourceFiles(manifest, '');
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const bundledManifestPath = join(bundleDir, 'substrate', '.bassclef', 'lite-manifest.json');
    const body = readFileSync(bundledManifestPath, 'utf8');
    expect(() => JSON.parse(body)).not.toThrow();
    expect(body.endsWith('\n')).toBe(true);
  });
});

describe('prepublish-bundle — R9 size ceiling', () => {
  it('// @risk: R9 — exits nonzero when total bundled size exceeds 5MB', () => {
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    // Seed each source file with 2MB of content — 3 files × 2MB = 6MB > 5MB ceiling.
    const twoMB = 'x'.repeat(2 * 1024 * 1024);
    seedSourceFiles(manifest, twoMB);
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/5\s*MB|size/i);
  });
});

describe('prepublish-bundle — postflight count check', () => {
  it('exits nonzero when bundled file count does not equal manifest.entries.length', () => {
    // Ship a manifest with N entries but seed only N-1 source files.
    const manifest = loadMini();
    seedSiblingManifest(manifest);
    seedSourceFiles(
      { entries: manifest.entries.slice(0, manifest.entries.length - 1) },
      ''
    );
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
  });
});

// ============================================================
// Phase 2 (goal 2026-09-13b) — dist/lite/ build path tests
// ============================================================
//
// Tier 0 tests per ledger F1 pre-mortem catch. These tests seed the
// wiring manifest + templates + opt IN to dist/lite/ build via
// BASSCLEF_BUILD_DIST_LITE=1. Fixture shape mirrors bassclef-upstream
// v0.39.0 §standards/bassclef-wiring-manifest.json + presence/dist-templates/.
//
// test-list (Beck):
// [x] Phase 2: happy path — wiring manifest + templates seeded → dist/lite/ has 5 files
// [x] Phase 2: settings.json emitted with tier=lite hook entries only (no standard/ultra)
// [x] Phase 2: wiring manifest missing → exit nonzero + stderr names path
// [x] Phase 2: schema major mismatch (v1.x vs expected 2.x) → exit nonzero
// [x] Phase 2: templates dir missing → exit nonzero + stderr names path
// [x] Phase 2: empty hooks block → exit nonzero (silent-empty guard)

interface WiringHookEntry {
  type: string;
  command: string;
  timeout?: number;
  tier: 'lite' | 'standard' | 'ultra';
}
interface WiringManifest {
  $schema?: string;
  version: string;
  hooks: Record<string, Array<{ matcher: string; hooks: WiringHookEntry[] }>>;
  permissions?: { allow: string[]; deny: string[] };
  env?: Record<string, string>;
  additionalDirectories?: string[];
}

function seedWiringManifest(manifest: WiringManifest): void {
  const dir = join(fakeSibling, 'standards');
  mkdirSync(dir, { recursive: true, mode: 0o755 });
  writeFileSync(join(dir, 'bassclef-wiring-manifest.json'), JSON.stringify(manifest, null, 2));
}

function seedDistTemplates(): void {
  const dir = join(fakeSibling, 'presence', 'dist-templates');
  mkdirSync(dir, { recursive: true, mode: 0o755 });
  writeFileSync(join(dir, 'CLAUDE.md'), '# CLAUDE.md template\n');
  writeFileSync(join(dir, 'whereami.md'), '# whereami template\n');
  writeFileSync(join(dir, '.bassclef-source.json'), '{"source": "template"}\n');
  writeFileSync(join(dir, '.gitignore'), 'node_modules/\n');
}

function miniWiringManifest(): WiringManifest {
  return {
    $schema: 'https://example.com/schema.json',
    version: '2.0.0',
    hooks: {
      SessionStart: [
        {
          matcher: '',
          hooks: [
            { type: 'command', command: '$HOME/.claude/hooks/lite-hook.sh', timeout: 10, tier: 'lite' },
            { type: 'command', command: '$HOME/.claude/hooks/standard-hook.sh', timeout: 10, tier: 'standard' },
            { type: 'command', command: '$HOME/.claude/hooks/ultra-hook.sh', timeout: 10, tier: 'ultra' },
          ],
        },
      ],
      UserPromptSubmit: [
        {
          matcher: '',
          hooks: [
            { type: 'command', command: '$HOME/.claude/hooks/lite-prompt.sh', timeout: 5, tier: 'lite' },
          ],
        },
      ],
    },
    permissions: { allow: ['Bash(git status:*)'], deny: ['Bash(rm -rf /)'] },
    env: { BASSCLEF_ROOT: '$HOME' },
    additionalDirectories: ['$HOME/.claude/rules'],
  };
}

describe('prepublish-bundle — Phase 2 dist/lite/ happy path', () => {
  it('exits 0 and populates dist/lite/ with 5 files when wiring manifest + templates seeded', () => {
    // Seed both the legacy substrate/ inputs AND the dist/lite/ inputs.
    const miniLegacy = loadMini();
    seedSiblingManifest(miniLegacy);
    seedSourceFiles(miniLegacy, '');
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    // Opt IN to dist/lite/ build.
    const result = runScript({
      BASSCLEF_SIBLING_ROOT: fakeSibling,
      BASSCLEF_BUILD_DIST_LITE: '1',
    });
    expect(result.status).toBe(0);
    const distLite = join(bundleDir, 'dist', 'lite');
    expect(existsSync(join(distLite, '.claude', 'settings.json'))).toBe(true);
    expect(existsSync(join(distLite, 'CLAUDE.md'))).toBe(true);
    expect(existsSync(join(distLite, 'whereami.md'))).toBe(true);
    expect(existsSync(join(distLite, '.bassclef-source.json'))).toBe(true);
    expect(existsSync(join(distLite, '.gitignore'))).toBe(true);
  });

  it('emits settings.json with tier=lite hook entries only (filters out standard + ultra)', () => {
    const miniLegacy = loadMini();
    seedSiblingManifest(miniLegacy);
    seedSourceFiles(miniLegacy, '');
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    const result = runScript({
      BASSCLEF_SIBLING_ROOT: fakeSibling,
      BASSCLEF_BUILD_DIST_LITE: '1',
    });
    expect(result.status).toBe(0);
    const settingsPath = join(bundleDir, 'dist', 'lite', '.claude', 'settings.json');
    const parsed = JSON.parse(readFileSync(settingsPath, 'utf8'));
    // SessionStart carries 1 lite entry (standard + ultra filtered out).
    // UserPromptSubmit carries 1 lite entry.
    const sessionStartHooks = parsed.hooks.SessionStart[0].hooks;
    expect(sessionStartHooks.length).toBe(1);
    expect(sessionStartHooks[0].command).toMatch(/lite-hook\.sh$/);
    expect(sessionStartHooks[0].tier).toBeUndefined(); // tier stripped
    const promptHooks = parsed.hooks.UserPromptSubmit[0].hooks;
    expect(promptHooks.length).toBe(1);
    expect(promptHooks[0].command).toMatch(/lite-prompt\.sh$/);
    // permissions + env + additionalDirectories preserved.
    expect(parsed.permissions.allow).toContain('Bash(git status:*)');
    expect(parsed.env.BASSCLEF_ROOT).toBe('$HOME');
    expect(parsed.additionalDirectories).toContain('$HOME/.claude/rules');
  });
});

describe('prepublish-bundle — Phase 2 dist/lite/ fail-fast', () => {
  it('exits nonzero with "wiring manifest missing" when standards/bassclef-wiring-manifest.json is absent', () => {
    const miniLegacy = loadMini();
    seedSiblingManifest(miniLegacy);
    seedSourceFiles(miniLegacy, '');
    // Do NOT seed wiring manifest; DO seed templates.
    seedDistTemplates();
    const result = runScript({
      BASSCLEF_SIBLING_ROOT: fakeSibling,
      BASSCLEF_BUILD_DIST_LITE: '1',
    });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/wiring manifest missing/i);
  });

  it('exits nonzero on schema major mismatch (v1.x manifest against expected 2.x)', () => {
    const miniLegacy = loadMini();
    seedSiblingManifest(miniLegacy);
    seedSourceFiles(miniLegacy, '');
    const oldSchema = miniWiringManifest();
    oldSchema.version = '1.0.0'; // wrong major
    seedWiringManifest(oldSchema);
    seedDistTemplates();
    const result = runScript({
      BASSCLEF_SIBLING_ROOT: fakeSibling,
      BASSCLEF_BUILD_DIST_LITE: '1',
    });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/incompatible|1\.0\.0/i);
  });

  it('exits nonzero when presence/dist-templates/ dir is missing', () => {
    const miniLegacy = loadMini();
    seedSiblingManifest(miniLegacy);
    seedSourceFiles(miniLegacy, '');
    seedWiringManifest(miniWiringManifest());
    // Do NOT seed templates.
    const result = runScript({
      BASSCLEF_SIBLING_ROOT: fakeSibling,
      BASSCLEF_BUILD_DIST_LITE: '1',
    });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/dist-templates/i);
  });

  it('exits nonzero on empty hooks block (silent-empty guard)', () => {
    const miniLegacy = loadMini();
    seedSiblingManifest(miniLegacy);
    seedSourceFiles(miniLegacy, '');
    const empty = miniWiringManifest();
    empty.hooks = {}; // silent-empty
    seedWiringManifest(empty);
    seedDistTemplates();
    const result = runScript({
      BASSCLEF_SIBLING_ROOT: fakeSibling,
      BASSCLEF_BUILD_DIST_LITE: '1',
    });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/empty|hooks/i);
  });
});

describe('prepublish-bundle — tarball audit (no operator-private path leaks)', () => {
  // Locks Saltzer #1 from the 2026-09-07 pre-mortem ledger:
  // `files: substrate/**` in package.json is broad. If any operator-private
  // path (chronicles, journals, session logs, state markers, risk ledgers,
  // iteration goal docs) ever ends up under substrate/, `npm pack` will
  // silently bundle it into the public tarball. This test asserts that
  // the tarball manifest contains zero paths matching the leak shapes.
  //
  // Runs against the real substrate/ bundle in the repo — requires
  // prepublish-bundle-substrate.mjs to have run against the sibling
  // manifest. Skips cleanly if npm is unavailable in the test env.
  it('// @risk: Saltzer #1 — npm pack --dry-run leaks zero operator-private paths', () => {
    const npmCheck = spawnSync('npm', ['--version'], { encoding: 'utf8' });
    if (npmCheck.status !== 0) return; // npm not on PATH — skip
    const substrateExists = existsSync(join(REPO_ROOT, 'substrate', '.bassclef', 'lite-manifest.json'));
    if (!substrateExists) return; // substrate not bundled yet — skip (publish pipeline populates it)
    const result = spawnSync('npm', ['pack', '--dry-run', '--json'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      timeout: 30_000,
    });
    expect(result.status).toBe(0);
    const parsed = JSON.parse(result.stdout);
    expect(Array.isArray(parsed)).toBe(true);
    const files = parsed[0]?.files ?? [];
    expect(Array.isArray(files)).toBe(true);
    expect(files.length).toBeGreaterThan(0);

    // Leak shapes — never allowed in a published tarball.
    // These are content dirs (session logs, ledgers, markers), not skill
    // definitions. Adopter-facing skills like /session-log carry their
    // SKILL.md; that IS meant to ship. The regex matches content paths.
    //
    // Chronicle patterns match DATED files (YYYY-MM-DD prefix), not skill
    // dirs. `substrate/.claude/skills/chronicle/SKILL.md` is a legit alias
    // skill per ADR-040 D1 grace window through 2026-10-31 (chronicle →
    // session-log rename); the SKILL.md itself ships.
    const leakRe = new RegExp(
      [
        '(^|/)docs/operator-private/',
        '(^|/)chronicle/\\d{4}-',
        '(^|/)docs/chronicle/\\d{4}-',
        '(^|/)docs/session-logs/',
        '(^|/)state/markers/',
        '(^|/)docs/risk-ledgers/',
        '(^|/)docs/iteration-bets/',
        '(^|/)docs/canvases/',
        '(^|/)docs/decompositions/',
        '(^|/)docs/journals/',
        '(^|/)docs/deferred-actions/',
      ].join('|'),
    );
    const leaks = files.map((f: { path: string }) => f.path).filter((p: string) => leakRe.test(p));
    expect(leaks).toEqual([]);
  });

  it('// @risk: Saltzer #1 — tarball top-level dirs match the strict allowlist', () => {
    const npmCheck = spawnSync('npm', ['--version'], { encoding: 'utf8' });
    if (npmCheck.status !== 0) return;
    const substrateExists = existsSync(join(REPO_ROOT, 'substrate', '.bassclef', 'lite-manifest.json'));
    if (!substrateExists) return;
    const result = spawnSync('npm', ['pack', '--dry-run', '--json'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      timeout: 30_000,
    });
    expect(result.status).toBe(0);
    const parsed = JSON.parse(result.stdout);
    const files: Array<{ path: string }> = parsed[0]?.files ?? [];
    const topLevel = new Set(files.map((f) => f.path.split('/')[0]));
    // Allowlist per package.json `files` field + the always-included set
    // (LICENSE, README.md, package.json ship regardless of `files`).
    // 'dist' top-level covers BOTH dist/*.js (cli output) AND dist/lite/ (Phase 2 bundle).
    const allowed = new Set(['dist', 'substrate', 'LICENSE', 'README.md', 'package.json']);
    const extras = [...topLevel].filter((d) => !allowed.has(d));
    expect(extras).toEqual([]);
  });
});
