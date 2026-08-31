#!/usr/bin/env node
// andon-scan.mjs — refuses if operator-private terms appear in shipped
// files. Two check kinds:
//   1. PATH check — the shipped file's own path matches an operator-
//      private location (e.g., substrate/docs/operator-private/x.md).
//   2. CONTENT check — the file's content contains a leak term
//      (absolute /Users or /home path; unauthorized email address).
//
// @requirement R-NPM-005
//
// Contract: ADR-004 §Ordered steps, check 9.
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
//
// Usage:
//   npm pack --dry-run --json > /tmp/pack.json
//   node scripts/andon-scan.mjs /tmp/pack.json
//
// Exit codes:
//   0 — no leaks found
//   2 — one or more leaks found; publishing refused
//
// Term list starts NARROW per Saltzer principle 1 (economy of
// mechanism). Grows on incident. Quarterly review prunes unused
// terms per ADR-004.
//
// Per-file allowlist via `# andon-allow: <regex>` header — one regex
// per header line. The scanner reads the header block at BOF (first
// ~20 lines) and adds those patterns to the allow list for that file
// only.
//
// Amendment 2026-08-31 (issue #40 follow-on): docs/operator-private/
// moved from CONTENT scan to PATH scan. Descriptive prose mentions
// (e.g., "See docs/operator-private/ for private strategy notes")
// legitimately ship in ADRs, skills, README, CONTRIBUTING. The real
// leak signal is a shipped FILE at that path. Per pre-code
// architect-review 2026-08-31 + ADR-004 §D3 amendment. Accepted-risk
// note: content mention of specific operator-private FILENAMES in
// prose is no longer scanned; PR review catches the rare content-
// pasting leak.

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve as pathResolve, dirname, join } from 'node:path';

const TERMS = [
  // Absolute POSIX home paths — a leak of the maintainer's local layout.
  /\/Users\/[a-z0-9-]+/i,
  /\/home\/[a-z0-9-]+/i,
  // Email addresses — LICENSE + package.json `author` are the primary
  // legitimate places; per-file allowlist entries below carry two
  // more public contact addresses.
  /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i,
];

// Path-scan terms — the shipped file's OWN path must not match these.
// Content mentions of these strings in prose stay legitimate (ADRs,
// skills, README, CONTRIBUTING describe the operator-private discipline).
const PATH_TERMS = [
  /(^|\/)docs\/operator-private\//,
];

// Baseline allow list — regexes that are allowed to match ANYWHERE in
// specific shipped files. Kept narrow. Additions require an ADR
// amendment.
const FILE_ALLOWLIST = [
  { file: 'LICENSE', patterns: [/.*/] }, // LICENSE is Apache-2.0 verbatim
  { file: 'package.json', patterns: [/[a-z0-9._%+-]+@[a-z0-9.-]+/i] }, // author + bugs email
  // Public contact addresses that legitimately appear in specific
  // files. Named per-file (not global) to keep the discrimination
  // knowledge local to the file that carries the address. Per
  // architect-review 2026-08-31 (Parnas information hiding).
  { file: 'CODE_OF_CONDUCT.md', patterns: [/conduct@bassclef\.dev/] },
  { file: '.claude/skills/promote/SKILL.md', patterns: [/hello@bassclef\.dev/] },
];

// Scan the shipped file's PATH itself. Returns hits when the path
// matches an operator-private location. Content is not read for this
// check — path check runs before content scan and short-circuits it
// when it fires.
export function scanPath(filename) {
  const hits = [];
  for (const term of PATH_TERMS) {
    if (term.test(filename)) {
      hits.push({
        term: filename,
        line: 0, // 0 signals path leak (not content leak) in the report
        context: `shipped file path matches operator-private location (regex: ${term.source})`,
      });
    }
  }
  return hits;
}

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

    // Path check first — short-circuits content scan when the file's
    // own path leaks an operator-private location.
    const pathHits = scanPath(rel);
    if (pathHits.length > 0) {
      findings.push({ file: rel, hits: pathHits });
      continue;
    }

    const full = join(repoRoot, rel);
    if (!existsSync(full)) continue;
    // Skip binary-ish files.
    if (!/\.(js|cjs|mjs|ts|tsx|json|md|html|css|txt|yml|yaml)$/i.test(rel) && rel !== 'LICENSE' && rel !== 'README') continue;
    const content = readFileSync(full, 'utf8');
    const hits = scanContent(rel, content);
    if (hits.length > 0) findings.push({ file: rel, hits });
  }

  if (findings.length === 0) {
    process.stdout.write('andon-scan: clean. No leaks in shipped tarball.\n');
    process.exit(0);
  }

  process.stderr.write('andon-scan: ANDON TRIPPED. Leaks in shipped tarball:\n');
  for (const f of findings) {
    for (const h of f.hits) {
      const marker = h.line === 0 ? '(path)' : `:${h.line}`;
      process.stderr.write(`  ${f.file}${marker}  term: ${h.term}\n`);
      process.stderr.write(`      context: ${h.context}\n`);
    }
  }
  process.stderr.write('\n');
  process.stderr.write('fix:\n');
  process.stderr.write('  - path leaks (marked "(path)"): rebuild from a CI-clean checkout OR cure the source manifest so the file does not ship.\n');
  process.stderr.write('  - content leaks (marked with line number): rebuild, OR if the reference is intentional add "# andon-allow: <regex>" to the file header, OR add a per-file FILE_ALLOWLIST entry to scripts/andon-scan.mjs (requires ADR-004 amendment).\n');
  process.exit(2);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
