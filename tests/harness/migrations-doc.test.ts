// docs/migrations/0.1.0.md — Tier 0 doc-existence tests per Beck TDD.
//
// The adopter-facing migration doc lands at Step 6. Three tests pin the
// contract that the doc exists and names both migration paths + the
// dry-run command.
//
// RED signal — docs/migrations/0.1.0.md does not exist yet. Every test
// here fails until Step 6 authors the doc.
//
// Ledger tie: RFC L3 (CHANGELOG cross-ref for the "adopter migration
// ships as MINOR" precedent) sits partly here — the doc names the
// precedent alongside its migration guidance.
//
// test-list (Beck):
// [ ] doc exists at expected path
// [ ] doc names both Path A (0.0.2 → 0.1.0) and Path B (0.0.1 → 0.1.0)
// [ ] doc includes at least one `bassclef migrate --dry-run` example

import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..', '..');
const MIGRATION_DOC = resolve(REPO_ROOT, 'docs', 'migrations', '0.1.0.md');

describe('docs/migrations/0.1.0.md', () => {
  it('exists at the expected path', () => {
    expect(existsSync(MIGRATION_DOC)).toBe(true);
  });

  it('names both Path A (0.0.2 upgrade) and Path B (0.0.1 fresh init)', () => {
    if (!existsSync(MIGRATION_DOC)) return;
    const body = readFileSync(MIGRATION_DOC, 'utf8');
    expect(body).toMatch(/0\.0\.2/);
    expect(body).toMatch(/0\.0\.1/);
    expect(body).toMatch(/[Pp]ath A/);
    expect(body).toMatch(/[Pp]ath B/);
  });

  it('// @rfc: L3 — includes at least one bassclef migrate --dry-run example AND CHANGELOG precedent note', () => {
    if (!existsSync(MIGRATION_DOC)) return;
    const body = readFileSync(MIGRATION_DOC, 'utf8');
    expect(body).toMatch(/bassclef migrate.*--dry-run/);
    // RFC L3 precedent note — the doc names "adopter migration ships as MINOR"
    // (or MINOR precedent language) somewhere in the body.
    expect(body.toLowerCase()).toMatch(/adopter migration|minor.*precedent|migration.*minor/);
  });
});
