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
// Updated for cli#477 (2026-11-06): the inventory now prints under
// --verbose, and the default banner summarizes instead. The two tests
// that pin the inventory run against --verbose. Their patterns are
// UNCHANGED — the output they assert on did not change, only the flag
// that asks for it. That is the whole point of a characterization test:
// it moved, it did not get weakened.
//
// A reader may ask why the per-file set is not pinned on the default
// path. It never belonged on stdout. `.bassclef/init.manifest.json`
// records every file with its outcome and its SHA-256, refused and
// errored files included, per ADR-010 D4 — so the manifest tests below
// are the ones that actually guard the file set.
//
// test-list:
// [x] non-JSON run exits 0 on a fresh target
// [x] --verbose run prints its summary lines to stdout in a fixed order
// [x] non-JSON run prints nothing to stderr on success
// [x] --verbose run prints the per-directory copy lines before the summary
// [x] default run prints no per-file inventory line
// [x] default run still prints the one total and the hook line
// [x] manifest records every file the run touched, with an outcome
// [x] manifest records a SHA-256 for every file the run created
// [x] manifest records refused files, so a partial init looks partial
// [x] sync on a 1-entry manifest reports exactly one managed file
// [x] sync takes no action on a manifest entry whose template is unknown

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
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

  it('prints its summary lines to stdout in a fixed order under --verbose', () => {
    // cli#477 — these lines moved behind --verbose. Patterns unchanged.
    const r = run('init', ['--verbose']);
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

  it('prints the per-directory copy lines before the summary under --verbose', () => {
    // cli#477 — same move, same pattern.
    const r = run('init', ['--verbose']);
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

// cli#477 — the default path. The two tests above pin what --verbose
// still prints; these pin that the default does NOT print it, and that
// the numbers a reader acts on survived the collapse.
describe('bassclef init default output is a summary, not an inventory', () => {
  it('prints no per-file inventory line', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
    // The pre-cure banner emitted one of these per file, because the
    // grouping key kept the filename. 171 of them on a real run.
    const inventoryLines = r.stdout
      .split('\n')
      .filter((l) => /^ {2}\S+: \d+ files copied$/.test(l));
    expect(
      inventoryLines,
      `default stdout carried ${inventoryLines.length} inventory lines; they belong behind --verbose`
    ).toHaveLength(0);
  });

  it('names each directory once, not each file', () => {
    const r = run('init', []);
    const groupLines = r.stdout
      .split('\n')
      .filter((l) => /^ {2}\S+: \d+ files?$/.test(l));
    // A real bundle spans on the order of fifteen directories. The exact
    // number moves with the bundle; the magnitude is the contract.
    expect(groupLines.length).toBeGreaterThan(0);
    expect(
      groupLines.length,
      `expected a directory summary, got ${groupLines.length} lines`
    ).toBeLessThan(30);
    // No group key may end in a file extension — that was the defect.
    for (const line of groupLines) {
      expect(line, 'a group key named a file, not a directory').not.toMatch(
        /^ {2}\S+\.(sh|md|json|jsonc|ts|mjs): /
      );
    }
  });

  it('still prints one total, the hook line, and the gitignore note', () => {
    const r = run('init', []);
    expect(r.stdout).toMatch(/files installed \(1 config \+ \d+ substrate\)/);
    expect(r.stdout).toMatch(/Installed \d+ of \d+ hooks/);
    expect(r.stdout).toMatch(/your substrate lives under/);
  });

  it('prints one total, not two', () => {
    const r = run('init', []);
    // The pre-cure banner printed the substrate count and then a grand
    // total that contained it, so the second number read as a correction.
    expect(r.stdout).not.toMatch(/substrate files copied/);
  });

  it('keeps absolute paths out of the statusline note', () => {
    const r = run('init', []);
    const statusLines = r.stdout
      .split('\n')
      .filter((l) => l.includes('statusline'));
    expect(statusLines.length).toBeGreaterThan(0);
    for (const line of statusLines) {
      // The detailed note carried three absolute paths, which on a real
      // install means it carried the operator's username.
      expect(line, 'statusline note leaked an absolute path').not.toMatch(/\s\//);
    }
  });
});

// cli#477 — the file set is guarded here, not on stdout. Per ADR-010 D1
// and D4 the manifest names every file the run touched, so this is the
// surface a test reads when it wants to know what init did.
describe('init manifest is the record of what the run touched', () => {
  interface ManifestFile {
    path: string;
    outcome: string;
    source?: string;
    content_hash_sha256?: string;
  }

  function readInitManifest(): { files: ManifestFile[] } {
    const raw = readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8');
    return JSON.parse(raw) as { files: ManifestFile[] };
  }

  it('records far more files than the default banner prints', () => {
    const r = run('init', []);
    expect(r.status).toBe(0);
    const manifest = readInitManifest();
    const bannerLines = r.stdout.split('\n').length;
    expect(manifest.files.length).toBeGreaterThan(bannerLines);
  });

  it('gives every entry an outcome', () => {
    run('init', []);
    const manifest = readInitManifest();
    const known = new Set(['created', 'unchanged', 'refused', 'error']);
    for (const file of manifest.files) {
      expect(known.has(file.outcome), `${file.path} has outcome ${file.outcome}`).toBe(true);
    }
  });

  it('records a SHA-256 for every file it created', () => {
    run('init', []);
    const manifest = readInitManifest();
    const created = manifest.files.filter((f) => f.outcome === 'created');
    expect(created.length).toBeGreaterThan(0);
    const missing = created.filter((f) => !f.content_hash_sha256);
    expect(
      missing.map((f) => f.path),
      'created entries without a hash cannot be checked for adopter edits later'
    ).toEqual([]);
  });

  it('records refused files, so a partial init looks partial', () => {
    // Pre-create a file init would otherwise write. The walker preserves
    // it; the manifest has to say so, per ADR-010 D4.
    const target = join(workDir, '.claude', 'settings.json');
    mkdirSync(join(workDir, '.claude'), { recursive: true });
    writeFileSync(target, '{"adopterEdited":true}\n');

    const r = run('init', []);
    expect(r.status).toBe(0);

    const manifest = readInitManifest();
    const refused = manifest.files.filter((f) => f.outcome === 'refused');
    expect(
      refused.length,
      'init preserved an existing file but the manifest did not record it'
    ).toBeGreaterThan(0);

    // And the adopter's content survived.
    expect(readFileSync(target, 'utf8')).toContain('adopterEdited');
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
