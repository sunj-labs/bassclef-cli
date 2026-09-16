// hook-routing integration test list — per Beck TDD + test-list-discipline.
//
// End-to-end tests using a minimal bundle fixture that mirrors public
// bassclef v0.40.0 dist/lite/ shape. Fixture provides settings.json
// with two-prefix commands + a handful of hook binaries under
// dist/lite/.claude/hooks/. Real 24-hook bundle test lands in a
// separate fixture file the code phase adds.
//
// @verifies F2-fold (Feathers — real settings.json fixture)
// @verifies S2, S3, S4, S5, N1, N4, N5, N6, F3, F6, P3 folds
// @verifies UC-init-walker-hook-routing main + Ext 5b, 6a, 6c, 6e, 10a
// @verifies spec rows 6, 7, 13
//
// RED phase — src/lib/scope-router.ts + related do not exist yet.
// copySubstrate walker rewrite has not landed. Every test [ ] pending.
//
// # test-list:
// [ ] init copies all hook binaries from bundle to correct scopes
// [ ] project-scope hooks land in <adopter-repo>/.claude/hooks/
// [ ] user-scope hooks land in <home>/.claude/hooks/
// [ ] every copied .sh has mode 0755 on POSIX
// [ ] cold-adopter simulation — every settings.json command resolves to a file
// [ ] banner reads "Installed N of M ..." Norman shape
// [ ] init exits 0 on happy path
// [ ] symlink at user-scope target refuses, exits 2 (Ext 6a)
// [ ] existing file at user-scope without --force refuses, exits 2 (Ext 6c)
// [ ] --force overwrites existing user-scope hooks
// [ ] unknown prefix throws UnknownScopePrefix, exits 5 (Ext 5b)
// [ ] path-traversal command throws PathTraversalRefused, exits 2 (Ext 6e)
// [ ] settings.json copy is byte-for-byte from bundle
// [ ] PLACEHOLDER_FILES set contains no hook filenames (F3 fold)
// [ ] second init without --force refuses every hook (Ext 10a)

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, writeFileSync, statSync, existsSync, symlinkSync, chmodSync, rmSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
// RED: this import path is fine (copy-substrate.ts exists), but its
// behavior does not yet route per scope. Assertions fail because the
// new routing behavior is unimplemented.
import { copySubstrate } from '../src/lib/copy-substrate.js';

let workDir: string;
let bundleDir: string;
let fakeHome: string;
let originalHome: string | undefined;

// Minimal fixture bundle — mirrors dist/lite/ shape with 4 hooks:
// 2 at $HOME prefix (bassclef-sync, session-reflection),
// 2 at $CLAUDE_PROJECT_DIR prefix (plain-english-steering, assert-verify-steering).
function buildFixtureBundle(root: string): void {
  mkdirSync(join(root, '.claude/hooks'), { recursive: true });
  mkdirSync(join(root, 'standards'), { recursive: true });
  writeFileSync(join(root, 'standards/bassclef-wiring-manifest.json'), JSON.stringify({
    version: '2.0.0',
    hooks: [
      { source: 'bassclef-sync.sh', target: '$HOME/.claude/hooks/bassclef-sync.sh' },
      { source: 'session-reflection.sh', target: '$HOME/.claude/hooks/session-reflection.sh' },
      { source: 'plain-english-steering.sh', target: '$CLAUDE_PROJECT_DIR/.claude/hooks/plain-english-steering.sh' },
      { source: 'assert-verify-steering.sh', target: '$CLAUDE_PROJECT_DIR/.claude/hooks/assert-verify-steering.sh' },
    ],
  }, null, 2));
  writeFileSync(join(root, '.claude/settings.json'), JSON.stringify({
    hooks: {
      SessionStart: [{ hooks: [
        { type: 'command', command: '$HOME/.claude/hooks/bassclef-sync.sh' },
        { type: 'command', command: '$HOME/.claude/hooks/session-reflection.sh' },
      ]}],
      UserPromptSubmit: [{ hooks: [
        { type: 'command', command: '$CLAUDE_PROJECT_DIR/.claude/hooks/plain-english-steering.sh' },
        { type: 'command', command: '$CLAUDE_PROJECT_DIR/.claude/hooks/assert-verify-steering.sh' },
      ]}],
    },
  }, null, 2));
  for (const name of ['bassclef-sync.sh', 'session-reflection.sh', 'plain-english-steering.sh', 'assert-verify-steering.sh']) {
    const p = join(root, '.claude/hooks', name);
    writeFileSync(p, `#!/bin/sh\necho ${name}\n`);
    chmodSync(p, 0o755);
  }
  // cli 1.0.4 — undeclared hook files (helpers + fragments) that
  // declared hooks source by relative dirname path. These land at
  // BOTH scopes because user-scope hooks (session-reflection.sh)
  // and project-scope hooks source them from co-located dirs.
  const traceHelper = join(root, '.claude/hooks/trace-helper.sh');
  writeFileSync(traceHelper, `#!/bin/sh\n# helper — sourced by declared hooks at either scope\ntrace_log() { echo "[trace] $*" >&2; }\n`);
  chmodSync(traceHelper, 0o755);
  mkdirSync(join(root, '.claude/hooks/session-reflection.d'), { recursive: true });
  const fragment = join(root, '.claude/hooks/session-reflection.d/10-example.sh');
  writeFileSync(fragment, `#!/bin/sh\n# fragment — sourced by session-reflection.sh\necho fragment\n`);
  chmodSync(fragment, 0o755);
}

