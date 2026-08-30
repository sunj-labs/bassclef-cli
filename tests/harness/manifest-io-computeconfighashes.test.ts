// manifest-io extension — computeConfigHashes — Tier 0 tests per Beck TDD.
//
// computeConfigHashes(targetDir, paths[]) returns SHA-256 for each named
// file that exists on disk. Skips absent files silently. LF-normalized
// per ADR-003 N1 discipline (Windows adopter parity).
//
// RED signal — computeConfigHashes does not exist yet in
// src/lib/manifest-io.ts. Import fails until Step 6 extends the module
// (~15 LOC delta per decomp § Control objects).
//
// Ledger tie: R2 (Linus — adopter-edited config files must survive
// migration). Compensator: hash the file before any write; record the
// current hash in the new manifest so classifier operates correctly.
//
// test-list (Beck):
// [ ] // @risk: R2 — 3 config files exist → returns 3-entry map with SHA-256s
// [ ] // @risk: R2 — one config file absent → returns 2-entry map; no throw
// [ ] // @risk: R2 — LF normalization: CRLF file hashes same as LF file

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';

import { computeConfigHashes } from '../../src/lib/manifest-io.js';

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-computehashes-test-'));
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
});

function seedFile(targetDir: string, relPath: string, body: string): void {
  const abs = join(targetDir, relPath);
  mkdirSync(dirname(abs), { recursive: true, mode: 0o755 });
  writeFileSync(abs, body);
}

function sha256Of(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

describe('computeConfigHashes', () => {
  it('// @risk: R2 — three config files exist returns 3-entry map with matching SHA-256s', async () => {
    const body = 'config body';
    seedFile(workDir, '.claude/settings.json', body);
    seedFile(workDir, 'substrate.config.md', body);
    seedFile(workDir, 'substrate.secrets.md', body);

    const result = await computeConfigHashes(workDir, [
      '.claude/settings.json',
      'substrate.config.md',
      'substrate.secrets.md',
    ]);

    expect(Object.keys(result).sort()).toEqual([
      '.claude/settings.json',
      'substrate.config.md',
      'substrate.secrets.md',
    ]);
    const expected = sha256Of(body);
    expect(result['.claude/settings.json']).toBe(expected);
    expect(result['substrate.config.md']).toBe(expected);
    expect(result['substrate.secrets.md']).toBe(expected);
  });

  it('// @risk: R2 — one config file absent returns 2-entry map without throwing', async () => {
    seedFile(workDir, '.claude/settings.json', 'a');
    seedFile(workDir, 'substrate.config.md', 'b');
    // substrate.secrets.md deliberately absent

    const result = await computeConfigHashes(workDir, [
      '.claude/settings.json',
      'substrate.config.md',
      'substrate.secrets.md',
    ]);

    expect(Object.keys(result).sort()).toEqual([
      '.claude/settings.json',
      'substrate.config.md',
    ]);
    expect('substrate.secrets.md' in result).toBe(false);
  });

  it('// @risk: R2 — LF normalization: CRLF file hashes same as LF file', async () => {
    seedFile(workDir, '.claude/settings.json', 'line1\r\nline2\r\n');
    const result = await computeConfigHashes(workDir, ['.claude/settings.json']);
    const expectedLF = sha256Of('line1\nline2\n');
    expect(result['.claude/settings.json']).toBe(expectedLF);
  });
});
