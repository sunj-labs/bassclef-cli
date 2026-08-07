#!/usr/bin/env node
// validate-tag.mjs — refuses if the release tag does not match the
// package.json version, or the tag is not semver-shaped, or the tagged
// commit is not reachable from origin/main.
//
// Contract: ADR-004 §Ordered steps, check 4.
//
// Usage:
//   node scripts/validate-tag.mjs <tag>
//
// Exit codes:
//   0 — all checks pass
//   1 — refused (mismatch, format, or ancestor fail)
//
// Executable: intentionally ESM (.mjs) with `#!/usr/bin/env node` so
// GitHub Actions can invoke without a build step. Same reason for
// zero runtime deps.

import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Semver v-prefixed tag pattern. Refuses v0.0.2.4 and v0.0.2extra.
const SEMVER_TAG_RE = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?$/;

export function isSemverTag(tag) {
  return SEMVER_TAG_RE.test(tag);
}

// String-equal comparison — stricter than semver-equal. Catches beta.1
// vs beta.01 typos that semver considers equal.
export function validateTagMatch(tag, packageVersion) {
  if (!tag.startsWith('v')) {
    throw new Error(
      `validate-tag: tag lacks required v prefix.\n` +
        `  got: ${tag}\n` +
        `  expected: v${packageVersion}\n` +
        `  fix: git tag v${packageVersion} && git push origin v${packageVersion}`
    );
  }
  if (!isSemverTag(tag)) {
    throw new Error(
      `validate-tag: tag is not a valid semver format.\n` +
        `  got: ${tag}\n` +
        `  expected form: vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-PRERELEASE\n` +
        `  fix: delete + re-tag with a semver-valid form.`
    );
  }
  const tagVersion = tag.slice(1);
  if (tagVersion !== packageVersion) {
    throw new Error(
      `validate-tag: version mismatch.\n` +
        `  package.json (./package.json) has version ${packageVersion}.\n` +
        `  tag ${tag} expects ${tagVersion}.\n` +
        `  fix: bump package.json to ${tagVersion}, commit, delete + re-push the tag.`
    );
  }
}

export function pickDistTag(tag) {
  const match = tag.match(SEMVER_TAG_RE);
  const prerelease = match?.[4];
  return prerelease ? 'next' : 'latest';
}

// Ancestor check via git. Refuses tags on branches never merged to main.
// Callers set SKIP_ANCESTOR=1 in tests where git subprocess is not
// meaningful.
export function assertAncestorOfMain(tag) {
  if (process.env['SKIP_ANCESTOR'] === '1') return;
  try {
    execSync(`git merge-base --is-ancestor ${tag} origin/main`, { stdio: 'ignore' });
  } catch {
    throw new Error(
      `validate-tag: tag ${tag} is not reachable from origin/main.\n` +
        `  fix: merge the tagged commit into main, or re-tag from a commit that is on main.`
    );
  }
}

async function main() {
  const tag = process.argv[2];
  if (!tag) {
    process.stderr.write('usage: node scripts/validate-tag.mjs <tag>\n');
    process.exit(1);
  }
  const pkgUrl = new URL('../package.json', import.meta.url);
  const pkg = JSON.parse(readFileSync(pkgUrl, 'utf8'));
  try {
    validateTagMatch(tag, pkg.version);
    assertAncestorOfMain(tag);
    process.stdout.write(`validate-tag: ${tag} == package.json ${pkg.version} + reachable from origin/main. OK.\n`);
    process.stdout.write(`validate-tag: dist-tag = ${pickDistTag(tag)}\n`);
    process.exit(0);
  } catch (e) {
    process.stderr.write(e.message + '\n');
    process.exit(1);
  }
}

// Run only when invoked directly (not when imported by tests).
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
