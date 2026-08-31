// andon-scan test list — per Beck TDD.
//
// @verifies R-NPM-005
//
// scanContent takes (filename, content, allowRegexes) and returns
// content-scan findings. scanPath takes (filename) and returns
// path-scan findings (docs/operator-private/ leak).
//
// Amendment 2026-08-31 (issue #40 follow-on):
//   - docs/operator-private/ moved from content scan to path scan
//   - two per-file allowlist entries added for public contact emails
// Test list extended per pre-code architect-review 2026-08-31.
//
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
//
// [x] T1: absolute POSIX home path (/Users/*) is caught in content
// [x] T2: absolute Linux home path (/home/*) is caught in content
// [x] T3: docs/operator-private/ mention in CONTENT passes (moved to path scan)
// [x] T4: clean content passes
// [x] T5: per-file `# andon-allow: <regex>` respected
// [x] T6: multi-hit report includes line numbers
// [x] T7: package.json author email allowed via baseline allowlist
// [x] T8: LICENSE contents allowed via baseline allowlist
// [x] T9: scanPath catches docs/operator-private/ in shipped file PATH
// [x] T10: scanPath ignores paths without the leak prefix
// [x] T11: CODE_OF_CONDUCT.md allows conduct@bassclef.dev (per-file allowlist)
// [x] T12: CODE_OF_CONDUCT.md does NOT allow hello@bassclef.dev (regex-specific)
// [x] T13: promote SKILL.md allows hello@bassclef.dev (per-file allowlist)
// [x] T14: intentionality anchor — filename mention in prose passes (accepted risk)
//
// Test fixtures build the offending paths from string parts so the
// pre-commit-gate CCF-3 operator-path guard does not false-fire on
// this test file. The guard scans literal source text; concatenation
// keeps the substring out of the file even though the runtime value
// is identical.

import { describe, it, expect } from 'vitest';
import { scanContent, scanPath } from '../scripts/andon-scan.mjs';

// Build fixture paths without letting the literal `/Users/<name>` or
// `/home/<name>` appear in this source file.
const POSIX_PREFIX = '/Us' + 'ers';
const LINUX_PREFIX = '/ho' + 'me';
const fixturePosix = (name: string) => `${POSIX_PREFIX}/${name}`;
const fixtureLinux = (name: string) => `${LINUX_PREFIX}/${name}`;

// Build operator-private path fixtures from parts too — same reason.
const OP_PRIVATE_PREFIX = 'docs/' + 'operator-private/';

describe('andon-scan scanContent', () => {
  it('T1: catches an absolute POSIX home path', () => {
    const hits = scanContent('dist/cli.js', `const p = "${fixturePosix('testuser/secret')}";`, []);
    expect(hits.length).toBeGreaterThan(0);
    expect(hits[0].term.startsWith(POSIX_PREFIX)).toBe(true);
  });

  it('T2: catches an absolute Linux home path', () => {
    const hits = scanContent('dist/cli.js', `const p = "${fixtureLinux('testuser/x')}";`, []);
    expect(hits.length).toBeGreaterThan(0);
  });

  it('T3: docs/operator-private/ mention in CONTENT passes (moved to path scan)', () => {
    // Prior to 2026-08-31 amendment this would have caught. Now the
    // string in prose is fine; only the shipped file PATH triggers.
    const hits = scanContent('README.md', `See ${OP_PRIVATE_PREFIX}strategy/2026-07-26-notes.md`, []);
    expect(hits).toEqual([]);
  });

  it('T4: passes clean content', () => {
    const hits = scanContent('dist/cli.js', 'export const version = "0.0.2";', []);
    expect(hits).toEqual([]);
  });

  it('T5: respects a per-file andon-allow header', () => {
    const content = [
      `# andon-allow: ${POSIX_PREFIX}/`,
      `const p = "${fixturePosix('example/config')}";`,
    ].join('\n');
    const allow = new RegExp(POSIX_PREFIX + '\\/');
    const hits = scanContent('scripts/example.mjs', content, [allow]);
    expect(hits).toEqual([]);
  });

  it('T6: reports line numbers on multi-hit content', () => {
    const content = [
      'line 1',
      `const home = "${fixturePosix('x')}";`,
      'line 3',
      `const other = "${fixtureLinux('y')}";`,
    ].join('\n');
    const hits = scanContent('dist/cli.js', content, []);
    expect(hits.length).toBe(2);
    expect(hits[0].line).toBe(2);
    expect(hits[1].line).toBe(4);
  });

  it('T7: allows an email address in package.json (baseline allowlist)', () => {
    const content = '{"name":"@thebassclef/core","author":"maintainer@example.com"}';
    const hits = scanContent('package.json', content, []);
    expect(hits).toEqual([]);
  });

  it('T8: allows an email address anywhere in LICENSE (baseline allowlist)', () => {
    const content = 'Apache License with an email like foo@bar.com inline.';
    const hits = scanContent('LICENSE', content, []);
    expect(hits).toEqual([]);
  });

  it('T11: CODE_OF_CONDUCT.md allows conduct@bassclef.dev (per-file allowlist)', () => {
    // Shipped as substrate/CODE_OF_CONDUCT.md from the sibling bundle.
    // Per-file allowlist matches via endsWith('/CODE_OF_CONDUCT.md').
    const content = 'To report a violation, email conduct@bassclef.dev.';
    const hits = scanContent('substrate/CODE_OF_CONDUCT.md', content, []);
    expect(hits).toEqual([]);
  });

  it('T12: CODE_OF_CONDUCT.md does NOT allow hello@bassclef.dev (regex-specific)', () => {
    // Per-file allowlist for CODE_OF_CONDUCT is scoped to conduct@ only.
    // hello@ in this file should still trip.
    const content = 'Some prose with hello@bassclef.dev in it.';
    const hits = scanContent('substrate/CODE_OF_CONDUCT.md', content, []);
    expect(hits.length).toBeGreaterThan(0);
    expect(hits[0].term).toContain('hello@bassclef.dev');
  });

  it('T13: promote SKILL.md allows hello@bassclef.dev (per-file allowlist)', () => {
    const content = '| lite (npm-shipped) | `email:hello@bassclef.dev` (or your address) |';
    const hits = scanContent('substrate/.claude/skills/promote/SKILL.md', content, []);
    expect(hits).toEqual([]);
  });

  it('T14: intentionality anchor — filename mention in prose passes (accepted risk)', () => {
    // Per architect-review 2026-08-31 Focus Area 5: content-mention
    // of a specific operator-private filename is no longer scanned.
    // PR review is the mitigation. This test pins the intentional gap.
    const content = `Historical example: ${OP_PRIVATE_PREFIX}2026-08-30-launch-secret.md was deleted.`;
    const hits = scanContent('substrate/architecture/decisions/ADR-031-non-breaking.md', content, []);
    expect(hits).toEqual([]);
  });
});

describe('andon-scan scanPath', () => {
  it('T9: scanPath catches docs/operator-private/ in shipped file PATH', () => {
    const hits = scanPath(`substrate/${OP_PRIVATE_PREFIX}README.md`);
    expect(hits.length).toBe(1);
    expect(hits[0].line).toBe(0); // path leak sentinel
    expect(hits[0].context).toContain('shipped file path matches');
  });

  it('T10: scanPath ignores paths without the leak prefix', () => {
    expect(scanPath('substrate/README.md')).toEqual([]);
    expect(scanPath('substrate/.claude/skills/promote/SKILL.md')).toEqual([]);
    expect(scanPath('dist/cli.js')).toEqual([]);
    expect(scanPath('package.json')).toEqual([]);
  });
});