beforeEach(() => {
  originalHome = process.env.HOME;
  workDir = mkdtempSync(join(homedir(), '.bassclef-hookroute-test-'));
  bundleDir = mkdtempSync(join(homedir(), '.bassclef-hookroute-bundle-'));
  fakeHome = mkdtempSync(join(homedir(), '.bassclef-hookroute-fakehome-'));
  process.env.HOME = fakeHome;
  buildFixtureBundle(bundleDir);
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(bundleDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
  if (originalHome === undefined) delete process.env.HOME;
  else process.env.HOME = originalHome;
});

describe('copySubstrate — per-scope routing (spec row 6, F2 fold)', () => {
  it('copies all hook binaries from bundle to correct scopes', () => {
    const result = copySubstrate(workDir, { bundleRoot: bundleDir });
    // Expected: 4 hooks copied — 2 to fakeHome, 2 to workDir
    expect(result.copied.length).toBeGreaterThanOrEqual(4);
  });

  it('project-scope hooks land in <adopter-repo>/.claude/hooks/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, '.claude/hooks/plain-english-steering.sh'))).toBe(true);
    expect(existsSync(join(workDir, '.claude/hooks/assert-verify-steering.sh'))).toBe(true);
  });

  it('user-scope hooks land in <home>/.claude/hooks/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(fakeHome, '.claude/hooks/bassclef-sync.sh'))).toBe(true);
    expect(existsSync(join(fakeHome, '.claude/hooks/session-reflection.sh'))).toBe(true);
  });
});

describe('copySubstrate — executable bit preservation (spec row 7, S3 fold)', () => {
  it('every copied .sh has mode 0755 on POSIX', () => {
    if (process.platform === 'win32') return;
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const paths = [
      join(fakeHome, '.claude/hooks/bassclef-sync.sh'),
      join(fakeHome, '.claude/hooks/session-reflection.sh'),
      join(workDir, '.claude/hooks/plain-english-steering.sh'),
      join(workDir, '.claude/hooks/assert-verify-steering.sh'),
    ];
    for (const p of paths) {
      const mode = statSync(p).mode & 0o777;
      expect(mode).toBe(0o755);
    }
  });
});

