// Workflow-path invariant test — per ADR-004 §Workflow file path L74.
//
// @verifies R-NPM-006
//
// `.github/workflows/publish.yml` is semver-locked. The npm trusted-
// publisher config on npmjs.com pins this exact path. Renaming the
// file breaks publishing silently — the workflow runs, but npm
// rejects the OIDC identity and every release fails until an operator
// updates the config.
//
// This test asserts the path exists. A PR that renames or deletes
// the file fails CI before it can merge to main.

import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const WORKFLOW_PATH = resolve(REPO_ROOT, '.github/workflows/publish.yml');

describe('workflow path invariant (ADR-004)', () => {
  it('.github/workflows/publish.yml exists at the semver-locked path', () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it('the workflow references its own scripts by relative path', () => {
    // Guard against a rename of the scripts/ dir the workflow calls.
    const yaml = readFileSync(WORKFLOW_PATH, 'utf8');
    expect(yaml).toContain('scripts/validate-tag.mjs');
    expect(yaml).toContain('scripts/andon-scan.mjs');
    expect(yaml).toContain('scripts/tier-filter.mjs');
  });

  it('the workflow permission set stays minimal', () => {
    // id-token: write for npm provenance, contents: read for checkout.
    // Any write-scope elevation on top of that is a defect per
    // ADR-004 §Job permissions.
    //
    // The check scans only the `permissions:` block so comments
    // explaining what is NOT granted do not false-trip.
    const yaml = readFileSync(WORKFLOW_PATH, 'utf8');
    const permBlock = extractPermissionsBlock(yaml);
    expect(permBlock).toContain('id-token: write');
    expect(permBlock).toContain('contents: read');
    expect(permBlock).not.toContain('contents: write');
    expect(permBlock).not.toContain('packages: write');
    expect(permBlock).not.toContain('pull-requests: write');
  });

  it('the workflow splits into checks + publish jobs (iteration c per D-4.1)', () => {
    // Two-job shape means the approver sees andon + tier-filter output
    // BEFORE the environment gate fires. Before iteration c the
    // environment gate sat on a single publish job, gating the whole
    // job before checkout — the approver had no check data to look at.
    //
    // Iteration c split into two jobs so the publish job (which carries
    // the environment) needs the checks job. Approval fires AFTER
    // checks green. See ADR-004 §Ordered steps + interaction-design
    // sequence diagram for the shape.
    const yaml = readFileSync(WORKFLOW_PATH, 'utf8');
    expect(yaml).toMatch(/^\s+checks:\s*$/m);
    expect(yaml).toMatch(/^\s+publish:\s*$/m);
    expect(yaml).toContain('needs: checks');
  });

  it('the publish job carries environment: npm-publish; the checks job does not', () => {
    // The environment gate lives on the publish job only. Placing it on
    // the checks job would gate the checks themselves, which defeats
    // the whole reason for the split.
    const yaml = readFileSync(WORKFLOW_PATH, 'utf8');
    const publishBlock = extractJobBlock(yaml, 'publish');
    const checksBlock = extractJobBlock(yaml, 'checks');
    expect(publishBlock).toContain('environment: npm-publish');
    expect(checksBlock).not.toContain('environment:');
  });
});

function extractPermissionsBlock(yaml: string): string {
  const lines = yaml.split('\n');
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^permissions:\s*$/.test(lines[i]!)) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) return '';
  const out: string[] = [];
  for (let i = start; i < lines.length; i++) {
    const line = lines[i]!;
    if (line === '' || /^\S/.test(line)) break; // exit on next top-level key
    // Skip comment lines — they explain what is NOT granted.
    if (/^\s*#/.test(line)) continue;
    out.push(line);
  }
  return out.join('\n');
}

// Extract a job block by name from the jobs: section. Returns lines
// under the job header up to the next job header or end of file.
function extractJobBlock(yaml: string, jobName: string): string {
  const lines = yaml.split('\n');
  let start = -1;
  const jobHeader = new RegExp(`^  ${jobName}:\\s*$`);
  for (let i = 0; i < lines.length; i++) {
    if (jobHeader.test(lines[i]!)) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) return '';
  const out: string[] = [];
  for (let i = start; i < lines.length; i++) {
    const line = lines[i]!;
    // Next job header is `  <name>:` at exactly 2-space indent.
    if (/^  \w+:\s*$/.test(line)) break;
    // Top-level key would also end the block.
    if (line.length > 0 && /^\S/.test(line)) break;
    out.push(line);
  }
  return out.join('\n');
}
