// cli 1.1.1 init reporting cures — unit tests.
//
// Per Beck: RED first. Per ADR-010 and RFC-0004.
//
// test-list:
// [x] classifyEntry sorts each of the eleven families
// [x] classifyEntry returns 'other' rather than dropping an unknown path
// [x] classifyEntry rejects a near-miss prefix (.claude/skillsfoo/)
// [x] classifyEntry accepts README.md as a root doc and rejects gitignore
// [x] buildInitReport totals equal config writes plus copied entries
// [x] buildInitReport family counts sum to the copied-entry count
// [x] buildInitReport splits refused from errored and keeps failed as the sum
// [x] buildInitReport counts repo and home destinations separately
// [x] renderJsonReport writes one object and one newline, nothing else

import { describe, it, expect } from 'vitest';
import { classifyEntry } from '../src/lib/catalog-classify.js';
import { buildInitReport, renderJsonReport } from '../src/lib/init-report.js';

describe('classifyEntry — the eleven families', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['.claude/skills/temperance/SKILL.md', 'skills'],
    ['.claude/rules/testing.md', 'rules'],
    ['.claude/agents/Builder.md', 'agents'],
    ['.claude/luminaries/kent-beck.md', 'luminaries'],
    ['lib/state.sh', 'libs'],
    ['architecture/decisions/ADR-001-x.md', 'adrs'],
    ['standards/state-spine.md', 'standards'],
    ['templates/spec-template.md', 'templates'],
    ['presence/install/bassclef-sync.template.sh', 'presence-templates'],
    ['scripts/generate-lite-manifest.sh', 'scripts'],
    ['README.md', 'root-docs'],
  ];
  for (const [path, family] of cases) {
    it(`sorts ${path} as ${family}`, () => {
      expect(classifyEntry(path)).toBe(family);
    });
  }
});

describe('classifyEntry — edges (RFC-0004 M-2)', () => {
  it('returns other for a path it does not recognize', () => {
    expect(classifyEntry('.claude/settings.json')).toBe('other');
  });

  it('does not treat a near-miss prefix as a skill', () => {
    expect(classifyEntry('.claude/skillsfoo/x.md')).toBe('other');
  });

  it('does not treat a hook as a skill', () => {
    expect(classifyEntry('.claude/hooks/session-end.sh')).toBe('hooks');
  });

  it('accepts README.md as a root doc', () => {
    expect(classifyEntry('README.md')).toBe('root-docs');
  });

  it('rejects gitignore as a root doc — it starts lowercase', () => {
    expect(classifyEntry('.gitignore')).toBe('other');
  });
});

describe('buildInitReport — totals (ADR-010 D1, Hoare postconditions)', () => {
  const entries = [
    { path: '.claude/skills/a/SKILL.md', scope: 'project' as const, content_hash_sha256: 'h1' },
    { path: '.claude/rules/b.md', scope: 'project' as const, content_hash_sha256: 'h2' },
    { path: '.claude/hooks/c.sh', scope: 'project' as const, content_hash_sha256: 'h3' },
    { path: '.claude/hooks/c.sh', scope: 'user' as const, content_hash_sha256: 'h3' },
  ];
  const configs = [{ path: 'substrate.config.md', hash: 'h0' }];

  it('counts every config write plus every copied entry as written', () => {
    const r = buildInitReport({
      entries,
      configs,
      refused: [],
      errored: [],
      hookCount: 1,
      declaredHooksCopied: 1,
      tier: 'lite',
    });
    expect(r.totals.written).toBe(configs.length + entries.length);
  });

  it('counts refused and errored files in totals.files, so the manifest matches', () => {
    // RFC-0005 A-1: totals.files counted successes only, so on any re-run
    // it drifted from the manifest by exactly the refused count. The
    // manifest records refused entries per ADR-010 D4; the report has to
    // count them or the two disagree — the exact defect this goal closes.
    const r = buildInitReport({
      entries,
      configs,
      refused: ['a.md', 'b.md'],
      errored: ['c.md'],
      hookCount: 1,
      declaredHooksCopied: 1,
      tier: 'lite',
    });
    expect(r.totals.written).toBe(configs.length + entries.length);
    expect(r.totals.files).toBe(configs.length + entries.length + 3);
  });

  it('keeps hooks.declared and hooks.copied in the same unit', () => {
    // RFC-0005 A-2: hooks.copied counted every hook FILE while declared
    // counted settings.json commands. A reader subtracting them saw
    // helpers as unexpected hooks. Files now have their own field.
    const r = buildInitReport({
      entries,
      configs,
      refused: [],
      errored: [],
      hookCount: 1,
      declaredHooksCopied: 1,
      tier: 'lite',
    });
    expect(r.hooks.declared).toBe(1);
    expect(r.hooks.copied).toBe(1);
    expect(r.hooks.files).toBe(2);
  });

  it('family counts sum to the copied-entry count', () => {
    const r = buildInitReport({
      entries,
      configs,
      refused: [],
      errored: [],
      hookCount: 1,
      declaredHooksCopied: 1,
      tier: 'lite',
    });
    const sum = Object.values(r.catalog).reduce((a, b) => a + b, 0);
    expect(sum).toBe(entries.length);
  });

  it('counts repo and home destinations separately', () => {
    const r = buildInitReport({
      entries,
      configs,
      refused: [],
      errored: [],
      hookCount: 1,
      declaredHooksCopied: 1,
      tier: 'lite',
    });
    expect(r.totals.project).toBe(3);
    expect(r.totals.user).toBe(1);
    expect(r.totals.project + r.totals.user).toBe(entries.length);
  });

  it('splits refused from errored and keeps failed as their sum', () => {
    const r = buildInitReport({
      entries,
      configs,
      refused: ['x.md', 'y.md'],
      errored: ['z.md'],
      hookCount: 1,
      declaredHooksCopied: 1,
      tier: 'lite',
    });
    expect(r.refused).toBe(2);
    expect(r.errored).toBe(1);
    // ADR-010 D7: `failed` survives one release as the sum, because a
    // vanished field reads as undefined and silently stops a reader's alerts.
    expect(r.failed).toBe(3);
  });
});

describe('renderJsonReport — stdout discipline (ADR-010 D6, RFC-0004 M-1)', () => {
  it('writes exactly one JSON object and one newline', () => {
    const r = buildInitReport({
      entries: [],
      configs: [],
      refused: [],
      errored: [],
      hookCount: 0,
      declaredHooksCopied: 0,
      tier: 'lite',
    });
    let buffer = '';
    renderJsonReport(r, (s: string) => { buffer += s; });
    // Byte-exact. Parsing alone would pass even with a human line appended.
    expect(buffer).toBe(JSON.stringify(r) + '\n');
    expect(buffer.endsWith('}\n')).toBe(true);
  });
});
