#!/usr/bin/env node
// tier-filter.mjs — refuses if any shipped Markdown file has YAML
// frontmatter with `tier: upstream`.
//
// Contract: ADR-004 §Ordered steps, check 10.
//
// Usage:
//   npm pack --dry-run --json > /tmp/pack.json
//   node scripts/tier-filter.mjs /tmp/pack.json
//
// Exit codes:
//   0 — no tier: upstream frontmatter in any shipped Markdown
//   3 — one or more files carry tier: upstream; publishing refused
//
// The scanner ONLY parses YAML frontmatter at BOF. A README table
// documenting the tier system with `| tier: upstream |` in its rows
// does not trip.

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve as pathResolve, dirname, join } from 'node:path';

// scanFrontmatter — returns true if the frontmatter block at BOF has
// tier: upstream as an exact top-level key value.
//
// Normalization steps applied before parsing:
//   1. CRLF → LF so Windows-authored Markdown does not silently pass
//   2. Optional UTF-8 BOM at BOF stripped
//   3. Optional leading blank lines tolerated
//   4. Quoted values (single or double) stripped before compare
//
// ADR-004 §Content-of-each-check L151-158 promises "parses the YAML
// frontmatter block." Windows-authored files with CRLF + BOM must
// parse consistently or the filter silently misses tier: upstream
// leaks.
export function scanFrontmatter(filename, content) {
  // Only .md/.mdx/.markdown are candidates.
  if (!/\.(md|mdx|markdown)$/i.test(filename)) return false;

  // Normalize line endings + strip BOM + skip leading blanks so the
  // frontmatter regex sees a canonical shape.
  let normalized = content.replace(/\r\n/g, '\n');
  if (normalized.charCodeAt(0) === 0xfeff) normalized = normalized.slice(1);
  normalized = normalized.replace(/^\s*\n/, ''); // drop one leading blank if present

  // Frontmatter must start at BOF (after normalization) with --- on a
  // line by itself. Trailing whitespace on the delimiter is tolerated.
  const fmMatch = normalized.match(/^---[ \t]*\n([\s\S]*?)\n---[ \t]*(?:\n|$)/);
  if (!fmMatch) return false;
  const block = fmMatch[1];

  // Look for a top-level key `tier` whose value is exactly `upstream`.
  // Value can be bare or quoted with single or double quotes.
  const tierMatch = block.match(/^tier:\s*(?:"([^"]*)"|'([^']*)'|(\S+))\s*$/m);
  if (!tierMatch) return false;

  const value = tierMatch[1] ?? tierMatch[2] ?? tierMatch[3];
  return value === 'upstream';
}

async function main() {
  const packJsonPath = process.argv[2];
  if (!packJsonPath) {
    process.stderr.write('usage: node scripts/tier-filter.mjs <pack-json-path>\n');
    process.exit(3);
  }

  let packManifest;
  try {
    const raw = readFileSync(packJsonPath, 'utf8');
    const parsed = JSON.parse(raw);
    packManifest = Array.isArray(parsed) ? parsed[0] : parsed;
  } catch (e) {
    process.stderr.write(`tier-filter: cannot read ${packJsonPath}: ${e.message}\n`);
    process.exit(3);
  }

  const repoRoot = pathResolve(dirname(fileURLToPath(import.meta.url)), '..');
  const hits = [];

  for (const entry of packManifest.files || []) {
    const rel = entry.path;
    const full = join(repoRoot, rel);
    if (!existsSync(full)) continue;
    const content = readFileSync(full, 'utf8');
    if (scanFrontmatter(rel, content)) hits.push(rel);
  }

  if (hits.length === 0) {
    process.stdout.write('tier-filter: clean. No tier: upstream frontmatter in shipped content.\n');
    process.exit(0);
  }

  process.stderr.write('tier-filter: REFUSED. Files marked tier: upstream:\n');
  for (const rel of hits) {
    process.stderr.write(`  ${rel}\n`);
  }
  process.stderr.write('\n');
  process.stderr.write('fix:\n');
  process.stderr.write('  - retag the source file with tier: lite or tier: standard, or\n');
  process.stderr.write('  - exclude it from the package.json "files" array.\n');
  process.exit(3);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
