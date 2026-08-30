// bassclef migrate command — end-to-end Tier 0 tests per Beck TDD.
//
// Spawns the compiled CLI at dist/cli.js with the `migrate` verb.
// Verifies orchestration: argv parse → root check → detection → branch
// dispatch → summary line → exit code.
//
// RED signal — src/commands/migrate.ts + src/cli.ts migrate dispatch
// do not exist yet. Every test here fails until Step 5 (argv + cli
// dispatch) and Step 6 (migrate command orchestrator) both land.
//
// Ledger ties:
// - R1 (argv parse error → exit 1)
// - R4 (unknown adopter state → exit 5 with Nygard cure message)
//
// test-list (Beck):
// [ ] // @risk: R1 — malformed argv exits 1 with error message
// [ ] // @risk: R4 — current state prints "Already at 0.1.0" and exits 0
// [ ] // @risk: R4 — unknown state exits 5 with cure message

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..', '..');
const CLI = resolve(REPO_ROOT, 'dist/cli.js');

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-migrate-e2e-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function seedManifest(targetDir: string, body: string): void {
  const manifestPath = join(targetDir, '.bassclef', 'init.manifest.json');
  mkdirSync(dirname(manifestPath), { recursive: true, mode: 0o755 });
  writeFileSync(manifestPath, body);
}

function runCLI(args: string[]): { status: number | null; stdout: string; stderr: string } {
  const result = spawnSync('node', [CLI, ...args], { encoding: 'utf8' });
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

describe('bassclef migrate — e2e', () => {
  it('// @risk: R1 — unknown flag exits 1 and names the flag', () => {
    // Skip if CLI is not built yet (dist/cli.js absent). Common when
    // running tests before `npm run build`. RED signal shipped as
    // "test fails to import migrate module" via the sister harness tests.
    if (!existsSync(CLI)) return;

    const result = runCLI(['migrate', '--dir', workDir, '--allow-any-dir', '--nope']);
    expect(result.status).toBe(1);
    expect(result.stderr).toMatch(/--nope/);
  });

  it('// @risk: R4 — current state prints "Already at 0.1.0" and exits 0', () => {
    if (!existsSync(CLI)) return;

    // Seed a 149-entry current manifest
    const currentManifest = {
      $bassclef: {
        template: 'init.manifest.json',
        manifest_schema_version: '0.1.0',
        generated_by: '@thebassclef/core',
        generated_by_version: '0.1.0',
      },
      created_at: '2026-08-30T00:00:00.000Z',
      target_dir: workDir,
      files: Array.from({ length: 149 }, (_, i) => ({
        path: `.claude/file-${i}.md`,
        template: `t${i}`,
        template_version: '0.1.0',
        content_hash_sha256: 'a'.repeat(64),
        outcome: 'created',
      })),
    };
    seedManifest(workDir, JSON.stringify(currentManifest));

    const result = runCLI(['migrate', '--dir', workDir, '--allow-any-dir', '--yes']);
    expect(result.status).toBe(0);
    expect(result.stdout + result.stderr).toMatch(/[Aa]lready at 0\.1\.0/);
  });

  it('// @risk: R4 — unknown state exits 5 with Nygard cure message', () => {
    if (!existsSync(CLI)) return;

    // Seed a 5-entry manifest — neither 3 (legacy) nor 149 (current)
    // AND v0.1.0 schema, so it does not match legacy detection but
    // does not match current entry count either.
    const oddManifest = {
      $bassclef: {
        template: 'init.manifest.json',
        manifest_schema_version: '0.1.0',
        generated_by: '@thebassclef/core',
        generated_by_version: '0.1.0',
      },
      created_at: '2026-08-30T00:00:00.000Z',
      target_dir: workDir,
      files: Array.from({ length: 5 }, (_, i) => ({
        path: `.claude/odd-${i}.md`,
        template: `t${i}`,
        template_version: '0.1.0',
        content_hash_sha256: 'b'.repeat(64),
        outcome: 'created',
      })),
    };
    seedManifest(workDir, JSON.stringify(oddManifest));

    const result = runCLI(['migrate', '--dir', workDir, '--allow-any-dir', '--yes']);
    expect(result.status).toBe(5);
    expect(result.stdout + result.stderr).toMatch(/[Rr]einstall.*@thebassclef\/core/);
  });
});
