// Tests for scripts/install-git-hooks.mjs.
//
// Covers the composePreCommitContent pure function. The spawn-based
// end-to-end path is verified manually + by the operator's first
// `npm run install-hooks` run in CONTRIBUTING first-time setup.
//
// @verifies R-NPM-007 (extension per Epic #194 Stories 1-3)
//
// test-list:
// [x] composePreCommitContent creates a fresh script when no prior content
// [x] composePreCommitContent returns null when prior content already carries the sentinel
// [x] composePreCommitContent appends preserving prior content when sentinel absent
// [x] composePreCommitContent handles empty string as no prior content
// [x] composePreCommitContent output invokes pre-commit-version-sync.sh via git rev-parse

import { describe, it, expect } from 'vitest';
import {
  composePreCommitContent,
  SENTINEL_OPEN,
  SENTINEL_CLOSE,
} from '../scripts/install-git-hooks.mjs';

describe('composePreCommitContent', () => {
  it('creates a fresh script when no prior content', () => {
    const result = composePreCommitContent(null);
    expect(result).not.toBeNull();
    expect(result).toContain('#!/usr/bin/env bash');
    expect(result).toContain(SENTINEL_OPEN);
    expect(result).toContain(SENTINEL_CLOSE);
  });

  it('returns null when prior content already carries the sentinel', () => {
    const prior = `#!/usr/bin/env bash\n\n${SENTINEL_OPEN}\nsomething\n${SENTINEL_CLOSE}\n`;
    const result = composePreCommitContent(prior);
    expect(result).toBeNull();
  });

  it('appends preserving prior content when sentinel absent', () => {
    const prior = `#!/usr/bin/env bash\necho "personal hook"\n`;
    const result = composePreCommitContent(prior);
    expect(result).not.toBeNull();
    expect(result).toContain('echo "personal hook"');
    expect(result).toContain(SENTINEL_OPEN);
    expect(result).toContain(SENTINEL_CLOSE);
    // Personal content must come before ours (preservation, not clobber).
    expect(result!.indexOf('echo "personal hook"')).toBeLessThan(
      result!.indexOf(SENTINEL_OPEN),
    );
  });

  it('handles empty string as no prior content', () => {
    const result = composePreCommitContent('');
    expect(result).toContain('#!/usr/bin/env bash');
    expect(result).toContain(SENTINEL_OPEN);
  });

  it('output invokes pre-commit-version-sync.sh via git rev-parse', () => {
    const result = composePreCommitContent(null);
    expect(result).toContain(
      '"$(git rev-parse --show-toplevel)/scripts/git-hooks/pre-commit-version-sync.sh"',
    );
  });
});
