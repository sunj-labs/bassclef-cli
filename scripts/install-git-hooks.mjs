#!/usr/bin/env node
// scripts/install-git-hooks.mjs
//
// Installs the bassclef-cli git hooks into .git/hooks/. Idempotent.
// Preserves any prior hook content by chaining.
//
// @requirement R-NPM-007 (extension per Epic #194 Stories 1-3)
//
// Usage:
//   npm run install-hooks
//   node scripts/install-git-hooks.mjs
//
// What it installs:
//   - .git/hooks/pre-commit → invokes scripts/git-hooks/pre-commit-version-sync.sh
//
// Sentinel: each installed section is wrapped in
//   # >>> bassclef-cli:<name> <<<
//   ...
//   # <<< bassclef-cli:<name> >>>
// A re-run reads the sentinel and skips (idempotent). Content OUTSIDE
// the sentinel block stays untouched — other hook systems (personal
// hooks, husky, lefthook) coexist.
//
// See docs/decompositions/2026-09-21-pre-tag-version-sync.md § Interface 5.

import { existsSync, mkdirSync, readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const SENTINEL_NAME = 'pre-commit-version-sync';
const SENTINEL_OPEN = `# >>> bassclef-cli:${SENTINEL_NAME} <<<`;
const SENTINEL_CLOSE = `# <<< bassclef-cli:${SENTINEL_NAME} >>>`;

const HOOK_BODY_LINES = [
  SENTINEL_OPEN,
  '# Installed by scripts/install-git-hooks.mjs. Do not edit inside the sentinels.',
  '# See scripts/git-hooks/pre-commit-version-sync.sh + CONTRIBUTING.md § Version bumps.',
  '"$(git rev-parse --show-toplevel)/scripts/git-hooks/pre-commit-version-sync.sh" || exit $?',
  SENTINEL_CLOSE,
];

/**
 * Resolve the .git/hooks path. Handles submodules + worktrees via `git rev-parse`.
 */
export function resolveHooksDir(repoRoot) {
  try {
    const output = execSync('git rev-parse --git-path hooks', {
      cwd: repoRoot,
      encoding: 'utf8',
    }).trim();
    return resolve(repoRoot, output);
  } catch (err) {
    throw new Error(
      `Could not resolve git hooks dir under ${repoRoot}: ${err.message}`,
    );
  }
}

/**
 * Compose the pre-commit script content given any prior content.
 * If prior content already carries the sentinel, return null (no-op).
 * If prior content lacks the sentinel, append our block preserving prior content.
 * If no prior content, produce a fresh script with shebang + our block.
 */
export function composePreCommitContent(priorContent) {
  const ourBlock = HOOK_BODY_LINES.join('\n');

  if (priorContent && priorContent.includes(SENTINEL_OPEN)) {
    // Already installed. No-op.
    return null;
  }

  if (!priorContent || priorContent.trim() === '') {
    return ['#!/usr/bin/env bash', 'set -e', '', ourBlock, ''].join('\n');
  }

  // Prior content exists AND lacks sentinel. Append preserving prior content.
  const trimmed = priorContent.replace(/\n+$/, '');
  return `${trimmed}\n\n${ourBlock}\n`;
}

function main() {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(scriptDir, '..');

  const hooksDir = resolveHooksDir(repoRoot);
  mkdirSync(hooksDir, { recursive: true });

  const preCommitPath = resolve(hooksDir, 'pre-commit');
  const priorContent = existsSync(preCommitPath)
    ? readFileSync(preCommitPath, 'utf8')
    : null;

  const nextContent = composePreCommitContent(priorContent);
  if (nextContent === null) {
    process.stdout.write(
      `install-git-hooks: pre-commit already carries bassclef-cli:${SENTINEL_NAME}. No changes.\n`,
    );
    return;
  }

  writeFileSync(preCommitPath, nextContent, 'utf8');
  chmodSync(preCommitPath, 0o755);

  process.stdout.write(
    `install-git-hooks: wrote ${preCommitPath}\n` +
      `  Section: bassclef-cli:${SENTINEL_NAME}\n` +
      `  On commit, checks the four version-bearing files agree.\n` +
      `  Bypass one commit: git commit --no-verify (PR-CI still catches drift).\n`,
  );
}

const isMain =
  process.argv[1] &&
  fileURLToPath(import.meta.url) === resolve(process.argv[1]);

if (isMain) {
  main();
}

export { SENTINEL_OPEN, SENTINEL_CLOSE, HOOK_BODY_LINES };
