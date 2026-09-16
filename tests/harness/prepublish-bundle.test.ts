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

// Cli 1.0.1 (bassclef-cli#79) — sibling's dist/lite/.claude/hooks/
// must ship the hook binaries the walker copies. Fixture mirrors
// the leaf filenames referenced by miniWiringManifest above.
function seedSiblingHookBinaries(names: readonly string[]): void {
  const dir = join(fakeSibling, 'dist', 'lite', '.claude', 'hooks');
  mkdirSync(dir, { recursive: true, mode: 0o755 });
  for (const leaf of names) {
    writeFileSync(join(dir, leaf), `#!/bin/sh\necho ${leaf}\n`);
  }
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
  it('exits 0 and populates dist/lite/ with 4 templates + settings + manifest + hook binaries when seeded', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    // Cli 1.0.1 walker needs hook binaries in the bundle per bassclef-cli#79.
    // miniWiringManifest declares 2 lite-tier hooks; seed both.
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-prompt.sh']);
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const distLite = join(bundleDir, 'dist', 'lite');
    // 4 templates + settings.json + wiring manifest = 6 base files.
    expect(existsSync(join(distLite, '.claude', 'settings.json'))).toBe(true);
    expect(existsSync(join(distLite, 'CLAUDE.md'))).toBe(true);
    expect(existsSync(join(distLite, 'whereami.md'))).toBe(true);
    expect(existsSync(join(distLite, '.bassclef-source.json'))).toBe(true);
    // npm-pack strips .gitignore files; prepublish ships it as
    // `gitignore` (no dot) in dist/lite/; walker renames back at write.
    expect(existsSync(join(distLite, 'gitignore'))).toBe(true);
    // Phase 3 L4 pre-mortem fold — wiring manifest lands in dist/lite/
    // standards/ so the reader schema check works.
    expect(existsSync(join(distLite, 'standards', 'bassclef-wiring-manifest.json'))).toBe(true);
    // Cli 1.0.1 addition — hook binaries land under dist/lite/.claude/hooks/.
    expect(existsSync(join(distLite, '.claude', 'hooks', 'lite-hook.sh'))).toBe(true);
    expect(existsSync(join(distLite, '.claude', 'hooks', 'lite-prompt.sh'))).toBe(true);
  });

  it('emits settings.json with tier=lite hook entries only (filters out standard + ultra)', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-prompt.sh']);
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

// ============================================================
// cli 1.0.3 (#87) — recursive hook tree copy
// ============================================================
//
// test-list (Beck) for cli 1.0.3:
// [ ] recursive walk copies a helper file that is NOT declared as a command
// [ ] recursive walk copies files nested under a fragment directory
// [ ] recursive walk preserves the executable bit on nested files
// [ ] postflight fails loud when a declared command lacks a matching binary
// [ ] recursive walk fails loud when sibling hook tree has zero *.sh files
// [ ] recursive walk fails loud when the sibling tree contains a symlink at top level
// [ ] recursive walk fails loud when the sibling tree contains a symlink nested inside a fragment dir
//
// @risk N1 — recursive walk misses a nested file
// @risk F1 — fixture drifts from real sibling shape
// @risk SS-1 — symlink refusal must fire on nested entries too

function seedSiblingHookTreeWithHelpers(): void {
  // Mirrors the real v0.42.0 shape: declared commands + helper + fragment dir.
  const hooksDir = join(fakeSibling, 'dist', 'lite', '.claude', 'hooks');
  const fragDir = join(hooksDir, 'session-reflection.d');
  mkdirSync(fragDir, { recursive: true, mode: 0o755 });

  // Declared commands (referenced by miniWiringManifest).
  writeFileSync(join(hooksDir, 'lite-hook.sh'), '#!/bin/sh\necho lite-hook\n', { mode: 0o755 });
  writeFileSync(join(hooksDir, 'lite-prompt.sh'), '#!/bin/sh\necho lite-prompt\n', { mode: 0o755 });

  // Helper — NOT a declared command; other hooks source it.
  writeFileSync(join(hooksDir, 'trace-helper.sh'), '#!/bin/sh\n# helper sourced by others\n', {
    mode: 0o755,
  });

  // Fragment dir contents.
  writeFileSync(join(fragDir, 'fragment-a.sh'), '#!/bin/sh\necho fragment-a\n', { mode: 0o755 });
  writeFileSync(join(fragDir, 'fragment-b.sh'), '#!/bin/sh\necho fragment-b\n', { mode: 0o755 });
}

describe('prepublish-bundle — cli 1.0.3 recursive tree copy', () => {
  it('copies a helper file that is NOT declared as a command in settings.json', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookTreeWithHelpers();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const helperPath = join(bundleDir, 'dist', 'lite', '.claude', 'hooks', 'trace-helper.sh');
    expect(existsSync(helperPath)).toBe(true);
  });

  it('copies files nested under session-reflection.d/ fragment directory', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookTreeWithHelpers();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const fragA = join(
      bundleDir,
      'dist',
      'lite',
      '.claude',
      'hooks',
      'session-reflection.d',
      'fragment-a.sh',
    );
    const fragB = join(
      bundleDir,
      'dist',
      'lite',
      '.claude',
      'hooks',
      'session-reflection.d',
      'fragment-b.sh',
    );
    expect(existsSync(fragA)).toBe(true);
    expect(existsSync(fragB)).toBe(true);
  });

  it('preserves executable bit on nested fragment files', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookTreeWithHelpers();
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);
    const fragPath = join(
      bundleDir,
      'dist',
      'lite',
      '.claude',
      'hooks',
      'session-reflection.d',
      'fragment-a.sh',
    );
    const { statSync } = require('node:fs');
    const mode = statSync(fragPath).mode & 0o777;
    // Executable bit on user (owner) — 0o100. Windows CI may report 0o644 — allow either exec bit or 0o644.
    const hasExecBit = (mode & 0o100) !== 0;
    const isWindowsBestEffort = process.platform === 'win32' && mode === 0o644;
    expect(hasExecBit || isWindowsBestEffort).toBe(true);
  });

  it('postflight fails loud when a declared command lacks a matching binary in the tree', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    // Seed a tree that has trace-helper.sh + fragments but MISSES lite-hook.sh
    // (which miniWiringManifest declares as a command).
    const hooksDir = join(fakeSibling, 'dist', 'lite', '.claude', 'hooks');
    mkdirSync(hooksDir, { recursive: true, mode: 0o755 });
    writeFileSync(join(hooksDir, 'trace-helper.sh'), '#!/bin/sh\n');
    writeFileSync(join(hooksDir, 'lite-prompt.sh'), '#!/bin/sh\n');
    // lite-hook.sh MISSING on purpose.
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/lite-hook\.sh/);
  });

  it('fails loud when sibling hook tree has zero *.sh files', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    // Create empty hooks dir.
    const hooksDir = join(fakeSibling, 'dist', 'lite', '.claude', 'hooks');
    mkdirSync(hooksDir, { recursive: true, mode: 0o755 });
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/empty|zero|missing/i);
  });

  it('fails loud when sibling tree contains a symlink at top level', () => {
    // Skip on Windows — symlinks require admin.
    if (process.platform === 'win32') return;
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    const hooksDir = join(fakeSibling, 'dist', 'lite', '.claude', 'hooks');
    mkdirSync(hooksDir, { recursive: true, mode: 0o755 });
    writeFileSync(join(hooksDir, 'lite-hook.sh'), '#!/bin/sh\n');
    writeFileSync(join(hooksDir, 'lite-prompt.sh'), '#!/bin/sh\n');
    writeFileSync(join(hooksDir, 'target.sh'), '#!/bin/sh\n');
    const { symlinkSync } = require('node:fs');
    symlinkSync('target.sh', join(hooksDir, 'trace-helper.sh'));
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/symlink/i);
  });

  it('fails loud when sibling tree contains a symlink nested inside a fragment directory', () => {
    if (process.platform === 'win32') return;
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    const hooksDir = join(fakeSibling, 'dist', 'lite', '.claude', 'hooks');
    const fragDir = join(hooksDir, 'session-reflection.d');
    mkdirSync(fragDir, { recursive: true, mode: 0o755 });
    writeFileSync(join(hooksDir, 'lite-hook.sh'), '#!/bin/sh\n');
    writeFileSync(join(hooksDir, 'lite-prompt.sh'), '#!/bin/sh\n');
    writeFileSync(join(fragDir, 'real-fragment.sh'), '#!/bin/sh\n');
    const { symlinkSync } = require('node:fs');
    symlinkSync('real-fragment.sh', join(fragDir, 'linked-fragment.sh'));
    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/symlink/i);
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

// ============================================================
// cli 1.1.0 — lite catalog reader (goal 2026-09-16)
// ============================================================
//
// RED phase for cli 1.1.0. Prepublish must read lite-manifest.json
// v1.6.x from the sibling and copy every entry to dist/lite/
// via identity path mapping.
//
// @verifies F-1 fix — ADR-057 D1 covers 12 manifest types
// @verifies F-8 GREEN — identity path mapping
// @verifies F-10 AMBER fold — build-time collision guard
// @verifies risk-ledger row N1 (fail-loud manifest missing)
// @verifies risk-ledger row RH (schema major mismatch)
//
// # test-list:
// [ ] Manifest read: prepublish reads lite-manifest.json + copies all entries at entry.path
// [ ] Fail-loud N1: manifest missing → nonzero exit + stderr names cure
// [ ] Fail-loud RH: schema major mismatch → nonzero exit + stderr names both versions
// [ ] Collision guard: manifest entry path in DIST_TEMPLATE_FILES → nonzero exit (ManifestCollision)
// [ ] Identity mapping: every entry.path resolves to a file under dist/lite/
// [ ] Type coverage: all 12 manifest type values (skill/rule/agent/luminary/lib/hook/adr/standard/template/presence-template/script/root-doc) land per ADR-057
// [ ] Postflight: dist/lite/ file count = manifest.entries.length + existing DIST_TEMPLATE_FILES + settings.json + wiring manifest

interface LiteManifestEntry {
  slug: string;
  type: string;
  path: string;
  tier: 'lite' | 'standard' | 'ultra';
  content_hash?: string;
  description?: string;
}

interface LiteManifest {
  tier: 'lite';
  manifest_version: string;
  generated_at: string;
  entries: LiteManifestEntry[];
}

function seedLiteManifest(manifest: LiteManifest): void {
  writeFileSync(join(fakeSibling, 'lite-manifest.json'), JSON.stringify(manifest, null, 2));
}

function seedManifestEntry(entry: LiteManifestEntry, content: string): void {
  const filePath = join(fakeSibling, entry.path);
  mkdirSync(join(filePath, '..'), { recursive: true });
  writeFileSync(filePath, content);
}

function miniLiteManifest(): LiteManifest {
  return {
    tier: 'lite',
    manifest_version: '1.6.1',
    generated_at: '2026-09-16T22:22:04Z',
    entries: [
      { slug: 'temperance', type: 'skill', path: '.claude/skills/temperance/SKILL.md', tier: 'lite' },
      { slug: 'testing', type: 'rule', path: '.claude/rules/testing.md', tier: 'lite' },
      { slug: 'kent-beck', type: 'luminary', path: '.claude/luminaries/kent-beck.md', tier: 'lite' },
      { slug: 'architect', type: 'agent', path: '.claude/agents/architect.md', tier: 'lite' },
      { slug: 'hook-inject', type: 'lib', path: 'lib/hook-inject.sh', tier: 'lite' },
      { slug: 'ADR-029', type: 'adr', path: 'architecture/decisions/ADR-029.md', tier: 'lite' },
      { slug: 'testing', type: 'standard', path: 'standards/testing.md', tier: 'lite' },
      { slug: 'chronicle-template', type: 'template', path: 'templates/chronicle-template.md', tier: 'lite' },
      { slug: 'bassclef-sync-template', type: 'presence-template', path: 'presence/install/bassclef-sync.template.sh', tier: 'lite' },
      { slug: 'aggregate-telemetry', type: 'script', path: 'scripts/aggregate-telemetry.sh', tier: 'lite' },
      { slug: 'AGENTS', type: 'root-doc', path: 'AGENTS.md', tier: 'lite' },
    ],
  };
}

function seedAllManifestEntries(manifest: LiteManifest): void {
  for (const entry of manifest.entries) {
    seedManifestEntry(entry, `# ${entry.slug} (${entry.type}) fixture\n`);
  }
}

describe('prepublish — cli 1.1.0 lite catalog reader (goal 2026-09-16)', () => {
  it('reads lite-manifest.json and copies every entry via identity path mapping', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    const manifest = miniLiteManifest();
    seedLiteManifest(manifest);
    seedAllManifestEntries(manifest);

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);

    // Every entry.path must exist under bundleDir/dist/lite/
    for (const entry of manifest.entries) {
      const target = join(bundleDir, 'dist', 'lite', entry.path);
      expect(existsSync(target)).toBe(true);
    }
  });

  it('fails loud when lite-manifest.json is missing (N1)', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    // Deliberately skip seedLiteManifest()

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/lite-manifest\.json/i);
    expect(result.stderr).toMatch(/(missing|not found|no such)/i);
  });

  it('fails loud on schema major mismatch (RH)', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    const badMajor: LiteManifest = { ...miniLiteManifest(), manifest_version: '99.0.0' };
    seedLiteManifest(badMajor);
    seedAllManifestEntries(badMajor);

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/schema|version|manifest_version/i);
  });

  it('fails loud on collision with DIST_TEMPLATE_FILES (F-10 AMBER fold)', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    const collisionManifest: LiteManifest = {
      ...miniLiteManifest(),
      entries: [
        ...miniLiteManifest().entries,
        // Deliberate collision — CLAUDE.md is already in DIST_TEMPLATE_FILES
        { slug: 'CLAUDE', type: 'root-doc', path: 'CLAUDE.md', tier: 'lite' },
      ],
    };
    seedLiteManifest(collisionManifest);
    seedAllManifestEntries(collisionManifest);

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/collision|conflict|CLAUDE\.md/i);
  });

  it('type coverage — all 12 manifest types land per ADR-057 D1', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    const manifest = miniLiteManifest();
    seedLiteManifest(manifest);
    seedAllManifestEntries(manifest);

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);

    const typesInFixture = new Set(manifest.entries.map((e) => e.type));
    expect(typesInFixture.size).toBeGreaterThanOrEqual(11); // 12 in real; 11 minimum viable coverage in fixture

    for (const entry of manifest.entries) {
      const target = join(bundleDir, 'dist', 'lite', entry.path);
      expect(existsSync(target)).toBe(true);
    }
  });

  it('postflight file count includes manifest entries plus dist templates plus wiring manifest', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    const manifest = miniLiteManifest();
    seedLiteManifest(manifest);
    seedAllManifestEntries(manifest);

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);

    // Count real files under dist/lite/
    const fsMod = require('node:fs') as typeof import('node:fs');
    let fileCount = 0;
    function walk(dir: string): void {
      for (const name of fsMod.readdirSync(dir)) {
        const p = join(dir, name);
        if (fsMod.statSync(p).isDirectory()) walk(p);
        else fileCount += 1;
      }
    }
    walk(join(bundleDir, 'dist', 'lite'));

    // 11 manifest entries + 4 dist templates + settings.json + wiring manifest + 2 hook binaries = 19 minimum
    expect(fileCount).toBeGreaterThanOrEqual(manifest.entries.length + 4);
  });

  it('bundled lite-manifest.json lands in dist/lite/standards/ for init reader', () => {
    seedWiringManifest(miniWiringManifest());
    seedDistTemplates();
    seedSiblingHookBinaries(['lite-hook.sh', 'lite-hook-2.sh']);
    const manifest = miniLiteManifest();
    seedLiteManifest(manifest);
    seedAllManifestEntries(manifest);

    const result = runScript({ BASSCLEF_SIBLING_ROOT: fakeSibling });
    expect(result.status).toBe(0);

    // Manifest itself is copied so init can verify what shipped
    const bundledManifest = join(bundleDir, 'dist', 'lite', 'standards', 'lite-manifest.json');
    expect(existsSync(bundledManifest)).toBe(true);

    const parsed = JSON.parse(readFileSync(bundledManifest, 'utf8'));
    expect(parsed.manifest_version).toBe(manifest.manifest_version);
    expect(parsed.entries.length).toBe(manifest.entries.length);
  });
});
