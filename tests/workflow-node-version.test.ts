// Workflow Node version invariant — per goal 2026-09-12b-node-bump + issue #66.
//
// @verifies R-CI-001 (Node runner version pin discipline)
//
// GitHub Actions emits a deprecation warning when a workflow runs on
// Node 20 as of 2026-09. Node 20 EOLs 2026-04. This test asserts every
// `node-version:` pin in every workflow file uses Node 22 or newer.
// A PR that reintroduces Node 20 (or older) fails CI.
//
// Rationale: workflow-only edits do not touch the published tarball,
// but they do touch the runner where `npm run build` produces the
// tarball. Silent drift back to Node 20 would restart the deprecation
// clock without anyone noticing until GHA hard-removes Node 20 support.

import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const WORKFLOWS_DIR = resolve(__dirname, '..', '.github/workflows');

// Every `node-version:` line in any workflow file.
function collectNodeVersionPins(): { file: string; line: number; version: string }[] {
  const results: { file: string; line: number; version: string }[] = [];
  const files = readdirSync(WORKFLOWS_DIR).filter((f) => f.endsWith('.yml') || f.endsWith('.yaml'));
  for (const file of files) {
    const path = join(WORKFLOWS_DIR, file);
    const lines = readFileSync(path, 'utf8').split('\n');
    for (let i = 0; i < lines.length; i++) {
      const match = lines[i].match(/node-version:\s*['"]?([^'"\s]+)['"]?/);
      if (match) {
        results.push({ file, line: i + 1, version: match[1] });
      }
    }
  }
  return results;
}

describe('workflow Node version invariant (#66)', () => {
  it('every workflow file pins Node 22 or newer', () => {
    const pins = collectNodeVersionPins();
    expect(pins.length).toBeGreaterThan(0);
    for (const pin of pins) {
      // Accept: '22', '22.x', '22.0.0', '24', 'lts/*', 'lts/jod' (Node 22 LTS alias)
      const versionOk =
        pin.version === 'lts/*' ||
        pin.version === 'lts/jod' ||
        /^(2[2-9]|[3-9]\d|\d{3,})(\.|$)/.test(pin.version);
      expect(versionOk, `${pin.file}:${pin.line} pins Node '${pin.version}' — must be 22+ per goal 2026-09-12b`).toBe(true);
    }
  });

  it('the current set of pins matches the expected 3-pin footprint', () => {
    // Belt-and-suspenders: if a new workflow adds a Node pin without
    // updating this test's expected count, the author sees a signal to
    // review whether that new workflow also needs the version guard.
    const pins = collectNodeVersionPins();
    expect(pins.length).toBe(3);
  });

  it('no workflow references "Node 20" as a step name (stale label check)', () => {
    // Catches half-done renames where the pin is 22 but the step name
    // still reads "Setup Node 20". Not a hard invariant, but a fast
    // signal that a bump landed cleanly.
    const files = readdirSync(WORKFLOWS_DIR).filter((f) => f.endsWith('.yml') || f.endsWith('.yaml'));
    for (const file of files) {
      const content = readFileSync(join(WORKFLOWS_DIR, file), 'utf8');
      // Step-name pattern: `- name: Setup Node 20` (with optional suffix).
      const staleStepName = /- name:\s*Setup Node 20\b/;
      expect(staleStepName.test(content), `${file} contains a stale "Setup Node 20" step name`).toBe(false);
    }
  });
});
