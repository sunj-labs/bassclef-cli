// paths constants — Tier 0 test per ledger v3 L109.
//
// One test covering R6 (single source of truth for path constants).
//
// test-list (Beck):
// [ ] R6: src/lib/paths.ts exports SUBSTRATE_ROOT + CLAUDE_TARGET_ROOT;
//        no .claude/(hooks|skills|rules) literal in src/ outside paths.ts
//
// RED signal — src/lib/paths.ts does not exist at Step 4. The import
// fails; the grep audit also fails because existing src/commands/
// files may still carry .claude literals. Step 6 introduces the
// constants file AND scrubs the literals.

import { describe, it, expect } from 'vitest';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { SUBSTRATE_ROOT, CLAUDE_TARGET_ROOT } from '../../src/lib/paths.js';

const REPO_ROOT = resolve(__dirname, '..', '..');
const PATHS_MODULE_PATH = join(REPO_ROOT, 'src', 'lib', 'paths.ts');

describe('paths constants — R6 single source of truth', () => {
  it('// @risk: R6 — constants exported and no .claude directory literal outside paths.ts', () => {
    expect(existsSync(PATHS_MODULE_PATH)).toBe(true);
    expect(SUBSTRATE_ROOT).toBe('substrate');
    expect(CLAUDE_TARGET_ROOT).toBe('.claude');

    // Grep audit — no .claude/(hooks|skills|rules) literals in src/ outside paths.ts.
    const srcDir = join(REPO_ROOT, 'src');
    const result = spawnSync('grep', ['-rE', '\\.claude/(hooks|skills|rules)', srcDir, '--exclude=paths.ts'], {
      encoding: 'utf8',
    });
    // grep exit code 1 means no match — the passing shape.
    expect(result.status).toBe(1);
    expect(result.stdout.trim()).toBe('');
  });
});