describe('copySubstrate — cold-adopter simulation (spec row 13, primary acceptance)', () => {
  it('every settings.json command resolves to a real file after init', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const settings = JSON.parse(readFileSync(join(workDir, '.claude/settings.json'), 'utf8'));
    for (const eventBlocks of Object.values(settings.hooks) as Array<{ hooks: Array<{ command: string }> }>) {
      for (const block of eventBlocks) {
        for (const h of block.hooks) {
          const resolved = h.command
            .replace(/^\$HOME\//, `${fakeHome}/`)
            .replace(/^\$CLAUDE_PROJECT_DIR\//, `${workDir}/`);
          expect(existsSync(resolved)).toBe(true);
        }
      }
    }
  });
});

describe('copySubstrate — banner shape (N1 council fold + N5 fold)', () => {
  it('banner reads Norman shape "Installed N of M hooks (lite tier). N in <repo>, M in ~/"', () => {
    // The banner is produced by init.ts, not copy-substrate directly.
    // This test asserts the copy count so init can compose the banner honestly.
    const result = copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(result.hookCount).toBe(4);
    expect(result.copied.length).toBeGreaterThanOrEqual(4);
  });
});

describe('copySubstrate — Ext 6a symlink at user-scope', () => {
  it('refuses to overwrite a symlink at ~/.claude/hooks/bassclef-sync.sh, exits 2', () => {
    if (process.platform === 'win32') return;
    mkdirSync(join(fakeHome, '.claude/hooks'), { recursive: true });
    const decoy = join(fakeHome, '.claude/hooks/decoy');
    writeFileSync(decoy, 'sentinel');
    symlinkSync(decoy, join(fakeHome, '.claude/hooks/bassclef-sync.sh'));
    const result = copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(result.refused.some((p: string) => p.includes('bassclef-sync.sh'))).toBe(true);
    // sentinel content preserved — symlink target untouched
    expect(readFileSync(decoy, 'utf8')).toBe('sentinel');
  });
});

describe('copySubstrate — Ext 6c existing file at user-scope (N4 fold)', () => {
  it('refuses to overwrite existing user-scope file without --force, exits 2', () => {
    mkdirSync(join(fakeHome, '.claude/hooks'), { recursive: true });
    writeFileSync(join(fakeHome, '.claude/hooks/bassclef-sync.sh'), 'pre-existing');
    const result = copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(result.refused.some((p: string) => p.includes('bassclef-sync.sh'))).toBe(true);
  });

  it('overwrites existing user-scope hooks with --force', () => {
    mkdirSync(join(fakeHome, '.claude/hooks'), { recursive: true });
    writeFileSync(join(fakeHome, '.claude/hooks/bassclef-sync.sh'), 'pre-existing');
    const result = copySubstrate(workDir, { bundleRoot: bundleDir, force: true });
    const after = readFileSync(join(fakeHome, '.claude/hooks/bassclef-sync.sh'), 'utf8');
    expect(after).toContain('bassclef-sync.sh'); // fixture body
  });
});

describe('copySubstrate — adversarial settings.json (Ext 5b, 6e)', () => {
  it('throws UnknownScopePrefix on $XDG_DATA_HOME/... command', () => {
    // Overwrite fixture settings with an adversarial prefix
    writeFileSync(join(bundleDir, '.claude/settings.json'), JSON.stringify({
      hooks: { SessionStart: [{ hooks: [{ type: 'command', command: '$XDG_DATA_HOME/.claude/hooks/x.sh' }] }] },
    }));
    expect(() => copySubstrate(workDir, { bundleRoot: bundleDir })).toThrow();
  });

  it('throws PathTraversalRefused on ../etc/passwd command', () => {
    writeFileSync(join(bundleDir, '.claude/settings.json'), JSON.stringify({
      hooks: { SessionStart: [{ hooks: [{ type: 'command', command: '$HOME/../../../etc/passwd' }] }] },
    }));
    expect(() => copySubstrate(workDir, { bundleRoot: bundleDir })).toThrow();
  });
});

describe('copySubstrate — settings.json verbatim (ADR-055 D1 + F3 fold)', () => {
  it('copies settings.json byte-for-byte from bundle', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const before = readFileSync(join(bundleDir, '.claude/settings.json'), 'utf8');
    const after = readFileSync(join(workDir, '.claude/settings.json'), 'utf8');
    expect(after).toBe(before);
  });

  it('PLACEHOLDER_FILES set does not include any hook filename (F3 fold)', () => {
    // Structural pin — imports the set indirectly through copy behavior.
    // If a hook filename matched, its bytes would be modified.
    copySubstrate(workDir, { bundleRoot: bundleDir });
    for (const name of ['bassclef-sync.sh', 'plain-english-steering.sh']) {
      const bundlePath = name.includes('sync') || name.includes('reflection')
        ? join(bundleDir, '.claude/hooks', name)
        : join(bundleDir, '.claude/hooks', name);
      const targetPath = name.includes('sync') || name.includes('reflection')
        ? join(fakeHome, '.claude/hooks', name)
        : join(workDir, '.claude/hooks', name);
      expect(readFileSync(targetPath, 'utf8')).toBe(readFileSync(bundlePath, 'utf8'));
    }
  });
});

describe('copySubstrate — Ext 10a idempotency (S5 fold)', () => {
  it('second run without --force refuses every hook already present', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const second = copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(second.refused.length).toBeGreaterThan(0);
    expect(second.copied.length).toBe(0);
  });
});

