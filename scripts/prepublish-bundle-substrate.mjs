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
  // Expected count = manifest.entries.length + 1 (the bundled manifest
  // itself lives at substrate/.bassclef/lite-manifest.json and counts).
  // Per #45 cure — the runtime needs the manifest in the tarball.
  const expectedCount = manifest.entries.length + 1;
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
      `postflight count mismatch: bundled ${actualCount} files but expected ${expectedCount} ` +
        `(${manifest.entries.length} manifest entries + 1 bundled manifest). ` +
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

// Write the bundled manifest into <bundleRoot>/.bassclef/lite-manifest.json.
// copy-substrate.ts reads this file at runtime to know which entries to
// walk. Before #45 the manifest was never bundled — runtime threw + init
// silent-catch hid the failure — adopter got 2 files instead of 149.
// Per issue #45 diagnose + ADR-007 §D3 Amendment part 2 (2026-08-31).
//
// @risk R7 — postflight assert verifies the file lives at the expected
// path with the expected shape (entries[] present + length matches
// manifest.entries).
function writeBundledManifest(bundleRoot, manifest) {
  const targetDir = join(bundleRoot, '.bassclef');
  mkdirSync(targetDir, { recursive: true, mode: 0o755 });
  const targetPath = join(targetDir, 'lite-manifest.json');
  const body = JSON.stringify(manifest, null, 2) + '\n';
  writeFileSync(targetPath, body, { mode: 0o644 });
  return targetPath;
}

// Postflight assert per Saltzer-Schroeder complete mediation — verify
// the bundled manifest lives at the exact runtime path copy-substrate.ts
// L174 expects, with entries[] preserved through the round-trip.
function assertBundledManifestPresent(bundleRoot, expectedEntryCount) {
  const targetPath = join(bundleRoot, '.bassclef', 'lite-manifest.json');
  if (!existsSync(targetPath)) {
    fail(
      `bundled manifest missing at ${targetPath}. ` +
        `writeBundledManifest did not run OR the write silently failed. ` +
        `Re-run the script; if the miss persists, investigate the mkdir + write path.`
    );
  }
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(targetPath, 'utf8'));
  } catch (err) {
    fail(
      `bundled manifest at ${targetPath} is not valid JSON: ${err.message}. ` +
        `The write likely corrupted the file. Re-run the script.`
    );
  }
  if (!Array.isArray(parsed.entries) || parsed.entries.length !== expectedEntryCount) {
    const actual = Array.isArray(parsed.entries) ? parsed.entries.length : 'not-an-array';
    fail(
      `bundled manifest entries[] shape wrong at ${targetPath}: got ${actual}, ` +
        `expected ${expectedEntryCount}. Re-run the script.`
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

  // Write the manifest itself into the bundle for runtime to walk.
  // #45 cure. See ADR-007 §D3 Amendment part 2.
  const bundledManifestPath = writeBundledManifest(bundleRoot, manifest);
  assertBundledManifestPresent(bundleRoot, manifest.entries.length);

  postflightChecks(bundleRoot, manifest, totalBytes);

  process.stdout.write(
    `bundled ${manifest.entries.length} files from ${manifestPath} into ${bundleRoot}\n`
  );
  process.stdout.write(
    `bundled manifest written to ${bundledManifestPath}\n`
  );
  process.exit(0);
}

main();
