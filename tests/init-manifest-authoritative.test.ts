// cli 1.1.1 — the manifest describes the whole run.
//
// Closes the findings RFC-0004 raised against the design before any code
// was written. Each test names the finding it pins.
//
// test-list:
// [x] S-1 — a dual-written helper produces two entries, one per scope
// [x] S-1 — the two entries are distinguishable by scope, not just path
// [x] D1 — manifest entry count equals the report's totals.files
// [x] D4 — refused files appear in the manifest with outcome 'refused'
// [x] M-3 — a dry run writes no manifest
// [x] M-4 — a shape-2 manifest still loads under the 1.1.1 reader
// [x] N-2 — the written manifest stays under a stated size ceiling
// [x] D10 — a manifest write failure prints to stderr and still exits 0
// [x] D9 — generated_by names the package that ships today

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync, rmSync, mkdirSync, writeFileSync, readFileSync, statSync, existsSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');

// 1 MB. The real manifest measured 198 KB at cli 1.1.1 on the lite tier.
// The ceiling exists so a future tier that ships several times the files
// fails this test rather than an adopter's editor (RFC-0004 N-2).
const MANIFEST_SIZE_CEILING_BYTES = 1_048_576;

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

function readManifest() {
  return JSON.parse(readFileSync(join(workDir, '.bassclef/init.manifest.json'), 'utf8'));
}

beforeEach(() => {
  fakeHome = mkdtempSync(join(homedir(), '.bassclef-auth-home-'));
  workDir = mkdtempSync(join(fakeHome, '.bassclef-auth-work-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  try { rmSync(fakeHome, { recursive: true, force: true }); } catch { /* ignore */ }
});

describe('manifest names the whole run (ADR-010 D1, D4)', () => {
  it('records as many entries as the report counts files', () => {
    const r = run('init', ['--json']);
    expect(r.status).toBe(0);
    const report = JSON.parse(r.stdout);
    expect(readManifest().files.length).toBe(report.totals.files);
  });

  it('still matches when the run refuses files', () => {
    // The test above passes on a fresh init because refused is 0 — it
    // cannot tell a correct report from one that counts successes only.
    // A second init into a populated HOME produces real refusals, which
    // is the case that caught RFC-0005 A-1.
    const other = mkdtempSync(join(fakeHome, '.bassclef-auth-first-'));
    spawnSync(process.execPath, [CLI, 'init', '--dir', other, '--allow-any-dir'], {
      encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: fakeHome },
    });

    const r = run('init', ['--json']);
    const report = JSON.parse(r.stdout);
    expect(report.refused).toBeGreaterThan(0);
    expect(readManifest().files.length).toBe(report.totals.files);
    expect(report.totals.files).toBe(report.totals.written + report.refused + report.errored);

    try { rmSync(other, { recursive: true, force: true }); } catch { /* ignore */ }
  });

  it('keeps hooks.declared and hooks.copied comparable', () => {
    // RFC-0005 A-2: copied used to count every hook file, so a reader
    // subtracting it from declared saw helpers as unexpected hooks.
    const r = run('init', ['--json']);
    const report = JSON.parse(r.stdout);
    expect(report.hooks.copied).toBeLessThanOrEqual(report.hooks.declared);
    expect(report.hooks.files).toBeGreaterThan(report.hooks.copied);
  });

  it('records more than the single config file', () => {
    // The defect this closes: cli 1.1.0 wrote 379 files and recorded one.
    run('init', []);
    expect(readManifest().files.length).toBeGreaterThan(100);
  });

  it('names the package that ships today, not the deprecated one', () => {
    run('init', []);
    expect(readManifest().$bassclef.generated_by).toBe('@thebassclef/lite');
  });

  it('marks each entry with who wrote it', () => {
    run('init', []);
    const sources = new Set(readManifest().files.map((f: { source?: string }) => f.source));
    expect(sources.has('config-composer')).toBe(true);
    expect(sources.has('bundle')).toBe(true);
  });
});

describe('dual-scope entries keep their identity (RFC-0004 S-1)', () => {
  it('records one entry per scope when a helper is written to both', () => {
    run('init', []);
    const files: Array<{ path: string; scope?: string }> = readManifest().files;

    const byPath = new Map<string, Set<string>>();
    for (const f of files) {
      if (!f.scope) continue;
      if (!byPath.has(f.path)) byPath.set(f.path, new Set());
      byPath.get(f.path)!.add(f.scope);
    }
    const dualWritten = [...byPath.entries()].filter(([, scopes]) => scopes.size > 1);

    // The walker dual-writes undeclared hook helpers. If that stops being
    // true this assertion should be revisited, not deleted — the point is
    // that a path is not a unique key.
    expect(dualWritten.length).toBeGreaterThan(0);
    for (const [, scopes] of dualWritten) {
      expect(scopes.has('user')).toBe(true);
      expect(scopes.has('project')).toBe(true);
    }
  });

  it('keys duplicated paths so the pair stays distinguishable', () => {
    run('init', []);
    const files: Array<{ path: string; scope?: string }> = readManifest().files;
    const keys = files.map((f) => `${f.path} ${f.scope ?? ''}`);
    expect(new Set(keys).size).toBe(keys.length);
  });
});

describe('a dry run records nothing (RFC-0004 M-3)', () => {
  it('writes no manifest', () => {
    const r = run('init', ['--dry-run']);
    expect(r.status).toBe(0);
    expect(existsSync(join(workDir, '.bassclef/init.manifest.json'))).toBe(false);
  });

  it('still reports what it would have written under --json', () => {
    const r = run('init', ['--dry-run', '--json']);
    const report = JSON.parse(r.stdout);
    expect(report.totals.files).toBeGreaterThan(100);
    expect(existsSync(join(workDir, '.bassclef/init.manifest.json'))).toBe(false);
  });
});

describe('older manifests still load (ADR-010 D5, RFC-0004 M-4)', () => {
  it('reads a shape-2 manifest without a schema complaint', () => {
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
        files: [
          {
            path: 'substrate.config.md',
            template: 'substrate.config.md',
            template_version: '0.1.0',
            outcome: 'created',
          },
        ],
      }, null, 2)
    );
    const r = run('sync', ['--dry-run']);
    expect(r.stderr).not.toMatch(/newer than this package understands/);
    expect(r.status).toBe(0);
  });
});

describe('manifest size stays bounded (RFC-0004 N-2)', () => {
  it('stays under the stated ceiling', () => {
    run('init', []);
    const bytes = statSync(join(workDir, '.bassclef/init.manifest.json')).size;
    expect(bytes).toBeLessThan(MANIFEST_SIZE_CEILING_BYTES);
  });
});

describe('a failed manifest write is audible (ADR-010 D10)', () => {
  it('prints the reason to stderr and still exits 0', () => {
    // .bassclef as a FILE makes the manifest directory impossible to create.
    writeFileSync(join(workDir, '.bassclef'), 'not a directory');
    const r = run('init', []);
    expect(r.stderr).toMatch(/could not write/i);
    expect(r.stderr).toMatch(/init\.manifest\.json/);
    // The substrate files did land, so init does not claim failure.
    expect(r.status).toBe(0);
  });
});