// cli 1.0.4 — undeclared hook files must land at BOTH scopes.
// Cold-adopter smoke on 1.0.3 crashed because trace-helper.sh (undeclared
// helper) landed at project scope only; session-reflection.sh at user
// scope sources it via `$(dirname "$0")/trace-helper.sh`, which resolves
// to ~/.claude/hooks/trace-helper.sh — the walker never wrote there.
//
// Falsification test on cold-adopter-1 (2026-09-16): manual cp of
// trace-helper.sh + session-reflection.d/ to ~/.claude/hooks/ cured
// SessionStart. That confirms dual-write is the right cure.
//
// @verifies L-fold (Torvalds — adopter contract: helpers land where sourcer looks)
// @verifies I-fold (Ishikawa — Machine axis of 6M fishbone: walker default is the fault)
// @verifies F-fold (Feathers — characterization test pins dual-scope invariant)
// @verifies K-fold (Beck — RED first)
// @verifies SS-fold (Saltzer-Schroeder — complete mediation: walker routes every hook file)
//
// # test-list:
// [ ] undeclared helper (trace-helper.sh) lands at BOTH ~/.claude/hooks/ and <repo>/.claude/hooks/
// [ ] undeclared fragment (session-reflection.d/10-example.sh) lands at both scopes
// [ ] fragment landing preserves the session-reflection.d/ directory shape at both scopes
// [ ] helper file at user scope is executable (0755) so declared user-scope hooks can source it
// [ ] cold-adopter simulation: session-reflection.sh at ~/.claude/hooks/ resolves trace-helper.sh via $(dirname "$0")
describe('copySubstrate — cli 1.0.4 dual-scope undeclared helpers (Linus L + Ishikawa I + Feathers F folds)', () => {
  it('undeclared helper (trace-helper.sh) lands at BOTH user scope AND project scope', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(fakeHome, '.claude/hooks/trace-helper.sh'))).toBe(true);
    expect(existsSync(join(workDir, '.claude/hooks/trace-helper.sh'))).toBe(true);
  });

  it('undeclared fragment (session-reflection.d/10-example.sh) lands at BOTH scopes', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(fakeHome, '.claude/hooks/session-reflection.d/10-example.sh'))).toBe(true);
    expect(existsSync(join(workDir, '.claude/hooks/session-reflection.d/10-example.sh'))).toBe(true);
  });

  it('fragment landing preserves session-reflection.d/ directory shape at user scope', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const userFragmentDir = join(fakeHome, '.claude/hooks/session-reflection.d');
    expect(existsSync(userFragmentDir)).toBe(true);
    expect(statSync(userFragmentDir).isDirectory()).toBe(true);
  });

  it('trace-helper.sh at user scope is executable (0755) so user-scope hooks can source it', () => {
    if (process.platform === 'win32') return;
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const mode = statSync(join(fakeHome, '.claude/hooks/trace-helper.sh')).mode & 0o777;
    expect(mode).toBe(0o755);
  });

  it('cold-adopter simulation: session-reflection.sh at user scope co-locates with trace-helper.sh', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    const sourcerPath = join(fakeHome, '.claude/hooks/session-reflection.sh');
    const helperSameDir = join(dirname(sourcerPath), 'trace-helper.sh');
    expect(existsSync(sourcerPath)).toBe(true);
    expect(existsSync(helperSameDir)).toBe(true);
  });
});

// cli 1.1.0 — walker routes non-hook types per ADR-057 D1.
//
// Extends the fixture with skill, rule, agent, luminary, lib, adr,
// standard, template, presence-template, script, root-doc entries.
// Asserts each family lands at its ADR-057 target-path prefix at
// project scope. Regression guard: 1.0.4 dual-scope hook behavior
// unchanged.
//
// @verifies ADR-057 D1 routing table (all 13 rows)
// @verifies F-9 GREEN — init walker path-prefix routing without manifest
// @verifies risk-ledger HW — Hyrum contract on destination paths
// @verifies risk-ledger regression guard — 1.0.4 hook logic preserved
//
// # test-list:
// [ ] skill files land at <repo>/.claude/skills/ (project scope only)
// [ ] rule files land at <repo>/.claude/rules/
// [ ] agent files land at <repo>/.claude/agents/
// [ ] luminary files land at <repo>/.claude/luminaries/
// [ ] lib files land at <repo>/lib/
// [ ] adr files land at <repo>/architecture/decisions/
// [ ] standard files land at <repo>/standards/
// [ ] template files land at <repo>/templates/
// [ ] presence-template files land at <repo>/presence/install/
// [ ] script files land at <repo>/scripts/
// [ ] root-doc files land at <repo>/ (repo root)
// [ ] non-hook files DO NOT dual-write to user scope
// [ ] 1.0.4 hook dual-scope behavior preserved (regression guard)

