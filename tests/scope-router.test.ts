// scope-router test list — per Beck TDD + test-list-discipline.
//
// @verifies S1-fold (sudo bypass refused)
// @verifies N2-fold (Nygard — $HOME unset fail-loud)
// @verifies N6-fold (Nygard — unknown scope prefix throws)
// @verifies S4-fold (Saltzer-Schroeder — path traversal refused)
// @verifies P3-fold (Hunt & Thomas — CopyResult per-entry scope shape)
// @verifies UC-init-walker-hook-routing Ext 1a, 1c, 5b, 6e + main step 5-6
//
// RED phase — src/lib/scope-router.ts does not exist yet. Imports fail.
// Every test [ ] pending.
//
// # test-list:
// [ ] classify($HOME/...) returns scope=user with home-rooted target
// [ ] classify($CLAUDE_PROJECT_DIR/...) returns scope=project with targetDir-rooted target
// [ ] classify(unknown prefix) throws CopyFailure UnknownScopePrefix
// [ ] classify($HOME/...) with HOME unset throws EnvironmentIncomplete
// [ ] classify($HOME/...) with HOME=/root and allowRoot=false throws SudoBypassRefused
// [ ] classify($HOME/...) with HOME=/root and allowRoot=true returns scope=user with /root target
// [ ] classify($HOME/../etc/passwd) throws PathTraversalRefused
// [ ] classify($CLAUDE_PROJECT_DIR/../../../etc/passwd) throws PathTraversalRefused
// [ ] classify preserves the relative path after the prefix
// [ ] classify normalizes duplicate slashes in the command
// [ ] ScopeDecision.scope is a literal 'user' | 'project' discriminator
// [ ] classify empty string command throws

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
// RED: this import fails today; file authored in code phase.
import { classify, CopyFailure, type ScopeDecision } from '../src/lib/scope-router.js';

let workDir: string;
let originalHome: string | undefined;

beforeEach(() => {
  workDir = mkdtempSync(join(homedir(), '.bassclef-router-test-'));
  originalHome = process.env.HOME;
});

afterEach(() => {
  try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  if (originalHome === undefined) delete process.env.HOME;
  else process.env.HOME = originalHome;
});

describe('classify — happy path (UC main step 5-6)', () => {
  it('returns scope=user for $HOME/... command', () => {
    if (homedir() === '/root') return;
    const decision = classify(
      { command: '$HOME/.claude/hooks/bassclef-sync.sh' },
      { targetDir: workDir, allowRoot: false }
    );
    expect(decision.scope).toBe('user');
    expect(decision.targetPath).toBe(join(homedir(), '.claude/hooks/bassclef-sync.sh'));
  });

  it('returns scope=project for $CLAUDE_PROJECT_DIR/... command', () => {
    const decision = classify(
      { command: '$CLAUDE_PROJECT_DIR/.claude/hooks/plain-english-steering.sh' },
      { targetDir: workDir, allowRoot: false }
    );
    expect(decision.scope).toBe('project');
    expect(decision.targetPath).toBe(join(workDir, '.claude/hooks/plain-english-steering.sh'));
  });

  it('preserves the relative path after the prefix', () => {
    const decision = classify(
      { command: '$CLAUDE_PROJECT_DIR/.claude/hooks/nested/deep/hook.sh' },
      { targetDir: workDir, allowRoot: false }
    );
    expect(decision.targetPath).toBe(join(workDir, '.claude/hooks/nested/deep/hook.sh'));
  });

  it('normalizes duplicate slashes in the command', () => {
    const decision = classify(
      { command: '$CLAUDE_PROJECT_DIR//.claude//hooks//x.sh' },
      { targetDir: workDir, allowRoot: false }
    );
    expect(decision.targetPath).toBe(join(workDir, '.claude/hooks/x.sh'));
  });
});

describe('classify — Ext 1a $HOME unset', () => {
  it('throws EnvironmentIncomplete when HOME empty and scope is user', () => {
    process.env.HOME = '';
    expect(() =>
      classify(
        { command: '$HOME/.claude/hooks/bassclef-sync.sh' },
        { targetDir: workDir, allowRoot: false }
      )
    ).toThrow(CopyFailure);
  });
});

describe('classify — Ext 1c sudo bypass', () => {
  it('throws SudoBypassRefused when HOME=/root and allowRoot=false', () => {
    process.env.HOME = '/root';
    let caught: unknown;
    try {
      classify(
        { command: '$HOME/.claude/hooks/bassclef-sync.sh' },
        { targetDir: workDir, allowRoot: false }
      );
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(CopyFailure);
    expect((caught as CopyFailure).kind).toBe('SudoBypassRefused');
  });

  it('returns scope=user with /root target when allowRoot=true', () => {
    process.env.HOME = '/root';
    const decision = classify(
      { command: '$HOME/.claude/hooks/bassclef-sync.sh' },
      { targetDir: workDir, allowRoot: true }
    );
    expect(decision.scope).toBe('user');
    expect(decision.targetPath).toBe('/root/.claude/hooks/bassclef-sync.sh');
  });
});

describe('classify — Ext 5b unknown prefix', () => {
  it('throws UnknownScopePrefix on $XDG_DATA_HOME/... command', () => {
    let caught: unknown;
    try {
      classify(
        { command: '$XDG_DATA_HOME/.claude/hooks/x.sh' },
        { targetDir: workDir, allowRoot: false }
      );
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(CopyFailure);
    expect((caught as CopyFailure).kind).toBe('UnknownScopePrefix');
  });

  it('throws on empty string command (defensive)', () => {
    expect(() =>
      classify({ command: '' }, { targetDir: workDir, allowRoot: false })
    ).toThrow(CopyFailure);
  });
});

describe('classify — Ext 6e path traversal', () => {
  it('throws PathTraversalRefused on $HOME/../etc/passwd', () => {
    if (homedir() === '/root') return;
    let caught: unknown;
    try {
      classify(
        { command: '$HOME/../etc/passwd' },
        { targetDir: workDir, allowRoot: false }
      );
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(CopyFailure);
    expect((caught as CopyFailure).kind).toBe('PathTraversalRefused');
  });

  it('throws PathTraversalRefused on $CLAUDE_PROJECT_DIR/../../../etc/passwd', () => {
    let caught: unknown;
    try {
      classify(
        { command: '$CLAUDE_PROJECT_DIR/../../../etc/passwd' },
        { targetDir: workDir, allowRoot: false }
      );
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(CopyFailure);
    expect((caught as CopyFailure).kind).toBe('PathTraversalRefused');
  });
});

describe('classify — ScopeDecision shape (P3 fold)', () => {
  it('returns a discriminator with literal scope value', () => {
    const decision: ScopeDecision = classify(
      { command: '$CLAUDE_PROJECT_DIR/.claude/hooks/x.sh' },
      { targetDir: workDir, allowRoot: false }
    );
    // Type-level pin: 'user' | 'project' as literal.
    const literalCheck: 'user' | 'project' = decision.scope;
    expect(['user', 'project']).toContain(literalCheck);
  });
});
