#!/usr/bin/env node
// scripts/prepublish-bundle-substrate.mjs
//
// Copies substrate files from the sibling bassclef-upstream checkout
// into substrate/ under CWD, so npm pack includes them in the tarball.
//
// Contract per docs/adrs/ADR-007-npm-lite-substrate-bundling.md:
// - D1 — bundle path lock: everything lands under substrate/<manifest.path>
// - D3 — prepublish safety envelope: fail fast at three checkpoints
// - RFC B3 — sibling-only source (no RemoteFetchStrategy in 0.1.0)
//
// Risk ledger v3 build wiring:
// @risk: R2 — pure Node; no execSync/spawn/spawnSync
// @risk: R7 — fail-fast: manifest missing, source missing, count mismatch
// @risk: R9 — reject when total bundled size passes 5MB
//
// Runs via package.json prepublishOnly. Reads manifest via:
//   1. env BASSCLEF_SIBLING_ROOT (test override)
//   2. default ../bassclef-upstream relative to CWD

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

const SIZE_CEILING_BYTES = 5 * 1024 * 1024;
const BUNDLE_DIR_NAME = 'substrate';

function fail(message) {
  process.stderr.write(`prepublish-bundle-substrate: ${message}\n`);
  process.exit(1);
}

function resolveSiblingRoot() {
  const override = process.env.BASSCLEF_SIBLING_ROOT;
  if (override && override.length > 0) return resolve(override);
  return resolve(process.cwd(), '..', 'bassclef-upstream');
}

function loadManifest(siblingRoot) {
  const manifestPath = join(siblingRoot, 'lite-manifest.json');
  if (!existsSync(manifestPath)) {
    fail(
      `manifest missing at ${manifestPath}. ` +
        `Check out sunj-labs/bassclef-upstream as a sibling directory, ` +
        `or set BASSCLEF_SIBLING_ROOT to point at the checkout.`
    );
  }
  let raw;
  try {
    raw = readFileSync(manifestPath, 'utf8');
  } catch (err) {
    fail(`cannot read manifest at ${manifestPath}: ${err.code ?? err.message}`);
  }
  let manifest;
  try {
    manifest = JSON.parse(raw);
  } catch (err) {
    fail(`manifest at ${manifestPath} is not valid JSON: ${err.message}`);
  }
  if (!Array.isArray(manifest.entries) || manifest.entries.length === 0) {
    fail(`manifest at ${manifestPath} has no entries[] array or the array is empty.`);
  }
  return { manifest, manifestPath };
}

function preflightSourcesExist(siblingRoot, manifest) {
  const missing = [];
  for (const entry of manifest.entries) {
    const sourcePath = join(siblingRoot, entry.path);
    if (!existsSync(sourcePath)) {
      missing.push(sourcePath);
    }
  }
  if (missing.length > 0) {
    fail(
      `source missing at ${missing[0]}` +
        (missing.length > 1 ? ` (and ${missing.length - 1} more)` : '') +
        `. Check the sibling checkout is current with the manifest.`
    );
  }
}

function copyEntry(siblingRoot, bundleRoot, entry) {
  const sourcePath = join(siblingRoot, entry.path);
  const targetPath = join(bundleRoot, entry.path);
  mkdirSync(dirname(targetPath), { recursive: true, mode: 0o755 });
  const content = readFileSync(sourcePath);
  writeFileSync(targetPath, content);
  return content.length;
}

function postflightChecks(bundleRoot, manifest, totalBytes) {
  const expectedCount = manifest.entries.length;
  // Count files bundled under substrate/ recursively.
  function walk(dir) {
    const names = readdirSync(dir);
    let count = 0;
    for (const name of names) {
      const p = join(dir, name);
      const st = statSync(p);
      if (st.isDirectory()) count += walk(p);
      else count += 1;
    }
    return count;
  }
  const actualCount = walk(bundleRoot);
  if (actualCount !== expectedCount) {
    fail(
      `postflight count mismatch: bundled ${actualCount} files but manifest declared ${expectedCount}. ` +
        `Re-run the script; investigate if the mismatch persists.`
    );
  }
  if (totalBytes > SIZE_CEILING_BYTES) {
    const mb = (totalBytes / (1024 * 1024)).toFixed(2);
    fail(
      `bundled size ${mb}MB is over the 5MB ceiling. ` +
        `Trim the manifest at bassclef-upstream or raise the ceiling in ADR-007 D3.`
    );
  }
}

function main() {
  const siblingRoot = resolveSiblingRoot();
  const { manifest, manifestPath } = loadManifest(siblingRoot);

  preflightSourcesExist(siblingRoot, manifest);

  const bundleRoot = resolve(process.cwd(), BUNDLE_DIR_NAME);
  mkdirSync(bundleRoot, { recursive: true, mode: 0o755 });

  let totalBytes = 0;
  for (const entry of manifest.entries) {
    totalBytes += copyEntry(siblingRoot, bundleRoot, entry);
  }

  postflightChecks(bundleRoot, manifest, totalBytes);

  process.stdout.write(
    `bundled ${manifest.entries.length} files from ${manifestPath} into ${bundleRoot}\n`
  );
  process.exit(0);
}

main();