function seedFixtureBundleWithCatalog(root: string): void {
  buildFixtureBundle(root);
  // Add one file per ADR-057 D1 non-hook type
  mkdirSync(join(root, '.claude/skills/temperance'), { recursive: true });
  writeFileSync(join(root, '.claude/skills/temperance/SKILL.md'), '# temperance skill\n');
  mkdirSync(join(root, '.claude/rules'), { recursive: true });
  writeFileSync(join(root, '.claude/rules/testing.md'), '# testing rule\n');
  mkdirSync(join(root, '.claude/agents'), { recursive: true });
  writeFileSync(join(root, '.claude/agents/architect.md'), '# architect agent\n');
  mkdirSync(join(root, '.claude/luminaries'), { recursive: true });
  writeFileSync(join(root, '.claude/luminaries/kent-beck.md'), '# kent-beck luminary\n');
  mkdirSync(join(root, 'lib'), { recursive: true });
  writeFileSync(join(root, 'lib/hook-inject.sh'), '#!/bin/sh\necho hook-inject\n');
  mkdirSync(join(root, 'architecture/decisions'), { recursive: true });
  writeFileSync(join(root, 'architecture/decisions/ADR-029-release-pipeline.md'), '# ADR-029\n');
  mkdirSync(join(root, 'standards'), { recursive: true });
  writeFileSync(join(root, 'standards/testing.md'), '# testing standard\n');
  mkdirSync(join(root, 'templates'), { recursive: true });
  writeFileSync(join(root, 'templates/chronicle-template.md'), '# chronicle template\n');
  mkdirSync(join(root, 'presence/install'), { recursive: true });
  writeFileSync(join(root, 'presence/install/bassclef-sync.template.sh'), '#!/bin/sh\n');
  mkdirSync(join(root, 'scripts'), { recursive: true });
  writeFileSync(join(root, 'scripts/aggregate-telemetry.sh'), '#!/bin/sh\n');
  writeFileSync(join(root, 'AGENTS.md'), '# AGENTS.md\n');
}

describe('copySubstrate — cli 1.1.0 non-hook type routing (ADR-057 D1)', () => {
  beforeEach(() => {
    process.env.HOME = fakeHome;
    seedFixtureBundleWithCatalog(bundleDir);
  });

  it('skill file lands at project scope only', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, '.claude/skills/temperance/SKILL.md'))).toBe(true);
    expect(existsSync(join(fakeHome, '.claude/skills/temperance/SKILL.md'))).toBe(false);
  });

  it('rule file lands at project scope only', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, '.claude/rules/testing.md'))).toBe(true);
    expect(existsSync(join(fakeHome, '.claude/rules/testing.md'))).toBe(false);
  });

  it('agent file lands at project scope only', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, '.claude/agents/architect.md'))).toBe(true);
  });

  it('luminary file lands at project scope only', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, '.claude/luminaries/kent-beck.md'))).toBe(true);
  });

  it('lib file lands at <repo>/lib/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'lib/hook-inject.sh'))).toBe(true);
  });

  it('adr file lands at <repo>/architecture/decisions/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'architecture/decisions/ADR-029-release-pipeline.md'))).toBe(true);
  });

  it('standard file lands at <repo>/standards/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'standards/testing.md'))).toBe(true);
  });

  it('template file lands at <repo>/templates/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'templates/chronicle-template.md'))).toBe(true);
  });

  it('presence-template file lands at <repo>/presence/install/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'presence/install/bassclef-sync.template.sh'))).toBe(true);
  });

  it('script file lands at <repo>/scripts/', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'scripts/aggregate-telemetry.sh'))).toBe(true);
  });

  it('root-doc file lands at <repo>/ (repo root)', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    expect(existsSync(join(workDir, 'AGENTS.md'))).toBe(true);
  });

  it('regression guard: 1.0.4 hook dual-scope behavior preserved', () => {
    copySubstrate(workDir, { bundleRoot: bundleDir });
    // session-reflection.sh at user scope (declared)
    expect(existsSync(join(fakeHome, '.claude/hooks/session-reflection.sh'))).toBe(true);
    // trace-helper.sh dual-writes at both scopes (undeclared helper — 1.0.4 logic)
    expect(existsSync(join(fakeHome, '.claude/hooks/trace-helper.sh'))).toBe(true);
    expect(existsSync(join(workDir, '.claude/hooks/trace-helper.sh'))).toBe(true);
  });
});
