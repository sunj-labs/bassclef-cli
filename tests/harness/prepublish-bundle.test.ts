// Prepublish bundle harness — Tier 0 tests post-Phase 3 (cli#73).
//
// Post-MAJOR 1.0.0 shape: dist/lite/ is the sole bundle path. substrate/
// bundle build retired. Tests cover R2 pure Node + Phase 3 dist/lite/
// happy path + Phase 3 fail-fast + tarball audit.
//
// test-list (Beck):
// [x] R2: script contains zero execSync|spawn|spawnSync calls
// [x] Phase 3: happy path — wiring manifest + templates seeded → dist/lite/ has 6 files
// [x] Phase 3: settings.json emitted with tier=lite hook entries only (no standard/ultra)
// [x] Phase 3: wiring manifest missing → exit nonzero + stderr names path
// [x] Phase 3: schema major mismatch (v1.x vs expected 2.x) → exit nonzero
// [x] Phase 3: templates dir missing → exit nonzero + stderr names path
// [x] Phase 3: empty hooks block → exit nonzero (silent-empty guard)
// [x] Phase 3: wiring manifest lands in dist/lite/standards/ (L4 pre-mortem fold)
// [x] tarball-audit: npm pack --dry-run bundles zero operator-private paths
// [x] tarball-audit: top-level dirs match strict allowlist (no substrate/)
//
// @risk R2 — script under test must stay pure Node.
// @risk L4 — wiring manifest MUST land in dist/lite/standards/ so the
//   reader schema check works at init time.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

const REPO_ROOT = resolve(__dirname, '..', '..');
const SCRIPT_PATH = join(REPO_ROOT, 'scripts', 'prepublish-bundle-substrate.mjs');

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
  return spawnSync('node', [SCRIPT_PATH], {
    cwd,
    env: { ...process.env, ...env },
    encoding: 'utf8',
  });
}

// ============================================================
// Wiring-manifest + dist-templates fixture (Phase 3 shape)
// ============================================================

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

describe('prepublish-bundle — R2 pure Node', () => {
  it('// @risk: R2 — script contains zero execSync|spawn|spawnSync calls', () => {
    expect(existsSync(SCRIPT_PATH)).toBe(true);
    const src = readFileSync(SCRIPT_PATH, 'utf8');
    const withoutLineComments = src.replace(/\/\/[^\n]*/g, '');
    const withoutBlockComments = withoutLineComments.replace(/\/\*[\s\S]*?\*\//g, '');
    expect(withoutBlockComments).not.toMatch(/\bexecSync\b/);
    expect(withoutBlockComments).not.toMatch(/\bspawn\b/);
    expect(withoutBlockComments).not.toMatch(/\bspawnSync\b/);
  });
});

describe('prepublish-bundle — Phase 3 dist/lite/ happy path', () => {
  it('exits 0 and populates dist/lite/ with 6 files when wiring manifest + templates seeded', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const distLite = join(bundleDir, 'dist', 'lite');
    // 4 templates + settings.json + wiring manifest = 6 files.
    expect(existsSync(join(distLite, '.claude', 'settings.json'))).toBe(true);
    expect(existsSync(join(distLite, 'CLAUDE.md'))).toBe(true);
    expect(existsSync(join(distLite, 'whereami.md'))).toBe(true);
    expect(existsSync(join(distLite, '.bassclef-source.json'))).toBe(true);
    expect(existsSync(join(distLite, '.gitignore'))).toBe(true);
    // Phase 3 L4 pre-mortem fold — wiring manifest lands in dist/lite/
    // standards/ so the reader schema check works.
    expect(existsSync(join(distLite, 'standards', 'bassclef-wiring-manifest.json'))).toBe(true);
  });

  it('emits settings.json with tier=lite hook entries only (filters out standard + ultra)', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const settingsPath = join(bundleDir, 'dist', 'lite', '.claude', 'settings.json');
    const parsed = JSON.parse(readFileSync(settingsPath, 'utf8'));
    const sessionStartHooks = parsed.hooks.SessionStart[0].hooks;
    expect(sessionStartHooks.length).toBe(1);
    expect(sessionStartHooks[0].command).toMatch(/lite-hook\.sh$/);
    expect(sessionStartHooks[0].tier).toBeUndefined(); // tier stripped
    const promptHooks = parsed.hooks.UserPromptSubmit[0].hooks;
    expect(promptHooks.length).toBe(1);
    expect(promptHooks[0].command).toMatch(/lite-prompt\.sh$/);
    expect(parsed.permissions.allow).toContain('Bash(git status:*)');
    expect(parsed.env.BASSCLEF_ROOT).toBe('$HOME');
    expect(parsed.additionalDirectories).toContain('$HOME/.claude/rules');
  });
});

describe('prepublish-bundle — Phase 3 dist/lite/ fail-fast', () => {
  it('exits nonzero with "wiring manifest missing" when standards/bassclef-wiring-manifest.json is absent', () => {
    // Do NOT seed wiring manifest; DO seed templates.
    seedDistTemplates();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/wiring manifest missing/i);
  });

  it('exits nonzero on schema major mismatch (v1.x manifest against expected 2.x)', () => {
    const oldSchema = miniWiringManifest();
    oldSchema.version = '1.0.0';
    seedWiringManifest(oldSchema);
    seedDistTemplates();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/incompatible|1\.0\.0/i);
  });

  it('exits nonzero when presence/dist-templates/ dir is missing', () => {
    seedWiringManifest(miniWiringManifest());
    // Do NOT seed templates.
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/dist-templates/i);
  });

  it('exits nonzero on empty hooks block (silent-empty guard)', () => {
    const empty = miniWiringManifest();
    empty.hooks = {};
    seedWiringManifest(empty);
    seedDistTemplates();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/empty|hooks/i);
  });
});

describe('prepublish-bundle — tarball audit (no operator-private path leaks)', () => {
  // Locks Saltzer #1: any operator-private path (chronicles, journals,
  // session logs, state markers, risk ledgers, iteration goal docs) must
  // NEVER end up in the tarball. Runs against dist/lite/ after prepublish.
  it('// @risk: Saltzer #1 — npm pack --dry-run leaks zero operator-private paths', () => {
    const npmCheck = spawnSync('npm', ['--version'], { encoding: 'utf8' });
    if (npmCheck.status !== 0) return;
    const distExists = existsSync(join(REPO_ROOT, 'dist', 'lite', '.claude', 'settings.json'));
    if (!distExists) return; // dist/lite/ not built yet — skip
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

  it('// @risk: Saltzer #1 — tarball top-level dirs match the strict allowlist (no substrate/)', () => {
    const npmCheck = spawnSync('npm', ['--version'], { encoding: 'utf8' });
    if (npmCheck.status !== 0) return;
    const distExists = existsSync(join(REPO_ROOT, 'dist', 'lite', '.claude', 'settings.json'));
    if (!distExists) return;
    const result = spawnSync('npm', ['pack', '--dry-run', '--json'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      timeout: 30_000,
    });
    expect(result.status).toBe(0);
    const parsed = JSON.parse(result.stdout);
    const files: Array<{ path: string }> = parsed[0]?.files ?? [];
    const topLevel = new Set(files.map((f) => f.path.split('/')[0]));
    // Phase 3 allowlist — substrate/ retired.
    const allowed = new Set(['dist', 'LICENSE', 'README.md', 'package.json']);
    const extras = [...topLevel].filter((d) => !allowed.has(d));
    expect(extras).toEqual([]);
    // Explicit assertion: substrate/ is NOT in the tarball.
    expect(topLevel.has('substrate')).toBe(false);
  });
});
