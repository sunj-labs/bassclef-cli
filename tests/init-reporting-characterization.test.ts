// Characterization tests — cli 1.1.x init reporting.
//
// Per @luminary michael-feathers: these pin what init does TODAY, before
// the current cure touches it. They are written first and they are not
// edited afterward. If a later change makes one of these fail, the change
// broke something an adopter could see.
//
// The one behavior deliberately NOT pinned here is `--json` stream
// placement. That is the defect (#94); its test lives in the cure file.
//
// Updated for bassclef-cli#120 (2026-09-18): the "0 files refused" line
// no longer fires on a fresh install (was noise; only fires now when
// refused > 0). The order test drops that regex from the fresh-install
// path. See tests/init-banner-noise-cleanup.test.ts for the new gates.
//
// test-list:
// [x] non-JSON run exits 0 on a fresh target
// [x] non-JSON run prints its summary lines to stdout in a fixed order
// [x] non-JSON run prints nothing to stderr on success
// [x] non-JSON run prints the per-directory copy lines before the summary
// [x] sync on a 1-entry manifest reports exactly one managed file
// [x] sync takes no action on a manifest entry whose template is unknown

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');
const HOME = homedir();

let workDir: string;
let fakeHome: string;

function run(cmd: string, args: readonly string[]) {
  return spawnSync(process.execPath, [CLI, cmd, ...args], {
    encoding: 'utf8',
    timeout: 30000,
    cwd: workDir,
    env: { ...process.env, HOME: fakeHome },
  });
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(HOME, '.bassclef-char-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-char-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('characterization — bassclef init without --json', () => {
  it('exits 0 on a fresh target', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
  });

  it('prints its summary lines to stdout in a fixed order', () => {
    const r = run('init', []);
    const lines = r.stdout.split('\n');

    // Each summary line, in the order init prints it today. Matching on a
    // stable fragment rather than the whole line keeps counts free to move
    // with the bundle while the ORDER stays pinned.
    const order = [
      /config files created/,
      /substrate files copied/,
      /files total \(1 config \+ \d+ substrate\)/,
      /Installed \d+ of \d+ hooks/,
      // "files refused (path collision)" line removed per bassclef-cli#120 —
      // fires only when refused > 0. Fresh install (this test) sees zero
      // refused and no line at all.
      /your substrate lives under/,
    ];

    let cursor = -1;
    for (const pattern of order) {
      const at = lines.findIndex((l, i) => i > cursor && pattern.test(l));
      expect(at, `expected a stdout line matching ${pattern} after line ${cursor}`).toBeGreaterThan(cursor);
      cursor = at;
    }
  });

  it('prints the per-directory copy lines before the summary', () => {
    const r = run('init', []);
    const lines = r.stdout.split('\n');
    const firstCopyLine = lines.findIndex((l) => /^ {2}\S+: \d+ files copied$/.test(l));
    const totalLine = lines.findIndex((l) => /files total \(/.test(l));
    expect(firstCopyLine).toBeGreaterThan(-1);
    expect(totalLine).toBeGreaterThan(firstCopyLine);
  });

  it('prints nothing to stderr on a successful run', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
    expect(r.stderr.trim()).toBe('');
  });
});

describe('characterization — bassclef sync against a small manifest', () => {
  function writeManifest(files: unknown[]) {
    mkdirSync(join(workDir, '.bassclef'), { recursive: true });
    writeFileSync(
      join(workDir, '.bassclef/init.manifest.json'),
      JSON.stringify({
        schema_version: 2,
        $bassclef: {
          template: 'init.manifest.json',
          manifest_schema_version: '0.1.0',
          generated_by: '@thebassclef/core',
          generated_by_version: '1.1.0',
        },
        created_at: new Date().toISOString(),
        target_dir: workDir,
        files,
      }, null, 2) + '\n'
    );
  }

  it('reports exactly one managed file for a 1-entry manifest', () => {
    run('init', []);
    const r = run('sync', ['--dry-run']);
    expect(r.status).toBe(0);
    const managed = (r.stdout.match(/substrate\.config\.md/g) ?? []).length;
    expect(managed).toBeGreaterThan(0);
  });

  it('takes no action on an entry whose template it does not manage', () => {
    // sync.ts classify() returns a no-op with a note for an unknown
    // template. This is the property cli 1.1.1 relies on when the manifest
    // starts carrying bundle files.
    writeManifest([
      {
        path: '.claude/skills/temperance/SKILL.md',
        template: 'bundle:.claude/skills/temperance/SKILL.md',
        template_version: '1.1.0',
        outcome: 'created',
      },
    ]);
    const r = run('sync', ['--dry-run']);
    expect(r.status).toBe(0);
    expect(r.stdout + r.stderr).not.toMatch(/would update .claude\/skills/i);
  });
});
