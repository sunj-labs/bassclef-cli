#!/usr/bin/env node
// andon-scan.mjs — refuses if operator-private terms appear in files
// npm pack will ship.
//
// Contract: ADR-004 §Ordered steps, check 9.
//
// Usage:
//   npm pack --dry-run --json > /tmp/pack.json
//   node scripts/andon-scan.mjs /tmp/pack.json
//
// Exit codes:
//   0 — no operator-private terms found in shipped content
//   2 — one or more terms found; publishing refused
//
// Term list starts NARROW per Saltzer principle 1 (economy of
// mechanism). Grows on incident. Quarterly review prunes unused
// terms per ADR-004.
//
// Per-file allowlist via `# andon-allow: <regex>` header — one regex
// per header line. The scanner reads the header block at BOF (first
// ~20 lines) and adds those patterns to the allow list for that file
// only.

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve as pathResolve, dirname, join } from 'node:path';

const TERMS = [
  // Absolute POSIX home paths — a leak of the maintainer's local layout.
  /\/Users\/[a-z0-9-]+/i,
  /\/home\/[a-z0-9-]+/i,
  // Operator-private path references — content that should never ship.
  /docs\/operator-private\//,
  // Email addresses — LICENSE + package.json `author` are the only
  // legitimate places; those get file-level allowlist entries below.
  /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i,
];

// Baseline allow list — regexes that are allowed to match ANYWHERE in
// specific shipped files. Kept narrow. Additions require an ADR
// amendment.
const FILE_ALLOWLIST = [
  { file: 'LICENSE', patterns: [/.*/] }, // LICENSE is Apache-2.0 verbatim
  { file: 'package.json', patterns: [/[a-z0-9._%+-]+@[a-z0-9.-]+/i] }, // author + bugs email
];

export function scanContent(filename, content, extraAllowRegexes = []) {
  // Read per-file header allowlist from `# andon-allow: <regex>` lines.
  const headerAllows = extractHeaderAllowlist(content);

  // File-level baseline allowlist for LICENSE, package.json.
  const baseline = FILE_ALLOWLIST.find((e) => filename === e.file || filename.endsWith('/' + e.file));
  const baselineAllows = baseline ? baseline.patterns : [];

  const allAllows = [...extraAllowRegexes, ...headerAllows, ...baselineAllows];

  const hits = [];
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (const term of TERMS) {
      const m = line.match(term);
      if (!m) continue;
      // Check allowlist.
      const allowed = allAllows.some((a) => a.test(m[0]) || a.test(line));
      if (allowed) continue;
      hits.push({ term: m[0], line: i + 1, context: line.trim() });
    }
  }
  return hits;
}

function extractHeaderAllowlist(content) {
  const out = [];
  const lines = content.split('\n').slice(0, 20);
  for (const line of lines) {
    const m = line.match(/#\s*andon-allow:\s*(.+)$/);
    if (m) {
      try {
        out.push(new RegExp(m[1].trim()));
      } catch {
        // Invalid regex in header — skip silently. The scan runs; a
        // broken header does not permit anything.
      }
    }
  }
  return out;
}

async function main() {
  const packJsonPath = process.argv[2];
  if (!packJsonPath) {
    process.stderr.write('usage: node scripts/andon-scan.mjs <pack-json-path>\n');
    process.exit(2);
  }

  let packManifest;
  try {
    const raw = readFileSync(packJsonPath, 'utf8');
    const parsed = JSON.parse(raw);
    // `npm pack --dry-run --json` emits an array with one entry per
    // package (usually one). Each entry has `.files: [{path, size, mode}]`.
    packManifest = Array.isArray(parsed) ? parsed[0] : parsed;
  } catch (e) {
    process.stderr.write(`andon-scan: cannot read ${packJsonPath}: ${e.message}\n`);
    process.exit(2);
  }

  const repoRoot = pathResolve(dirname(fileURLToPath(import.meta.url)), '..');
  const findings = [];

  for (const entry of packManifest.files || []) {
    const rel = entry.path;
    const full = join(repoRoot, rel);
    if (!existsSync(full)) continue;
    // Skip binary-ish files.
    if (!/\.(js|cjs|mjs|ts|tsx|json|md|html|css|txt|yml|yaml)$/i.test(rel) && rel !== 'LICENSE' && rel !== 'README') continue;
    const content = readFileSync(full, 'utf8');
    const hits = scanContent(rel, content);
    if (hits.length > 0) findings.push({ file: rel, hits });
  }

  if (findings.length === 0) {
    process.stdout.write('andon-scan: clean. No operator-private terms in shipped content.\n');
    process.exit(0);
  }

  process.stderr.write('andon-scan: ANDON TRIPPED. Operator-private terms in shipped content:\n');
  for (const f of findings) {
    for (const h of f.hits) {
      process.stderr.write(`  ${f.file}:${h.line}  term: ${h.term}\n`);
      process.stderr.write(`      context: ${h.context}\n`);
    }
  }
  process.stderr.write('\n');
  process.stderr.write('fix:\n');
  process.stderr.write('  - rebuild from a CI-clean checkout, or\n');
  process.stderr.write('  - if the reference is intentional, add "# andon-allow: <regex>" to the file header.\n');
  process.exit(2);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
